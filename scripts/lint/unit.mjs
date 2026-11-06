// scripts/lint/unit.mjs
// The vocabulary gate for the bare record-entity `unit`.
//
// `unit` is ordinary as a quantifier (`a unit of work`, `a unit of a pass`) and
// inside a compound (`unit test`, `unit suite`, `test unit`). It is not a
// synonym for a record entity: where the text means the iteration, the
// delivery commit, the branch, the handover, the roadmap row or the numbered
// item, it names that. The rule is stated in
// docs/reference/terminology.md, "Usage".
//
// The test-unit domain is exempt: its "unit" is the test unit, the quantity the
// suite counts. Those files are named below rather than rewritten.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const ROOT = process.cwd();

const ROOTS = [
  "workflow",
  ".agents/skills",
  "docs/reference",
  "docs/development",
  "AGENTS.md",
  "src/reasoning/agent",
];

const SKIP_PREFIXES = [
  "src/reasoning/agent/drafts/",
];

// The test-unit domain: its "unit" is the test case, the quantity the test
// suite counts, not the work unit.
const EXEMPT_PREFIXES = [
  ".agents/skills/testing/",
  ".agents/skills/initialize/assets/conventions/testing/",
  "workflow/coding-agent/skills/initialize/assets/conventions/testing/",
  "workflow/coding-agent/skills/close-read/",
];

const EXEMPT_FILES = new Set([
  "docs/development/test_harness_mechanism.md",
  "docs/reference/terminology.md",
]);

// The quantifier and the compound senses stay.
const ALLOWED =
  /\bunit[- ]tests?\b|\bunit[- ]testing\b|\bunit[- ]tested\b|\bunit suites?\b|\bunit harness(?:es)?\b|\bunit contracts?\b|\btest units?\b|\bunit under test\b|\bharness units?\b|\boperator units?\b|\bunit of (?:work|a pass|measure|isolation|instruction|a turn|turn)\b|\btoggle unit\b|\bunit cases?\b|\bUNIT:|\bprinciple-sequence-verifiable-units\b/gi;

const findings = [];
let scanned = 0;

function* walk(path) {
  const full = join(ROOT, path);
  let stat;
  try {
    stat = statSync(full);
  } catch {
    return;
  }
  if (stat.isFile()) {
    if (full.endsWith(".md")) yield path;
    return;
  }
  for (const name of readdirSync(full).sort()) {
    const child = `${path}/${name}`;
    if (SKIP_PREFIXES.some((p) => child.startsWith(p))) continue;
    yield* walk(child);
  }
}

function exempt(path) {
  return (
    EXEMPT_FILES.has(path) ||
    EXEMPT_PREFIXES.some((p) => path.startsWith(p))
  );
}

for (const root of ROOTS) {
  for (const path of walk(root)) {
    if (exempt(path)) continue;
    scanned += 1;
    const lines = readFileSync(join(ROOT, path), "utf8").split("\n");
    lines.forEach((line, index) => {
      const cleaned = line.replace(ALLOWED, " ");
      if (!/\bunits?\b/i.test(cleaned)) return;
      const match = /\bunits?\b/i.exec(cleaned);
      const start = Math.max(0, match.index - 60);
      const end = Math.min(cleaned.length, match.index + match[0].length + 60);
      const window = cleaned.slice(start, end).replace(/\s+/g, " ").trim();
      findings.push(`${path}:${index + 1}: ${window}`);
    });
  }
}

for (const finding of findings) console.log(finding);
if (findings.length === 0) {
  console.log(`unit vocabulary: clear across ${scanned} file(s)`);
} else {
  console.log(`unit vocabulary: ${findings.length} record-entity use(s) across ${scanned} file(s)`);
  process.exitCode = 1;
}
