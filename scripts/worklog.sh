#!/usr/bin/env bash
# scripts/worklog.sh  --  `scripts/worklog.sh --help` states every read and its flags.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec node "$REPO_ROOT/src/build/record-layout.mjs" "$@"
