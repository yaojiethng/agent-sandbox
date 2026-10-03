#!/usr/bin/env bash
# scripts/check_prompt_frontmatter.sh
# Frontmatter parse gate over every prompt, skill and policy in the tree.
#
# Enforces docs/development/prompt-authoring-conventions.md
# `## Structure of a workflow document`: a prompt's frontmatter is YAML, and a
# value that does not parse costs the prompt silently. Pi drops such a prompt
# at load time without a message in the session, so it simply never appears in
# the command list. The authoring rule was written before this gate and missed
# anyway, so the rule is enforced here instead of restated.
#
# The scan also covers every policy file (docs/**/*_policy.md), whose
# frontmatter holds a description and a scope per docs/operations/
# documentation_policy.md `### Document header format`.
#
# The parse itself is Node's, in scripts/lint/prompt-frontmatter.mjs, because
# the `yaml` package is not a dependency of this repository and the repository
# has no YAML reader of its own. The gate fails rather than skips when Node or
# the parser is missing, so an absent dependency is never read as a pass.
#
# Test seam: PROMPT_FRONTMATTER_SCAN_ROOT points the scan at a fixture root
# that mirrors the real layout, so the gate's branches are exercised without
# touching the real tree.
#
# Exit codes: 0 = no findings, 1 = findings OR the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/prompt-frontmatter.mjs"
SCAN_ROOT="${PROMPT_FRONTMATTER_SCAN_ROOT:-$REPO_ROOT}"

if ! command -v node >/dev/null 2>&1; then
  echo "Frontmatter gate: node is not on PATH; cannot parse frontmatter." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Frontmatter gate: $SCAN_SCRIPT is missing; cannot parse frontmatter." >&2
  exit 1
fi

if PROMPT_FRONTMATTER_SCAN_ROOT="$SCAN_ROOT" node "$SCAN_SCRIPT"; then
  echo "Clean (${SECONDS}s)"
  exit 0
fi

echo "Blocking gate: fix the frontmatter above (see docs/development/prompt-authoring-conventions.md and docs/operations/documentation_policy.md)." >&2
exit 1
