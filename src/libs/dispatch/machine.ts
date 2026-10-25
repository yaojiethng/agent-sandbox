// The route availability machine. Pure: it holds no clock, opens no file and
// spawns nothing, so every transition and every invariant is testable without
// a worker.
//
// A route is `<provider>/<model>`. Its record says whether the next attempt may
// happen now, and if not, when. The reason is carried for the report; the
// decision reads only `until`.

import { DispatchError } from './errors.ts';
import type { Availability, Outcome, OutcomeClass, OutcomeWrite, Reason, RouteRecord, RouteTable, Scope, Selection } from './types.ts';

// The runtime arrays a decoder and a command line both need. One home, so a new
// member of a union is one edit rather than three that can disagree.
export const CLASSES: OutcomeClass[] = ['success', 'transient', 'quota', 'capability', 'timeout', 'unknown'];
export const SCOPES: Scope[] = ['none', 'model', 'provider', 'account', 'request'];
export const REASONS: Reason[] = ['flaky', 'rate', 'quota', 'timeout'];

export const BACKOFF_BASE_MS = 15_000;
export const BACKOFF_CAP_MS = 15 * 60 * 1000;
export const TIMEOUT_BACKOFF_MS = 5 * 60 * 1000;

// Each transition names the invariant it upholds, so a mutation row can break
// that invariant by name instead of by line number.
export const INVARIANTS = [
  { id: 'I1', statement: 'a failure never brings the next attempt earlier than the record already puts it' },
  { id: 'I2', statement: 'a malformed request leaves the route record untouched' },
  { id: 'I3', statement: 'an unclassified failure leaves the route record untouched' },
  { id: 'I4', statement: 'a dead route stays dead for the session' },
  { id: 'I5', statement: 'a success clears the strike count' },
  { id: 'I6', statement: 'the clock is the only way out of cooling' },
] as const;

// The transition table is data, so the suite can hold itself to it: every id
// below needs a case, every case names an id, and every id names an invariant.
// The table names each row's invariant, which is the column the suite checks.
// The event and target prose lives in `docs/reference/dispatch.md`, so the two
// cannot drift apart without a document disagreeing.
export const TRANSITIONS = [
  { id: 'R1', invariant: 'I5' },
  { id: 'R2', invariant: 'I5' },
  { id: 'R3', invariant: 'I1' },
  { id: 'R4', invariant: 'I1' },
  { id: 'R5', invariant: 'I1' },
  { id: 'R6', invariant: 'I1' },
  { id: 'R7', invariant: 'I4' },
  { id: 'R8', invariant: 'I2' },
  { id: 'R9', invariant: 'I3' },
  { id: 'R10', invariant: 'I6' },
  { id: 'R11', invariant: 'I6' },
  { id: 'R12', invariant: 'I4' },
] as const;

export const SELECTIONS = [
  { id: 'S1', kind: 'run' },
  { id: 'S2', kind: 'blocked' },
  { id: 'S3', kind: 'unroutable' },
] as const;

function backoff(strikes: number): number {
  const raw = BACKOFF_BASE_MS * Math.pow(2, Math.max(0, strikes - 1));
  return Math.min(raw, BACKOFF_CAP_MS);
}

/** Apply a turn's writes in order: one loop for every writer of the memory. */
export function applyWrites(table: RouteTable, writes: OutcomeWrite[]): RouteTable {
  const next = { ...table };
  for (const write of writes) {
    next[write.route] = applyOutcome(next[write.route] ?? { state: 'untried' }, write.outcome);
  }
  return next;
}

export function applyOutcome(route: RouteRecord, o: Outcome): RouteRecord {
  // A held route is frozen by the record itself, not by the absence of a
  // writer. An attempt is recorded whichever chose it, a pin included, because
  // the memory is evidence about the route rather than about the decision that
  // selected it. What the record cannot do is move a route the router holds
  // back: cooling changes only when the clock passes (I6), and dead never
  // leaves the session (I4). Severity only ever moves down, so a capability
  // fault still kills a cooling route.
  if (route.state === 'dead') return route;
  // A cooldown is frozen against improvement: only the clock makes the route
  // attemptable again (I6), so a success neither readies it nor clears its
  // strikes. A failure still extends the wait and counts a strike (I1), and a
  // capability fault still kills it, because severity only ever moves down.
  if (route.state === 'cooling' && o.class === 'success') return route;
  const strikes = route.state === 'cooling' ? route.strikes : 0;
  const previousUntil = route.state === 'cooling' ? route.until : 0;

  // A failure never brings the next attempt earlier than the record already
  // puts it, which is the anti-thrash rule.
  const cool = (until: number, reason: Reason, nextStrikes: number): RouteRecord => ({
    state: 'cooling',
    until: Math.max(until, previousUntil),
    reason,
    strikes: nextStrikes,
  });

  switch (o.class) {
    case 'success':
      return { state: 'ready' };
    case 'transient':
      return cool(o.at + backoff(strikes + 1), 'flaky', strikes + 1);
    case 'quota':
      if (o.reason === 'rate') return cool(o.at + backoff(strikes + 1), 'rate', strikes + 1);
      return cool(o.refreshAt ?? o.at + backoff(strikes + 1), 'quota', strikes + 1);
    case 'timeout':
      return cool(o.at + TIMEOUT_BACKOFF_MS, 'timeout', strikes + 1);
    case 'capability':
      // A malformed request says nothing about the route, so the record stays.
      if (o.scope === 'request') return route;
      return { state: 'dead' };
    case 'unknown':
      // Unknown text is a statement about the classifier, not about the route.
      return route;
    default: {
      const unhandled: never = o.class;
      throw new DispatchError(`dispatch: unhandled outcome class: ${String(unhandled)}`);
    }
  }
}

export function applyClock(route: RouteRecord, at: number): RouteRecord {
  if (route.state === 'cooling' && at >= route.until) return { state: 'untried' };
  return route;
}

// The resolution half: take the first candidate whose route may be attempted
// now. One predicate answers availability, so `select` and the seat path ask the
// same question of the same record.
export function availability(record: RouteRecord | undefined, now: number): Availability {
  const current = applyClock(record ?? { state: 'untried' }, now);
  if (current.state === 'untried' || current.state === 'ready') return { kind: 'run' };
  if (current.state === 'cooling') {
    return { kind: 'blocked', until: current.until, reason: current.reason };
  }
  return { kind: 'dead' };
}

export function select<T extends { key: string }>(
  candidates: T[],
  table: RouteTable,
  now: number,
): Selection<T> {
  let earliest = Infinity;
  let earliestReason: Reason = 'flaky';
  const blocked: string[] = [];
  const dead: string[] = [];

  for (const candidate of candidates) {
    const state = availability(table[candidate.key], now);
    if (state.kind === 'run') return { kind: 'run', chosen: candidate };
    if (state.kind === 'blocked') {
      blocked.push(candidate.key);
      if (state.until < earliest) {
        earliest = state.until;
        earliestReason = state.reason;
      }
      continue;
    }
    dead.push(candidate.key);
  }

  if (earliest !== Infinity) {
    return { kind: 'blocked', earliest, reason: earliestReason, routes: blocked };
  }
  return { kind: 'unroutable', routes: dead };
}
