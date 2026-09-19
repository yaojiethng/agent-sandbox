#!/usr/bin/env node
// scripts/lint/autofix.js
// Auto-fix markdownlint findings across the repo, one rule at a time.
// Uses the markdownlint core API (v0.41, bundled by markdownlint-cli2)
// directly, which avoids the cli2 config-file-linting interaction.
//
// Usage:
//   node scripts/lint/autofix.js <RULE> [FILE...]
//     RULE        rule name to fix (e.g. MD022). Only this rule is applied.
//     FILE...     files to process (default: all tracked *.md except
//                 docs/operations/documentation_policy.md, which is the
//                 non-chore file).
//
// Non-fixable rules (MD040/MD056/etc.) are skipped: the runner only writes
// files for rules whose findings carry usable fixInfo.
"use strict";
const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const PREFIX = "/home/agentuser/.local/lib/node_modules/markdownlint-cli2/node_modules/markdownlint/lib";

async function main() {
  const rule = process.argv[2];
  if (!rule) { console.error("usage: node scripts/lint/autofix.js <RULE> [FILE...]"); process.exit(2); }
  const explicit = process.argv.slice(3);

  // files to process
  let files;
  if (explicit.length) {
    files = explicit;
  } else {
    const tracked = execSync("git ls-files '*.md'", { encoding: "utf8", cwd: process.cwd() })
      .split("\n").filter(Boolean)
      .filter(f => !f.endsWith("docs/operations/documentation_policy.md"));
    files = tracked;
  }

  const fix = await import(`${PREFIX}/exports.mjs`);
  const sync = await import(`${PREFIX}/exports-sync.mjs`);

  const config = {
    "default": true,
    // disabled: policy conflicts / manual-review rules
    "MD013": false,  // line-length -- contradicts documentation_policy
    "MD060": false,  // table padding
  };

  let changed = 0;
  for (const f of files) {
    if (!fs.existsSync(f)) continue;
    let content;
    try { content = fs.readFileSync(f, "utf8"); } catch { continue; }
    const key = `__target`;
    const lintRes = sync.lint({ strings: { [key]: content }, config });
    const violations = (lintRes[key] || []).filter(v =>
      v.ruleNames && v.ruleNames[0] === rule && v.fixInfo);
    if (!violations.length) continue;
    const fixed = fix.applyFixes(content, violations);
    if (fixed !== content) { fs.writeFileSync(f, fixed); changed++; }
  }
  console.log(`autofix ${rule}: ${changed} file(s) changed`);
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });