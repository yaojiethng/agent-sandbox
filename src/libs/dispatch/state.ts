// The session's route memory: one small JSON map, replaced atomically, and the
// one transaction every attempt records through.
//
// The file lives in the container's transient area and is namespaced by
// session, so it dies with the container. It is never a bind-mounted path: a
// mount would outlive the attempts that justify it.

import { closeSync, mkdirSync, openSync, readFileSync, renameSync, unlinkSync, writeFileSync, writeSync } from 'node:fs';
import { dirname } from 'node:path';
import { REASONS, applyWrites } from './machine.ts';
import { DispatchError } from './errors.ts';
import type { Outcome, OutcomeWrite, Reason, RouteRecord, State } from './types.ts';

const LOCK_WAIT_MS = 5;
const LOCK_LIMIT_MS = 2000;
const sleepCell = new Int32Array(new SharedArrayBuffer(4));

// A lock names its holder, so a lock left by a process that died can be taken
// over instead of refusing every later attempt for the rest of the session.
function lockHolder(lock: string): number | undefined {
  try {
    const pid = Number(readFileSync(lock, 'utf8').trim().split(/\s+/)[0]);
    return Number.isInteger(pid) && pid > 0 ? pid : undefined;
  } catch {
    return undefined;
  }
}

function holderAlive(pid: number): boolean {
  try {
    process.kill(pid, 0);
    return true;
  } catch (error) {
    // EPERM means the process exists and belongs to someone else.
    return (error as NodeJS.ErrnoException).code === 'EPERM';
  }
}

export function emptyState(session: string): State {
  return { version: 1, session, routes: {}, usage: {} };
}

export function defaultPath(): string {
  if (process.env.DISPATCH_STATE_FILE) return process.env.DISPATCH_STATE_FILE;
  const session = process.env.SESSION_ID || 'default';
  return `/tmp/agent-sandbox/dispatch-state-${session}.json`;
}

/** Read one JSON file, or `undefined` when it is missing or unreadable. */
export function readJson(path: string): unknown {
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch {
    return undefined;
  }
}

/** Write one JSON file atomically: beside the target, then rename. */
export function writeJson(path: string, value: unknown, pretty = false): void {
  mkdirSync(dirname(path), { recursive: true });
  // A concurrent reader sees either the previous file or the next one and never
  // a half-written one.
  const temp = `${path}.${process.pid}.tmp`;
  writeFileSync(temp, pretty ? `${JSON.stringify(value, null, 2)}\n` : `${JSON.stringify(value)}\n`);
  renameSync(temp, path);
}

function decodeRecord(raw: unknown): RouteRecord | undefined {
  if (typeof raw !== 'object' || raw === null) return undefined;
  const value = raw as Record<string, unknown>;
  if (value.state === 'untried') return { state: 'untried' };
  if (value.state === 'ready') return { state: 'ready' };
  if (value.state === 'cooling') {
    if (typeof value.until !== 'number' || typeof value.strikes !== 'number') return undefined;
    if (!REASONS.includes(value.reason as Reason)) return undefined;
    return {
      state: 'cooling',
      until: value.until,
      reason: value.reason as Reason,
      strikes: value.strikes,
    };
  }
  if (value.state === 'dead') return { state: 'dead' };
  return undefined;
}

// The disk-to-memory boundary is a decoder, not a cast. A file it cannot vouch
// for is an empty memory: a storage error must not become a route verdict, so a
// record missing the fields its variant requires refuses the whole file rather
// than being reinterpreted as `dead`.
export function decodeState(raw: unknown, session: string): State {
  if (typeof raw !== 'object' || raw === null) return emptyState(session);
  const parsed = raw as Record<string, unknown>;
  if (parsed.version !== 1) return emptyState(session);
  const routes: Record<string, RouteRecord> = {};
  if (typeof parsed.routes === 'object' && parsed.routes !== null) {
    for (const [route, value] of Object.entries(parsed.routes)) {
      const record = decodeRecord(value);
      if (record === undefined) return emptyState(session);
      routes[route] = record;
    }
  }
  const usage: Record<string, number> = {};
  if (typeof parsed.usage === 'object' && parsed.usage !== null) {
    for (const [route, value] of Object.entries(parsed.usage)) {
      if (typeof value !== 'number' || !Number.isFinite(value)) return emptyState(session);
      usage[route] = value;
    }
  }
  return {
    version: 1,
    session: typeof parsed.session === 'string' ? parsed.session : session,
    routes,
    usage,
  };
}

export function load(path: string, session: string): State {
  return decodeState(readJson(path), session);
}

export function save(path: string, state: State): void {
  writeJson(path, state, true);
}

/**
 * Record one attempt and return the route's new record.
 *
 * The read, the transition and the write are one transaction under a lock file,
 * because the atomic rename makes a single write safe for a reader and says
 * nothing about two writers. A failed lock acquisition is a refusal, not a lost
 * outcome: the caller is told the memory is busy rather than silently dropping
 * the other dispatch's cooldown.
 */
export function recordAttempt(
  path: string,
  session: string,
  route: string,
  outcome: Outcome,
  metered: boolean,
): RouteRecord {
  return recordOutcomes(path, session, [{ route, outcome, metered }]).routes[route];
}

/**
 * Record a turn's attempts as one transaction.
 *
 * A turn's seats are read at one boundary, so the memory they produce is one
 * state: the read, every transition and the write happen under one lock. A
 * per-attempt write would let a second dispatch observe half a turn and would
 * cost one lock round-trip per seat.
 */
export function recordOutcomes(path: string, session: string, writes: OutcomeWrite[]): State {
  return withLock(path, () => {
    const state = load(path, session);
    state.routes = applyWrites(state.routes, writes);
    for (const write of writes) {
      if (write.metered) state.usage[write.route] = (state.usage[write.route] ?? 0) + 1;
    }
    save(path, state);
    return state;
  });
}

function withLock<T>(path: string, body: () => T): T {
  mkdirSync(dirname(path), { recursive: true });
  const lock = `${path}.lock`;
  const deadline = Date.now() + LOCK_LIMIT_MS;
  let fd: number | undefined;
  for (;;) {
    try {
      fd = openSync(lock, 'wx');
      writeSync(fd, String(process.pid));
      break;
    } catch {
      const holder = lockHolder(lock);
      if (holder !== undefined && !holderAlive(holder)) {
        // The holder died without releasing: the stale lock is not a writer.
        try {
          unlinkSync(lock);
        } catch {
          // Another attempt took it over first; the retry loop decides.
        }
        continue;
      }
      if (Date.now() > deadline) {
        throw new DispatchError(`dispatch: the route memory is locked by another writer: ${lock}`);
      }
      Atomics.wait(sleepCell, 0, 0, LOCK_WAIT_MS);
    }
  }
  try {
    return body();
  } finally {
    closeSync(fd);
    try {
      unlinkSync(lock);
    } catch {
      // The lock is already gone, so there is nothing to release.
    }
  }
}
