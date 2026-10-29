#!/usr/bin/env bash
# scripts/check_code_snippets.sh
# The code-snippet gate: every fenced block under docs/ declares where it came
# from, and a block claiming a source still matches it.
#
# The rule and its four patterns are
# .agents/skills/project-documentation/references/code-snippets.md. The gate
# holds a baseline of the blocks that predate it, so today's tree is grandfathered
# and a block added from here declares itself.
#
# Usage: bash scripts/check_code_snippets.sh [--update]
# Exit:  0 = clean, 1 = a finding, 2 = the baseline is missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

( cd "$REPO_ROOT" && node scripts/lint/code-snippets.mjs "$@" )
