// scripts/lint/code-snippets.mjs
// The code-snippet rule's cheap check: every fenced block under docs/ says where
// it came from, and a block that names a source is compared against it.
//
// The rule and its four patterns are
// .agents/skills/project-documentation/references/code-snippets.md. The gate
// cannot tell that a block restates a file the repository owns: that is a
// judgement about the block's content. What it can do is make the claim
// mechanical, so a `derived` block fails the moment its source moves on, and
// make an undeclared block impossible to add silently.
//
// Findings:
//   UNDECLARED   -- no `<!-- snippet: ... -->` marker on the line above the
//                   fence, and no baseline entry holding this block's content
//   UNKNOWN-KIND -- the marker names none of derived, generated, illustrative
//   NOSOURCE     -- a `derived <path>` marker names a file that is not there
//   STALE        -- a `derived <path>` block's lines are no longer in that file
//   PRUNABLE     -- a baseline entry with no block left to carry it
//
// An archive is a record of the system as it stood, so docs/adr/archive/ is not
// read: holding a record to today's source would correct the record.
//
// Usage: node code-snippets.mjs [--root DIR] [--update]
// Exit:  0 = clean, 1 = a finding, 2 = the baseline is missing

import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const argv = process.argv.slice(2);
const rootArg = argv.indexOf('--root');
const ROOT = rootArg > -1 ? argv[rootArg + 1] : process.cwd();
const UPDATE = argv.includes('--update');
const BASELINE = path.join(ROOT, 'scripts/lint/code-snippets.baseline');
const SKIP = /^docs\/adr\/archive\//;
const KINDS = new Set(['derived', 'generated', 'illustrative']);

const rel = (p) => path.relative(ROOT, p).split(path.sep).join('/');

function markdownFiles(dir) {
  const out = [];
  const walk = (d) => {
    for (const e of fs.readdirSync(d, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
      const p = path.join(d, e.name);
      if (e.isDirectory()) walk(p);
      else if (e.name.endsWith('.md') && !SKIP.test(rel(p))) out.push(p);
    }
  };
  if (fs.existsSync(dir)) walk(dir);
  return out;
}

// A block's content is compared with trailing whitespace and the blank lines at
// either end removed, because those are what an editor or a paste changes, and
// they are not what the block says.
function normalize(lines) {
  const trimmed = lines.map((l) => l.replace(/\s+$/, ''));
  while (trimmed.length && trimmed[0] === '') trimmed.shift();
  while (trimmed.length && trimmed[trimmed.length - 1] === '') trimmed.pop();
  return trimmed.join('\n');
}

function hash(body) {
  return crypto.createHash('sha256').update(body).digest('hex').slice(0, 16);
}

const MARKER = /^<!-- snippet: (.*?) -->$/;
const blocks = [];

for (const file of markdownFiles(path.join(ROOT, 'docs'))) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  let open = -1;
  let marker = null;
  let markerLine = 0;
  for (let i = 0; i < lines.length; i += 1) {
    const fence = /^\s*```/.exec(lines[i]);
    if (!fence) continue;
    if (open === -1) {
      open = i;
      marker = null;
      for (let j = i - 1; j >= 0; j -= 1) {
        if (lines[j].trim() === '') continue;
        const m = MARKER.exec(lines[j].trim());
        if (m) {
          marker = m[1].trim();
          markerLine = j + 1;
        }
        break;
      }
    } else {
      const body = normalize(lines.slice(open + 1, i));
      blocks.push({ file: rel(file), line: open + 1, marker, markerLine, body, hash: hash(body) });
      open = -1;
    }
  }
}

const findings = [];
const add = (block, kind, detail) => findings.push({ file: block.file, line: block.line, kind, detail });

for (const b of blocks) {
  if (b.marker === null) continue;
  const [kindWord, ...rest] = b.marker.split(/\s+/);
  if (!KINDS.has(kindWord)) {
    add(b, 'UNKNOWN-KIND', `marker names "${kindWord}", which is none of derived, generated, illustrative`);
    continue;
  }
  if (kindWord !== 'derived') continue;
  const source = rest.join(' ');
  if (!source) {
    add(b, 'UNKNOWN-KIND', 'a derived marker names no path');
    continue;
  }
  const sourcePath = path.join(ROOT, source);
  if (!fs.existsSync(sourcePath)) {
    add(b, 'NOSOURCE', `no such file: ${source}`);
    continue;
  }
  const sourceBody = normalize(fs.readFileSync(sourcePath, 'utf8').split('\n'));
  if (!`\n${sourceBody}\n`.includes(`\n${b.body}\n`)) {
    add(b, 'STALE', `the block's lines are not in ${source} any more`);
  }
}

const readBaseline = () =>
  fs.existsSync(BASELINE)
    ? fs
        .readFileSync(BASELINE, 'utf8')
        .split('\n')
        .map((l) => l.trim())
        .filter((l) => l && !l.startsWith('#'))
        .map((l) => {
          const [h, ...file] = l.split(/\s+/);
          return { hash: h, file: file.join(' ') };
        })
    : null;

const baseline = readBaseline();

if (UPDATE) {
  const rows = blocks
    .filter((b) => b.marker === null)
    .map((b) => `${b.hash}  ${b.file}`)
    .sort();
  const head = [
    '# scripts/lint/code-snippets.baseline',
    '# Blocks that were in the tree when the code-snippet gate landed, and declare',
    '# no source. Regenerate with: node scripts/lint/code-snippets.mjs --update',
    '# An entry leaving this file is the edit that states an intent to change a block.',
  ];
  fs.writeFileSync(BASELINE, `${[...head, ...rows].join('\n')}\n`);
  console.log(`code-snippets: baseline holds ${rows.length} block(s)`);
  process.exit(0);
}

if (baseline === null) {
  console.error(`code-snippets: no baseline at ${rel(BASELINE)}; run node scripts/lint/code-snippets.mjs --update`);
  process.exit(2);
}

const inBaseline = new Set(baseline.map((e) => e.hash));
for (const b of blocks) {
  if (b.marker === null && !inBaseline.has(b.hash)) {
    add(b, 'UNDECLARED', 'no `<!-- snippet: ... -->` marker above the fence, and no baseline entry');
  }
}
const present = new Set(blocks.map((b) => b.hash));
for (const e of baseline) {
  if (!present.has(e.hash)) {
    findings.push({ file: e.file, line: 0, kind: 'PRUNABLE', detail: 'a baseline entry with no block left; --update drops it' });
  }
}

if (findings.length === 0) {
  console.log(`code-snippets: clean, ${blocks.length} block(s) across docs/`);
  process.exit(0);
}
findings.sort((a, b) => (a.file === b.file ? a.line - b.line : a.file < b.file ? -1 : 1));
console.log(`code-snippets: ${findings.length} finding(s)`);
for (const f of findings) {
  console.log(`  ${f.file}${f.line ? `:${f.line}` : ''}  ${f.kind}  ${f.detail}`);
}
process.exit(1);
