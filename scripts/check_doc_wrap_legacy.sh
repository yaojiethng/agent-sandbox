#!/usr/bin/env bash
# scripts/check_doc_wrap_legacy.sh
# Ends a file-level doc-wrap exemption when the file is next edited.
#
# scripts/lint/doc-wrap.mjs exempts two lists, both config-driven. Files under a
# recordTrees entry are closed records read as history and are never
# flagged. Files named in legacyFiles are live documents not yet reflowed: the
# Markdown gate skips them, which is why their wrap debt does not block every
# commit.
#
# A file-level exemption that never ends is an exemption with no owner. So the
# commit that touches a legacy file is the commit that must clear it. The rule
# reads DOC_WRAP_ENFORCE -- the changed Markdown files, comma-separated -- and
# stops exempting a legacy file once it appears there. This script derives that
# list, runs the real Markdown gate over the tree with the variable set, and
# fails when the findings name an enforced file. --stale additionally reports
# entries whose file is already clean or gone, which is the bookkeeping half of
# the same debt.
#
# The grandfather trees are not covered here, on purpose. A closed record is
# appended to and never reflowed; enforcing them would block every handover.
#
# Usage:
#   check_doc_wrap_legacy.sh [--staged] [--stale] [FILE ...]
#     --staged   enforce the Markdown files staged for commit (default when no
#                FILE is given)
#     --stale    also report entries naming a file that is clean or gone
#     FILE ...   enforce the named Markdown files
#
# Exit codes: 0 = nothing to clear, 1 = findings or stale entries, 2 = the gate
# could not run. The finding count is printed, never encoded
# (bash-coding-conventions.md 3.2).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT" || exit 2

CONFIG_PATH=".markdownlint-cli2.mjs"
LEGACY_FILE=""
STAGED_ONLY=0
SWEEP_STALE=0
FILES=()

while (( $# > 0 )); do
  case "$1" in
    --staged)
      STAGED_ONLY=1
      shift
      ;;
    --stale)
      SWEEP_STALE=1
      shift
      ;;
    --)
      shift
      while (( $# > 0 )); do
        FILES+=("$1")
        shift
      done
      ;;
    *)
      FILES+=("$1")
      shift
      ;;
  esac
done

legacy_entries() {
  node --input-type=module -e '
    import settings from "./.markdownlint-cli2.mjs";
    const list = settings?.config?.["doc-wrap"]?.legacyFiles ?? [];
    process.stdout.write(list.join("\n") + "\n");
  ' 2>/dev/null
}

# markdownlint_command -- the tool as the Markdown gate resolves it.
markdownlint_command() {
  if command -v markdownlint-cli2 >/dev/null 2>&1; then
    printf 'markdownlint-cli2'
  elif [[ -x "$HOME/.local/bin/markdownlint-cli2" ]]; then
    printf '%s' "$HOME/.local/bin/markdownlint-cli2"
  fi
}

main() {
  local mdl legacy_list touched file relative_name out findings total=0 stale=0

  if ! command -v node >/dev/null 2>&1; then
    echo "Legacy wrap gate: node is not on PATH; cannot read the config." >&2
    return 2
  fi
  mdl="$(markdownlint_command)"
  if [[ -z "$mdl" ]]; then
    echo "Legacy wrap gate: markdownlint-cli2 is not installed; cannot run." >&2
    return 2
  fi
  if [[ ! -f "$CONFIG_PATH" ]]; then
    echo "Legacy wrap gate: $CONFIG_PATH is missing; cannot read the config." >&2
    return 2
  fi

  LEGACY_FILE="$(mktemp "${TMPDIR:-/tmp}/doc-wrap-legacy.XXXXXX")" || return 2
  legacy_entries > "$LEGACY_FILE" || : > "$LEGACY_FILE"
  if [[ ! -s "$LEGACY_FILE" ]]; then
    echo "Legacy wrap gate: no file is listed as legacy; nothing to enforce."
    return 0
  fi

  # The enforced set is the intersection of what changed and what is listed:
  # enforcing a file that carries no entry would flag debt nobody grandfathered.
  touched=""
  legacy_list="$(tr '\n' ',' < "$LEGACY_FILE" | sed 's/,$//')"
  while IFS= read -r file; do
    [[ "$file" == *.md ]] || continue
    relative_name="${file#./}"
    grep -Fxq -- "$relative_name" "$LEGACY_FILE" || continue
    touched+="${touched:+,}${relative_name}"
  done < <(changed_files)

  if [[ -n "$touched" ]]; then
    out="$(DOC_WRAP_ENFORCE="$touched" "$mdl" '**/*.md' 2>&1)"
    while IFS= read -r file; do
      [[ -n "$file" ]] || continue
      relative_name="${file%%:*}"
      findings="$(printf '%s\n' "$out" | grep -c "^${relative_name}:" || true)"
      (( findings > 0 )) || continue
      printf '%s\n' "$out" | grep "^${relative_name}:" >&2
      total=$((total + findings))
    done < <(printf '%s\n' "$touched" | tr ',' '\n')
  fi

  if (( SWEEP_STALE == 1 )); then
    # One run with every listed file enforced: a file that reports nothing is
    # clean, so its entry is stale bookkeeping.
    out="$(DOC_WRAP_ENFORCE="$legacy_list" "$mdl" '**/*.md' 2>&1)"
    while IFS= read -r relative_name; do
      [[ -n "$relative_name" ]] || continue
      if [[ ! -f "$relative_name" ]]; then
        echo "Legacy wrap gate: $relative_name is listed as legacy but does not exist." >&2
        stale=$((stale + 1))
        continue
      fi
      if printf '%s\n' "$out" | grep -q "^${relative_name}:"; then
        continue
      fi
      echo "Legacy wrap gate: $relative_name is clean; drop it from the legacy list." >&2
      stale=$((stale + 1))
    done < "$LEGACY_FILE"
  fi

  if (( total > 0 || stale > 0 )); then
    echo "Blocking gate: $total finding(s) and $stale stale entry(ies); the debt ends when the file is next edited." >&2
    return 1
  fi

  echo "Legacy wrap gate: clean"
  return 0
}

changed_files() {
  if (( STAGED_ONLY == 1 || ${#FILES[@]} == 0 )); then
    git diff --cached --name-only --diff-filter=ACMR
  else
    printf '%s\n' "${FILES[@]}"
  fi
}

cleanup() {
  [[ -n "$LEGACY_FILE" ]] && rm -f "$LEGACY_FILE"
  return 0
}
trap cleanup EXIT

main "$@"