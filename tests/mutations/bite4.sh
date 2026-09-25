#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_inventory.sh
orig=/tmp/session_inventory.orig
cp "$src" "$orig"
n_dry=$(grep -nF '  [[ "${1#"$DRYRUN_SID_PREFIX"}" != "$1" ]]' "$orig" | cut -d: -f1)
n_age=$(grep -nF '  [[ -n "$sha" ]] || { echo "-"; return 0; }' "$orig" | cut -d: -f1)
n_ref=$(grep -nF '    echo "$ref"; return 0' "$orig" | cut -d: -f1)
echo "lines: dry=$n_dry age=$n_age ref=$n_ref"

run() { local label="$1"; shift
  if cmp -s "$src" "$orig"; then echo "$label: NO-OP"; else
    local out; out=$(bash "$@" 2>&1) || true
    local pf; pf=$(printf '%s\n' "$out" | grep -oE 'pass=[0-9]+ fail=[0-9]+ skip=[0-9]+' | tail -1)
    local f; f=$(printf '%s' "$pf" | grep -oE 'fail=[0-9]+' | cut -d= -f2)
    printf '%-50s %s  [%s]\n' "$label" "$([[ "${f:-0}" -gt 0 ]] && echo PROVEN || echo SURVIVED)" "${pf:-none}"
  fi
  cp "$orig" "$src"; }

awk -v n="$n_dry" 'NR==n{print "  [[ \"${1#\"$DRYRUN_SID_PREFIX\"}\" == \"$1\" ]]"; next}{print}' "$orig" > "$src"
run "M13 session_is_dry_run: invert predicate" tests/test_session_inventory.sh tests/test_start_agent.sh

awk -v n="$n_ref" 'NR==n{print "    echo \"WRONG\"; return 0"; next}{print}' "$orig" > "$src"
run "M14 project_current_branch: wrong branch name" tests/test_resume.sh tests/test_interactive_session_select.sh

awk -v n="$n_age" 'NR==n{print "  :"; next}{print}' "$orig" > "$src"
run "M15 project_branch_age: drop empty-sha '-' branch" tests/test_resume.sh tests/test_interactive_session_select.sh

echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
