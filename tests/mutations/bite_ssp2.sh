#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_save_policy.sh; orig=/tmp/ssp.orig; cp "$src" "$orig"
run() { local label="$1"
  if cmp -s "$src" "$orig"; then printf '%-50s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out f=""
  for t in tests/test_session_save_guard.sh tests/test_routing.sh; do
    out=$(bash "$t" 2>&1); local x; x=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
    [[ -n "$x" ]] && f+="$(basename $t)[$x] "
  done
  printf '%-50s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ if (new!="") print new; next } {print}' "$orig" > "$src"; }
m 181 '    :'; run "S14 cycle: EXPORT-ERROR log rescue off"
m 222 '  checkpoint=$("$path_fn" "$changes_dir" "autosave" "$session_id" 2>/dev/null)'; run "S15 tick: path-fn failure not absorbed"
m 244 '    :'; run "S16 loop: sleep removed"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
