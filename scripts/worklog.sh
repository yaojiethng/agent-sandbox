#!/usr/bin/env bash
# scripts/worklog.sh
# The work-log record seam: the derived reads the workflow prompts used to
# compute by hand. The layout is declared once in `src/build/record-layout.json`
# and read through `src/build/record-layout.mjs`, so this script adds no rule of
# its own.
#
# Usage: scripts/worklog.sh <trees|path|list|latest|active|track|reserve-id> [options]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec node "$REPO_ROOT/src/build/record-layout.mjs" "$@"
