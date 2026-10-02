#!/usr/bin/env bash
# scripts/check_markdown.sh
# markdownlint-cli2 gate over all Markdown files in the working tree
# (tracked and untracked), except node_modules.
# BLOCKING: exits 1 on any finding or when the gate cannot run.
#
# Exit codes: 0 = no findings, 1 = findings OR the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).
#
# Uses .markdownlint-cli2.mjs at the repo root. The config enables the
# rule subset that matches docs/operations/documentation_policy.md plus
# the custom doc-ascii rule (plain-ASCII prose), the doc-wrap rule
# (one paragraph per physical line) and the record-links rule (link targets
# and heading fragments resolve). MD013 and MD060 are
# disabled because they contradict written policy (see config header).
#
# Every clean run prints the record-links coverage line: how many Markdown
# files were checked and how many the config exempts. A carve-out nobody
# counts is a carve-out that grows without anyone noticing, and the count is
# the only cheap signal that the exempt set is shrinking. The list itself is
# read from the config, so the number and the list cannot disagree.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_ROOT" || exit 1

# print_link_coverage -- one line naming the checked and exempt file counts for
# the record-links rule, read from .markdownlint-cli2.mjs so the number and the
# carve-out list share one source. Prints nothing when the config carries no
# recordTrees list: a rule that exempts nothing has no coverage line and says
# nothing by staying quiet.
# warn_unresolved_rules -- a rule named in the config but absent from
# customRules never runs and reports nothing, so the gap is silent. doc-wrap sat
# enabled and unregistered for the life of this config. The check warns and does
# not block: an unresolved rule name is a signal, and the gate that owns the rule
# decides. Built-in rules (MD*) resolve by name and are not checked here.
warn_unresolved_rules() {
  if ! command -v node >/dev/null 2>&1; then
    return 0
  fi
  node --input-type=module -e '
    import settings from "./.markdownlint-cli2.mjs";
    import { pathToFileURL } from "node:url";
    import { resolve } from "node:path";

    const enabled = Object.entries(settings?.config ?? {})
      .filter(([name, value]) => name !== "default" && value !== false)
      .map(([name]) => name);
    const custom = settings?.customRules ?? [];
    const names = new Set();
    for (const ref of custom) {
      try {
        const mod = await import(pathToFileURL(resolve(ref)).href);
        for (const rule of mod.default ?? []) {
          for (const n of rule?.names ?? []) {
            names.add(n);
          }
        }
      } catch {
        process.stderr.write("Markdown gate: warning: custom rule " + ref + " did not load.\n");
      }
    }
    for (const name of enabled) {
      if (/^MD\d+$/.test(name) || names.has(name)) {
        continue;
      }
      process.stderr.write(
        "Markdown gate: warning: rule " + JSON.stringify(name) +
        " is enabled in the config but no customRules entry exports it; it is not running.\n"
      );
    }
  ' 2>&1 | grep "^Markdown gate: warning:" >&2 || true
}

print_link_coverage() {
  if ! command -v node >/dev/null 2>&1; then
    return 0
  fi
  node --input-type=module -e '
    import { recordTrees } from "./.markdownlint-cli2.mjs";
    import { readdirSync, statSync } from "node:fs";
    import { join } from "node:path";

    const roots = recordTrees ?? [];
    if (roots.length === 0) {
      process.exit(0);
    }
    const walk = (dir) => {
      let total = 0;
      for (const entry of readdirSync(dir, { withFileTypes: true })) {
        const full = join(dir, entry.name);
        if (entry.isDirectory()) {
          total += walk(full);
        } else if (entry.name.endsWith(".md")) {
          total += 1;
        }
      }
      return total;
    };
    let exempt = 0;
    for (const root of roots) {
      try {
        exempt += walk(root);
      } catch {
        exempt += 0;
      }
    }
    process.stdout.write(
      "record-links coverage: " + roots.length + " exempt tree(s), " + exempt +
      " Markdown file(s) exempt (file count, not link health)\n"
    );
  '
}

if ! command -v markdownlint-cli2 >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/markdownlint-cli2" ]; then
  echo "markdownlint-cli2 is not installed in this image (install via npm i -g markdownlint-cli2)." >&2
  exit 1
fi

if command -v markdownlint-cli2 >/dev/null 2>&1; then
  MDL="markdownlint-cli2"
else
  MDL="$HOME/.local/bin/markdownlint-cli2"
fi

OUTPUT="$($MDL '**/*.md' 2>&1)"
STATUS=$?

echo "$OUTPUT"

COUNT="$(printf '%s' "$OUTPUT" | grep -cE '^[^ ]+:[0-9]+ error [A-Za-z0-9-]+' || true)"

# A run that linted no file is the gate not running: it would otherwise print
# "0 finding(s) / Clean" over an empty set. Ask the tool what it linted -- the
# config globs and ignores decide that, not the tracked-file count. A non-zero
# status with no count line means the tool failed before linting, which is a
# different cause and gets a different message.
LINTED="$(printf '%s' "$OUTPUT" | sed -n 's/^Linting: \([0-9][0-9]*\) file.*$/\1/p' | head -1)"
if [[ "${LINTED:-0}" -eq 0 && "$STATUS" -eq 0 ]]; then
  echo "Markdown gate: no Markdown files were linted; cannot run the gate." >&2
  exit 1
fi

if (( STATUS != 0 || COUNT > 0 )); then
  echo ""
  echo "markdownlint: $COUNT finding(s)" >&2
  if [[ "${LINTED:-0}" -eq 0 && "$COUNT" -eq 0 ]]; then
    echo "Blocking gate: markdownlint-cli2 exited $STATUS without linting any file; the tool could not run." >&2
  else
    echo "Blocking gate: fix the findings above. Excluded files are marked in .markdownlint-cli2.mjs ignores." >&2
  fi
  exit 1
fi
echo "markdownlint: 0 finding(s)"
warn_unresolved_rules
print_link_coverage
echo "Clean (${SECONDS}s)"
exit 0