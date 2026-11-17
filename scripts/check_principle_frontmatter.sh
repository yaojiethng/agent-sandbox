#!/usr/bin/env bash
# scripts/check_principle_frontmatter.sh
# The principle-frontmatter gate: every principle under the provider root
# declares `name`, `description`, `metadata.neighbours`, `metadata.intent`
# and `metadata.mechanism`, the conditional `metadata.leitwort` is valid when
# present, and the principle does not set `disable-model-invocation`.
#
# The body shape is a convention, not this gate's subject:
# .agents/skills/instruction-authoring/references/skill-conventions.md
# `## A principle skill`. The neighbour rule is
# .agents/skills/instruction-authoring/patterns/admission.md.
#
# Usage: bash scripts/check_principle_frontmatter.sh
# Exit:  0 = clean, 1 = a finding, 2 = the root could not be read

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

( cd "$REPO_ROOT" && node scripts/lint/principle-frontmatter.mjs "$@" )
