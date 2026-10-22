// scripts/lint/numbering.mjs
// The numbering rule's cheap check: one document at a time, plus the documents
// it names.
//
// The rule is stated in .agents/skills/numbering/SKILL.md. A document class
// declares whether its units take a number or an identity name, and the check
// reads the class's own document. Nothing here holds a registry, a baseline or
// a counter: a number is contiguous from 1 within its own scope, so a gap is the
// whole defect signal.
//
// Checks, all from one pass:
//   gaps     --  numbered units of one kind are 1..n in document order
//   sections --  dotted section numbers are siblings-incrementing, with a parent
//   refs     --  a qualified reference `<document id>/<unit>` names a document
//                that exists and a unit that exists in it
//
// Usage: node numbering.mjs [--root DIR]

import fs from 'node:fs';
import path from 'node:path';

const rootArg = process.argv.indexOf('--root');
const ROOT = rootArg > -1 ? process.argv[rootArg + 1] : process.cwd();
process.chdir(ROOT);
const skip = /(^|\/)(\.git|\.scratchpad|node_modules|archive|drafts)\//;

const files = [];
(function walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name).replace(/^\.\//, '');
    if (skip.test(p + '/')) continue;
    if (e.isDirectory()) walk(p);
    else if (e.name.endsWith('.md')) files.push(p);
  }
})(ROOT);

// unit lines: a heading, a list item or an ordered item that opens with a kind
const unitLine = /^(?:#{1,6}|[-*]|\d+\.)\s+\**([FQDR])(\d{1,3})\b/;
const sectionLine = /^(#{1,6})\s+(\d+(?:\.\d+)*)[.)]?\s/;

const units = new Map(); // file -> Map(prefix -> [{n, line}])
const sections = new Map(); // file -> [{depth, num, line}]

for (const f of files) {
  const lines = fs.readFileSync(f, 'utf8').split('\n');
  let fenced = false;
  lines.forEach((line, i) => {
    if (/^```/.test(line)) { fenced = !fenced; return; }
    if (fenced) return;
    const u = line.match(unitLine);
    if (u) {
      if (!units.has(f)) units.set(f, new Map());
      const m = units.get(f);
      if (!m.has(u[1])) m.set(u[1], []);
      m.get(u[1]).push({ n: Number(u[2]), line: i + 1 });
    }
    const h = line.match(/^(#{1,6})\s+(.*)$/);
    if (h) {
      if (!sections.has(f)) sections.set(f, []);
      const sm = line.match(sectionLine);
      sections.get(f).push({
        depth: h[1].length,
        numbered: Boolean(sm),
        num: sm ? sm[2].split('.').map(Number) : null,
        line: i + 1,
      });
    }
  });
}

const findings = [];
const add = (f, line, kind, detail) => findings.push({ f, line, kind, detail });

for (const [f, byKind] of units) {
  for (const [prefix, list] of byKind) {
    list.forEach((u, i) => {
      if (u.n !== i + 1) add(f, u.line, 'gaps', `${prefix}${u.n} is at position ${i + 1}, expected ${prefix}${i + 1}`);
    });
  }
}

// A depth carries a section series when its numbered headings form an
// uninterrupted run. An unnumbered heading inside the run means the numbers are
// enumerating prose, not sections, and that depth is left alone.
for (const [f, list] of sections) {
  const depths = new Set(list.map((h) => h.depth));
  for (const depth of depths) {
    const atDepth = list.filter((h) => h.depth === depth);
    const numbered = atDepth.filter((h) => h.numbered);
    if (numbered.length < 2) continue;
    const lastNumbered = atDepth.lastIndexOf(numbered[numbered.length - 1]);
    const uninterrupted = atDepth.slice(0, lastNumbered + 1).every((h) => h.numbered);
    if (!uninterrupted) continue;
    for (let i = 1; i < numbered.length; i++) {
      const prev = numbered[i - 1];
      const s = numbered[i];
      const sameParent = s.num.slice(0, -1).join('.') === prev.num.slice(0, -1).join('.');
      if (sameParent && s.num[s.num.length - 1] !== prev.num[prev.num.length - 1] + 1) {
        add(f, s.line, 'sections', `${s.num.join('.')} follows ${prev.num.join('.')}`);
      }
      if (s.num.length > prev.num.length + 1) {
        add(f, s.line, 'sections', `${s.num.join('.')} skips a level after ${prev.num.join('.')}`);
      }
    }
  }
}

// qualified references: a handover id, a milestone id, or a backticked path,
// then a slash, then a unit number
const docRef = /(?:\b(\d{8}-\d{2})|`([^`]+\.md)`)\s*\/\s*([FQDR])(\d{1,3})\b/g;
const byBase = new Map();
for (const f of files) {
  const b = path.basename(f);
  if (!byBase.has(b)) byBase.set(b, []);
  byBase.get(b).push(f);
}

for (const f of files) {
  const text = fs.readFileSync(f, 'utf8');
  for (const m of text.matchAll(docRef)) {
    const id = m[1] ?? m[2];
    const prefix = m[3];
    const n = Number(m[4]);
    const target = m[2]
      ? (byBase.get(path.basename(m[2])) ?? [])
      : files.filter((x) => path.basename(x).startsWith(id));
    if (target.length !== 1) { add(f, lineOf(text, m.index), 'refs', `${id} names ${target.length} documents`); continue; }
    const list = (units.get(target[0])?.get(prefix) ?? []).map((u) => u.n);
    if (!list.includes(n)) add(f, lineOf(text, m.index), 'refs', `${id}/${prefix}${n} names no unit in ${target[0]}`);
  }
}

function lineOf(text, index) { return text.slice(0, index).split('\n').length; }

for (const x of findings) console.log(`${x.f}:${x.line}: ${x.kind}: ${x.detail}`);
if (findings.length) {
  console.log(`numbering: ${findings.length} finding(s) across ${files.length} document(s)`);
  process.exit(1);
}
const withSections = [...sections.values()].filter((l) => l.some((h) => h.numbered)).length;
console.log(`numbering: clean across ${files.length} document(s), ${units.size} with numbered units, ${withSections} with numbered sections`);
