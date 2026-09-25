#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/routing.sh; orig=/tmp/routing.orig; cp "$src" "$orig"
run() { local label="$1"
  if cmp -s "$src" "$orig"; then printf '%-48s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out f
  out=$(bash tests/test_routing.sh 2>&1)
  f=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
  printf '%-48s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ if (new!="") print new; next } {print}' "$orig" > "$src"; }

m 132 '    echo "${PARENT_DIR}/${SUBDIR}/${EXPORT_TIME}-${SESSION_ID}-${LABEL}"'; run "R1 export_path: label order swapped"
m 126 '  if false; then'; run "R2 export_path: autosave branch removed"
m 117 '  if false; then'; run "R3 export_path: required-args guard off"
m 156 '  _latest=$(find "$_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -n 1)'; run "R4 resolve_latest_dir: tail -> head"
m 156 '  _latest=$(find "$_base" -mindepth 1 -maxdepth 1 2>/dev/null | sort | tail -n 1)'; run "R5 resolve_latest_dir: -type d removed"
m 176 '  _latest=$(find "$_base" -mindepth 1 -maxdepth 1 -type d -printf '"'"'%T@ %p\n'"'"' 2>/dev/null | sort | tail -n 1 | cut -d'"'"' '"'"' -f2-)'; run "R6 by_mtime: numeric sort -> lexicographic"
m 176 '  _latest=$(find "$_base" -mindepth 1 -maxdepth 1 -type d -printf '"'"'%T@ %p\n'"'"' 2>/dev/null | sort -n | tail -n 1)'; run "R7 by_mtime: path cut removed"
m 214 '    if false; then'; run "R8 draft: absolute-path rejection off"
m 244 '  if false; then'; run "R9 draft: draftability validation off"
m 224 '    if [[ "$CHANNEL" != "autosave" ]]; then'; run "R10 draft: autosave mtime resolution swapped"
m 44 '  :'; run "R11 _resolve_paths: input_dir read dropped"
m 47 '  :'; run "R12 _resolve_paths: dirs_resolve fallback off"
m 71 '    autosave) echo "${CHANGES_DIR}/session" ;;'; run "R13 channel: autosave -> session dir"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"

echo
echo "== probes =="
# shellcheck disable=SC1090  # subject path is runtime-resolved
source "$orig"
D=/tmp/rtprobe; rm -rf "$D"; mkdir -p "$D/.changes" "$D/.in" "$D/.out"
( unset CHANGES_DIR INPUT_DIR OUTPUT_DIR
  _d_changes=$(session_state_read "$D" "changes_dir" 2>/dev/null); CHANGES_DIR="$_d_changes"
  printf '  partial state not probed inline; see below\n' )
source src/libs/session_state.sh >/dev/null 2>&1
git -C "$D" init -q 2>/dev/null
printf 'changes_dir=/custom/changes\n' > "$D/.git/SESSION_STATE"
# shellcheck disable=SC2034  # SANDBOX_DIR is read by the sourced routing library
( SANDBOX_DIR="$D"; unset CHANGES_DIR INPUT_DIR OUTPUT_DIR
  _d=$(session_state_read "$D" "changes_dir" 2>/dev/null) && CHANGES_DIR="$_d"
  _d=$(session_state_read "$D" "input_dir" 2>/dev/null) && INPUT_DIR="$_d"
  _d=$(session_state_read "$D" "output_dir" 2>/dev/null) && OUTPUT_DIR="$_d"
  printf '  partial record: before fallback CHANGES_DIR=<%s> INPUT_DIR=<%s>\n' "${CHANGES_DIR:-}" "${INPUT_DIR:-}"
  if [[ -z "${CHANGES_DIR:-}" || -z "${INPUT_DIR:-}" || -z "${OUTPUT_DIR:-}" ]]; then dirs_resolve "$D"; fi
  printf '  partial record: after fallback  CHANGES_DIR=<%s>\n' "$CHANGES_DIR" )
# equal-mtime stability
E=/tmp/rtprobe2; rm -rf "$E"; mkdir -p "$E/alpha" "$E/beta"; touch -d "2020-01-01" "$E/alpha" "$E/beta"
a=$(resolve_latest_dir_by_mtime "$E"); b=$(resolve_latest_dir_by_mtime "$E")
printf '  equal mtimes: run1=<%s> run2=<%s>\n' "$(basename "$a")" "$(basename "$b")"
rm -rf /tmp/rtprobe /tmp/rtprobe2
