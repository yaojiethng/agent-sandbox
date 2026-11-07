import test from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { defaultPath, load, recordAttempt } from '../../../src/libs/dispatch/state.ts';

function empty(session: string) {
  return { version: 1, session, routes: {}, usage: {} };
}

test('a saved memory loads back unchanged', () => {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-state-'));
  const path = join(dir, 'state.json');
  writeFileSync(path, JSON.stringify({
    version: 1,
    session: 's1',
    routes: { 'p/a': { state: 'cooling', until: 10, reason: 'flaky', strikes: 1 } },
    usage: { 'p/a': 3 },
  }));
  assert.deepEqual(load(path, 's1'), {
    version: 1,
    session: 's1',
    routes: { 'p/a': { state: 'cooling', until: 10, reason: 'flaky', strikes: 1 } },
    usage: { 'p/a': 3 },
  });
});

test('a missing or corrupt file is an empty memory, never an error', () => {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-state-'));
  const missing = join(dir, 'absent.json');
  assert.deepEqual(load(missing, 's1'), empty('s1'));
  const corrupt = join(dir, 'corrupt.json');
  writeFileSync(corrupt, 'not json');
  assert.deepEqual(load(corrupt, 's1'), empty('s1'));
});

test('the default path is namespaced by session and honours the override', () => {
  const before = process.env.DISPATCH_STATE_FILE;
  const beforeSession = process.env.SESSION_ID;
  delete process.env.DISPATCH_STATE_FILE;
  process.env.SESSION_ID = 'abc';
  assert.match(defaultPath(), /dispatch-state-abc\.json$/);
  process.env.DISPATCH_STATE_FILE = '/tmp/override.json';
  assert.equal(defaultPath(), '/tmp/override.json');
  if (before === undefined) delete process.env.DISPATCH_STATE_FILE;
  else process.env.DISPATCH_STATE_FILE = before;
  if (beforeSession === undefined) delete process.env.SESSION_ID;
  else process.env.SESSION_ID = beforeSession;
});

test('a readable file missing a field is merged onto an empty memory', () => {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-state-'));
  const path = join(dir, 'partial.json');
  writeFileSync(path, JSON.stringify({ version: 1, routes: { 'p/a': { state: 'ready' } } }));
  assert.deepEqual(load(path, 's1').usage, {});
  const wrongVersion = join(dir, 'wrong-version.json');
  writeFileSync(wrongVersion, JSON.stringify({ version: 2, routes: {} }));
  assert.deepEqual(load(wrongVersion, 's1'), empty('s1'));
  const notObject = join(dir, 'not-object.json');
  writeFileSync(notObject, JSON.stringify('not an object'));
  assert.deepEqual(load(notObject, 's1'), empty('s1'));
});

test('recording an attempt is one transaction and leaves no lock behind', () => {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-state-'));
  const path = join(dir, 'state.json');
  const next = recordAttempt(path, 's1', 'p/a', { at: 1000, class: 'success', scope: 'none' }, true);
  assert.deepEqual(next, { state: 'ready' });
  assert.deepEqual(load(path, 's1').usage, { 'p/a': 1 });
  assert.equal(existsSync(`${path}.lock`), false);
});

test('a lock left by a dead process is taken over', () => {
  const dir = mkdtempSync(join(tmpdir(), 'dispatch-state-'));
  const path = join(dir, 'state.json');
  // A pid the kernel cannot have assigned: the holder is provably gone.
  writeFileSync(`${path}.lock`, '2147483647\n');
  assert.deepEqual(recordAttempt(path, 's1', 'p/a', { at: 1, class: 'success', scope: 'none' }, false), { state: 'ready' });
  assert.equal(existsSync(`${path}.lock`), false);
});
