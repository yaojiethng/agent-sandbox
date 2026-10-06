#!/usr/bin/env bash
# scripts/check_instruction_context.sh
# Asserts the CONTEXT.md of each instruction runtime path against the image map.
#
# docs/development/instruction-context-template.md owns the shape. A runtime
# path, not a source directory, is the subject: two source directories can
# merge into one, and two files landing on one path overwrite each other in the
# image. So the gate checks one file per path, the file's directory list against
# the directories the dockerfiles actually send there, and the path itself
# against the pi settings roots.
#
# Every claim is checkable against two artefacts, so the gate checks them
# instead of trusting the prose: the provider dockerfiles decide which
# directory lands where, and the pi settings.json decides whether a landed path
# is a prompt root, a skill root or a package. A COPY line added or removed
# breaks the file that described the old map, which is the failure this gate
# exists to catch: a stale instruction is worse than a missing one.
#
# The two AGENTS.md layers are the same claim one level up: the provider layer
# covers the container, the project layer the working tree, and the folder files
# own the always-reachable set. So the gate checks each layer's `## Scope` table
# against that set -- a named path must be one of its rows or sit inside one --
# and checks that the two layers cover every row exactly once.
#
# Test seam: INSTRUCTION_CONTEXT_SCAN_ROOT points the scan at a fixture root
# that mirrors the repository layout, so the gate's branches run without
# touching the real tree.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded (bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="${INSTRUCTION_CONTEXT_SCAN_ROOT:-$REPO_ROOT}"

INSTRUCTION_DIRS=(
  "src/reasoning/agent/prompts"
  "src/reasoning/agent/skills"
  "src/reasoning/providers/pi/config/agent/prompts"
  "src/reasoning/providers/pi/config/agent/skills"
  "workflow/coding-agent/prompts"
  "workflow/coding-agent/skills"
)

PROVIDER_GLOB="src/reasoning/providers/*/provider.dockerfile"
SETTINGS_REL="src/reasoning/providers/pi/config/agent/settings.json"

REQUIRED_HEADINGS=(
  "## Runtime identity"
  "## Reachable"
  "## Not reachable"
  "## Assumptions"
)

# The four provider-neutral folders. Their images carry the same paths, so a
# context file here may not name a provider, a provider home or a provider
# install path: the running provider resolves $AGENT_HOME instead. A provider's
# own folder, such as the pi config tree, is absent from this list and may name
# its provider.
NEUTRAL_DIRS=(
  "src/reasoning/agent/prompts"
  "src/reasoning/agent/skills"
  "workflow/coding-agent/prompts"
  "workflow/coding-agent/skills"
)

PROVIDER_MARKERS=( "/home/agentuser/.pi" "/home/agentuser/.hermes" "/home/agentuser/.opencode" "pi-coding-agent" "@earendil-works" ".hermes/" ".opencode/" )

# The two AGENTS.md layers, provider first. Each names the runtime paths it
# covers in a `## Scope` table.
LAYER_FILES=(
  "provider:src/reasoning/providers/pi/config/agent/AGENTS.md"
  "project:AGENTS.md"
)

FINDINGS=0
finding() {
  printf '%s: %s\n' "$1" "$2"
  FINDINGS=$((FINDINGS + 1))
}

mapfile -t dockerfiles < <(compgen -G "$SCAN_ROOT/$PROVIDER_GLOB" || true)
if (( ${#dockerfiles[@]} == 0 )); then
  echo "Instruction-context gate: no provider dockerfile under $SCAN_ROOT/$PROVIDER_GLOB; cannot check the image map." >&2
  exit 1
fi

settings="$SCAN_ROOT/$SETTINGS_REL"
if [[ ! -f "$settings" ]]; then
  echo "Instruction-context gate: $SETTINGS_REL is missing; cannot check the settings roots." >&2
  exit 1
fi

# field_value FILE FIELD  --  the value of a `| FIELD | VALUE |` row, with
# backticks stripped. Prints nothing when no row names the field.
field_value() {
  awk -F'|' -v want="$2" '
    {
      key = $2; value = $3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", key)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      if (key == want) { gsub(/`/, "", value); print value; exit }
    }
  ' "$1"
}

# section_has_content FILE HEADING  --  true when the section holds a line with
# content before the next `##` heading.
section_has_content() {
  awk -v want="$2" '
    $0 == want { inside = 1; next }
    inside && /^## / { exit }
    inside && NF { found = 1; exit }
    END { exit !found }
  ' "$1"
}

# reachable_paths FILE  --  the path keys of the `## Reachable` table whose
# condition is `always`, one per line, backticks stripped and sorted. Those
# rows describe the container itself, so they are identical in every context
# file.
reachable_paths() {
  awk -F'|' '
    /^## Reachable$/ { inside = 1; next }
    inside && /^## / { exit }
    inside && $2 ~ /^[[:space:]]*`[$\/]/ {
      condition = $4
      gsub(/[[:space:]]/, "", condition)
      if (condition != "always") next
      path = $2
      gsub(/[`[:space:]]/, "", path)
      if (path != "") print path
    }
  ' "$1" | sort
}

# layer_paths FILE  --  the path keys of the `## Scope` table, one per line,
# backticks stripped and unique. The two AGENTS.md layers use this shape.
layer_paths() {
  awk -F'|' '
    /^## Scope$/ { inside = 1; next }
    inside && /^## / { exit }
    inside && $2 ~ /^[[:space:]]*`/ {
      path = $2
      gsub(/[`[:space:]]/, "", path)
      if (path != "") print path
    }
  ' "$1" | sort -u
}

# layers_relate ROW PATH  --  true when ROW and PATH name the same runtime
# location, or one contains the other. A layer may name a parent of a reachable
# path or a path inside one, and both count as covering it.
layers_relate() {
  local row="$1" path="$2"
  [[ "$row" == "$path" ]] && return 0
  [[ "$path" == */ && "$row" == "$path"* ]] && return 0
  [[ "$row" == */ && "$path" == "$row"* ]] && return 0
  return 1
}

# copy_dests DIR  --  sets COPY_DESTS to one destination per dockerfile COPY
# line whose source is DIR.
COPY_DESTS=()
copy_dests() {
  local dir="$1" file src dest
  COPY_DESTS=()
  for file in "${dockerfiles[@]}"; do
    while read -r src dest; do
      [[ -z "$src" ]] && continue
      if [[ "${src%/}" == "$dir" ]]; then
        COPY_DESTS+=("$dest")
      fi
    done < <(awk '$1 == "COPY" { print $2, $3 }' "$file")
  done
}

# copied_parent DIR  --  true when a COPY line names a parent of DIR, so DIR
# arrives inside a copied tree rather than by its own line.
copied_parent() {
  local dir="$1" file src
  for file in "${dockerfiles[@]}"; do
    while read -r src _; do
      [[ -z "$src" ]] && continue
      if [[ "$dir" == "${src%/}/"* ]]; then
        return 0
      fi
    done < <(awk '$1 == "COPY" { print $2, $3 }' "$file")
  done
  return 1
}

# path_key DIR  --  the runtime path a directory lands on, as a comparison key.
# A copied directory keys on its destination, a directory inside a copied tree
# keys on itself under `provisioned:`, and an uncopied directory keys on itself
# under `none:`, because no two uncopied directories share a runtime path.
path_key() {
  local dir="$1"
  copy_dests "$dir"
  if (( ${#COPY_DESTS[@]} > 0 )); then
    printf '%s' "${COPY_DESTS[0]}"
  elif copied_parent "$dir"; then
    printf 'provisioned:%s' "$dir"
  else
    printf 'none:%s' "$dir"
  fi
}

# covered_dirs KEY  --  every instruction directory that lands on KEY, in
# INSTRUCTION_DIRS order.
covered_dirs() {
  local key="$1" dir
  for dir in "${INSTRUCTION_DIRS[@]}"; do
    if [[ "$(path_key "$dir")" == "$key" ]]; then
      printf '%s\n' "$dir"
    fi
  done
}

# expected_runtime_path DIR  --  what the file must declare for DIR: the
# destination the image copies to, `none` when no line does, or `declared` for
# a directory that arrives inside a copied tree and names its own path.
expected_runtime_path() {
  local dir="$1"
  copy_dests "$dir"
  if (( ${#COPY_DESTS[@]} > 0 )); then
    printf '%s' "${COPY_DESTS[0]}"
  elif copied_parent "$dir"; then
    printf 'declared'
  else
    printf 'none'
  fi
}

# First pass: every provider dockerfile must send a directory to the same
# destination. A disagreement means the runtime path depends on the provider.
for dir in "${INSTRUCTION_DIRS[@]}"; do
  copy_dests "$dir"
  if (( ${#COPY_DESTS[@]} > 1 )); then
    unique=$(printf '%s\n' "${COPY_DESTS[@]}" | sort -u | wc -l)
    if (( unique > 1 )); then
      finding "$dir/CONTEXT.md" "provider dockerfiles disagree on the runtime path: ${COPY_DESTS[*]}"
    fi
  fi
done

checked=0
seen_keys=()
REACHABLE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/reachable.XXXXXX")"
trap 'rm -rf "$REACHABLE_DIR"' EXIT

for dir in "${INSTRUCTION_DIRS[@]}"; do
  key="$(path_key "$dir")"

  skip=0
  for seen in ${seen_keys[@]+"${seen_keys[@]}"}; do
    [[ "$seen" == "$key" ]] && skip=1
  done
  (( skip )) && continue
  seen_keys+=("$key")

  mapfile -t covered < <(covered_dirs "$key")
  covered_list="$(printf '%s/\n' "${covered[@]}" | paste -sd, - | sed 's/,/, /g')"

  file=""
  holder=""
  claimed=0
  for sibling in "${covered[@]}"; do
    if [[ -f "$SCAN_ROOT/$sibling/CONTEXT.md" ]]; then
      claimed=$((claimed + 1))
      if [[ -z "$file" ]]; then
        file="$SCAN_ROOT/$sibling/CONTEXT.md"
        holder="$sibling"
      fi
    fi
  done

  if [[ -z "$file" ]]; then
    finding "$key" "no CONTEXT.md for this runtime path ($covered_list)"
    continue
  fi
  checked=$((checked + 1))
  rel="$holder/CONTEXT.md"

  if (( claimed > 1 )); then
    finding "$key" "$claimed CONTEXT.md files claim this runtime path: $covered_list"
  fi

  if [[ "$(sed -n '1p' "$file")" != "# System Assumptions" ]]; then
    finding "$rel" "line 1 must be '# System Assumptions'"
  fi

  for heading in "${REQUIRED_HEADINGS[@]}"; do
    if ! grep -qxF "$heading" "$file"; then
      finding "$rel" "missing heading '$heading'"
    fi
  done

  if ! section_has_content "$file" "## Reachable"; then
    finding "$rel" "the 'Reachable' section holds no row"
  fi
  for heading in "## Not reachable" "## Assumptions"; do
    if ! section_has_content "$file" "$heading"; then
      finding "$rel" "the '$heading' section holds no bullet"
    fi
  done

  declared_dirs="$(field_value "$file" "Source folders")"
  normalized_dirs="$(printf '%s' "$declared_dirs" | sed 's/, */, /g')"
  if [[ "$normalized_dirs" != "$covered_list" ]]; then
    finding "$rel" "Source folders reads '$normalized_dirs', expected '$covered_list'"
  fi

  loaded_when="$(field_value "$file" "Loaded when")"
  if [[ -z "$loaded_when" ]]; then
    finding "$rel" "Loaded when is empty"
  fi

  # The reachable set is repeated in every file on purpose, so a row added to
  # one file and missed in another is a drift rather than a difference.
  reachable_paths "$file" > "$REACHABLE_DIR/$(printf '%s' "$holder" | tr '/' '_')"

  # A provider-neutral folder names no provider.
  for neutral in "${NEUTRAL_DIRS[@]}"; do
    if [[ "$holder" == "$neutral" ]]; then
      for marker in "${PROVIDER_MARKERS[@]}"; do
        if grep -qF "$marker" "$file"; then
          finding "$rel" "a provider-neutral folder names '$marker'; use \$AGENT_HOME or drop the path"
        fi
      done
    fi
  done

  runtime_true="$(expected_runtime_path "$holder")"
  copy_dests "$holder"
  runtime_path="$(field_value "$file" "Runtime path")"
  case "$runtime_path" in
    none)
      if [[ "$runtime_true" != "none" ]]; then
        finding "$rel" "Runtime path reads 'none' while the image copies the directory to '${COPY_DESTS[0]}'"
      fi
      ;;
    /opt/*)
      if [[ "$runtime_true" == "none" ]]; then
        finding "$rel" "Runtime path reads '$runtime_path' while no dockerfile copies the directory"
      elif [[ "$runtime_true" == "declared" ]]; then
        finding "$rel" "Runtime path reads '$runtime_path' while the image copies the directory only inside a copied parent"
      elif [[ "$runtime_path" != "$runtime_true" ]]; then
        finding "$rel" "Runtime path reads '$runtime_path', the image copies to '$runtime_true'"
      fi
      settings_key="${runtime_path%/}"
      if ! grep -qF "\"$settings_key\"" "$settings"; then
        finding "$rel" "Runtime path '$runtime_path' is not a root in $SETTINGS_REL"
      fi
      ;;
    '$AGENT_HOME/'*)
      if [[ "$runtime_true" != "declared" ]]; then
        finding "$rel" "Runtime path reads '$runtime_path' while no dockerfile copies a parent of the directory"
      fi
      ;;
    '')
      finding "$rel" "Runtime path is empty"
      ;;
    *)
      finding "$rel" "Runtime path reads '$runtime_path', which is neither an /opt path, a \$AGENT_HOME path, nor 'none'"
      ;;
  esac
done

# The `always` reachable rows describe the container itself and are the same in
# every file. Compare each file against the first one, so a row that lands in
# one and not the others fails.
reachable_files=("$REACHABLE_DIR"/*)
if (( ${#reachable_files[@]} > 1 )); then
  baseline="${reachable_files[0]}"
  for other in "${reachable_files[@]:1}"; do
    if ! diff -q "$baseline" "$other" > /dev/null; then
      only_baseline="$(comm -23 "$baseline" "$other" | paste -sd, -)"
      only_other="$(comm -13 "$baseline" "$other" | paste -sd, -)"
      finding "${other##*/}" "the always reachable set differs from ${baseline##*/}: missing [${only_baseline:-none}], extra [${only_other:-none}]"
    fi
  done
fi

# The two AGENTS.md layers split the container between them. Each one's
# `## Scope` table names the runtime paths it covers; the folder files own the
# always-reachable set, so a named path is checked against that set rather than
# against the other layer. Then every always row is checked to belong to
# exactly one layer, which is what makes the split exhaustive.
ALWAYS_FILE="$REACHABLE_DIR/.always"
cat "${reachable_files[@]}" > "$ALWAYS_FILE"
sort -u "$ALWAYS_FILE" -o "$ALWAYS_FILE"

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
    done < "$ALWAYS_FILE"
    if (( known == 0 )); then
      finding "$layer_rel" "the Scope table names '$path', which no CONTEXT.md declares always reachable"
    fi
  done

  printf '%s\n' "${layer_paths_list[@]}" > "$REACHABLE_DIR/.layer_$layer"
done

while read -r row; do
  [[ -z "$row" ]] && continue
  claimers=()
  for entry in "${LAYER_FILES[@]}"; do
    layer="${entry%%:*}"
    layer_source="$REACHABLE_DIR/.layer_$layer"
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
    0) finding "AGENTS.md layers" "no layer covers '$row', which the CONTEXT.md files declare always reachable" ;;
    1) ;;
    *) finding "AGENTS.md layers" "more than one layer covers '$row': $(printf '%s ' "${claimers[@]}")" ;;
  esac
done < "$ALWAYS_FILE"

if (( FINDINGS == 0 )); then
  echo "Instruction-context gate: clean across $checked file(s)"
  echo "Clean (${SECONDS}s)"
  exit 0
fi

echo "Instruction-context gate: $FINDINGS finding(s) across $checked file(s)" >&2
echo "Blocking gate: align the CONTEXT.md files and the two AGENTS.md layer tables with the image map (see docs/development/instruction-context-template.md)." >&2
exit 1
