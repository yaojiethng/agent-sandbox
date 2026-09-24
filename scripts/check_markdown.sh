#!/usr/bin/env bash
# scripts/check_markdown.sh
# markdownlint-cli2 gate over all tracked Markdown files.
# BLOCKING: exits 1 on any finding or when the gate cannot run.
#
# Exit codes: 0 = no findings, 1 = findings OR the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# docs/development/bash-coding-conventions.md 3.2).
#
# Uses .markdownlint-cli2.mjs at the repo root. The config enables the
# rule subset that matches docs/operations/documentation_policy.md plus
# the custom doc-ascii rule (plain-ASCII prose) and the doc-wrap rule
# (one paragraph per physical line, both live). MD013 and MD060 are
# disabled because they contradict written policy (see config header).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_ROOT" || exit 1

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

COUNT="$(printf '%s' "$OUTPUT" | grep -cE '^[^ ]+:[0-9]+ error MD[0-9]+' || true)"

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
echo "Clean"
exit 0