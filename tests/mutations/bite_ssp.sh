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

m 36 '  if false; then'; run "S1 save_needed: git-failure guard off"
m 45 '  [[ -n "$_head" && "$_head" == "$_baseline" ]]'; run "S2 save_needed: baseline compare inverted"
m 64 '    2) echo "$_label: cannot read the sandbox repository; saving anyway" >&2; return 1 ;;'; run "S3 save_decision: undeterminable -> skip"
m 65 ''; run "S4 save_decision: unknown-status arm removed"
m 84 '  _baseline=$(session_state_read "$_sandbox_dir" "host_head_sha" 2>/dev/null || true)'; run "S5 export_needed: init_sha -> host_head_sha"
m 104 '  if true; then'; run "S6 _save_baseline: success gate off"
m 111 ''; run "S7 _save_baseline: init_sha fallback removed"
m 149 '  as_stage="$channel_dir/.autosave-staging-$(basename "$as_dir")"'; run "S8 cycle: staging moved inside the channel"
m 160 '  if false; then'; run "S9 cycle: aside recovery off"
m 175 '  "${export_cmd[@]}" "$as_stage" "$sandbox_dir" "$(basename "$as_dir")" || rc=$?'; run "S10 cycle: export argv order swapped"
m 166 '  save_decision "$sandbox_dir" "$as_dir" "autosave" || return 1'; run "S11 cycle: skip status 2 -> 1"
m 227 '  autosave_cycle "$changes_dir/autosave" "$checkpoint" "$sandbox_dir" "$@"'; run "S12 tick: cycle argv order swapped"
m 245 '    autosave_tick "$path_fn" "$changes_dir" "$sandbox_dir" "$session_id" "$@"'; run "S13 loop: tick status not absorbed"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
