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

export class DispatchError extends Error {}

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

export function parseAssignment(role: string, entry: string): Assignment {
  const at = entry.indexOf(' at ');
  // The level is what follows the last ` at `, so a ` at ` inside the model
  // part cannot swallow it.
  const key = at === -1 ? entry : entry.slice(0, at);
  const level = at === -1 ? '' : entry.slice(entry.lastIndexOf(' at ') + 4);
  if (!key.includes('/') || key.includes(' ') || key.startsWith('/')) {
    throw new DispatchError(`dispatch: role '${role}' has a malformed entry: '${entry}'`);
  }
  if (level !== '' && !LEVEL.test(level)) {
    throw new DispatchError(`dispatch: role '${role}' has a malformed thinking level in: '${entry}'`);
  }
  const slash = key.indexOf('/');
  const provider = key.slice(0, slash);
  const model = key.slice(slash + 1);
  return {
    role,
    provider,
    model,
    level: level === '' ? undefined : level,
    text: entry,
    key,
    runtime: runtimeFor(provider, model),
  };
}

export function roleAssignments(role: string, file?: string): Assignment[] {
  if (!ROLE_TAG.test(role)) throw new DispatchError(`dispatch: '${role}' is not a role tag`);
  const path = file ?? defaultTableFile();
  const line = tableLines(path).find((text) => text.startsWith(`${role}:`));
  if (line === undefined) {
    throw new DispatchError(`dispatch: no recommendation for role '${role}' in ${path}`);
  }
  const assignments: Assignment[] = [];
  const seen = new Set<string>();
  // Every entry is validated before any is returned, so a malformed entry
  // refuses the whole role rather than routing on a partial list.
  for (const entry of line.slice(line.indexOf(':') + 1).split(';')) {
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

export function firstAssignment(role: string, file?: string): Assignment {
  return roleAssignments(role, file)[0];
}

export function tableAssignments(file?: string): Assignment[] {
  const path = file ?? defaultTableFile();
  const assignments: Assignment[] = [];
  const seen = new Set<string>();
  for (const line of tableLines(path)) {
    const tag = ROLE_LINE.exec(line);
    if (tag === null) continue;
    const role = tag[1];
    // A role's line is its first one, so a second line for that role states no
    // assignment the table does not already hold.
    if (seen.has(role)) continue;
    seen.add(role);
    // A listing skips the role a malformed line refuses, so one typo does not
    // cost the operator every other role in the table.
    try {
      assignments.push(...roleAssignments(role, path));
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
  // forwarded and fails at the provider. A default here is the same guess with
  // the same symptom, so an absent model refuses.
  if (model === '') {
    throw new DispatchError(`dispatch: the runtime for '${provider}' needs the model as well`);
  }
  return model.endsWith('-free') ? 'opencode' : 'pi';
}
