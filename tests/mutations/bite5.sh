#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_inventory.sh; orig=/tmp/session_inventory.orig; cp "$src" "$orig"
get() { grep -nF "$1" "$orig" | cut -d: -f1 | head -1; }
run() { local label="$1"; shift; local out; out=$(bash "$1" 2>&1)
  echo "### $label"; printf '%s\n' "$out" | grep -E "^(FAIL|  FAIL)" | sed 's/^/   /'
  cp "$orig" "$src"; }
n_gate=$(get '  [[ "$agent_img" == *"-agent-"* ]] || return 0')
n_sha=$(get '  git -C "$dir" rev-parse HEAD 2>/dev/null || true')
n_stale=$(get '    if [[ "$rec_sha" == "$current_sha" ]]; then echo "fresh"; else echo "stale"; fi')
n_ref=$(get '    echo "$ref"; return 0')

awk -v n="$n_gate" 'NR==n{print "  :"; next}{print}' "$orig" > "$src"
run "M2 provider gate off" tests/test_session_inventory.sh
awk -v n="$n_sha" 'NR==n{print "  echo HEAD"; next}{print}' "$orig" > "$src"
run "M5 project_current_sha -> echo HEAD" tests/test_session_inventory.sh
awk -v n="$n_stale" 'NR==n{print "    if [[ \"$rec_sha\" == \"$current_sha\" ]]; then echo \"stale\"; else echo \"fresh\"; fi"; next}{print}' "$orig" > "$src"
run "M6 session_stale fresh/stale swapped" tests/test_session_inventory.sh
awk -v n="$n_ref" 'NR==n{print "    echo \"WRONG\"; return 0"; next}{print}' "$orig" > "$src"
run "M14 project_current_branch wrong name" tests/test_resume.sh
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
