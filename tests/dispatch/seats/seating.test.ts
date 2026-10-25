// The seat run's bookkeeping: the rotation, the reassignment and the verdict.
//
// The ids are synthetic. A test that named a real table model would break when
// the operator edited the table, so the candidates are built here.

import { strict as assert } from 'node:assert';
import test from 'node:test';
import { decodeSeatState, seatCandidates, seatOrders, seatResult, seatTurn, startSeats } from '../../../src/libs/dispatch/seats.ts';
import type { Assignment } from '../../../src/libs/dispatch/table.ts';
import type { RouteRecord } from '../../../src/libs/dispatch/types.ts';

const AT = Date.parse('2026-10-23T00:00:00Z');

function assignment(key: string): Assignment {
  return {
    role: '_R',
    key,
    text: `${key} at high`,
    provider: key.split('/')[0],
    model: key.split('/')[1],
    runtime: 'pi',
    level: 'high',
  };
}

const READY: RouteRecord = { state: 'ready' };

test('a seat takes candidate ((i - 1) mod m) + 1', () => {
  const state = startSeats(5, [assignment('p/a'), assignment('p/b'), assignment('p/c')]);
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

test('a seating with no candidate refuses', () => {
  assert.throws(() => startSeats(1, []), /a seating needs at least one candidate/);
});

test('a retryable outcome keeps the seat on its assignment', () => {
  const state = startSeats(1, [assignment('p/a'), assignment('p/b')]);
  const applied = seatResult(state, 1, 1, 'Error: Rate limit exceeded', AT);
  assert.equal(applied.outcome, 'retry');
  assert.equal(state.slots[0].idx, 0, 'the seat keeps its assignment');
  assert.equal(applied.write?.outcome.class, 'quota');
});

test('a dead candidate is dropped and the seat takes the next in the rotation', () => {
  const state = startSeats(2, [assignment('p/a'), assignment('p/b'), assignment('p/c')]);
  const turn = seatTurn(state, [{ seat: 1, rc: 1, logText: 'Error: the model is unavailable' }], {}, AT);
  assert.equal(turn.kind, 'fire');
  const dead = turn.writes[0].outcome;
  assert.equal(dead.class, 'capability', 'the memory holds the model dead');
  assert.equal(state.slots[0].idx, 1, 'seat 1 moves to the next candidate');
  assert.equal(state.slots[1].idx, 1, 'seat 2 keeps the assignment it already held');
});

test('a dead route advances every seat on it, not just the one that found it', () => {
  const state = startSeats(2, [assignment('p/a'), assignment('p/b')]);
  const turn = seatTurn(
    state,
    [
      { seat: 1, rc: 1, logText: 'Error: the model is unavailable' },
      { seat: 2, rc: 0, logText: 'report\n' },
    ],
    {},
    AT,
  );
  assert.equal(turn.kind, 'fire');
  assert.equal(state.slots[0].idx, 1, 'seat 1 leaves the dead route');
  assert.equal(state.slots[1].state, 'done', 'seat 2 finished where it was');
  assert.deepEqual(
    turn.kind === 'fire' ? turn.orders.map((order) => [order.seat, order.candidate.key]) : [],
    [[1, 'p/b']],
  );
});

test('a seat whose every candidate is dead is unroutable', () => {
  const state = startSeats(1, [assignment('p/a')]);
  const turn = seatTurn(state, [{ seat: 1, rc: 1, logText: 'Error: the model is unavailable' }], {}, AT);
  assert.equal(turn.kind, 'refusal');
  if (turn.kind !== 'refusal') return;
  assert.equal(turn.refusal.kind, 'unroutable');
  assert.deepEqual(turn.refusal.routes, ['p/a']);
  assert.equal(state.slots[0].state, 'gone');
});

test('an unclassified sentence stops the run rather than reassigning', () => {
  const state = startSeats(1, [assignment('p/a'), assignment('p/b')]);
  const applied = seatResult(state, 1, 1, 'the model failed', AT);
  assert.equal(applied.outcome, 'stop');
  assert.equal(applied.exit, 1);
  assert.equal(applied.write?.outcome.class, 'unknown', 'no candidate is blamed');
});

test('a timeout stops the run rather than reassigning', () => {
  const state = startSeats(1, [assignment('p/a'), assignment('p/b')]);
  const applied = seatResult(state, 1, 124, 'aborted: the time limit of 1800s expired', AT);
  assert.equal(applied.outcome, 'stop');
});

test('every seat on a working model finishes the run at zero', () => {
  const state = startSeats(2, [assignment('p/a'), assignment('p/b')]);
  const first = seatTurn(
    state,
    [
      { seat: 1, rc: 1, logText: 'Error: the model is unavailable' },
      { seat: 2, rc: 0, logText: 'report\n' },
    ],
    {},
    AT,
  );
  assert.equal(first.kind, 'fire', 'seat 1 takes the candidate seat 2 finished on');
  const second = seatTurn(state, [{ seat: 1, rc: 0, logText: 'report\n' }], {}, AT);
  assert.equal(second.kind, 'finished');
});

test('a fault no other model repairs stops the run, scope included', () => {
  const state = startSeats(2, [assignment('p/a'), assignment('p/b')]);
  const applied = seatResult(state, 1, 1, '401: {"type":"AuthError","message":"Invalid API key."}', AT);
  assert.equal(applied.outcome, 'stop', 'an unfunded or unauthorised account is not repaired by another model');
  assert.equal(applied.write?.outcome.class, 'capability');
});

test('a seat that logs nothing stops the run', () => {
  const state = startSeats(1, [assignment('p/a'), assignment('p/b')]);
  const applied = seatResult(state, 1, 0, '   \n', AT);
  assert.equal(applied.outcome, 'stop', 'a silent exit says nothing about the route');
  assert.equal(applied.exit, 1);
  assert.equal(applied.write?.outcome.class, 'unknown', 'the memory records no success the attempt did not earn');
});

test('an attemptable seat is ordered to fire with its runtime', () => {
  const state = startSeats(2, [assignment('p/a'), assignment('p/b')]);
  const orders = seatOrders(state, { 'p/a': READY, 'p/b': READY }, AT);
  assert.deepEqual(
    orders.map((order) => [order.seat, order.candidate.text, order.candidate.runtime]),
    [
      [1, 'p/a at high', 'pi'],
      [2, 'p/b at high', 'pi'],
    ],
  );
});

test('a cooling seat is waited on, not fired', () => {
  const state = startSeats(1, [assignment('p/a')]);
  const records: Record<string, RouteRecord> = {
    'p/a': { state: 'cooling', until: AT + 60_000, reason: 'rate', strikes: 1 },
  };
  assert.deepEqual(seatOrders(state, records, AT), []);
});

test('a pinned seat fires even when the memory holds its route back', () => {
  const state = startSeats(1, [assignment('p/a')], true);
  const records: Record<string, RouteRecord> = {
    'p/a': { state: 'cooling', until: AT + 60_000, reason: 'quota', strikes: 2 },
  };
  const orders = seatOrders(state, records, AT);
  assert.equal(orders.length, 1, 'the pin is the caller value, not a routing decision');
});

test('a stopping seat does not truncate the turn\'s writes', () => {
  const state = startSeats(2, [assignment('p/a'), assignment('p/b')]);
  const turn = seatTurn(
    state,
    [
      { seat: 1, rc: 124, logText: '' },
      { seat: 2, rc: 0, logText: 'report\n' },
    ],
    {},
    AT,
  );
  // Both seats fired in the turn, so both outcomes are the memory's to record:
  // the stop ends the run, it does not discard the other seat's success.
  assert.equal(turn.kind, 'stopped');
  assert.deepEqual(turn.writes.map((write) => write.route), ['p/a', 'p/b']);
});

test('a pinned seat stops on a retryable outcome instead of re-firing', () => {
  const state = startSeats(1, [assignment('p/a')], true);
  const turn = seatTurn(state, [{ seat: 1, rc: 1, logText: 'Rate limit exceeded' }], {}, AT);
  // The memory never holds a pinned route back, so a retry would re-fire the
  // same attempt with no wait: the pin is one attempt, as the pinned walk is.
  assert.equal(turn.kind, 'stopped');
});

test('an unreadable run state is refused rather than resumed', () => {
  const state = startSeats(1, [assignment('p/a')]);
  assert.deepEqual(decodeSeatState(JSON.parse(JSON.stringify(state))), state);
  assert.equal(decodeSeatState({ role: '_R', turn: 1 }), undefined);
  assert.equal(decodeSeatState({ ...state, candidates: [{ key: 'p/a' }] }), undefined);
});
