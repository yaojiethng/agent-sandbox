#!/usr/bin/env bash
# Bite sweep for scripts/prune.sh. Each mutant runs against the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
cp scripts/prune.sh /tmp/prune.orig
trap 'cp /tmp/prune.orig scripts/prune.sh' EXIT

bite() {
  local id="$1" desc="$2" expr="$3"
  cp /tmp/prune.orig scripts/prune.sh
  sed -i "$expr" scripts/prune.sh
  if cmp -s /tmp/prune.orig scripts/prune.sh; then
    printf '%s NO-OP     | %s (sed did not match)\n' "$id" "$desc"; return
  fi
  local log="/tmp/bite_prune_$id.log"
  if bash scripts/run_tests.sh > "$log" 2>&1; then
    printf '%s SURVIVED  | %s\n' "$id" "$desc"
  else
    printf '%s PROVEN    | %s\n     -> %s\n' "$id" "$desc" "$(grep -m3 -E '^FAIL |^  - ' "$log" | tr '\n' ' ' | sed 's/  */ /g')"
  fi
  cp /tmp/prune.orig scripts/prune.sh
}

bite P1  "age filter disabled (cutoff guard -> false)"        's|  if \[\[ -n "\$cutoff_ts" \]\]; then|  if false; then|'
bite P2  "Rule 1 record rm becomes a no-op"                   's|      rm -f "\$SANDBOX_DIR/.compose/\$sid.yml"|      :|'
bite P3  "predictive preview: stale SIDs not treated removed" 's|    TREATED_REMOVED_SIDS=( "\${SIDS_PRUNED\[@\]}" )|    TREATED_REMOVED_SIDS=()|'
bite P4  "empty session-id guard removed in _sid_is_orphaned" 's|  \[\[ -n "\$sid" \]\] \|\| return 1|  :|'
bite P5  "--age-days integer validation removed"              's|if \[\[ ! "\$AGE_DAYS" =~ \^\[0-9\]+\$ \]\]; then|if false; then|'
bite P6  "sandbox_dir_canon failure ignored"                  's|if ! canon_dir="\$(sandbox_dir_canon "\$SANDBOX_DIR")"; then exit 1; fi|canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")" \|\| true|'
bite P7  "extra bogus filter added to docker volume ls"       's|  vols="\$(docker volume ls \\|  vols="$(docker volume ls --filter label=nope \\|'
bite P8  "docker stop before rm removed"                      's|          docker stop "\$id" 2>/dev/null \|\| true|          :|'
bite P9  "--project required check removed"                   's|  if \[\[ -z "\$PROJECT_DIR" \]\]; then|  if false; then|'
bite P10 "--stale kind validation accepts everything"         's|    ""\|sandbox) ;;|    ""\|sandbox\|*) ;;|'
bite P11 "interactive abort gate does not stop execution"     's|"\$PRUNE_CMD" \|\| exit 1|"$PRUNE_CMD" \|\| true|'
bite P12 "docker volume rm branch removed"                    's|          docker volume rm "\$id" 2>/dev/null \|\| true|          :|'
bite P13 "staleness test weakened: stale -> != fresh"         's|== "stale" \]\] \|\| continue|!= "fresh" ]] \|\| continue|'

cp /tmp/prune.orig scripts/prune.sh
cmp -s /tmp/prune.orig scripts/prune.sh && echo "restored: pristine"
