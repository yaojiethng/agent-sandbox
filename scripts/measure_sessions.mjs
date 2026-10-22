#!/usr/bin/env node
// scripts/measure_sessions.mjs
// Measure what the agent received, from the pi session store.
//
// A session store is a directory per working directory, one JSONL file per
// session. Each line holds either a session record or one message. This script
// reads the store and nothing else; it writes nothing.
//
// Usage:
//   node scripts/measure_sessions.mjs delivery [store] [root]
//   node scripts/measure_sessions.mjs join     [store]
//
// delivery  counts sessions, iteration passes, commits and brief sizes, then
//           reports per document whether its path was named in a read or a bash
//           call, whether its text appeared without one, and the union.
// join      treats "the session named a convention skill" as the exposure and
//           the operator correction rate per pass as the outcome, with the
//           pass's user-turn count as an offset so length cannot inflate it.
//
// The unit is the pass: a session that wrote a file under devlog/handovers/.
// A typed slash command is not an invocation, because almost no session starts
// with one.
//
// Traps, each measured the hard way:
//   - A bash command containing "SKILL.md" touches every skill. Match the
//     repository-relative path, never the basename.
//   - Resolving a read of "SKILL.md" by its stem collapses every skill onto one
//     file. Map the directory.
//   - Matching absolute paths only drops the relative ones. Accept both.
//   - A fingerprint taken from a common sentence matches the wrong document.
//     A fingerprint must be a line that appears in one document only.
//   - Tool output is truncated for large files, so a read can hide the text. A
//     document is delivered when its path is named or its text is matched.

import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const [mode, storeArgument] = process.argv.slice(2);
const STORE = storeArgument || process.env.PI_SESSION_STORE || join(process.env.HOME, '.pi/agent/sessions');

// One correction pattern, calibrated against a labelled sample: it flags the
// operator's rejections and skips bare acknowledgements. Precision matters more
// than reach here, because a false positive inflates the outcome in both arms.
const CORRECTION =
  /^(no\b|stop\b|why\b|again\b|wrong\b|revert\b|don'?t\b|undo\b|but\b|that'?s not|you didn'?t|not what|nope\b|wait\b|hold on\b|let'?s not\b)|(\bpremature\b|\bpushback\b|why .{0,12}you\b|by our (spec|specification)\b|\brolled back\b|\bi (was )?unclear\b|a bit (large|much|off|premature)\b|seems (to be )?.{0,20}\b(large|off|wrong)\b)/i;

const CONVENTIONS = [
  'task-list',
  'work-log',
  'decision-records',
  'docs',
  'git-discipline',
  'testing',
].map((n) => `.agents/skills/${n}/SKILL.md`);

const walk = (dir, out = []) => {
  for (const entry of readdirSync(dir)) {
    if (entry === '.git' || entry === 'node_modules') continue;
    const path = join(dir, entry);
    statSync(path).isDirectory() ? walk(path, out) : out.push(path);
  }
  return out;
};

const messages = (path) =>
  readFileSync(path, 'utf8')
    .split('\n')
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);

// readSession -- one pass over a session file, returning what both modes need.
const readSession = (path) => {
  const out = { pass: false, commit: false, turns: 0, corrections: 0, brief: null, named: new Set(), text: [] };
  for (const record of messages(path)) {
    const message = record.message;
    if (!message) continue;
    let body = typeof message.content === 'string' ? message.content : '';
    if (Array.isArray(message.content)) {
      for (const part of message.content) {
        if (part.type === 'text') body += part.text + '\n';
        if (part.type !== 'toolCall') continue;
        const args = part.arguments || {};
        const target = String(args.path || args.file_path || '');
        const command = String(args.command || '');
        if ((part.name === 'write' || part.name === 'edit') && target.includes('devlog/handovers/')) out.pass = true;
        if (part.name === 'bash' && /git commit/.test(command)) out.commit = true;
        for (const convention of CONVENTIONS) {
          if ((part.name === 'read' && target.endsWith(convention)) || (part.name === 'bash' && command.includes(convention))) {
            out.named.add(convention);
          }
        }
      }
    }
    out.text.push({ role: message.role, body });
    if (message.role !== 'user') continue;
    if (out.brief === null) out.brief = body;
    else {
      out.turns += 1;
      if (CORRECTION.test(body.trim())) out.corrections += 1;
    }
  }
  return out;
};

const sessions = () => {
  try {
    statSync(STORE);
  } catch {
    console.error(`no session store at ${STORE}`);
    process.exit(2);
  }
  return walk(STORE).filter((path) => path.endsWith('.jsonl')).map((path) => ({ path, ...readSession(path) }));
};

const quantile = (values, p) => {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(p * (sorted.length - 1))];
};

const modeDelivery = () => {
  const all = sessions();
  const passes = all.filter((s) => s.pass);
  const briefs = passes.map((s) => (s.brief || '').length);
  const summary = {
    sessions: all.length,
    passes: passes.length,
    commits: all.filter((s) => s.commit).length,
    slashOpeners: all.filter((s) => /^\/[a-z]/.test((s.brief || '').trim())).length,
    briefMean: Math.round(briefs.reduce((a, b) => a + b, 0) / (briefs.length || 1)),
    briefMedian: quantile(briefs, 0.5),
    briefP90: quantile(briefs, 0.9),
    briefMax: Math.max(0, ...briefs),
    briefTotal: briefs.reduce((a, b) => a + b, 0),
  };
  console.log(JSON.stringify(summary));
  const named = new Map();
  for (const s of all) for (const convention of s.named) named.set(convention, (named.get(convention) || 0) + 1);
  for (const convention of CONVENTIONS) console.log(`${convention}\t${named.get(convention) || 0}`);
};

// Poisson fit with an offset: log(mu) = log(turns) + b0 + b1 * exposure.
const fit = (rows, key) => {
  let b = [Math.log(0.02), 0];
  for (let step = 0; step < 60; step += 1) {
    const gradient = [0, 0];
    const hessian = [
      [0, 0],
      [0, 0],
    ];
    for (const row of rows) {
      const x = [1, row[key]];
      const eta = Math.log(Math.max(row.turns, 1)) + b[0] + b[1] * x[1];
      const mu = Math.exp(eta);
      for (let i = 0; i < 2; i += 1) {
        gradient[i] += x[i] * (row.corrections - mu);
        for (let j = 0; j < 2; j += 1) hessian[i][j] -= x[i] * x[j] * mu;
      }
    }
    const det = hessian[0][0] * hessian[1][1] - hessian[0][1] * hessian[1][0];
    if (!det) break;
    const d0 = (hessian[1][1] * -gradient[0] - hessian[0][1] * -gradient[1]) / det;
    const d1 = (-hessian[1][0] * -gradient[0] + hessian[0][0] * -gradient[1]) / det;
    b = [b[0] + d0, b[1] + d1];
    if (Math.abs(d0) + Math.abs(d1) < 1e-9) break;
  }
  let information = 0;
  for (const row of rows) {
    const mu = Math.exp(Math.log(Math.max(row.turns, 1)) + b[0] + b[1] * row[key]);
    information += row[key] * row[key] * mu;
  }
  return { estimate: b[1], se: Math.sqrt(1 / (information || 1)) };
};

const modeJoin = () => {
  const rows = sessions()
    .filter((s) => s.pass)
    .map((s) => ({ turns: s.turns, corrections: s.corrections, exposure: s.named.size ? 1 : 0 }));
  const rate = (row) => (row.turns ? 1000 * row.corrections / row.turns : 0);
  const mean = (values) => values.reduce((a, b) => a + b, 0) / (values.length || 1);
  const exposed = rows.filter((r) => r.exposure === 1);
  const unexposed = rows.filter((r) => r.exposure === 0);
  const { estimate, se } = fit(rows, 'exposure');
  console.log(
    JSON.stringify({
      passes: rows.length,
      exposed: exposed.length,
      unexposed: unexposed.length,
      rateExposed: +mean(exposed.map(rate)).toFixed(1),
      rateUnexposed: +mean(unexposed.map(rate)).toFixed(1),
      oddsRatio: +Math.exp(estimate).toFixed(2),
      ciLow: +Math.exp(estimate - 1.96 * se).toFixed(2),
      ciHigh: +Math.exp(estimate + 1.96 * se).toFixed(2),
    }),
  );
};

if (mode === 'delivery') modeDelivery();
else if (mode === 'join') modeJoin();
else {
  console.error('usage: measure_sessions.mjs delivery|join [store]');
  process.exit(2);
}
