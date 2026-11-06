#!/usr/bin/env bash
# scripts/check_unit_vocabulary.sh
# The vocabulary gate: `unit` names no record entity, while the quantifier and
# the test-unit compound stay. The rule is docs/reference/terminology.md's
# "Usage"; the checker is scripts/lint/unit.mjs.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

( cd "$REPO_ROOT" && node scripts/lint/unit.mjs "$@" )
