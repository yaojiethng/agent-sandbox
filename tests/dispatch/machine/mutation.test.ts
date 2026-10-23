// The mutation gate for the dispatch library. Each row is a deliberate break of
// an invariant the module holds by construction, replayed against a copy of
// the module and the suite in a temp mirror. The repository tree is never the
// subject, so a row that dies mid-run cannot leave a mutant behind.
//
// A green suite only proves the machine while a broken one goes red, so every
// row must turn its named case red. The control row replays the same mirror
// unedited and must stay green: without it a mirror the suite cannot run green
// in turns every break red, and every row passes for free.

import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, '..', '..', '..');
const MODULE_DIR = 'src/libs/dispatch';
const SUITE_DIR = 'tests/dispatch/machine';

type Row = {
  id: string;
  invariant: string;
  file: string;
  find: string;
  replace: string;
  test: string;
  expect: string;
};

const ROWS: Row[] = [
  {
    id: 'M1',
    invariant: 'I1',
    file: 'machine.ts',
    find: 'until: Math.max(until, previousUntil),',
    replace: 'until: until,',
    test: 'machine.test.ts',
    expect: 'a failure never brings the next attempt earlier than the record already puts it',
  },
  {
    id: 'M2',
    invariant: 'I2',
    file: 'machine.ts',
    find: "      if (o.scope === 'request') return route;\n",
    replace: '',
    test: 'machine.test.ts',
    expect: '[R8] a malformed request leaves the route record untouched',
  },
  {
    id: 'M3',
    invariant: 'I3',
    file: 'machine.ts',
    find: [
      '    default:',
      '      // Unknown text is a statement about the classifier, not about the route.',
      '      return route;',
    ].join('\n'),
    replace: ['    default:', "      return { state: 'dead' };"].join('\n'),
    test: 'machine.test.ts',
    expect: '[R9] an unknown sentence says nothing about the route',
  },
  {
    id: 'M4',
    invariant: 'I4',
    file: 'classify.ts',
    find: ["    class: 'capability',", "    scope: 'request',"].join('\n'),
    replace: ["    class: 'transient',", "    scope: 'request',"].join('\n'),
    test: 'classify.test.ts',
    expect: 'a malformed request is capability on the request',
  },
  {
    // T1 and T2 pin the table module's two standing rules. A machine transition
    // carries its invariant's id, so those rows cite one; the table's rules are
    // stated without ids, in `docs/reference/dispatch.md` `## Requirements` and
    // `docs/reference/terminology.md` `## runtime`, so these two name them T1 and
    // T2.
    id: 'M5',
    invariant: 'T1',
    file: 'table.ts',
    find: "  return model.endsWith('-free') ? 'opencode' : 'pi';",
    replace: "  return 'opencode';",
    test: 'table.test.ts',
    expect: 'a paid model on an OpenCode provider resolves to pi',
  },
  {
    id: 'M6',
    invariant: 'T2',
    file: 'table.ts',
    find: "  if (!key.includes('/') || key.includes(' ') || key.startsWith('/')) {",
    replace: '  if (false) {',
    test: 'table.test.ts',
    expect: 'a malformed entry refuses the role',
  },
];

const ROW_TESTS = [...new Set(ROWS.map((row) => row.test))];

// The replayed suite runs in well under a second, so this bounds a hung replay
// rather than a slow one, and it stays inside the file's own test deadline.
const REPLAY_TIMEOUT_MS = 30_000;

type Replay = { status: number | null; output: string };

// The mirror holds the two subtrees the suite's imports reach, at the paths
// those imports expect, so `../../../src/libs/dispatch/...` resolves unchanged.
function buildMirror(): string {
  const root = mkdtempSync(join(tmpdir(), 'dispatch-mutation-'));
  cpSync(join(REPO_ROOT, MODULE_DIR), join(root, MODULE_DIR), { recursive: true });
  cpSync(join(REPO_ROOT, SUITE_DIR), join(root, SUITE_DIR), { recursive: true });
  return root;
}

function replay(root: string, testFiles: readonly string[]): Replay {
  const env = { ...process.env };
  // `node --test` marks its children with NODE_TEST_CONTEXT, and a child that
  // keeps the marker reads its own `--test` argument as a recursive run and
  // exits 0, which would turn every break green.
  delete env.NODE_TEST_CONTEXT;
  const run = spawnSync(
    process.execPath,
    ['--test', ...testFiles.map((file) => join(root, SUITE_DIR, file))],
    { cwd: root, encoding: 'utf8', timeout: REPLAY_TIMEOUT_MS, env },
  );
  return { status: run.status, output: `${run.stdout}\n${run.stderr}` };
}

// A break must hit its anchor exactly once. An absent or ambiguous anchor is a
// row that drifted from the code, and replaying it unedited would read as a
// surviving break rather than as a stale row.
function breakOnce(root: string, row: Row): void {
  const file = join(root, MODULE_DIR, row.file);
  const before = readFileSync(file, 'utf8');
  const at = before.indexOf(row.find);
  assert.ok(at >= 0, `${row.id}: the find text is not in ${row.file}`);
  assert.equal(before.indexOf(row.find, at + 1), -1, `${row.id}: the find text appears more than once in ${row.file}`);
  writeFileSync(file, before.slice(0, at) + row.replace + before.slice(at + row.find.length), 'utf8');
}

function failedWith(output: string, name: string): boolean {
  return output
    .split('\n')
    .some((line) => /^\s*not ok \d+ - /.test(line) && line.includes(name));
}

test('control: the unedited mirror passes the row suites', () => {
  const root = buildMirror();
  let run: Replay;
  try {
    run = replay(root, ROW_TESTS);
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
  assert.equal(run.status, 0, `the unedited mirror must pass, or every break reads as proof:\n${run.output}`);
  console.log(`control  unedited  green: ${ROW_TESTS.join(', ')}`);
});

for (const row of ROWS) {
  test(`${row.id} ${row.invariant}: ${row.expect}`, () => {
    const root = buildMirror();
    let run: Replay;
    try {
      breakOnce(root, row);
      run = replay(root, [row.test]);
    } finally {
      rmSync(root, { recursive: true, force: true });
    }
    assert.ok(run.status !== null, `${row.id}: the replay hit its deadline, so it proves nothing:\n${run.output}`);
    assert.notEqual(run.status, 0, `${row.id}: the ${row.invariant} break left ${row.test} green, so the invariant is not pinned:\n${run.output}`);
    assert.ok(failedWith(run.output, row.expect), `${row.id}: the named case did not go red, so another failure explains the exit code:\n${run.output}`);
    console.log(`${row.id}  ${row.invariant}  proven: ${row.test} failed at "${row.expect}"`);
  });
}
