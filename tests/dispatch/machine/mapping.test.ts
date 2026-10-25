// The mapping check: every transition id in the table has a case, and every
// case names an id the table holds. Without it the suite stops matching the
// machine and an uncovered transition still reads as covered.

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { INVARIANTS, SELECTIONS, TRANSITIONS } from '../../../src/libs/dispatch/machine.ts';

const here = dirname(fileURLToPath(import.meta.url));

function idsIn(file: string): string[] {
  const source = readFileSync(join(here, file), 'utf8');
  return [...source.matchAll(/\[([RS]\d+)\]/g)].map((m) => m[1]);
}

test('[M1] every transition and selection id has a case', () => {
  const cases = new Set([...idsIn('machine.test.ts')]);
  const declared: string[] = [...TRANSITIONS.map((t) => t.id), ...SELECTIONS.map((s) => s.id)];
  const missing = declared.filter((id) => !cases.has(id));
  assert.deepEqual(missing, [], `uncovered ids: ${missing.join(', ')}`);
});

test('[M2] every case names an id the table holds', () => {
  const declared = new Set<string>([...TRANSITIONS.map((t) => t.id), ...SELECTIONS.map((s) => s.id)]);
  const unknown = [...idsIn('machine.test.ts')].filter((id) => !declared.has(id));
  assert.deepEqual(unknown, [], `cases naming unknown ids: ${unknown.join(', ')}`);
});

test('[M3] every transition names an invariant the table holds', () => {
  const known = new Set(INVARIANTS.map((i) => i.id));
  const unnamed = TRANSITIONS.filter((t) => !known.has(t.invariant)).map((t) => t.id);
  assert.deepEqual(unnamed, [], `transitions with no invariant: ${unnamed.join(', ')}`);
});
