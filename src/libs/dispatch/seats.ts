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
// gives them their logs.

import { classify } from './classify.ts';
import { select } from './machine.ts';
import type { RouteRecord } from './types.ts';
import type { Assignment, Runtime } from './table.ts';
import { DispatchError } from './table.ts';

export type SeatOutcome = 'done' | 'retry' | 'rotate' | 'stop';

export type SeatCandidate = {
  index: number;
  key: string;
  entry: string;
  runtime: Runtime;
  level?: string;
};

export type SeatSlot = {
  seat: number;
  idx: number;
  state: 'active' | 'done' | 'gone';
};

export type SeatState = {
  role: string;
  seats: number;
  turn: number;
  candidates: SeatCandidate[];
  slots: SeatSlot[];
  dropped: number[];
  /** A non-zero code stops the run: the failure said nothing about the route. */
  stop: number;
};

export type SeatOrder = { seat: number; entry: string; runtime: Runtime };

export type SeatStep = {
  state: SeatState;
  orders: SeatOrder[];
  waiting: number;
};

/** The candidates a role may deal now, in the order the table wrote them. */
export function seatCandidates(
  assignments: Assignment[],
  records: Record<string, RouteRecord>,
  at: number,
): SeatCandidate[] {
  return assignments
    .filter((a) => select([a.key], records, at).kind === 'run')
    .map((a, index) => ({ index, key: a.key, entry: a.text, runtime: a.runtime, level: a.level }));
}

/**
 * A caller's pin: one candidate, taken as given. Resolution is the default and a
 * pin overrides it, so the pinned route is attempted whether or not the memory
 * holds it back: the caller named it on purpose, and the pin is what makes the
 * run reproducible. The attempt is recorded like any other, because the memory
 * is evidence about the route and not about the decision that selected it.
 */
export function pinnedCandidates(assignment: Assignment): SeatCandidate[] {
  return [
    {
      index: 0,
      key: assignment.key,
      entry: assignment.text,
      runtime: assignment.runtime,
      level: assignment.level,
    },
  ];
}

/** The seating: one rotation over the candidates. */
export function startSeats(
  role: string,
  seats: number,
  candidates: SeatCandidate[],
): SeatState {
  if (candidates.length === 0) {
    throw new DispatchError(`dispatch: unroutable: ${role} names no candidate that may be attempted now`);
  }
  if (!Number.isInteger(seats) || seats < 1) {
    throw new DispatchError('dispatch: --seats needs a count of at least 1');
  }
  const slots: SeatSlot[] = Array.from({ length: seats }, (_, i) => ({
    seat: i + 1,
    idx: i % candidates.length,
    state: 'active',
  }));
  return {
    role,
    seats,
    turn: 0,
    candidates,
    slots,
    dropped: [],
    stop: 0,
  };
}

/** The seats this turn may fire, and how many are held back by the memory. */
export function seatOrders(
  state: SeatState,
  records: Record<string, RouteRecord>,
  at: number,
): SeatStep {
  const orders: SeatOrder[] = [];
  let waiting = 0;
  state.slots.forEach((slot) => {
    if (slot.state !== 'active') return;
    const candidate = state.candidates[slot.idx];
    if (select([candidate.key], records, at).kind !== 'run') {
      waiting += 1;
      return;
    }
    orders.push({ seat: slot.seat, entry: candidate.entry, runtime: candidate.runtime });
  });
  return { state, orders, waiting };
}

export type SeatResult = {
  state: SeatState;
  outcome: SeatOutcome;
  /** The record the route memory must take for this attempt, when it takes one. */
  record?: {
    route: string;
    class: string;
    scope: string;
    reason?: string;
    refreshAt?: number;
    metered: boolean;
  };
  exit: number;
};

/**
 * Apply one seat's outcome. A success ends the seat. A retryable outcome leaves
 * the seat on its assignment and lets the memory set the next attempt's moment.
 * A capability failure says the model is gone, so the candidate is dropped and
 * the seat takes the next one in the remaining rotation. A timeout or an
 * unclassified sentence stops the run rather than guessing at a second model,
 * and so does a zero exit with an empty log: the log is the only evidence the
 * seat ran, so a silent one is a failure and not a success.
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

  if (rc === 0) {
    if (logText.trim() === '') {
      state.stop = 1;
      return { state, outcome: 'stop', exit: 1 };
    }
    slot.state = 'done';
    return {
      state,
      outcome: 'done',
      record: { route: candidate.key, class: 'success', scope: 'none', metered },
      exit: 0,
    };
  }

  const verdict = classify(logText, at);
  const record = {
    route: candidate.key,
    class: verdict.class,
    scope: verdict.scope,
    reason: verdict.reason,
    refreshAt: verdict.refreshAt,
    metered,
  };

  if (verdict.class === 'transient' || verdict.class === 'quota') {
    return { state, outcome: 'retry', record, exit: rc };
  }
  if (verdict.class === 'timeout' || verdict.class === 'unknown') {
    state.stop = rc;
    return { state, outcome: 'stop', record, exit: rc };
  }

  state.dropped.push(slot.idx);
  const m = state.candidates.length;
  let next = (slot.idx + 1) % m;
  let guard = 0;
  while (state.dropped.includes(next) && guard < m) {
    next = (next + 1) % m;
    guard += 1;
  }
  if (guard >= m) {
    slot.state = 'gone';
    return { state, outcome: 'rotate', record, exit: rc };
  }
  slot.idx = next;
  return { state, outcome: 'rotate', record, exit: rc };
}

/**
 * Whether the run has finished, and with which code. A seat that was reassigned
 * and then succeeded still ended on a working model, so the run succeeded: only
 * a seat with no candidate left fails it.
 */
export function seatVerdict(state: SeatState): { done: boolean; code: number; why: string } {
  const gone = state.slots.find((s) => s.state === 'gone');
  if (gone !== undefined) {
    return { done: true, code: 4, why: `seat ${gone.seat} has no candidate left` };
  }
  const active = state.slots.find((s) => s.state === 'active');
  if (active !== undefined) {
    return { done: false, code: 0, why: '' };
  }
  return { done: true, code: 0, why: '' };
}
