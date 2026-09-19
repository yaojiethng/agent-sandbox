#!/usr/bin/env node
// scripts/lint/escape_table_pipes.js
// Escape unescaped pipes that appear INSIDE backtick code spans on table
// rows (lines starting with "|"), so markdownlint MD056 does not count
// them as extra table columns.
//
// Only affects characters between ` and ` on lines whose first non-space
// char is "|". Style-free and content-safe: pipes outside code spans are
// never touched.
//
// Usage: node scripts/lint/escape_table_pipes.js FILE...
"use strict";
const fs = require("fs");

function processFile(f) {
  const lines = fs.readFileSync(f, "utf8").split("\n");
  let changed = 0;
  const out = lines.map((line) => {
    if (!/^\s*\|/.test(line)) return line; // not a table row
    const m = line.match(/`([^`]*)`/g);
    if (!m) return line;
    // escape pipes inside each backtick span
    const escaped = line.replace(/`([^`]*)`/g, (_, inner) => {
      if (inner.includes("|")) changed++;
      return "`" + inner.replace(/\|/g, "\\|") + "`";
    });
    return escaped;
  });
  if (changed) fs.writeFileSync(f, out.join("\n"));
  return changed;
}

const files = process.argv.slice(2);
let total = 0;
for (const f of files) total += processFile(f);
console.log(`escaped pipes in ${total} code span(s) across ${files.length} file(s)`);