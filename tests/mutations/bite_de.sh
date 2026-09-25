#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/diff_export.sh; orig=/tmp/de.orig; cp "$src" "$orig"
FILES="test_diff_export test_diff_dispatch test_package_branch test_diff_rename"
run() { local label="$1"
  if cmp -s "$src" "$orig"; then printf '%-52s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out f=""
  for t in $FILES; do
    out=$(timeout 300 bash "tests/$t.sh" 2>&1); local x; x=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
    [[ -n "$x" ]] && f+="${t}[$x] "
  done
  printf '%-52s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ print new; next } {print}' "$orig" > "$src"; }
m 55 '  _pb_stderr=$(mktemp 2>/dev/null) || _pb_stderr=""'; run "E1 temp file moved out of OUTPUT_DIR"
m 77 '  :  # cleanup on success'; run "E2 success cleanup removed"
m 71 '    _write_export_status "$OUTPUT_DIR" "SUCCESS" "$_export_ts" "$_exit_code" "$_init_sha"'; run "E3 failure status written as SUCCESS"
m 75 '    return 0'; run "E4 failure exit code not propagated"
m 74 '    :'; run "E5 error-log write removed"
m 63 '  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR" "false" 2> >(tee "$_pb_stderr" >&2) || {'; run "E6 no-renames arg flipped to false"
m 40 '  _export_ts=$(date +%Y%m%d-%H%M%S)'; run "E7 timestamp no longer UTC"
m 46 '  _init_sha=$(session_state_read "$SANDBOX_DIR" "init_sha" 2>/dev/null)'; run "E8 init_sha read guard removed"
m 136 '  if false; then'; run "E9 lockfile early return disabled"
m 140 '  local _max_polls=$(( _timeout * 1 )); run=1'; run "E10 poll budget cut to one fifth"
m 144 '    sleep 0.01'; run "E11 poll interval shortened"
m 150 '    return 0'; run "E12 persistent lock no longer fails"
m 104 '    :'; run "E13 session id dropped from the log filename"
m 113 '    :'; run "E14 SUMMARY line dropped from the log"
m 34 '  if [[ -z "$SANDBOX_DIR" ]]; then'; run "E15 OUTPUT_DIR arg guard removed"
m 36 '    return 1'; run "E16 arg-guard return flipped"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
