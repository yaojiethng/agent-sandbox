import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { chmodSync, mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  DispatchError,
  defaultTableFile,
  firstAssignment,
  parseAssignment,
  roleAssignments,
  tableAssignments,
} from '../../../src/libs/dispatch/table.ts';
import { argvFor, commandFor } from '../../../src/libs/dispatch/launch.ts';

const HERE = dirname(fileURLToPath(import.meta.url));
const CLI = resolve(HERE, '..', '..', '..', 'src', 'libs', 'dispatch', 'cli.ts');
const BIN = '/opt/opencode';
const BRIEF = '/tmp/brief.md';

// The binary is pinned, so no case depends on what this image happens to
// install and the expected command strings stay literal.
process.env.DISPATCH_OPENCODE_BIN = BIN;

// Each case writes its own table, so no case reads the operator's real file and
// none can disturb another.
function tableFile(body: string): string {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-table-'));
  const path = join(dir, 'model-recommendations.md');
  writeFileSync(path, body);
  return path;
}

function briefFile(body: string): string {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-brief-'));
  const path = join(dir, 'brief.md');
  writeFileSync(path, body);
  return path;
}

function refusal(run: () => unknown): string {
  try {
    run();
  } catch (error) {
    assert.ok(error instanceof DispatchError, `expected a DispatchError, got ${String(error)}`);
    return error.message;
  }
  assert.fail('expected a refusal');
}

function cli(argv: string[], env: NodeJS.ProcessEnv = {}): { code: number | null; out: string; err: string } {
  const run = spawnSync(process.execPath, [CLI, ...argv], {
    encoding: 'utf8',
    env: { ...process.env, DISPATCH_OPENCODE_BIN: BIN, ...env },
  });
  return { code: run.status, out: run.stdout, err: run.stderr };
}

// --- the grammar -----------------------------------------------------------

test('a role line resolves in written order, with a repeat dropped', () => {
  const file = tableFile('_CHAIN: opencode/a-free at high; deepseek/b at low; opencode/a-free at high\n');
  assert.deepEqual(
    roleAssignments('_CHAIN', file).map((a) => a.text),
    ['opencode/a-free at high', 'deepseek/b at low'],
  );
});

test('an entry without a level parses, and its level is undefined', () => {
  const a = parseAssignment('_REVIEWER', 'opencode-go/deepseek-v4.1-flash');
  assert.equal(a.level, undefined);
  assert.equal(a.key, 'opencode-go/deepseek-v4.1-flash');
  assert.equal(a.model, 'deepseek-v4.1-flash');
});

test('an entry with a level carries it beside the key, not inside it', () => {
  const a = parseAssignment('_REVIEWER', 'openrouter/z-ai/glm-5.3-flash at high');
  assert.equal(a.key, 'openrouter/z-ai/glm-5.3-flash');
  assert.equal(a.provider, 'openrouter');
  assert.equal(a.model, 'z-ai/glm-5.3-flash');
  assert.equal(a.level, 'high');
});

test('an entry is trimmed of the whitespace around it', () => {
  const file = tableFile('_SPACE:   opencode/a-free at high  ;  ;\tdeepseek/b\n');
  assert.deepEqual(
    roleAssignments('_SPACE', file).map((a) => a.text),
    ['opencode/a-free at high', 'deepseek/b'],
  );
});

test('a second line for one role states no assignment, because the first is the line', () => {
  const file = tableFile('_DUP: deepseek/first\n_DUP: deepseek/second\n');
  assert.deepEqual(
    tableAssignments(file).map((a) => a.text),
    ['deepseek/first'],
  );
});

test('a heading, a Format line and prose are not roles', () => {
  const file = tableFile(
    [
      '# Model recommendations',
      'Format: `_ROLE: <provider>/<model> at <level>`',
      'One line per role.',
      '_REAL: deepseek/x at high',
      '',
    ].join('\n'),
  );
  assert.deepEqual(
    tableAssignments(file).map((a) => a.role),
    ['_REAL'],
  );
});

test('the head of a role is its preferred assignment', () => {
  const file = tableFile('_HEAD: opencode/a-free at high; deepseek/b at low\n');
  assert.equal(firstAssignment('_HEAD', file).key, 'opencode/a-free');
});

test('the default table file honours the override, then the repository copy, then the agent home', () => {
  assert.equal(defaultTableFile({ DISPATCH_REC_FILE: '/x/table.md' }), '/x/table.md');
  const copy = mkdtempSync(join(tmpdir(), 'dispatch-repo-'));
  mkdirSync(join(copy, '.agents'));
  writeFileSync(join(copy, '.agents', 'model-recommendations.md'), '_X: deepseek/x\n');
  assert.equal(
    defaultTableFile({ DISPATCH_REPO_ROOT: copy, AGENT_HOME: '/home/agent' }),
    join(copy, '.agents', 'model-recommendations.md'),
  );
  // A tree without the committed copy falls back to the agent home, which is
  // the single-file mount a container carries.
  const bare = mkdtempSync(join(tmpdir(), 'dispatch-bare-'));
  assert.equal(
    defaultTableFile({ DISPATCH_REPO_ROOT: bare, AGENT_HOME: '/home/agent' }),
    '/home/agent/model-recommendations.md',
  );
  assert.equal(
    defaultTableFile({ DISPATCH_REPO_ROOT: bare, HOME: '/home/user' }),
    '/home/user/.pi/model-recommendations.md',
  );
});

// --- the runtime -----------------------------------------------------------

test('a free model on an OpenCode provider resolves to the OpenCode CLI', () => {
  assert.equal(parseAssignment('_X', 'opencode/x-free').runtime, 'opencode');
});

test('a paid model on an OpenCode provider resolves to pi', () => {
  assert.equal(parseAssignment('_X', 'opencode/x').runtime, 'pi');
});

test('the OpenCode Go gateway is a pi provider, free model or not', () => {
  assert.equal(parseAssignment('_X', 'opencode-go/x-free').runtime, 'pi');
  assert.equal(parseAssignment('_X', 'opencode-go/x').runtime, 'pi');
});

test('a provider outside the OpenCode set resolves to pi', () => {
  assert.equal(parseAssignment('_X', 'deepseek/x').runtime, 'pi');
});

test('a level suffix never changes the runtime', () => {
  assert.equal(parseAssignment('_X', 'opencode/x-free at high').runtime, 'opencode');
  assert.equal(parseAssignment('_X', 'opencode/x at high').runtime, 'pi');
  assert.equal(parseAssignment('_X', 'opencode-go/x-free at low').runtime, 'pi');
});

test('the OpenCode set is declared, so a new provider is a data edit', () => {
  const before = process.env.DISPATCH_OPENCODE_PROVIDERS;
  process.env.DISPATCH_OPENCODE_PROVIDERS = 'opencode opencode-go';
  try {
    assert.equal(parseAssignment('_X', 'opencode-go/x-free').runtime, 'opencode');
  } finally {
    if (before === undefined) delete process.env.DISPATCH_OPENCODE_PROVIDERS;
    else process.env.DISPATCH_OPENCODE_PROVIDERS = before;
  }
});

// --- the refusals ----------------------------------------------------------

test('a malformed entry refuses the role', () => {
  const file = tableFile('_BAD: nonsense\n');
  assert.equal(
    refusal(() => roleAssignments('_BAD', file)),
    "dispatch: role '_BAD' has a malformed entry: 'nonsense'",
  );
  // The message names the entry as written, level and all, not the model part.
  const levelled = tableFile('_BAD: nonsense at high\n');
  assert.equal(
    refusal(() => roleAssignments('_BAD', levelled)),
    "dispatch: role '_BAD' has a malformed entry: 'nonsense at high'",
  );
});

test('an entry whose model starts with a slash is malformed', () => {
  const file = tableFile('_BAD: /model\n');
  assert.equal(refusal(() => roleAssignments('_BAD', file)), "dispatch: role '_BAD' has a malformed entry: '/model'");
});

test('a malformed thinking level refuses the role', () => {
  const file = tableFile('_BAD: deepseek/x at HIGH\n');
  assert.equal(
    refusal(() => roleAssignments('_BAD', file)),
    "dispatch: role '_BAD' has a malformed thinking level in: 'deepseek/x at HIGH'",
  );
});

test('a malformed entry refuses the whole role rather than a partial list', () => {
  const file = tableFile('_BAD: deepseek/x at high; nonsense; deepseek/y\n');
  assert.equal(
    refusal(() => roleAssignments('_BAD', file)),
    "dispatch: role '_BAD' has a malformed entry: 'nonsense'",
  );
});

test('a non-role tag refuses', () => {
  const file = tableFile('_REAL: deepseek/x\n');
  assert.equal(refusal(() => roleAssignments('Format', file)), "dispatch: 'Format' is not a role tag");
});

test('an absent role table refuses and names the file', () => {
  const path = join(tmpdir(), 'dispatch-table-absent', 'model-recommendations.md');
  assert.equal(refusal(() => roleAssignments('_X', path)), `dispatch: role table not found: ${path}`);
});

test('a role with no line refuses and names the file', () => {
  const file = tableFile('_REAL: deepseek/x\n');
  assert.equal(refusal(() => roleAssignments('_ABSENT', file)), `dispatch: no recommendation for role '_ABSENT' in ${file}`);
});

test('a role line naming no model refuses', () => {
  const file = tableFile('_EMPTY:  ;  ;\n');
  assert.equal(refusal(() => roleAssignments('_EMPTY', file)), "dispatch: role '_EMPTY' names no model");
});

test('the runtime for an OpenCode provider needs the model as well', () => {
  assert.equal(
    refusal(() => parseAssignment('_X', 'opencode/ at high')),
    "dispatch: the runtime for 'opencode' needs the model as well",
  );
});

// --- the command string ----------------------------------------------------

test('an OpenCode assignment prints the CLI command it runs', () => {
  const a = parseAssignment('_IMPL', 'opencode/x-free at high');
  assert.equal(
    commandFor(a, { brief: BRIEF, dir: '/work' }),
    `${BIN} run --auto --print-logs --log-level ERROR --title brief.md --dir /work -m opencode/x-free --variant high "$(cat ${BRIEF})"`,
  );
});

test('a pi assignment prints the pi command it runs', () => {
  const a = parseAssignment('_IMPL', 'deepseek/deepseek-flash at high');
  assert.equal(
    commandFor(a, { brief: BRIEF, dir: '/work' }),
    `pi --provider deepseek --model deepseek-flash --thinking high -p "$(cat ${BRIEF})"`,
  );
});

test('an assignment without a level prints no level flag', () => {
  const a = parseAssignment('_IMPL', 'deepseek/deepseek-flash');
  assert.equal(
    commandFor(a, { brief: BRIEF, dir: '/work' }),
    `pi --provider deepseek --model deepseek-flash -p "$(cat ${BRIEF})"`,
  );
});

test('a session resumes a run on both runtimes', () => {
  const pi = parseAssignment('_IMPL', 'deepseek/x at high');
  assert.equal(
    commandFor(pi, { brief: BRIEF, dir: '/work', session: 'sess-1' }),
    `pi --provider deepseek --model x --thinking high --session sess-1 -p "$(cat ${BRIEF})"`,
  );
  const opencode = parseAssignment('_ADVISOR', 'opencode/x-free at high');
  assert.equal(
    commandFor(opencode, { brief: BRIEF, dir: '/work', session: 'sess-2' }),
    `${BIN} run --auto --print-logs --log-level ERROR --title brief.md --dir /work -m opencode/x-free --variant high --session sess-2 "$(cat ${BRIEF})"`,
  );
});

test('a value with a space is shell-quoted, so the command re-reads as one word', () => {
  const a = parseAssignment('_ADVISOR', 'opencode/x-free at high');
  assert.equal(
    commandFor(a, { brief: '/tmp/my brief.md', dir: '/work dir' }),
    `${BIN} run --auto --print-logs --log-level ERROR --title my\\ brief.md --dir /work\\ dir -m opencode/x-free --variant high "$(cat /tmp/my\\ brief.md)"`,
  );
});

test('the argv is the same command, with the brief read as its own argument', () => {
  const brief = briefFile('the brief text\n\n');
  const pi = parseAssignment('_IMPL', 'deepseek/x at high');
  assert.deepEqual(argvFor(pi, { brief, dir: '/work' }), [
    'pi',
    '--provider',
    'deepseek',
    '--model',
    'x',
    '--thinking',
    'high',
    '-p',
    'the brief text',
  ]);
  const opencode = parseAssignment('_ADVISOR', 'opencode/x-free at high');
  assert.deepEqual(argvFor(opencode, { brief, dir: '/work' }), [
    BIN,
    'run',
    '--auto',
    '--print-logs',
    '--log-level',
    'ERROR',
    '--title',
    'brief.md',
    '--dir',
    '/work',
    '-m',
    'opencode/x-free',
    '--variant',
    'high',
    'the brief text',
  ]);
});

// --- the command line ------------------------------------------------------

test('table roles prints every role in file order and preference order', () => {
  const file = tableFile('_ONE: opencode/a-free at high; deepseek/b\n_Format: prose\n_TWO: opencode-go/c-free at low\n');
  assert.deepEqual(cli(['table', 'roles', '--file', file]), {
    code: 0,
    out: '_ONE opencode/a-free at high opencode\n_ONE deepseek/b pi\n_TWO opencode-go/c-free at low pi\n',
    err: '',
  });
});

test('table list prints one assignment per line, in the role order', () => {
  const file = tableFile('_ONE: opencode/a-free at high; deepseek/b; opencode/a-free at high\n');
  assert.deepEqual(cli(['table', 'list', '--role', '_ONE', '--file', file]), {
    code: 0,
    out: 'opencode/a-free at high\ndeepseek/b\n',
    err: '',
  });
});

test('table resolve prints the key, the level and the runtime, with - for an absent level', () => {
  const file = tableFile('_ONE: opencode/a-free at high; deepseek/b\n_TWO: deepseek/c\n');
  assert.deepEqual(cli(['table', 'resolve', '--role', '_ONE', '--file', file]), {
    code: 0,
    out: 'opencode/a-free high opencode\n',
    err: '',
  });
  assert.deepEqual(cli(['table', 'resolve', '--role', '_TWO', '--file', file]), {
    code: 0,
    out: 'deepseek/c - pi\n',
    err: '',
  });
});

test('a refused role exits 1 with the message on stderr and nothing on stdout', () => {
  const file = tableFile('_REAL: deepseek/x\n');
  for (const argv of [
    ['table', 'list', '--role', '_ABSENT', '--file', file],
    ['table', 'resolve', '--role', 'Format', '--file', file],
    ['table', 'roles', '--file', join(tmpdir(), 'absent-table.md')],
  ]) {
    const run = cli(argv);
    assert.equal(run.code, 1, `exit code for ${argv.join(' ')}`);
    assert.equal(run.out, '');
    assert.match(run.err, /^dispatch: /);
  }
});

test('command prints the role command', () => {
  const file = tableFile('_IMPL: deepseek/deepseek-flash at high\n_ADVISOR: opencode/x-free at high\n');
  assert.deepEqual(cli(['command', '--role', '_IMPL', '--brief', BRIEF, '--dir', '/work', '--file', file]), {
    code: 0,
    out: `pi --provider deepseek --model deepseek-flash --thinking high -p "$(cat ${BRIEF})"\n`,
    err: '',
  });
  assert.deepEqual(cli(['command', '--role', '_ADVISOR', '--brief', BRIEF, '--dir', '/work', '--file', file]), {
    code: 0,
    out: `${BIN} run --auto --print-logs --log-level ERROR --title brief.md --dir /work -m opencode/x-free --variant high "$(cat ${BRIEF})"\n`,
    err: '',
  });
});

test('command --model overrides the role pair and keeps the role level', () => {
  const file = tableFile('_IMPL: deepseek/deepseek-flash at high\n');
  assert.equal(
    cli(['command', '--role', '_IMPL', '--brief', BRIEF, '--dir', '/work', '--model', 'opencode/y-free', '--file', file])
      .out,
    `${BIN} run --auto --print-logs --log-level ERROR --title brief.md --dir /work -m opencode/y-free --variant high "$(cat ${BRIEF})"\n`,
  );
});

test('command --thinking overrides the role level and keeps the role pair', () => {
  const file = tableFile('_IMPL: deepseek/deepseek-flash at high\n');
  assert.equal(
    cli(['command', '--role', '_IMPL', '--brief', BRIEF, '--dir', '/work', '--thinking', 'low', '--file', file]).out,
    `pi --provider deepseek --model deepseek-flash --thinking low -p "$(cat ${BRIEF})"\n`,
  );
});

test('command without a role, a brief or a dir refuses', () => {
  const run = cli(['command', '--role', '_IMPL', '--brief', BRIEF]);
  assert.equal(run.code, 1);
  assert.equal(run.err, 'dispatch: ROLE, BRIEF and DIR are required\n');
});

test("command refuses a pin that is not provider/model", () => {
  const file = tableFile('_IMPL: deepseek/deepseek-flash at high\n');
  const run = cli(['command', '--role', '_IMPL', '--brief', BRIEF, '--dir', '/work', '--model', 'justmodel', '--file', file]);
  assert.equal(run.code, 1);
  assert.equal(run.out, '');
  assert.equal(run.err, "dispatch: the role's model 'justmodel' is not provider/model\n");
});

test('table resolve --entry answers for the entry given, not the role head', () => {
  const file = tableFile('_ONE: deepseek/head at low\n');
  assert.deepEqual(cli(['table', 'resolve', '--role', '_ONE', '--entry', 'opencode/x-free at high', '--file', file]), {
    code: 0,
    out: 'opencode/x-free high opencode\n',
    err: '',
  });
});

// A runtime is runnable when its binary resolves on PATH and is executable, so
// each case gives PATH a fixture and never depends on what this host installs.
function pathWith(name: string): string {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-path-'));
  writeFileSync(join(dir, name), '#!/bin/sh\n');
  chmodSync(join(dir, name), 0o755);
  return dir;
}

test('table check passes when an assignment reaches a runtime present here', () => {
  const file = tableFile('_CLI: opencode/x-free at high\n_PI: deepseek/x at high\n');
  assert.deepEqual(cli(['table', 'check', '--role', '_CLI', '--file', file], { DISPATCH_OPENCODE_BIN: pathWith('opencode') + '/opencode' }), {
    code: 0,
    out: '',
    err: '',
  });
  assert.deepEqual(cli(['table', 'check', '--role', '_PI', '--file', file], { PATH: pathWith('pi') }), {
    code: 0,
    out: '',
    err: '',
  });
});

test('table check names the runtime that is missing', () => {
  const file = tableFile('_CLI: opencode/x-free at high\n_PI: deepseek/x at high\n');
  assert.deepEqual(cli(['table', 'check', '--role', '_CLI', '--file', file], { DISPATCH_OPENCODE_BIN: '/no/such/opencode' }), {
    code: 1,
    out: '',
    err: "dispatch: role '_CLI' needs the opencode CLI, not runnable: /no/such/opencode\n",
  });
  assert.deepEqual(cli(['table', 'check', '--role', '_PI', '--file', file], { PATH: '/nonexistent' }), {
    code: 1,
    out: '',
    err: "dispatch: role '_PI' needs the pi CLI, not on PATH\n",
  });
});

test('table check passes on a runnable fallback', () => {
  const file = tableFile('_MIX: opencode/x-free at high; deepseek/y at high\n');
  assert.deepEqual(
    cli(['table', 'check', '--role', '_MIX', '--file', file], {
      DISPATCH_OPENCODE_BIN: '/no/such/opencode',
      PATH: pathWith('pi'),
    }),
    { code: 0, out: '', err: '' },
  );
});
