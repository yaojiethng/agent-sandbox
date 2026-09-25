#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_save_policy.sh; orig=/tmp/ssp.orig; cp "$src" "$orig"
run() { local label="$1"
  if cmp -s "$src" "$orig"; then printf '%-52s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out f=""
  for t in tests/test_session_save_guard.sh tests/test_routing.sh; do
    out=$(bash "$t" 2>&1); local x; x=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
    [[ -n "$x" ]] && f+="$(basename $t)[$x] "
  done
  printf '%-52s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ if (new!="") print new; next } {print}' "$orig" > "$src"; }
m 227 '  autosave_cycle "$checkpoint" "$changes_dir/session" "$sandbox_dir" "$@"'; run "S17 tick: channel dir autosave -> session"
m 158 '  :'; run "S18 cycle: channel mkdir removed"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
echo
echo "=== autosave channel path definitions ===" && grep -rn 'changes_dir/autosave\|CHANGES_DIR}/autosave\|/autosave"' src/libs/*.sh | sed 's/\(.\{130\}\).*/\1.../'
