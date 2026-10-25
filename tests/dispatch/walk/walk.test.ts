// The walk's advance rule: one case per branch of the table. The shell cases
// hold the wiring; these hold the policy.

import { strict as assert } from 'node:assert';
import test from 'node:test';
import { decideWalk } from '../../../src/libs/dispatch/walk.ts';
import type { WalkInput } from '../../../src/libs/dispatch/walk.ts';

function input(partial: {
  class?: 'success' | 'transient' | 'quota' | 'capability' | 'timeout' | 'unknown';
  scope?: 'none' | 'model' | 'provider' | 'account' | 'request';
  emptyLog?: boolean;
}): WalkInput {
  return { mode: 'general', class: 'success', scope: 'none', emptyLog: false, ...partial };
}

function worker(partial: {
  class?: 'success' | 'transient' | 'quota' | 'capability' | 'timeout' | 'unknown';
  scope?: 'none' | 'model' | 'provider' | 'account' | 'request';
  treeChanged?: boolean;
  emptyLog?: boolean;
}): WalkInput {
  return { mode: 'worker', class: 'success', scope: 'none', treeChanged: false, emptyLog: false, ...partial };
}

test('a general walk advances on a route failure that another model may repair', () => {
  assert.deepEqual(decideWalk(input({ class: 'transient' })), { advance: true });
  assert.deepEqual(decideWalk(input({ class: 'quota', scope: 'account' })), { advance: true });
  assert.deepEqual(decideWalk(input({ class: 'capability', scope: 'model' })), { advance: true });
});

test('a timeout is not retried on another entry', () => {
  const decision = decideWalk(input({ class: 'timeout' }));
  assert.equal(decision.advance, false);
  if (decision.advance) return;
  assert.match(decision.reason, /same budget/);
});

test('a capability failure at the request or the account is not repaired by another model', () => {
  for (const scope of ['request', 'account'] as const) {
    const decision = decideWalk(input({ class: 'capability', scope }));
    assert.equal(decision.advance, false, `scope ${scope}`);
    if (decision.advance) continue;
    assert.match(decision.reason, /not another model/);
  }
});

test('an unclassified failure is not guessed at', () => {
  const decision = decideWalk(input({ class: 'unknown' }));
  assert.equal(decision.advance, false);
});

test('an exit zero with an empty log is a failure in either mode', () => {
  assert.equal(decideWalk(input({ emptyLog: true })).advance, false);
  assert.equal(decideWalk(worker({ emptyLog: true })).advance, false);
});

test('a worker advances only while the tree is unchanged', () => {
  assert.deepEqual(decideWalk(worker({})), { advance: true });
  const changed = decideWalk(worker({ treeChanged: true }));
  assert.equal(changed.advance, false);
  if (changed.advance) return;
  assert.match(changed.reason, /change set/);
});

test('a worker stops on a failure no model repairs, and on a changed tree', () => {
  assert.equal(decideWalk(worker({ class: 'capability', scope: 'account' })).advance, false);
  assert.equal(decideWalk(worker({ class: 'capability', scope: 'request' })).advance, false);
  assert.equal(decideWalk(worker({ treeChanged: true })).advance, false);
  // The worker's own divergence: an unclassified failure with an unchanged
  // tree may still be another model's to solve.
  assert.deepEqual(decideWalk(worker({ class: 'unknown' })), { advance: true });
});
