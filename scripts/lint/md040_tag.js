// scripts/lint/md040_tag.js -- apply a language tag to bare ``` fences.
// Policy (operator-adjudicated): clear shell code -> bash; everything else
// (trees, directory listings, make/CLI usage, plain text blobs, example
// markdown) -> text. This is not a content judgment: it applies the
// confirmed (i) default and only promotes to bash on strong code signals.
"use strict";
const fs = require("fs");
const { execSync } = require("child_process");

const PREFIX = "/home/agentuser/.local/lib/node_modules/markdownlint-cli2/node_modules/markdownlint/lib";

// Strong bash signal: a block that starts with a control flow keyword,
// function, `$ cmd`, assignment, shebang, or common shell builtin.
function isBash(body) {
  const first = body.trimStart().split("\n")[0] || "";
  return /^(if |for |while |case |function |[a-zA-Z_][a-zA-Z0-9_]*\(\)\s*\{|#!\/|export |readonly |local |set -|source |\. )/.test(first)
    || (body.includes("\n") && /^(\s*)?(if |for |while |case )/.test(body))
    || /^(\$\s|sudo |make |docker |npm |npx |git |agent-sandbox )/.test(first);
}

async function main() {
  const mode = process.argv[2] || "apply"; // apply | plan
  const files = execSync("git ls-files '*.md'", { encoding: "utf8", cwd: process.cwd() })
    .split("\n").filter(Boolean)
    .filter(f => !f.endsWith("docs/operations/documentation_policy.md"));
  const sync = await import(`${PREFIX}/exports-sync.mjs`);
  const cfg = { default: true, MD013: false, MD060: false };

  let plan = [];
  for (const f of files) {
    const lines = fs.readFileSync(f, "utf8").split("\n");
    const vv = (sync.lint({ strings: { _: lines.join("\n") }, config: cfg })._ || [])
      .filter(v => v.ruleNames[0] === "MD040");
    for (const v of vv) {
      const i = v.lineNumber - 1;
      const block = [];
      let j = i + 1;
      while (j < lines.length && !lines[j].startsWith("```")) { block.push(lines[j]); j++; }
      const body = block.join("\n");
      const tag = isBash(body) ? "bash" : "text";
      plan.push({ file: f, line: v.lineNumber, tag, body: body.slice(0, 60) });
    }
  }
    if (mode === "plan") {
      console.log("MD040 tagging plan:");
      for (const p of plan) console.log(`  ${p.tag.padEnd(5)} ${p.file}:${p.line}  ${p.body.replace(/\n/g," ")}`);
      console.log(`\n${plan.length} fences; bash=${plan.filter(p=>p.tag==="bash").length}, text=${plan.filter(p=>p.tag==="text").length}`);
      return;
    }
    // Human-confirmed overrides (operator-reviewed); file:line -> tag
    const overrides = {
      "devlog/discussions/design_apply_draft_workflow.md:53": "text",
      "devlog/discussions/design_apply_draft_workflow.md:65": "text",
      "devlog/discussions/design_apply_draft_workflow.md:75": "text",
      "devlog/discussions/design_apply_draft_workflow.md:83": "text",
      "devlog/discussions/prompt-eval-design.md:298": "text",
      "devlog/handovers/20260701-02-design-m2_6_2_persistence_scoping.md:16": "text",
      "devlog/handovers/20260810-04-impl-cli_help_routing_and_provider_doc.md:99": "text",
      "src/reasoning/agent/skills/setup-pre-commit/SKILL.md:41": "text",
    };
    // apply: rewrite the opening ``` -> ```<tag> for each fence
    let changed = 0;
    for (const p of plan) {
      const tag = overrides[`${p.file}:${p.line}`] || p.tag;
      const lines = fs.readFileSync(p.file, "utf8").split("\n");
      const idx = p.line - 1;
      if (lines[idx] === "```") { lines[idx] = "```" + tag; changed++; }
      fs.writeFileSync(p.file, lines.join("\n"));
    }
    console.log(`applied tags to ${changed} fences`);
}
main().catch(e => { console.error(e); process.exit(1); });