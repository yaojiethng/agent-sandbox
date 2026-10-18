#!/usr/bin/env node
// Detects inversions in a commit range: content one commit writes that a later
// commit in the same range removes.
//
// An inversion is what makes a reviewer read the same rule twice, the second
// occurrence cancelling the first. It cannot be read off commit subjects, which
// describe intent, so it is computed from the patches.
//
//   node .agents/drafts/history-cleanup/inversions.mjs <base> [tip]
//   VERBOSE=1 node ... <base> [tip]     also prints each line in full
//
// Reads added and removed content lines per commit per file, then reports every
// ordered pair where a line added by the earlier commit is removed by the later
// one. Only pairs inside the range are compared; a line removed outside it is
// out of scope.
//
// The diff marker must be stripped before comparing. Keeping it makes every
// added line differ from every removed one by the leading character, so the
// report is a confident and wrong "none". That defect was live for one run.
//
// Two kinds of hit are not design inversions and the caller has to classify
// them: a record corrected by a later commit, and a generated file regenerated
// whole at each commit, whose hash-keyed rows churn without anyone reading them.

import { execFileSync } from "node:child_process";

const base = process.argv[2];
const tip = process.argv[3] ?? "HEAD";
const git = (args) => execFileSync("git", args, { encoding: "utf8", maxBuffer: 1 << 28 });
const shas = git(["log", "--reverse", "--format=%h", `${base}..${tip}`]).trim().split("\n");

// per commit: file -> { added:Set, removed:Set }
const per = shas.map((sha) => {
  const out = git(["diff-tree", "-p", "--no-commit-id", "-U0", sha]);
  const files = new Map();
  let file = null;
  for (const line of out.split("\n")) {
    if (line.startsWith("+++ b/")) { file = line.slice(6); if (!files.has(file)) files.set(file, { added: new Set(), removed: new Set() }); continue; }
    if (line.startsWith("--- ")) continue;
    if (!file || line.startsWith("@@")) continue;
    const body = line.slice(1).trim();
    if (body.length < 8) continue;
    if (line.startsWith("+")) files.get(file).added.add(body);
    else if (line.startsWith("-")) files.get(file).removed.add(body);
  }
  return { sha, files };
});

const findings = [];
for (let i = 0; i < per.length; i++) {
  for (let j = i + 1; j < per.length; j++) {
    for (const [file, a] of per[i].files) {
      const b = per[j].files.get(file);
      if (!b) continue;
      for (const line of a.added) if (b.removed.has(line)) findings.push({ file, write: per[i].sha, undo: per[j].sha, line });
    }
  }
}
const byPair = new Map();
for (const f of findings) {
  const k = `${f.write} -> ${f.undo}  ${f.file}`;
  byPair.set(k, (byPair.get(k) ?? 0) + 1);
}
console.log("## Inversions, content written then removed inside the range\n");
if (findings.length === 0) console.log("none");
for (const [k, n] of [...byPair.entries()].sort((x, y) => y[1] - x[1])) console.log(`${String(n).padStart(3)} lines  ${k}`);
console.log(`\ntotal ${findings.length} line(s) across ${byPair.size} pair/file combination(s)`);

if (process.env.VERBOSE) {
  console.log("\n## The lines, in full\n");
  for (const f of findings) console.log(`${f.write} -> ${f.undo}  ${f.file}\n    ${f.line.slice(0, 170)}\n`);
}
