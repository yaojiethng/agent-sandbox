#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_inventory.sh
orig=/tmp/session_inventory.orig
cp "$src" "$orig"

show() { local out; out=$(bash "$@" 2>&1) || true
  local pf; pf=$(printf '%s\n' "$out" | grep -oE 'pass=[0-9]+ fail=[0-9]+ skip=[0-9]+' | tail -1)
  local fails; fails=$(printf '%s' "$pf" | grep -oE 'fail=[0-9]+' | cut -d= -f2)
  printf '%s  [%s]\n' "$([[ "${fails:-0}" -gt 0 ]] && echo PROVEN || echo SURVIVED)" "${pf:-no-summary}"; }

echo "== M11 clean: drop the negative-diff clamp in BOTH formatters =="
awk 'NR==223||NR==243{print "  diff=$(( now - ep ))"; next}{print}' "$orig" > "$src"
cmp -s "$src" "$orig" && echo NO-OP || show tests/test_session_log.sh
cp "$orig" "$src"

echo
echo "== M1 applied: service-boundary reset removed =="
awk 'NR==34{next}{print}' "$orig" > "$src"
# shellcheck disable=SC1090  # subject path is runtime-resolved
( source "$src"
  p=/tmp/probe_rec.yml
  printf 'services:\n  sandbox:\n    image: sbx\n  agent:\n    extra: x\n  other:\n    image: LEAK\n' > "$p"
  echo "record_image agent (agent block has no image; 'other' does) -> '$(record_image "$p" agent)'  [original: empty]"
  rm -f "$p" )
cp "$orig" "$src"

echo
echo "== M12 applied: ts_to_epoch format guard accepts anything =="
awk 'NR==212{print "  [[ \"$ts\" =~ ^.*$ ]] || { echo \"\"; return 0; }"; next}{print}' "$orig" > "$src"
# shellcheck disable=SC1090  # subject path is runtime-resolved
( source "$src"
  echo "ts_to_epoch '20260828-120000junk' -> '$(ts_to_epoch '20260828-120000junk')'  [original: empty]" )
cp "$orig" "$src"

echo
echo "== Original-file probes for untested surfaces =="
# shellcheck disable=SC1090  # subject path is runtime-resolved
( source "$src"
  d=/tmp/probe_sbx; rm -rf "$d"; mkdir -p "$d/.compose"; export SANDBOX_DIR="$d"
  # P: duplicate keys in a hand-edited log; docstring says last set wins
  printf 'last_stopped=A\nlast_stopped=B\n' > "$d/.compose/dup.log"
  echo "P-A session_log_read on duplicate keys -> '$(session_log_read dup last_stopped)'  [docstring: last set wins]"
  # P: sed replacement-value interpolation
  session_log_set val 'k' 'a&b'; echo "P-B session_log_set value 'a&b' -> file: '$(cat "$d/.compose/val.log")'"
  rm -f "$d/.compose/val.log"
  session_log_set val2 'k' 'a#b' 2>/tmp/err; echo "P-C session_log_set value 'a#b' -> file: '$(cat "$d/.compose/val2.log" 2>/dev/null)'  stderr: $(tr '\n' ' ' < /tmp/err)"
  # P: project_branch_age "-" for empty sha and N>1
  export PROJECT_DIR="$d"; git -C "$d" init -q 2>/dev/null
  echo "P-D project_branch_age '' -> '$(project_branch_age '')'"
  echo "P-E project_current_branch in a git repo with no commit -> '$(project_current_branch)'"
  rm -rf "$d" )
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
