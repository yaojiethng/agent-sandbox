#!/usr/bin/env bash
# Bite sweep for scripts/start_agent.sh. Each mutant runs against the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
cp scripts/start_agent.sh /tmp/start.orig
trap 'cp /tmp/start.orig scripts/start_agent.sh' EXIT

bite() {
  local id="$1" desc="$2" expr="$3"
  cp /tmp/start.orig scripts/start_agent.sh
  sed -i "$expr" scripts/start_agent.sh
  if cmp -s /tmp/start.orig scripts/start_agent.sh; then
    printf '%s NO-OP     | %s (sed did not match)\n' "$id" "$desc"; return
  fi
  if [[ "${DRY:-}" == 1 ]]; then
    diff /tmp/start.orig scripts/start_agent.sh | sed -n '2,5p' | cut -c1-96 | sed 's/^/       /'
    cp /tmp/start.orig scripts/start_agent.sh; return
  fi
  local log="/tmp/bite_start_$id.log"
  if bash scripts/run_tests.sh > "$log" 2>&1; then
    printf '%s SURVIVED  | %s\n' "$id" "$desc"
  else
    printf '%s PROVEN    | %s\n     -> %s\n' "$id" "$desc" "$(grep -m4 -E '^FAIL |^  - ' "$log" | tr '\n' ' ' | sed 's/  */ /g')"
  fi
  cp /tmp/start.orig scripts/start_agent.sh
}

bite S1  "validate_wsl_path: the Windows test never fires"     's|  if \[\[ "$PATH_VAL" =~ \^\[A-Za-z\]:\\\\ \]\]; then|  if false; then|'
bite S2  "--delivery validation accepts anything"              's|    copy\|mount) ;;|    copy\|mount\|*) ;;|'
bite S3  "dry-run no longer rebuilds current source"           's|^      REFRESH=true$|      :|'
bite S4  "--fast + --rebuild combination accepted"             's|^      if \[\[ "$REBUILD" == true \]\]; then$|      if false; then|'
bite S5  "--refresh accepted for dry-run"                      's|^    if \[\[ "$REFRESH" == true \]\]; then$|    if false; then|'
bite S6  "--fast accepted outside dry-run"                     's|  if \[\[ "$FAST" == true && "$MODE" != "dry-run" \]\]; then|  if false; then|'
bite S7  "--provider required check disabled (main, l.353)"     '353s|^  if \[\[ -z "$PROVIDER_NAME" \]\]; then|  if false; then|'
bite S8  "derived SANDBOX_DIR name changes"                    's|-sandbox"$|-sandboxXX"|'
bite S9  "dry-run session id prefix removed"                   's|    export SESSION_ID="\${DRYRUN_SID_PREFIX}\${SESSION_ID}"|    export SESSION_ID="${SESSION_ID}"|'
bite S10 "sandbox_dir_canon failure ignored"                   's|  if ! canon_dir="\$(sandbox_dir_canon "\$SANDBOX_DIR")"; then exit 1; fi|  canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")" \|\| true|'
bite S11 "mount unborn-HEAD check disabled"                    's|      if ! git -C "\$PROJECT_DIR" rev-parse --verify HEAD >/dev/null 2>&1; then|      if false; then|'
bite S12 "recorded worktree mode accepts any value"            's|        true\|false) ;;|        true\|false\|*) ;;|'
bite S13 "worktree flatten mismatch no longer refused"         's|      if \[\[ "\$recorded_flatten" != "\$FLATTEN" \]\]; then|      if false; then|'
bite S14 "--interactive allowed outside standard mode (l.127)"  '127s|^  if \[\[ "$MODE" != "standard" \]\]; then|  if false; then|'
bite S15 "wizard lists providers without a dockerfile"         's|    \[\[ -f "\${p}provider.dockerfile" \]\] \|\| continue|    :|'
bite S17 "parse_help_flag call removed"                        's|  if parse_help_flag "\$@"; then|  if false; then|'

cp /tmp/start.orig scripts/start_agent.sh
cmp -s /tmp/start.orig scripts/start_agent.sh && echo "restored: pristine"
