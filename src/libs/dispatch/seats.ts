// The seat run: a request for n seats over a role's candidates.
//
// The seating is one rotation over the candidates, which are the role's entries
// that the route memory allows at this moment, m of them. Seat i takes candidate
// ((i - 1) mod m) + 1, so the first m seats are distinct models and the rest
// repeat them in written order. Seats fire together within a turn and are read
// at its boundary, so a turn costs its slowest seat rather than the sum and the
// candidate set has one writer per turn.
//
// This module holds the bookkeeping and nothing else: it decides what to fire
// and what an outcome does to the seating. The entrypoint fires the attempts and
// gives them their logs; the route memory is written by the caller in one
// transaction from the writes a turn returns.

import { classify } from './classify.ts';
import { applyWrites, availability, select } from './machine.ts';
import type { OutcomeClass, OutcomeWrite, Refusal, RouteTable, Scope } from './types.ts';
import type { Assignment } from './table.ts';
import { DispatchError } from './errors.ts';
import { assignmentOf, pinned, roleAssignments, withLevel } from './table.ts';
import { decideWalk } from './walk.ts';

/** One seat's answer: a stop carries its exit and reason; the rest carry their write. */
export type SeatResult =
  | { outcome: 'stop'; write: OutcomeWrite; exit: number; why: string }
  | { outcome: 'done' | 'retry' | 'drop'; write: OutcomeWrite };

export type SeatSlot = {
  seat: number;
  idx: number;
  state: 'active' | 'done' | 'gone';
};

export type SeatState = {
  turn: number;
  candidates: Assignment[];
  slots: SeatSlot[];
  /** A caller's pin overrides the memory, so the run is never held back by it. */
  pinned: boolean;
};

export type SeatOrder = { seat: number; candidate: Assignment };

export type SeatAttempt = { seat: number; rc: number; logText: string };

/** A seat that did not finish: the run reports it and carries on or stops. */
export type SeatNote = { seat: number; class: OutcomeClass; scope: Scope };

export type SeatTurn =
  | { kind: 'stopped'; seat: number; exit: number; why: string; writes: OutcomeWrite[]; notes: SeatNote[] }
  | { kind: 'fire'; orders: SeatOrder[]; writes: OutcomeWrite[]; notes: SeatNote[] }
  | { kind: 'finished'; writes: OutcomeWrite[]; notes: SeatNote[] }
  | { kind: 'refusal'; refusal: Refusal; writes: OutcomeWrite[]; notes: SeatNote[] };

/** The candidates a role may deal now, in the order the table wrote them. */
export function seatCandidates(
  assignments: Assignment[],
  records: RouteTable,
  at: number,
): Assignment[] {
  return assignments.filter((assignment) => availability(records[assignment.key], at).kind === 'run');
}

/**
 * The candidates a role offers for one attempt, or the selection's own refusal.
 * A pin is the caller's assignment, so it skips the routing question and seats
 * every seat on that one entry. Every other caller resolves through the memory,
 * which is the one place the pin rule is written.
 */
export function resolveAttempts(
  role: string,
  path: string,
  records: RouteTable,
  at: number,
  options: { pin?: string; level?: string } = {},
): { kind: 'run'; candidates: Assignment[] } | Refusal {
  const { pin, level } = options;
  if (pin !== undefined) return { kind: 'run', candidates: [pinned(role, pin, level)] };
  const all = roleAssignments(role, path);
  const runnable = seatCandidates(all, records, at);
  if (runnable.length === 0) {
    // With nothing runnable, the selection names the answer: a wait, or a role
    // with no entry left. It is the one refusal vocabulary.
    const decided = select(all, records, at);
    if (decided.kind !== 'run') return decided;
    throw new DispatchError('dispatch: a role with a runnable entry dealt no candidate');
  }
  const candidates = runnable.map((assignment) => (level === undefined ? assignment : withLevel(assignment, level)));
  return { kind: 'run', candidates };
}

/** The seating: one rotation over the candidates. */
export function startSeats(seats: number, candidates: Assignment[], pinned = false): SeatState {
  if (!Number.isInteger(seats) || seats < 1) {
    throw new DispatchError('dispatch: a seating needs at least one seat');
  }
  if (candidates.length === 0) {
    throw new DispatchError('dispatch: a seating needs at least one candidate');
  }
  const slots: SeatSlot[] = Array.from({ length: seats }, (_, i) => ({
    seat: i + 1,
    idx: i % candidates.length,
    state: 'active',
  }));
  return { turn: 0, candidates, slots, pinned };
}

/** The seats this turn may fire. */
export function seatOrders(state: SeatState, records: RouteTable, at: number): SeatOrder[] {
  const orders: SeatOrder[] = [];
  state.slots.forEach((slot) => {
    if (slot.state !== 'active') return;
    const candidate = state.candidates[slot.idx];
    // A pin is the caller's value, taken as given: the memory records the
    // attempt but never holds the pinned route back.
    if (!state.pinned && availability(records[candidate.key], at).kind !== 'run') return;
    orders.push({ seat: slot.seat, candidate });
  });
  return orders;
}

/**
 * Apply one seat's outcome. A success ends the seat. A retryable outcome leaves
 * the seat on its assignment and lets the memory set the next attempt's moment.
 * A capability failure says the model is gone, so the caller advances the seat
 * past it. A timeout, an unclassified sentence or an empty log stops the run:
 * one rule, the walk's, so the two paths cannot disagree.
 */
export function seatResult(
  state: SeatState,
  seat: number,
  rc: number,
  logText: string,
  at: number,
): SeatResult {
  const slot = state.slots.find((s) => s.seat === seat);
  if (slot === undefined) throw new DispatchError(`dispatch: no seat ${seat} in this run`);
  const candidate = state.candidates[slot.idx];
  const metered = candidate.runtime === 'opencode';
  const empty = logText.trim() === '';
  // A zero exit with an empty log is not a success: it classifies as the empty
  // text does, so the memory records no success the attempt did not earn.
  const verdict = rc === 0 && !empty ? undefined : classify(logText, at);

  const write: OutcomeWrite =
    verdict === undefined
      ? { route: candidate.key, outcome: { at, class: 'success', scope: 'none' }, metered }
      : {
          route: candidate.key,
          outcome: {
            at,
            class: verdict.class,
            scope: verdict.scope,
            reason: verdict.reason,
            refreshAt: verdict.refreshAt,
          },
          metered,
        };

  const disposition = decideWalk({
    mode: 'general',
    class: verdict?.class ?? 'success',
    scope: verdict?.scope ?? 'none',
    emptyLog: empty,
  });
  if (!disposition.advance) {
    const klass = write.outcome.class;
    const scope = write.outcome.scope;
    const why = empty ? 'produced no output' : `ended ${klass} (${scope})`;
    return { outcome: 'stop', write, exit: rc === 0 ? 1 : rc, why };
  }
  if (verdict === undefined) {
    slot.state = 'done';
    return { outcome: 'done', write };
  }
  if (verdict.class === 'transient' || verdict.class === 'quota') {
    // A pin has no next candidate and the memory never holds it back, so a
    // retry would re-fire the same attempt with no wait. One attempt, the same
    // answer the pinned walk gives.
    if (state.pinned) return { outcome: 'stop', write, exit: rc === 0 ? 1 : rc, why: `ended ${verdict.class} (${verdict.scope})` };
    return { outcome: 'retry', write };
  }
  return { outcome: 'drop', write };
}

/** Move a seat past every candidate whose route is dead. */
function advancePastDead(state: SeatState, slot: SeatSlot, records: RouteTable, at: number): void {
  const total = state.candidates.length;
  for (let step = 1; step <= total; step += 1) {
    const idx = (slot.idx + step) % total;
    if (availability(records[state.candidates[idx].key], at).kind !== 'dead') {
      slot.idx = idx;
      return;
    }
  }
  slot.state = 'gone';
}

/**
 * One turn: record the attempts' effects, advance past dead routes, and answer
 * what the run does next. The writes are returned, not applied, so the caller
 * owns the one transaction that persists them.
 */
export function seatTurn(
  state: SeatState,
  attempts: SeatAttempt[],
  records: RouteTable,
  at: number,
): SeatTurn {
  const writes: OutcomeWrite[] = [];
  const notes: SeatNote[] = [];
  // Every seat in the turn fired concurrently, so every seat's outcome is part
  // of the one transaction; a stop ends the run but never truncates the writes.
  let stopped: { seat: number; exit: number; why: string } | undefined;
  for (const attempt of attempts) {
    const applied = seatResult(state, attempt.seat, attempt.rc, attempt.logText, at);
    writes.push(applied.write);
    if (applied.outcome === 'retry' || applied.outcome === 'drop') {
      notes.push({
        seat: attempt.seat,
        class: applied.write.outcome.class,
        scope: applied.write.outcome.scope,
      });
    }
    if (applied.outcome === 'stop' && stopped === undefined) {
      stopped = { seat: attempt.seat, exit: applied.exit, why: applied.why };
    }
  }
  if (stopped !== undefined) return { kind: 'stopped', ...stopped, writes, notes };

  state.turn += 1;
  const next = applyWrites(records, writes);
  // A route that another seat's attempt killed is dead for every seat on it, so
  // the advance reads the memory rather than a private list of indices.
  state.slots.forEach((slot) => {
    if (slot.state !== 'active') return;
    if (availability(next[state.candidates[slot.idx].key], at).kind === 'dead') {
      advancePastDead(state, slot, next, at);
    }
  });

  const orders = seatOrders(state, next, at);
  if (orders.length > 0) return { kind: 'fire', orders, writes, notes };

  // The remaining active seats are the selection's own candidate list, so the
  // answer is the selection's, not a second derivation of it.
  const active = state.slots
    .filter((slot) => slot.state === 'active')
    .map((slot) => state.candidates[slot.idx]);
  if (active.length === 0 && !state.slots.some((slot) => slot.state === 'gone')) {
    return { kind: 'finished', writes, notes };
  }
  // A seat with no active entry left is asked over the full list, so one
  // selection answers both arms and one guard states the invariant.
  const decided = select(active.length > 0 ? active : state.candidates, next, at);
  if (decided.kind === 'run') throw new DispatchError('dispatch: a seat that may run was not ordered');
  return { kind: 'refusal', refusal: decided, writes, notes };
}

/**
 * The run state's disk decoder. A state file is read after one process wrote it
 * and another resumes it, so every variant it carries is checked before use: an
 * unreadable file refuses the turn rather than resuming a half-understood run.
 */
export function decodeSeatState(raw: unknown): SeatState | undefined {
  if (typeof raw !== 'object' || raw === null) return undefined;
  const value = raw as Record<string, unknown>;
  if (typeof value.turn !== 'number' || typeof value.pinned !== 'boolean') return undefined;
  if (!Array.isArray(value.candidates) || !Array.isArray(value.slots)) return undefined;
  const candidates: Assignment[] = [];
  for (const rawCandidate of value.candidates) {
    const candidate = decodeAssignment(rawCandidate);
    if (candidate === undefined) return undefined;
    candidates.push(candidate);
  }
  const slots: SeatSlot[] = [];
  for (const rawSlot of value.slots) {
    if (typeof rawSlot !== 'object' || rawSlot === null) return undefined;
    const fields = rawSlot as Record<string, unknown>;
    if (!Number.isInteger(fields.seat) || typeof fields.idx !== 'number') return undefined;
    if (!Number.isInteger(fields.idx) || fields.idx < 0 || fields.idx >= candidates.length) return undefined;
    if (fields.state !== 'active' && fields.state !== 'done' && fields.state !== 'gone') return undefined;
    if (slots.some((slot) => slot.seat === fields.seat)) return undefined;
    slots.push({ seat: fields.seat, idx: fields.idx, state: fields.state });
  }
  return { turn: value.turn, candidates, slots, pinned: value.pinned };
}

function decodeAssignment(raw: unknown): Assignment | undefined {
  if (typeof raw !== 'object' || raw === null) return undefined;
  const value = raw as Record<string, unknown>;
  if (typeof value.role !== 'string' || typeof value.provider !== 'string' || typeof value.model !== 'string') {
    return undefined;
  }
  if (value.level !== undefined && typeof value.level !== 'string') return undefined;
  // The key, the text and the runtime are derived from the primary fields, so a
  // state file cannot say one route and launch another.
  try {
    return assignmentOf({
      role: value.role,
      provider: value.provider,
      model: value.model,
      level: value.level as string | undefined,
    });
  } catch {
    return undefined;
  }
}
