#!/usr/bin/env bash
# scripts/check_principle_neighbours.sh
# The principle-neighbour gate: every principle declares `metadata.neighbours`,
# and every declared name resolves to a live principle. There is no baseline:
# a missing field fails, and the existing corpus declares `[]`.
#
# The rule is .agents/skills/instruction-authoring/patterns/admission.md; the
# field's shape is references/skill-conventions.md in the same skill.
#
# Usage: bash scripts/check_principle_neighbours.sh
# Exit:  0 = clean, 1 = a finding, 2 = the root could not be read

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

( cd "$REPO_ROOT" && node scripts/lint/principle-neighbours.mjs "$@" )
