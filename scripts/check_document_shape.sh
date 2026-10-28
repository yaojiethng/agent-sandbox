#!/usr/bin/env bash
# scripts/check_document_shape.sh
# The instruction-document gate: every prompt, skill and policy block parses;
# every shipping document declares its reader; every `principle-` skill carries
# the corpus shape and a claim from the authoring convention's table.
#
# The three claims share one file set, one walk and one parser, so they share one
# gate. Enforced documents are docs/development/prompt-authoring-conventions.md
# `## Structure of a workflow document`, `## The principle shape` and `## The
# principle claims`, `.agents/skills/project-documentation/SKILL.md` `## How a document opens`,
# and the decision in docs/adr/principle_skill_shape.md. The scanner is
# scripts/lint/document-shape.mjs.
#
# A prompt whose frontmatter does not parse is dropped by pi at load time with no
# message in the session, so it simply never appears in the command list. That is
# why the parse is a gate rather than an authoring rule alone.
#
# Scope: the instruction roots a manifest cell declares, the project's own
# `.agents/` trees, and the policy files. Every set is derived, so a new surface,
# a new policy file or a new principle enters with no second edit.
#
# Test seams: DOCUMENT_SHAPE_SCAN_ROOT points the tree scan at a fixture,
# DOCUMENT_SHAPE_MANIFEST_ROOT points the declaration read elsewhere, and
# DOCUMENT_SHAPE_SHIPPED_ROOTS names the shipping folders instead of deriving
# them.
#
# Options: `--map` prints the principle corpus grouped by claim. Any other
# argument reaches the scanner unchanged.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/document-shape.mjs"
SCAN_ROOT="${DOCUMENT_SHAPE_SCAN_ROOT:-$REPO_ROOT}"

if ! command -v node >/dev/null 2>&1; then
  echo "Document shape gate: node is not on PATH; cannot parse frontmatter." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Document shape gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

cd "$REPO_ROOT" || exit 1

DOCUMENT_SHAPE_SCAN_ROOT="$SCAN_ROOT" node "$SCAN_SCRIPT" "$@"
rc=$?

if (( rc == 0 )); then
  echo "Clean (${SECONDS}s)"
else
  echo "Blocking gate: fix the findings above (see docs/development/prompt-authoring-conventions.md and `.agents/skills/project-documentation/SKILL.md`)." >&2
fi
exit "$rc"
