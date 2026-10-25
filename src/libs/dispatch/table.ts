// The role table's grammar, its resolution and the runtime decision.
//
// The table is one line per role, an ordered list of assignments:
//
//   _REVIEWER: opencode/minimax-flash-free at high; deepseek/deepseek-flash at high
//
// The first assignment is preferred and each later one is its fallback. This
// module owns the grammar, so a caller reads an assignment and never parses a
// line. Every refusal carries the message the shell seam printed, byte for byte,
// because a caller reads the same text whichever entry point refused.

import { DispatchError, UsageError } from './errors.ts';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

export type Runtime = 'pi' | 'opencode';

export type Assignment = {
  role: string;
  provider: string;
  model: string;
  level?: string;
  text: string;
  key: string;
  runtime: Runtime;
};

const ROLE_TAG = /^_[A-Z][A-Z0-9_]*$/;
const ROLE_LINE = /^(_[A-Z][A-Z0-9_]*):/;
const LEVEL = /^[a-z]+$/;
// The whitespace a body entry is trimmed of, which is the set `[[:space:]]`
// names in the shell seam's `sed`.
const EDGE_SPACE = /^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g;
const SEPARATOR = /[ \t\n]+/;

// The providers only the OpenCode CLI serves. pi's own registry is the
// complement, so a provider absent from this list is reached by pi.
const OPENCODE_PROVIDERS = 'opencode';

export function defaultTableFile(env: NodeJS.ProcessEnv = process.env): string {
  if (env.DISPATCH_REC_FILE) return env.DISPATCH_REC_FILE;
  // The table is version controlled with the repository, so the tree this
  // module lives in is read before the agent home. The agent-home copy is a
  // single-file bind mount in a container, so it is the fallback rather than
  // the choice.
  const root = env.DISPATCH_REPO_ROOT || resolve(import.meta.dirname, '..', '..', '..');
  const copy = `${root}/.agents/model-recommendations.md`;
  if (existsSync(copy)) return copy;
  return `${env.AGENT_HOME || `${env.HOME ?? ''}/.pi`}/model-recommendations.md`;
}

/** The one constructor of an assignment: key, text and runtime are derived. */
export function assignmentOf(parts: {
  role: string;
  provider: string;
  model: string;
  level?: string;
}): Assignment {
  const key = `${parts.provider}/${parts.model}`;
  return {
    role: parts.role,
    provider: parts.provider,
    model: parts.model,
    key,
    text: parts.level === undefined ? key : `${key} at ${parts.level}`,
    runtime: runtimeFor(parts.provider, parts.model),
    level: parts.level,
  };
}

export function parseAssignment(role: string, entry: string, pin = false): Assignment {
  // One grammar for an assignment. A pin differs only in whose value it is, so
  // it says so in the refusal rather than repeating the checks.
  const malformed = (): DispatchError =>
    new (pin ? UsageError : DispatchError)(
      pin
        ? `dispatch: the role's model '${entry}' is not provider/model`
        : `dispatch: role '${role}' has a malformed entry: '${entry}'`,
    );
  // The level follows the last ` at `, and the key is the rest. A second
  // delimiter therefore lands in the key and is refused as malformed, rather
  // than being silently discarded.
  const at = entry.lastIndexOf(' at ');
  const key = at === -1 ? entry : entry.slice(0, at);
  const level = at === -1 ? '' : entry.slice(at + 4);
  if (!key.includes('/') || key.includes(' ') || key.startsWith('/')) throw malformed();
  if (level !== '' && !LEVEL.test(level)) {
    throw new (pin ? UsageError : DispatchError)(
      pin
        ? `dispatch: the role's model '${entry}' has a malformed thinking level`
        : `dispatch: role '${role}' has a malformed thinking level in: '${entry}'`,
    );
  }
  const slash = key.indexOf('/');
  const provider = key.slice(0, slash);
  const model = key.slice(slash + 1);
  // An empty model reaches `pi --model ''`, so the grammar refuses it here
  // rather than in every caller that builds a pin.
  if (model === '') throw malformed();
  return assignmentOf({ role, provider, model, level: level === '' ? undefined : level });
}

/** A caller's thinking level: the grammar is the table's, and so is the usage refusal. */
export function decodeLevel(value: string | undefined): string | undefined {
  if (value === undefined || value === '') return undefined;
  if (!LEVEL.test(value)) throw new UsageError(`dispatch: --thinking '${value}' is not a thinking level`);
  return value;
}

export function withLevel(assignment: Assignment, level: string): Assignment {
  const parsed = decodeLevel(level);
  return assignmentOf({
    role: assignment.role,
    provider: assignment.provider,
    model: assignment.model,
    level: parsed,
  });
}

/** The caller's own assignment, with the caller's level applied once. */
export function pinned(role: string, pin: string, level?: string): Assignment {
  const base = parseAssignment(role, pin, true);
  return level === undefined ? base : withLevel(base, level);
}

type RoleLine = { role: string; body: string };

// One matcher for the role-line grammar, so a listing and a resolution cannot
// disagree about what a role's line is.
function parseRoleLine(line: string): RoleLine | undefined {
  const tag = ROLE_LINE.exec(line);
  if (tag === null) return undefined;
  return { role: tag[1], body: line.slice(tag[0].length) };
}

function assignmentsFor(role: string, body: string): Assignment[] {
  const assignments: Assignment[] = [];
  const seen = new Set<string>();
  // Every entry is validated before any is returned, so a malformed entry
  // refuses the whole role rather than routing on a partial list.
  for (const entry of body.split(';')) {
    const text = entry.replace(EDGE_SPACE, '');
    if (text === '') continue;
    const assignment = parseAssignment(role, text);
    // A repeat adds no fallback, and the first occurrence is the one kept.
    if (seen.has(text)) continue;
    seen.add(text);
    assignments.push(assignment);
  }
  if (assignments.length === 0) {
    throw new DispatchError(`dispatch: role '${role}' names no model`);
  }
  return assignments;
}

export function roleAssignments(role: string, path: string): Assignment[] {
  if (!ROLE_TAG.test(role)) throw new DispatchError(`dispatch: '${role}' is not a role tag`);
  const line = tableLines(path).map(parseRoleLine).find((candidate) => candidate?.role === role);
  if (line === undefined) {
    throw new DispatchError(`dispatch: no recommendation for role '${role}' in ${path}`);
  }
  return assignmentsFor(role, line.body);
}

export function firstAssignment(role: string, path: string): Assignment {
  return roleAssignments(role, path)[0];
}

export function tableAssignments(path: string): Assignment[] {
  const assignments: Assignment[] = [];
  const seen = new Set<string>();
  for (const parsed of tableLines(path).map(parseRoleLine)) {
    if (parsed === undefined) continue;
    // A role's line is its first one, so a second line for that role states no
    // assignment the table does not already hold.
    if (seen.has(parsed.role)) continue;
    seen.add(parsed.role);
    // A listing skips the role a malformed line refuses, so one typo does not
    // cost the operator every other role in the table.
    try {
      assignments.push(...assignmentsFor(parsed.role, parsed.body));
    } catch (error) {
      if (!(error instanceof DispatchError)) throw error;
    }
  }
  return assignments;
}

function tableLines(path: string): string[] {
  try {
    return readFileSync(path, 'utf8').split('\n');
  } catch {
    throw new DispatchError(`dispatch: role table not found: ${path}`);
  }
}

function runtimeFor(provider: string, model: string): Runtime {
  const declared = process.env.DISPATCH_OPENCODE_PROVIDERS || OPENCODE_PROVIDERS;
  if (!declared.split(SEPARATOR).includes(provider)) return 'pi';
  // The decision needs the model, not only the provider: keying on the
  // provider alone sends a paid model through the CLI, where the request is
  // forwarded and fails at the provider.
  return model.endsWith('-free') ? 'opencode' : 'pi';
}
