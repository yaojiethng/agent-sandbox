#!/usr/bin/env node
// Documented command surface matrix. Reads the ADR taxonomy table, resolves each
// documented artifact, checks it under the shipped prompt root the manifest
// declares, and reports the roadmap task row that names the command.
//
// Exit codes: 0 in reading mode; with --strict, 1 when a documented command's
// artifact neither ships nor carries a legitimate exemption (a draft artifact,
// or a future-milestone owning row).
import { readFileSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { join } from "node:path";

const REPO = execSync("git rev-parse --show-toplevel", { encoding: "utf8" }).trim();
const ADR = "docs/adr/coding_agent_loop_workflow.md";
const MANIFEST = "src/build/container-interface.json";
const strict = process.argv.includes("--strict");

const manifest = JSON.parse(readFileSync(join(REPO, MANIFEST), "utf8"));
const promptCell = (manifest.cells || []).find((c) =>
  (c.sources || []).some((s) => s.includes("workflow/coding-agent/prompts")),
);
if (!promptCell || !promptCell.runtime_path) {
  console.error(`command-surface-matrix: no cell in ${MANIFEST} declares a workflow prompt source`);
  process.exit(1);
}
const RUNTIME = promptCell.runtime_path;
const runtimePresent = existsSync(RUNTIME);

const adr = readFileSync(join(REPO, ADR), "utf8");
const rows = adr
  .split("\n")
  .filter((l) => /^\|\s*`\//.test(l))
  .map((l) => {
    const cells = l.split("|").map((c) => c.trim());
    const cmd = (cells[1].match(/`(\/[^`]+)`/) || [])[1];
    const owner = cells[2].replace(/\*\*/g, "").replace(/\s*\(.*$/, "");
    const artifactCell = cells[cells.length - 2];
    const path = (artifactCell.match(/`([^`]+\.md)`/) || [])[1] || "";
    const declaredDraft = /draft/i.test(artifactCell);
    return { cmd, owner, path, declaredDraft };
  });

// /wrapup appears in the ADR body rather than the table, so it is injected only
// when the ADR names it. A repository without the row gets no spurious finding.
if (!rows.some((r) => r.cmd === "/wrapup") && adr.includes("`/wrapup`")) {
  rows.push({
    cmd: "/wrapup",
    owner: "shared close runbook",
    path: "workflow/coding-agent/prompts/wrapup.md",
    declaredDraft: false,
  });
}

function namingRow(cmd) {
  const token = "`" + cmd + "`";
  for (const file of ["devlog/roadmap.md", "devlog/roadmap_future.md"]) {
    const lines = readFileSync(join(REPO, file), "utf8").split("\n");
    for (let i = 0; i < lines.length; i++) {
      if (!lines[i].includes(token) || !/^\s*- \[[ x]\]/i.test(lines[i])) continue;
      let heading = "";
      for (let j = i; j >= 0; j--) {
        if (/^#{2,4}\s/.test(lines[j])) {
          heading = lines[j].replace(/^#+\s*/, "").trim().replace(/\s*--.*$/, "").split(" - ")[0];
          break;
        }
      }
      const future = file.includes("roadmap_future");
      const state = /^\s*- \[x\]/i.test(lines[i]) ? "closed" : "open";
      return `${future ? "future" : "active"} ${heading} (${state})`;
    }
  }
  return "-";
}

const pad = (s, n) => (s.length > n ? s.slice(0, n - 1) + "~" : s + " ".repeat(n - s.length));
const width = { cmd: 17, path: 44, shipped: 8, owner: 36, row: 24 };
const head = [
  pad("command", width.cmd),
  pad("repo artifact", width.path),
  pad("shipped", width.shipped),
  pad("ADR owner", width.owner),
  "naming task row",
];
console.log(head.join("  "));
console.log(Object.values(width).map((n) => "-".repeat(n)).join("  "));

const findings = [];
for (const r of rows) {
  const inRepo = r.path ? existsSync(join(REPO, r.path)) : false;
  const shipped = inRepo && runtimePresent && existsSync(join(RUNTIME, r.path.split("/").pop()));
  const row = namingRow(r.cmd);
  const futureRow = row.startsWith("future");
  const repoCol = r.path ? (inRepo ? "exists" : "MISSING") : "none";
  console.log(
    [
      pad(r.cmd, width.cmd),
      pad(r.path || "-", width.path),
      pad(runtimePresent ? (shipped ? "yes" : "NO") : "?", width.shipped),
      pad(r.owner, width.owner),
      row,
    ].join("  "),
  );

  // A path that does not exist is legitimate only when the owning row is a
  // future milestone, whose artifact is not built yet. A row that declares the
  // artifact a draft must still have that draft in the tree.
  if (r.path && !inRepo) {
    if (!futureRow) findings.push(`${r.cmd}: documented path does not resolve (${r.path})`);
  } else if (r.path && runtimePresent && !shipped && !r.declaredDraft && !futureRow) {
    findings.push(`${r.cmd}: documented and neither shipped nor declared a draft (${r.path})`);
  }
  void repoCol;
}

if (!runtimePresent) {
  console.error(`\n  note: runtime root ${RUNTIME} is absent, so shipped status is unchecked`);
}

if (findings.length) {
  console.error("\n" + findings.map((f) => "  " + f).join("\n"));
  console.error(`${findings.length} finding(s)`);
}
process.exit(strict && findings.length ? 1 : 0);
