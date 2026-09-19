#!/usr/bin/env bash
# scripts/check_markdown.sh
# markdownlint-cli2 gate over all tracked Markdown files.
# BLOCKING: exits nonzero on any finding.
#
# Uses .markdownlint-cli2.mjs at the repo root. The config enables the
# rule subset that matches docs/operations/documentation_policy.md plus
# the custom doc-ascii rule (plain-ASCII prose). MD013 and MD060 are
# disabled because they contradict written policy (see config header).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$REPO_ROOT" || exit 1

if ! command -v markdownlint-cli2 >/dev/null 2>&1 && [ ! -x "$HOME/.local/bin/markdownlint-cli2" ]; then
  echo "markdownlint-cli2 is not installed in this image (install via npm i -g markdownlint-cli2)." >&2
  exit 127
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

echo ""
echo "markdownlint: $COUNT finding(s)"
if (( STATUS != 0 )); then
  echo "Blocking gate: fix the findings above. Excluded files are marked in .markdownlint-cli2.mjs ignores." >&2
fi
if (( COUNT == 0 )); then
  echo "Clean"
fi
exit "$STATUS"