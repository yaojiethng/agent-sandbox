#!/usr/bin/env bash
# scripts/check_vocabulary.sh
# Holds the shipping instruction surfaces to the reserved vocabulary.
#
# Two bans, each an entry in docs/reference/terminology.md.
#
# `thing` names no referent, so nothing in the sentence can be checked against it:
# write the artifact the sentence means (the file, the value, the clause, the
# record). The entry's own heading is the one line that states the word, and the
# gate skips that line.
#
# `layer` is reserved for the container architecture: the capability layer and
# the reasoning layer. The other senses are replaced, per the reserved-terms
# table in docs/adr/coding_agent_project_bindings.md and the model in
# docs/adr/container_execution_model.md: instruction roots use "surface",
# `AGENTS.md` scope names the file, record dependency uses "class" or "record",
# agent nesting uses "levels", and Docker build keeps Docker's own term.
#
# The subject set is derived from the manifest rather than listed: the shipping
# instruction surfaces are the `image` rows whose destination is the workflow
# agent tree or the shipped docs. A surface added to the manifest is scanned
# without editing this script, so a hand-listed root cannot go stale.
#
# Test seam: VOCABULARY_SCAN_ROOT points the scan at a fixture root that mirrors
# the repository layout, so the gate's branches run without touching the real
# tree.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded (bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="${VOCABULARY_SCAN_ROOT:-$REPO_ROOT}"
MANIFEST_REL="src/build/container-interface.json"

# The disallowed senses: a qualifier the reserved-terms table replaces, bound to
# the noun `layer`. The container-architecture qualifiers are absent, so a
# capability or reasoning layer never matches, and Docker's own build term is
# not a qualifier here.
PATTERN='(provider|project|sandbox|user|universal|workflow|record|delivery|reference|instruction|implementation)[ -]layer'

# The banned noun, as a standalone word: `do_thing` is an identifier and
# `nothing` is a different word. The registry entry's own heading is the single
# line that may state it.
PATTERN_THING='(^|[^A-Za-z0-9_])things?([^A-Za-z0-9_]|$)'

FINDINGS=0
finding() {
  printf '%s: %s\n' "$1" "$2"
  FINDINGS=$((FINDINGS + 1))
}

if ! command -v jq >/dev/null 2>&1; then
  echo "Vocabulary gate: jq is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_ROOT/$MANIFEST_REL" ]]; then
  echo "Vocabulary gate: $MANIFEST_REL is missing; the surfaces are undeclared." >&2
  exit 1
fi

mapfile -t SOURCES < <(
  jq -r '.image[]
    | select(.destination | startswith("/opt/workflow/agent/") or startswith("/opt/sandbox/docs/"))
    | .source' "$SCAN_ROOT/$MANIFEST_REL" | sort -u
)

if (( ${#SOURCES[@]} == 0 )); then
  echo "Vocabulary gate: the manifest declares no instruction-surface source." >&2
  exit 1
fi

for src in "${SOURCES[@]}"; do
  target="$SCAN_ROOT/$src"
  if [[ ! -e "$target" ]]; then
    finding "$src" "the manifest declares this surface, but it is missing"
    continue
  fi
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    finding "${hit%%:*}" "$(printf '%s' "$hit" | cut -d: -f2,3-)"
  done < <(grep -rnE "$PATTERN" "$target" 2>/dev/null)
done

for src in "${SOURCES[@]}"; do
  target="$SCAN_ROOT/$src"
  [[ -e "$target" ]] || continue
  while IFS= read -r hit; do
    [[ -z "$hit" ]] && continue
    [[ "$hit" == *":## thing" ]] && continue
    finding "${hit%%:*}" "$(printf '%s' "$hit" | cut -d: -f2,3-)"
  done < <(grep -rnE "$PATTERN_THING" "$target" 2>/dev/null)
done

if (( FINDINGS == 0 )); then
  echo "Vocabulary gate: clean across ${#SOURCES[@]} instruction-surface source(s)"
  echo "Clean (${SECONDS}s)"
  exit 0
fi

echo "Vocabulary gate: $FINDINGS finding(s)" >&2
echo "Blocking gate: fix each finding above. A 'layer' sense takes the reserved term (docs/adr/container_execution_model.md); a 'thing' takes the artifact the sentence means (docs/reference/terminology.md)." >&2
exit 1
