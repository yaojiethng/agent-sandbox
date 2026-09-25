#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_hints.sh; orig=/tmp/session_hints.orig; cp "$src" "$orig"
run() { # $1 label
  if cmp -s "$src" "$orig"; then echo "$1: NO-OP"; cp "$orig" "$src"; return; fi
  local s t
  s=$(bash tests/test_trace_start.sh 2>&1 | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
  t=$(bash tests/test_trace_stop.sh 2>&1 | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
  printf '%-46s start[%s] stop[%s]\n' "$1" "${s:-ok}" "${t:-ok}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ if (new!="") print new; next } {print}' "$orig" > "$src"; }

m 27 '  echo "Resume this session now: make resume SESSION_ID=$_session_id"'; run "B1 resume hint text changed"
m 45 '    echo "Bundle this session'"'"'s changes: make draft BUNDLE=$(basename "$_export_dir")"'; run "B2 draft hint text changed"
m 44 '  if true; then'; run "B3 draftability gate removed"
m 38 '    -name "*-${_session_id}" 2>/dev/null | sort | head -n 1) || return 0'; run "B4 newest -> oldest (head)"
m 38 '    -name "*" 2>/dev/null | sort | tail -n 1) || return 0'; run "B5 session-id filter removed"
m 32 ''; run "B6 session-base guard removed"
m 38 '    -name "*-${_session_id}" 2>/dev/null | sort | tail -n 1)'; run "B7 assignment || return 0 removed"
m 29 ''; run "B8 dirs_resolve removed"
m 44 '  if [[ -d "$_export_dir/patches" ]]; then'; run "B9 uncommitted.diff branch removed"
m 39 ''; run "B10 empty-export-dir guard removed"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
