// The route availability machine. Pure: it holds no clock, opens no file and
// spawns nothing, so every transition and every invariant is testable without
// a worker.
//
// A route is `<provider>/<model>`. Its record says whether the next attempt may
// happen now, and if not, when. The reason is carried for the report; the
// decision reads only `until`.

import type { Outcome, Reason, RouteRecord, RouteTable, Selection } from './types.ts';

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
export const TRANSITIONS = [
  { id: 'R1', from: 'untried', on: 'success', to: 'ready', invariant: 'I5' },
  { id: 'R2', from: 'ready', on: 'success', to: 'ready', invariant: 'I5' },
  { id: 'R3', from: 'untried|ready|cooling', on: 'transient', to: 'cooling:flaky', invariant: 'I1' },
  { id: 'R4', from: 'untried|ready|cooling', on: 'quota:rate', to: 'cooling:rate', invariant: 'I1' },
  { id: 'R5', from: 'untried|ready|cooling', on: 'quota:plan', to: 'cooling:quota', invariant: 'I1' },
  { id: 'R6', from: 'untried|ready|cooling', on: 'timeout', to: 'cooling:timeout', invariant: 'I1' },
  { id: 'R7', from: 'untried|ready|cooling', on: 'capability:model|provider|account', to: 'dead', invariant: 'I4' },
  { id: 'R8', from: 'any', on: 'capability:request', to: 'same', invariant: 'I2' },
  { id: 'R9', from: 'any', on: 'unknown', to: 'same', invariant: 'I3' },
  { id: 'R10', from: 'cooling', on: 'clock>=until', to: 'untried', invariant: 'I6' },
  { id: 'R11', from: 'cooling', on: 'success', to: 'cooling', invariant: 'I6' },
  { id: 'R12', from: 'dead', on: 'any attempt', to: 'dead', invariant: 'I4' },
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
    text: o.text,
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
      return { state: 'dead', text: o.text };
    default:
      // Unknown text is a statement about the classifier, not about the route.
      return route;
  }
}

export function applyClock(route: RouteRecord, at: number): RouteRecord {
  if (route.state === 'cooling' && at >= route.until) return { state: 'untried' };
  return route;
}

// The resolution half: take the first entry whose route may be attempted now.
export function select(entries: string[], table: RouteTable, now: number): Selection {
  let earliest = Infinity;
  let earliestReason: Reason = 'flaky';
  const blocked: string[] = [];
  const dead: { route: string; text?: string }[] = [];

  for (const entry of entries) {
    const record = applyClock(table[entry] ?? { state: 'untried' }, now);
    if (record.state === 'untried' || record.state === 'ready') {
      return { kind: 'run', entry };
    }
    if (record.state === 'cooling') {
      blocked.push(entry);
      if (record.until < earliest) {
        earliest = record.until;
        earliestReason = record.reason;
      }
      continue;
    }
    dead.push({ route: entry, text: record.text });
  }

  if (earliest !== Infinity) {
    return { kind: 'blocked', earliest, reason: earliestReason, routes: blocked };
  }
  return { kind: 'unroutable', reasons: dead };
}
