// The session's route memory: one small JSON map, replaced atomically.
//
// The file lives in the container's transient area and is namespaced by
// session, so it dies with the container. It is never a bind-mounted path: a
// mount would outlive the attempts that justify it.

import { readFileSync, writeFileSync, renameSync, mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import type { State } from './types.ts';

export function emptyState(session: string): State {
  return { version: 1, session, routes: {}, usage: {} };
}

export function defaultPath(): string {
  if (process.env.DISPATCH_STATE_FILE) return process.env.DISPATCH_STATE_FILE;
  const session = process.env.SESSION_ID || 'default';
  return `/tmp/agent-sandbox/dispatch-state-${session}.json`;
}

export function load(path: string, session: string): State {
  try {
    const parsed = JSON.parse(readFileSync(path, 'utf8')) as State;
    if (parsed && parsed.version === 1 && parsed.routes) return parsed;
  } catch {
    // A missing or unreadable file is an empty memory, never an error: a fresh
    // session legitimately knows nothing.
  }
  return emptyState(session);
}

export function save(path: string, state: State): void {
  mkdirSync(dirname(path), { recursive: true });
  // Write beside the target, then rename, so a concurrent reader sees either
  // the previous map or the next one and never a half-written file.
  const temp = `${path}.${process.pid}.tmp`;
  writeFileSync(temp, `${JSON.stringify(state, null, 2)}\n`);
  renameSync(temp, path);
}
