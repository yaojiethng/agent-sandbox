import test from 'node:test';
import assert from 'node:assert/strict';
import { classify, nextUtcMidnight } from '../../../src/libs/dispatch/classify.ts';

const AT = Date.UTC(2026, 9, 22, 14, 2, 0);

test('a rate limit is quota with the rate reason', () => {
  const v = classify('429 Rate limit exceeded', AT);
  assert.equal(v.id, 'rate-limit');
  assert.equal(v.class, 'quota');
  assert.equal(v.reason, 'rate');
});

test('a plan limit is quota, not capability, and carries the reset it replenishes at', () => {
  const v = classify('FreeUsageLimitError: daily free usage exhausted', AT);
  assert.equal(v.class, 'quota');
  assert.equal(v.scope, 'account');
  assert.equal(v.refreshAt, nextUtcMidnight(AT));
  assert.ok(v.refreshAt! > AT);
});

test('an expired key is capability on the account, which no clock lifts', () => {
  const v = classify('AuthError: Invalid API key', AT);
  assert.equal(v.class, 'capability');
  assert.equal(v.scope, 'account');
  assert.equal(v.refreshAt, undefined);
});

test('a refusal to serve this client is capability on the provider', () => {
  const v = classify('FreeTierError: can only be used from within the OpenCode app', AT);
  assert.equal(v.id, 'client-refused');
  assert.equal(v.class, 'capability');
  assert.equal(v.scope, 'provider');
});

test('an unavailable model is capability on the model', () => {
  const v = classify('Model is unavailable', AT);
  assert.equal(v.class, 'capability');
  assert.equal(v.scope, 'model');
});

test('an unfunded balance is the account\'s, even when the body carries a request error code', () => {
  // A 402 arrives with "code":"invalid_request_error" in the body. The code names
  // the shape of the envelope, not the fault, and the fault is no-retry.
  const v = classify('402: {"message":"Insufficient Balance (request_id: 9cf76f00)","type":"unknown_error","code":"invalid_request_error"}', AT);
  assert.equal(v.id, 'funds');
  assert.equal(v.class, 'capability');
  assert.equal(v.scope, 'account');
});

test('a malformed request is capability on the request', () => {
  const v = classify('invalid_request_error: reasoning_effort', AT);
  assert.equal(v.id, 'bad-request');
  assert.equal(v.class, 'capability');
  assert.equal(v.scope, 'request');
});

test('a 503 is transient', () => {
  const v = classify('503 Service Unavailable', AT);
  assert.equal(v.id, 'transport');
  assert.equal(v.class, 'transient');
});

test('an undeclared sentence is unclassified rather than guessed', () => {
  const v = classify('the gateway said no in a new way', AT);
  assert.equal(v.id, 'unclassified');
  assert.equal(v.class, 'unknown');
});

test('the next UTC midnight is the declared replenishment, not a guess', () => {
  const midnight = nextUtcMidnight(AT);
  assert.equal(new Date(midnight).getUTCHours(), 0);
  assert.equal(new Date(midnight).getUTCMinutes(), 0);
  assert.ok(midnight - AT <= 24 * 60 * 60 * 1000);
});

test('the supervisor ending an attempt at its limit is timeout, which stops the walk', () => {
  const v = classify('aborted: the time limit of 1800s expired', AT);
  assert.equal(v.id, 'attempt-timeout');
  assert.equal(v.class, 'timeout');
  assert.equal(v.reason, 'timeout');
});

test('the supervisor ending a silent attempt is transient, so the next entry is tried', () => {
  const v = classify('aborted: no output for 15s, which is how the CLI retries a refused request', AT);
  assert.equal(v.id, 'silent-attempt');
  assert.equal(v.class, 'transient');
  assert.equal(v.reason, 'flaky');
});
