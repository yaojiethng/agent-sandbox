#!/usr/bin/env bash
# Corrected / completed bites for resume_agent.sh.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/resume_agent.sh
ORIG=/tmp/resume.orig

bite() { # bite <label> <literal-old> <literal-new>
  local label="$1"
  cp "$ORIG" "$SRC"
  OLD="$2" NEW="$3" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  if cmp -s "$ORIG" "$SRC"; then printf '%-5s NO-OP (literal not found)\n' "$label"; return 0; fi
  timeout 900 bash scripts/run_tests.sh > "/tmp/bite_res_$label.log" 2>&1
  cp "$ORIG" "$SRC"
  if grep -q '^FAIL ' "/tmp/bite_res_$label.log"; then
    printf '%-5s PROVEN    %s\n' "$label" "$(grep '^FAIL ' "/tmp/bite_res_$label.log" | sed 's/^FAIL //' | tr '\n' ' ')"
  else
    printf '%-5s SURVIVED  %s\n' "$label" "$(tail -1 "/tmp/bite_res_$label.log")"
  fi
}

# A2b the --provider-without-a-picker guard (A2 used an ineffective [[ ... && false ]])
bite A2b 'if [[ -n "$PROVIDER_FILTER" && -z "$SESSION_ID_ARG" && "$RESUME_LIST" != true && "$INTERACTIVE_FLAG" != true ]]; then' 'if false; then'
# A3b no resume target (same correction)
bite A3b 'if [[ -z "$SESSION_ID_ARG" ]]; then
  echo "Error: no resume target given' 'if false; then
  echo "Error: no resume target given'
# A4b --sandbox requirement (same correction)
bite A4b 'if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Error: --sandbox is required' 'if false; then
  echo "Error: --sandbox is required'
# A8b the ambient SANDBOX_TYPE warning (literal count had matched 2 patterns)
bite A8b 'if [[ -n "${SANDBOX_TYPE:-}" ]]; then
  echo "Warning: ambient SANDBOX_TYPE=$SANDBOX_TYPE ignored' 'if false; then
  echo "Warning: ambient SANDBOX_TYPE=$SANDBOX_TYPE ignored'
# A15b SESSION_TS from the record (literal had a typo)
bite A15b 'SESSION_TS="$(record_label "$RECORD_FILE" session-ts)"' 'SESSION_TS=""'
# A22 the --list branch
bite A22 'if [[ "$RESUME_LIST" == true ]]; then' 'if false; then'
# A23 the --interactive branch
bite A23 'if [[ "$INTERACTIVE_FLAG" == true ]]; then' 'if false; then'
# A24 the empty-inventory refusal in both branches
bite A24 '  [[ "${#RESUME_INVENTORY[@]}" -gt 0 ]] || _no_sessions' '  :'
# A27 a cancelled picker no longer aborts
bite A27 'chosen="$(interactive_pick "$_label" PICKER "" "$RESUME_LIST_PAGE_SIZE" "$_RESUME_HEADER")" || exit 1' 'chosen="$(interactive_pick "$_label" PICKER "" "$RESUME_LIST_PAGE_SIZE" "$_RESUME_HEADER")" || :'
# A28 the confirm gate inverted
bite A28 'if ! interactive_confirm_or_abort "Resume session $chosen?"' 'if interactive_confirm_or_abort "Resume session $chosen?"'

echo "--- integrity ---"; cp "$ORIG" "$SRC"; cmp -s "$ORIG" "$SRC" && echo "restored byte-identical"
