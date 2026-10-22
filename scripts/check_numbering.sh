#!/usr/bin/env bash
# scripts/check_numbering.sh
# The numbering gate: numbered units are contiguous within their scope, sections
# follow the one before them, and a qualified reference names a document and a
# unit that exist.
#
# The rule is stated in .agents/skills/numbering/SKILL.md. The check reads one
# document at a time and holds no baseline, because a number is contiguous from
# 1 within its own scope: a gap is the whole defect signal.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

( cd "$REPO_ROOT" && node scripts/lint/numbering.mjs "$@" )
