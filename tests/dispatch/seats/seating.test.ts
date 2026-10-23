// The seat run's bookkeeping: the rotation, the reassignment and the verdict.
//
// The ids are synthetic. A test that named a real table model would break when
// the operator edited the table, so the candidates are built here.

import { strict as assert } from 'node:assert';
import test from 'node:test';
import { seatCandidates, seatOrders, seatResult, seatVerdict, startSeats } from '../../../src/libs/dispatch/seats.ts';
import type { SeatCandidate } from '../../../src/libs/dispatch/seats.ts';
import type { Assignment } from '../../../src/libs/dispatch/table.ts';
import type { RouteRecord } from '../../../src/libs/dispatch/types.ts';

const AT = Date.parse('2026-10-23T00:00:00Z');

function candidate(key: string, index: number): SeatCandidate {
  return { index, key, entry: `${key} at high`, runtime: 'opencode', level: 'high' };
}

function assignment(key: string): Assignment {
  return {
    key,
    text: `${key} at high`,
    provider: key.split('/')[0],
    model: key.split('/')[1],
    runtime: 'opencode',
    level: 'high',
  };
}

const READY: RouteRecord = { state: 'ready' };

test('a seat takes candidate ((i - 1) mod m) + 1', () => {
  const state = startSeats('_R', 5, [candidate('p/a', 0), candidate('p/b', 1), candidate('p/c', 2)]);
  assert.deepEqual(state.slots.map((slot) => slot.idx), [0, 1, 2, 0, 1]);
});

test('a route the memory holds back is not dealt', () => {
  const assignments = [assignment('p/a'), assignment('p/b')];
  const records: Record<string, RouteRecord> = {
    'p/a': { state: 'cooling', until: AT + 60_000, reason: 'rate', strikes: 1 },
    'p/b': READY,
  };
  const candidates = seatCandidates(assignments, records, AT);
  assert.deepEqual(candidates.map((c) => c.key), ['p/b']);
});

test('a role with no candidate is unroutable', () => {
  assert.throws(
    () => startSeats('_R', 1, []),
    /unroutable: _R names no candidate that may be attempted now/,
  );
});

test('a retryable outcome keeps the seat on its assignment', () => {
  const state = startSeats('_R', 1, [candidate('p/a', 0), candidate('p/b', 1)]);
  const applied = seatResult(state, 1, 1, 'Error: Rate limit exceeded', AT);
  assert.equal(applied.outcome, 'retry');
  assert.equal(state.slots[0].idx, 0);
  assert.deepEqual(state.dropped, []);
  assert.equal(applied.record?.class, 'quota');
});

test('a dead candidate is dropped and the seat takes the next in the rotation', () => {
  const state = startSeats('_R', 2, [candidate('p/a', 0), candidate('p/b', 1), candidate('p/c', 2)]);
  const applied = seatResult(state, 1, 1, '401: {"type":"AuthError","message":"Invalid API key."}', AT);
  assert.equal(applied.outcome, 'rotate');
  assert.deepEqual(state.dropped, [0]);
  assert.equal(state.slots[0].idx, 1, 'seat 1 moves to the next candidate');
  assert.equal(state.slots[1].idx, 1, 'seat 2 keeps the assignment it already held');
});

test('a seat whose every candidate is dead is unroutable', () => {
  const state = startSeats('_R', 1, [candidate('p/a', 0)]);
  seatResult(state, 1, 1, 'Error: the model is unavailable', AT);
  assert.equal(state.slots[0].state, 'gone');
  assert.equal(seatVerdict(state).code, 4);
});

test('an unclassified sentence stops the run rather than reassigning', () => {
  const state = startSeats('_R', 1, [candidate('p/a', 0), candidate('p/b', 1)]);
  const applied = seatResult(state, 1, 1, 'the model failed', AT);
  assert.equal(applied.outcome, 'stop');
  assert.equal(state.stop, 1);
  assert.deepEqual(state.dropped, [], 'no candidate is blamed');
});

test('a timeout stops the run rather than reassigning', () => {
  const state = startSeats('_R', 1, [candidate('p/a', 0), candidate('p/b', 1)]);
  const applied = seatResult(state, 1, 124, 'aborted: the time limit of 1800s expired', AT);
  assert.equal(applied.outcome, 'stop');
});

test('every seat on a working model finishes the run at zero', () => {
  const state = startSeats('_R', 2, [candidate('p/a', 0), candidate('p/b', 1)]);
  seatResult(state, 1, 1, '401: {"type":"AuthError","message":"Invalid API key."}', AT);
  seatResult(state, 2, 0, '', AT);
  seatResult(state, 1, 0, '', AT);
  const verdict = seatVerdict(state);
  assert.equal(verdict.done, true);
  assert.equal(verdict.code, 0, 'a seat that was reassigned and then succeeded does not fail the run');
});

test('an attemptable seat is ordered to fire with its runtime', () => {
  const state = startSeats('_R', 2, [candidate('p/a', 0), candidate('p/b', 1)]);
  const step = seatOrders(state, { 'p/a': READY, 'p/b': READY }, AT);
  assert.deepEqual(step.orders, [
    { seat: 1, entry: 'p/a at high', runtime: 'opencode' },
    { seat: 2, entry: 'p/b at high', runtime: 'opencode' },
  ]);
  assert.equal(step.waiting, 0);
});

test('a cooling seat is waited on, not fired', () => {
  const state = startSeats('_R', 1, [candidate('p/a', 0)]);
  const records: Record<string, RouteRecord> = {
    'p/a': { state: 'cooling', until: AT + 60_000, reason: 'rate', strikes: 1 },
  };
  const step = seatOrders(state, records, AT);
  assert.deepEqual(step.orders, []);
  assert.equal(step.waiting, 1);
});
