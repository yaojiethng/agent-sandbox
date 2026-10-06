#!/usr/bin/env bash
# scripts/check_instruction_surfaces.sh
# Holds the two AGENTS.md layer tables and the loop inventory to their sources.
#
# The instruction surfaces are declared once in
# src/build/container-interface.json: the `session` rows are the environment a
# session reads whatever surface it is reading from, and each `cells` row is one
# surface. Two claims live outside that file because they are about the agent's
# own instructions rather than about the container:
#
#   1. The two AGENTS.md layers split the session environment between them. The
#      provider layer covers the container, the project layer the working tree.
#      Each layer's `## Scope` table names runtime paths, and every session row
#      is covered by exactly one layer.
#   2. The loop inventory. docs/operations/iteration_policy.md's frontmatter
#      `scope` names the runbooks it governs; the project layer's `### Loop
#      prompts` table is the inventory an agent reads. One declaration, two
#      readers, checked both ways.
#
# Everything else about a surface is checked against the artefact that
# implements it by scripts/check_container_layout.sh, which reads the same
# manifest through src/build/container-interface.mjs.
#
# Test seam: INSTRUCTION_SURFACE_SCAN_ROOT points the scan at a fixture root
# that mirrors the repository layout, so the gate's branches run without
# touching the real tree.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded (bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="${INSTRUCTION_SURFACE_SCAN_ROOT:-$REPO_ROOT}"
MODULE_REL="src/build/container-interface.mjs"

# The two AGENTS.md layers, provider first. Each names the runtime paths it
# covers in a `## Scope` table.
LAYER_FILES=(
  "provider:src/reasoning/providers/pi/config/agent/AGENTS.md"
  "project:AGENTS.md"
)

# The loop inventory. The policy's `scope` is the declaration; the layer's table
# is the inventory an agent reads.
ITERATION_POLICY_REL="docs/operations/iteration_policy.md"
INVENTORY_REL="AGENTS.md"
INVENTORY_HEADING="### Loop prompts"

FINDINGS=0
finding() {
  printf '%s: %s\n' "$1" "$2"
  FINDINGS=$((FINDINGS + 1))
}

if ! command -v node >/dev/null 2>&1; then
  echo "Instruction-surface gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$REPO_ROOT/$MODULE_REL" ]]; then
  echo "Instruction-surface gate: $MODULE_REL is missing; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_ROOT/src/build/container-interface.json" ]]; then
  echo "Instruction-surface gate: src/build/container-interface.json is missing; the surfaces are undeclared." >&2
  exit 1
fi

SESSION_PATHS=()
while IFS= read -r path; do
  [[ -z "$path" ]] && continue
  SESSION_PATHS+=("$path")
done < <(node "$REPO_ROOT/$MODULE_REL" session --root "$SCAN_ROOT")

if (( ${#SESSION_PATHS[@]} == 0 )); then
  echo "Instruction-surface gate: the manifest declares no session row; there is nothing for a layer to cover." >&2
  exit 1
fi

# section_has_content FILE HEADING  --  true when the section holds a line with
# content before the next heading.
section_has_content() {
  awk -v want="$2" '
    $0 == want { inside = 1; next }
    inside && (/^#[^#]/ || /^##[^#]/) { exit }
    inside && NF { found = 1; exit }
    END { exit !found }
  ' "$1"
}

# layer_paths FILE  --  the path keys of the `## Scope` table, one per line,
# backticks stripped and unique.
layer_paths() {
  awk -F'|' '
    /^## Scope$/ { inside = 1; next }
    inside && (/^#[^#]/ || /^##[^#]/) { exit }
    inside && $2 ~ /^[[:space:]]*`/ {
      path = $2
      gsub(/[`[:space:]]/, "", path)
      if (path != "") print path
    }
  ' "$1" | sort -u
}

# layers_relate ROW PATH  --  true when ROW and PATH name the same runtime
# location, or one contains the other. A layer may name a parent of a session
# row or a path inside one, and both count as covering it.
layers_relate() {
  local row="$1" path="$2"
  [[ "$row" == "$path" ]] && return 0
  [[ "$path" == */ && "$row" == "$path"* ]] && return 0
  [[ "$row" == */ && "$path" == "$row"* ]] && return 0
  return 1
}

# policy_scope FILE  --  the prompt names in the frontmatter `scope` list, one
# per line and sorted.
policy_scope() {
  sed -n 's/^scope:[[:space:]]*\[\(.*\)\][[:space:]]*$/\1/p' "$1" | head -1 \
    | tr ',' '\n' | tr -d ' "' | sed '/^$/d' | sort
}

# inventory_prompts FILE HEADING  --  the prompt names in the layer's inventory
# table, one per line and sorted.
inventory_prompts() {
  awk -F'|' -v want="$2" '
    $0 == want { inside = 1; next }
    inside && /^#/ { exit }
    inside && $2 ~ /^[[:space:]]*`/ {
      name = $2
      gsub(/[`[:space:]]/, "", name)
      if (name != "") print name
    }
  ' "$1" | sort
}

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/surface.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

printf '%s\n' "${SESSION_PATHS[@]}" | sort -u > "$WORK_DIR/session"

# The two layers split the session environment between them. Each layer's
# `## Scope` table names the runtime paths it covers; a named path is checked
# against the session rows rather than against the other layer. Then every
# session row must belong to exactly one layer, which is what makes the split
# exhaustive.
for entry in "${LAYER_FILES[@]}"; do
  layer="${entry%%:*}"
  layer_rel="${entry#*:}"
  layer_file="$SCAN_ROOT/$layer_rel"

  if [[ ! -f "$layer_file" ]]; then
    finding "$layer_rel" "the $layer layer is missing; cannot check what it covers"
    continue
  fi
  if ! grep -qxF '## Scope' "$layer_file"; then
    finding "$layer_rel" "missing heading '## Scope'"
    continue
  fi
  if ! section_has_content "$layer_file" "## Scope"; then
    finding "$layer_rel" "the 'Scope' section holds no table row"
  fi

  mapfile -t layer_paths_list < <(layer_paths "$layer_file")
  if (( ${#layer_paths_list[@]} == 0 )); then
    finding "$layer_rel" "the 'Scope' table names no runtime path"
    continue
  fi

  for path in "${layer_paths_list[@]}"; do
    known=0
    while read -r row; do
      [[ -z "$row" ]] && continue
      if layers_relate "$row" "$path"; then
        known=1
        break
      fi
    done < "$WORK_DIR/session"
    if (( known == 0 )); then
      finding "$layer_rel" "the Scope table names '$path', which is not a session row in the manifest"
    fi
  done

  printf '%s\n' "${layer_paths_list[@]}" > "$WORK_DIR/layer_$layer"
done

while read -r row; do
  [[ -z "$row" ]] && continue
  claimers=()
  for entry in "${LAYER_FILES[@]}"; do
    layer="${entry%%:*}"
    layer_source="$WORK_DIR/layer_$layer"
    [[ -f "$layer_source" ]] || continue
    while read -r path; do
      [[ -z "$path" ]] && continue
      if layers_relate "$row" "$path"; then
        claimers+=("$layer")
        break
      fi
    done < "$layer_source"
  done
  case "${#claimers[@]}" in
    0) finding "AGENTS.md layers" "no layer covers '$row', which the manifest declares a session row" ;;
    1) ;;
    *) finding "AGENTS.md layers" "more than one layer covers '$row': $(printf '%s ' "${claimers[@]}")" ;;
  esac
done < "$WORK_DIR/session"

# The loop inventory, both ways.
policy_file="$SCAN_ROOT/$ITERATION_POLICY_REL"
inventory_file="$SCAN_ROOT/$INVENTORY_REL"
if [[ ! -f "$policy_file" ]]; then
  finding "$ITERATION_POLICY_REL" "missing; cannot check the loop inventory against its scope"
else
  policy_prompts="$WORK_DIR/policy_prompts"
  policy_scope "$policy_file" > "$policy_prompts"
  if [[ ! -s "$policy_prompts" ]]; then
    finding "$ITERATION_POLICY_REL" "the frontmatter holds no scope list; the loop inventory has no source"
  fi

  if [[ ! -f "$inventory_file" ]]; then
    finding "$INVENTORY_REL" "missing; cannot check the loop inventory"
  elif ! grep -qxF "$INVENTORY_HEADING" "$inventory_file"; then
    finding "$INVENTORY_REL" "missing heading '$INVENTORY_HEADING'"
  else
    inventory_rows="$WORK_DIR/inventory"
    inventory_prompts "$inventory_file" "$INVENTORY_HEADING" > "$inventory_rows"

    missing="$(comm -23 "$policy_prompts" "$inventory_rows" | paste -sd, -)"
    extra="$(comm -13 "$policy_prompts" "$inventory_rows" | paste -sd, -)"
    if [[ -n "$missing" ]]; then
      finding "$INVENTORY_REL" "the inventory omits [${missing}], which the policy's scope names"
    fi
    if [[ -n "$extra" ]]; then
      finding "$INVENTORY_REL" "the inventory names [${extra}], which the policy's scope does not govern"
    fi
  fi
fi

if (( FINDINGS == 0 )); then
  echo "Instruction-surface gate: clean across ${#SESSION_PATHS[@]} session row(s)"
  echo "Clean (${SECONDS}s)"
  exit 0
fi

echo "Instruction-surface gate: $FINDINGS finding(s)" >&2
echo "Blocking gate: align the two AGENTS.md layer tables with the manifest's session rows, or the loop inventory with the policy's scope (see docs/development/instruction-surface-conventions.md)." >&2
exit 1
