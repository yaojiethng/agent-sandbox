import test from 'node:test';
import assert from 'node:assert/strict';
import {
  BACKOFF_BASE_MS,
  TIMEOUT_BACKOFF_MS,
  applyClock,
  applyOutcome,
  select,
} from '../../../src/libs/dispatch/machine.ts';
import type { Outcome, RouteRecord } from '../../../src/libs/dispatch/types.ts';

const AT = Date.UTC(2026, 9, 22, 14, 2, 0);
const UNTRIED: RouteRecord = { state: 'untried' };
const READY: RouteRecord = { state: 'ready' };

function outcome(partial: Partial<Outcome>): Outcome {
  return { at: AT, class: 'success', scope: 'none', ...partial };
}

test('[R1] an untried route that succeeds becomes ready', () => {
  assert.deepEqual(applyOutcome(UNTRIED, outcome({})), { state: 'ready' });
});

test('[R2] a ready route that succeeds stays ready', () => {
  assert.deepEqual(applyOutcome(READY, outcome({})), { state: 'ready' });
});

test('[R3] a transient fault cools the route with growing backoff', () => {
  const first = applyOutcome(UNTRIED, outcome({ class: 'transient' }));
  assert.equal(first.state, 'cooling');
  if (first.state !== 'cooling') return;
  assert.equal(first.reason, 'flaky');
  assert.equal(first.until, AT + BACKOFF_BASE_MS);

  const second = applyOutcome(first, outcome({ class: 'transient', at: AT + BACKOFF_BASE_MS }));
  assert.equal(second.state, 'cooling');
  if (second.state !== 'cooling') return;
  assert.equal(second.strikes, 2);
  assert.ok(second.until - (AT + BACKOFF_BASE_MS) > BACKOFF_BASE_MS, 'the second wait is longer');
});

test('[R4] a rate limit cools with the rate reason', () => {
  const r = applyOutcome(UNTRIED, outcome({ class: 'quota', reason: 'rate' }));
  assert.equal(r.state, 'cooling');
  if (r.state !== 'cooling') return;
  assert.equal(r.reason, 'rate');
});

test('[R5] a plan limit cools until the declared refresh', () => {
  const refresh = AT + 3_600_000;
  const r = applyOutcome(UNTRIED, outcome({ class: 'quota', reason: 'quota', refreshAt: refresh }));
  assert.equal(r.state, 'cooling');
  if (r.state !== 'cooling') return;
  assert.equal(r.until, refresh);
  assert.equal(r.reason, 'quota');
});

test('[R6] a timeout cools the route for a fixed wait', () => {
  const r = applyOutcome(UNTRIED, outcome({ class: 'timeout' }));
  assert.equal(r.state, 'cooling');
  if (r.state !== 'cooling') return;
  assert.equal(r.reason, 'timeout');
  assert.equal(r.until, AT + TIMEOUT_BACKOFF_MS);
});

test('[R7] a capability fault outside the request kills the route for the session', () => {
  for (const scope of ['model', 'provider', 'account'] as const) {
    const r = applyOutcome(UNTRIED, outcome({ class: 'capability', scope }));
    assert.equal(r.state, 'dead', `scope ${scope} kills the route`);
  }
});

test('[R8] a malformed request leaves the route record untouched', () => {
  assert.deepEqual(applyOutcome(UNTRIED, outcome({ class: 'capability', scope: 'request' })), UNTRIED);
  assert.deepEqual(applyOutcome(READY, outcome({ class: 'capability', scope: 'request' })), READY);
});

test('[R9] an unknown sentence says nothing about the route', () => {
  assert.deepEqual(applyOutcome(READY, outcome({ class: 'unknown' })), READY);
});

test('[R10] a cooling route becomes untried once the clock reaches until', () => {
  const cooling = applyOutcome(UNTRIED, outcome({ class: 'transient' }));
  if (cooling.state !== 'cooling') throw new Error('expected cooling');
  assert.deepEqual(applyClock(cooling, cooling.until - 1), cooling);
  assert.deepEqual(applyClock(cooling, cooling.until), { state: 'untried' });
});

test('[S1] resolution takes the first dispatchable entry, after any cooling one', () => {
  const table = { 'p/a': applyOutcome(UNTRIED, outcome({ class: 'transient' })) };
  const r = select(['p/a', 'p/b'], table, AT);
  assert.deepEqual(r, { kind: 'run', entry: 'p/b' });
});

test('[S2] resolution blocks on the earliest wait when every entry is cooling', () => {
  const table = {
    'p/a': applyOutcome(UNTRIED, outcome({ class: 'quota', reason: 'quota', refreshAt: AT + 60_000 })),
    'p/b': applyOutcome(UNTRIED, outcome({ class: 'transient' })),
  };
  const r = select(['p/a', 'p/b'], table, AT);
  assert.equal(r.kind, 'blocked');
  if (r.kind !== 'blocked') return;
  assert.equal(r.earliest, AT + BACKOFF_BASE_MS);
  assert.deepEqual(r.routes.sort(), ['p/a', 'p/b']);
});

test('[S3] resolution is unroutable when every entry is dead', () => {
  const dead = applyOutcome(UNTRIED, outcome({ class: 'capability', scope: 'model' }));
  const r = select(['p/a', 'p/b'], { 'p/a': dead, 'p/b': dead }, AT);
  assert.equal(r.kind, 'unroutable');
});

test('a failure never brings the next attempt earlier than the record already puts it', () => {
  const cooling = applyOutcome(UNTRIED, outcome({ class: 'quota', reason: 'quota', refreshAt: AT + 3_600_000 }));
  if (cooling.state !== 'cooling') throw new Error('expected cooling');
  const again = applyOutcome(cooling, outcome({ class: 'transient', at: AT + 1000 }));
  assert.equal(again.state, 'cooling');
  if (again.state !== 'cooling') return;
  assert.ok(again.until >= cooling.until, 'until is monotone');
});
