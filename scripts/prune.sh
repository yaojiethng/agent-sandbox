#!/usr/bin/env bash
# scripts/prune.sh
#
# Registry-based prune (Rules 1+2) for a single project+sandbox instance.
# Replaces the legacy volume-label `--stale` + `docker system prune` path.
# The `.compose/<session-id>.yml` registry is the source of truth for which
# sessions exist and whether they are stale.
#
# INVARIANT  --  the prune outcome is a partition of sessions. After prune, every
# session is either **fully pruned** (its record AND its resources are gone) or
# **fully kept** (its record AND its resources are intact)  --  never partial, and
# never collateral damage to a kept session's resources. A stale record is
# removed by Rule 1; that makes its session's resources orphaned, and Rule 2
# removes them in the same pass. A resource is orphaned iff its session has no
# record on disk, so a kept session (record present) is never touched.
#
# Usage:
#   prune.sh --name=<project> --project=<path> --sandbox=<path> \
#       [--stale=<sandbox|image|all>] [--provider=<n>] [--age-days=<n>] \
#       [--interactive] [--dry-run]
#
# Two rules (design `20260818-02`, mount-model record #7), always run as a
# complete pass (no partial/scope split; simulation is --dry-run):
#   Rule 1  --  remove stale `.compose/*.yml` records.
#   Rule 2  --  remove resources (containers, networks, volumes) labeled
#            `agent-sandbox.sandbox-dir` whose session has NO `.compose` record.
#
# Execution is strictly sequential: Rule 1 removes the records first, then
# Rule 2 re-derives its orphan list against the updated registry  --  a resource
# is an orphan iff its session has no record on disk. Removing a stale record
# therefore makes that session's resources orphaned, and the fresh Rule 2 scan
# catches them in the same pass. No in-memory contract couples the two rules;
# the registry is the single source of truth at each step.
#
# Preview (--dry-run / --interactive) cannot delete-then-rescan, so it treats a
# Rule-1-selected session's record as already removed to predict Rule 2's
# result. That prediction is render-only; the real action always re-scans.
#
# Rule 1 selection (registry-truth, D7 / `session_stale` + image staleness):
#   A record is selected, per the requested staleness kind, when it is
#   sandbox-stale (host-head-sha != current project HEAD) and/or image-stale
#   (referenced image's container-sig != current source) and older than
#   AGE_DAYS. `STALE=sandbox|image|all` select the sandbox / image / either
#   staleness dimension (STALE=all or unset = the "remove all stale" filter).
#
# Rule 2 scope: delivery-scoped in effect  --  copy sessions register a volume,
# mount sessions do not, so removing labeled resources yields copy -> volume +
# containers and mount -> registry resources only. Worktrees are never touched.

set -euo pipefail

PRUNE_AGE_DAYS=3
STALE_KIND="${STALE_KIND:-}"      # sandbox|image|all (empty = all implemented)
AGE_DAYS="${AGE_DAYS:-$PRUNE_AGE_DAYS}"
PROVIDER_FILTER=""
INTERACTIVE_FLAG=false
DRY_RUN_FLAG=false
PROJECT_DIR=""

usage() {
  cat <<EOF
Usage: agent-sandbox prune --name=<name> --project=<path> --sandbox=<path> [options]

Registry-based prune: removes stale session records and orphaned resources
for this project+sandbox. Always a complete pass (Rule 1 records + Rule 2
resources). Simulation is --dry-run; confirmation is --interactive.

Options:
  --stale=<kind>   Staleness kind to target: sandbox (repo out of date),
                   image (image out of date), or all (default; either).
  --provider=<n>   Narrow stale-record selection to this provider.
  --age-days=<n>   Stale-record age cutoff (default ${PRUNE_AGE_DAYS} days).
  --interactive    Show the prune plan + equivalent command, then confirm.
  --dry-run        Print what would be pruned without acting.

Required:
  --name=<name>       Project name
  --project=<path>    Project repository path (for current HEAD)
  --sandbox=<path>    Path to the sandbox directory
EOF
}
# -------------------------
# Rule 1: selected stale records
# -------------------------
# Prints `session-id|provider|ts|branch|delivery` for each selected stale
# record. Best-effort; never fails the prune on a malformed record.
# Selection is driven by the staleness kind (STALE=sandbox|image|all): a
# record is selected when it is stale by the enabled criterion (sandbox =
# host-head-sha mismatch; image = referenced image container-sig mismatch),
# and older than AGE_DAYS, narrowed by PROVIDER.
rule1_selected_records() {
  [[ -d "$SANDBOX_DIR/.compose" ]] || return 0
  local current_sha cutoff_ts
  current_sha="$(project_current_sha)"
  cutoff_ts="$(date -d "${AGE_DAYS} days ago" +%Y%m%d 2>/dev/null || true)"

  local line sid provider ts branch delivery rec_day
  # Enumeration (glob -> provider recovery -> PROVIDER_FILTER) is the shared
  # `enumerate_records` core from session_inventory.sh.
  while IFS= read -r line; do
    IFS='|' read -r sid provider ts branch <<< "$line"
    local file="$SANDBOX_DIR/.compose/$sid.yml"
    # Staleness selection by kind. Each criterion is evaluated only when its
    # kind is enabled (sandbox-only / image-only / either for STALE=all).
    case "$STALE_KIND" in
      sandbox)
        [[ "$(session_stale "$file" "$current_sha")" == "stale" ]] || continue
        ;;
      image)
        [[ "$(record_image_stale "$file" "$REPO_ROOT")" == "stale" ]] || continue
        ;;
      ""|all)
        [[ "$(session_stale "$file" "$current_sha")" == "stale" \
           || "$(record_image_stale "$file" "$REPO_ROOT")" == "stale" ]] || continue
        ;;
    esac
    # Age narrowing (applies to every selected record regardless of kind).
    ts="${ts:-00000000-000000}"
    if [[ -n "$cutoff_ts" ]]; then
      rec_day="${ts:0:8}"
      [[ -z "$rec_day" || "$rec_day" > "$cutoff_ts" ]] && continue
    fi
    # Delivery lives in the sandbox-service env (`SANDBOX_TYPE`, set by the
    # delivery overlay). Disclosure in the plan only  --  it gates neither rule.
    delivery="$(env_field "$file" SANDBOX_TYPE)"
    printf '%s|%s|%s|%s|%s\n' "$sid" "$provider" "$ts" "${branch:-}" "$delivery"
  done < <(enumerate_records)
}

# env_field FILE VAR  --  read a `VAR=value` from any service `environment:`
# block in a registry record (e.g. `SANDBOX_TYPE=mount`).
env_field() {
  local file="$1" var="$2"
  grep -E "[[:space:]]*-[[:space:]]*${var}=[^[:space:]]+" "$file" \
    | sed -E "s/.*[[:space:]]-*[[:space:]]*${var}=([^[:space:]]+).*/\1/" | head -1 || true
}

# -------------------------
# Rule 2: orphaned resources
# -------------------------
# ORPHAN_TEST  --  a resource's session-id is orphaned if it has no record on
# disk. For a predictive preview (--dry-run / --interactive) the Rule-1-selected
# SIDs are treated as already-removed, so a session whose record is about to be
# deleted is reported as orphaned too. Execution clears this set and re-scans
# the genuine registry.
# _sid_is_orphaned SID  --  true when the session is not a keeper (no record).
_sid_is_orphaned() {
  local sid="$1"
  [[ -n "$sid" ]] || return 1
  [[ ! -f "$SANDBOX_DIR/.compose/$sid.yml" ]] && return 0
  local s
  for s in "${TREATED_REMOVED_SIDS[@]:-}"; do
    [[ "$s" == "$sid" ]] && return 0
  done
  return 1
}

# _session_id_of KIND ID  --  read `agent-sandbox.session-id` from a docker
# resource's labels.
_session_id_of() {
  local kind="$1" id="$2"
  case "$kind" in
    container) docker inspect "$id" --format '{{index .Config.Labels "agent-sandbox.session-id"}}' 2>/dev/null || true ;;
    network)   docker network inspect "$id" --format '{{index .Labels "agent-sandbox.session-id"}}' 2>/dev/null || true ;;
    volume)    docker volume inspect "$id" --format '{{index .Labels "agent-sandbox.session-id"}}' 2>/dev/null || true ;;
  esac
}

# collect_orphans KIND ID...  --  emit `kind|id|sid` for each resource whose
# session is not a keeper.
collect_orphans() {
  local kind="$1"; shift
  local id sid
  for id in "$@"; do
    [[ -n "$id" ]] || continue
    sid="$(_session_id_of "$kind" "$id")"
    _sid_is_orphaned "$sid" && printf '%s|%s|%s\n' "$kind" "$id" "$sid"
  done
}

# Emits `kind|id|sid` for every orphaned resource of this project+sandbox
# across all three resource kinds.
rule2_orphan_resources() {
  local -a ids=()
  local cids nets vols

  cids="$(docker ps -aq \
    --filter "label=agent-sandbox.project-name=${PROJECT_NAME}" \
    --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" 2>/dev/null || true)"
  mapfile -t ids <<< "$cids"
  collect_orphans container "${ids[@]}"

  nets="$(docker network ls -q \
    --filter "label=agent-sandbox.project-name=${PROJECT_NAME}" \
    --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" 2>/dev/null || true)"
  mapfile -t ids <<< "$nets"
  collect_orphans network "${ids[@]}"

  vols="$(docker volume ls \
    --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" \
    --format '{{.Name}}' 2>/dev/null || true)"
  mapfile -t ids <<< "$vols"
  collect_orphans volume "${ids[@]}"
}

# -------------------------
# Preview renderers (plan display)
# -------------------------
show_rule1() {
  local line sid provider ts branch delivery
  printf '  %-8s %-10s %-17s %-22s %-7s\n' "session-id" "provider" "session-ts" "branch" "delivery"
  for line in "${RULE1_RECS[@]}"; do
    IFS='|' read -r sid provider ts branch delivery <<< "$line"
    printf '  %-8s %-10s %-17s %-22s %-7s\n' "$sid" "$provider" "$ts" "${branch:-}" "${delivery:-}"
  done
}

show_rule2() {
  local line kind id sid
  for line in "${ORPHANS[@]}"; do
    IFS='|' read -r kind id sid <<< "$line"
    echo "  $kind: $id  (session $sid)"
  done
}

# -------------------------
# Build the Rule-1 selection

# -------------------------
# CLI entry point
# -------------------------
main() {
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  source "$REPO_ROOT/src/libs/common.sh"
  # session_inventory.sh also sources container_sig.sh (image-staleness criterion).
  source "$REPO_ROOT/src/libs/session_inventory.sh"

  parse_help_flag "$@"
  parse_base_flags "$@"
  local ARG
  for ARG in "$@"; do
    case "$ARG" in
      --stale=*)         STALE_KIND="${ARG#--stale=}" ;;
      --provider=*)      PROVIDER_FILTER="${ARG#--provider=}" ;;
      --age-days=*)      AGE_DAYS="${ARG#--age-days=}" ;;
      --interactive)     INTERACTIVE_FLAG=true ;;
      --dry-run)         DRY_RUN_FLAG=true ;;
    esac
  done
  for ARG in "$@"; do
    case "$ARG" in
      --project=*) PROJECT_DIR="${ARG#--project=}" ;;
    esac
  done
  check_base_flags
  if [[ -z "$PROJECT_DIR" ]]; then
    echo "Error: --project is required (need the current HEAD for staleness)." >&2
    usage >&2
    exit 1
  fi

  # Staleness-kind validation.
  case "$STALE_KIND" in
    ""|sandbox|image|all) ;;
    *)
      echo "Error: unknown --stale kind '$STALE_KIND' (expected sandbox, image, or all)." >&2
      usage >&2
      exit 1
      ;;
  esac

  if [[ ! "$AGE_DAYS" =~ ^[0-9]+$ ]]; then
    echo "Error: --age-days must be a non-negative integer (got '$AGE_DAYS')." >&2
    usage >&2
    exit 1
  fi

  # ORPHAN_TEST  --  a resource's session-id is orphaned if it has no record on
  # disk. For a predictive preview (--dry-run / --interactive) the Rule-1-selected
  # SIDs are treated as already-removed, so a session whose record is about to be
  # deleted is reported as orphaned too. Execution clears this set and re-scans
  # the genuine registry.
  TREATED_REMOVED_SIDS=()

  mapfile -t RULE1_RECS < <(rule1_selected_records)
  # SIDS_PRUNED  --  the list of SIDs Rule 1 will remove (its "removal result").
  SIDS_PRUNED=( "${RULE1_RECS[@]%%|*}" )
  
  # -------------------------
  # Preview / confirm (--dry-run and --interactive)  --  predictive, render-only
  # -------------------------
  if [[ "$DRY_RUN_FLAG" == true || "$INTERACTIVE_FLAG" == true ]]; then
    TREATED_REMOVED_SIDS=( "${SIDS_PRUNED[@]}" )
    mapfile -t ORPHANS < <(rule2_orphan_resources)
  
    if [[ "${#RULE1_RECS[@]}" -eq 0 && "${#ORPHANS[@]}" -eq 0 ]]; then
      echo "Nothing to prune  --  no stale records and no orphaned resources."
      exit 0
    fi
    if [[ "${#RULE1_RECS[@]}" -gt 0 ]]; then
      echo "Rule 1  --  ${#RULE1_RECS[@]} stale record(s) to remove:"
      show_rule1
    fi
    if [[ "${#ORPHANS[@]}" -gt 0 ]]; then
      echo "Rule 2  --  ${#ORPHANS[@]} orphaned resource(s) to remove:"
      show_rule2
    fi
  
    if [[ "$DRY_RUN_FLAG" == true ]]; then
      echo "Dry run: nothing was removed."
      exit 0
    fi
  
    # Interactive: print the equivalent non-interactive command, then confirm.
    source "$REPO_ROOT/scripts/workflows/interactive.sh"
    echo ""
    PRUNE_CMD="agent-sandbox prune"
    PRUNE_CMD+=" --name=$PROJECT_NAME --project=$PROJECT_DIR --sandbox=$SANDBOX_DIR"
    [[ -n "$PROVIDER_FILTER" ]] && PRUNE_CMD+=" --provider=$PROVIDER_FILTER"
    [[ -n "$STALE_KIND" ]] && PRUNE_CMD+=" --stale=$STALE_KIND"
    [[ -n "$AGE_DAYS" ]] && PRUNE_CMD+=" --age-days=$AGE_DAYS"
    echo "Equivalent non-interactive command:"
    echo "  $PRUNE_CMD"
    echo ""
    interactive_confirm_or_abort "Proceed with the prune above?" "$PRUNE_CMD" || exit 1
  fi
  
  # -------------------------
  # Execute  --  strictly sequential, reading the real registry at each step
  # -------------------------
  DID_WORK=false
  
  # Rule 1  --  remove stale records (iterate the removal result directly).
  if [[ "${#RULE1_RECS[@]}" -gt 0 ]]; then
    echo "Rule 1  --  removing ${#SIDS_PRUNED[@]} stale record(s):"
    for sid in "${SIDS_PRUNED[@]}"; do
      [[ -n "$sid" ]] || continue
      echo "  removing record: $SANDBOX_DIR/.compose/$sid.yml"
      rm -f "$SANDBOX_DIR/.compose/$sid.yml"
    done
    DID_WORK=true
  fi
  
  # Rule 2  --  remove orphaned resources. Fresh scan against the updated registry
  # (the deleted records are gone, so their sessions are now orphaned here).
  TREATED_REMOVED_SIDS=()
  mapfile -t ORPHANS < <(rule2_orphan_resources)
  if [[ "${#ORPHANS[@]}" -gt 0 ]]; then
    echo "Rule 2  --  removing ${#ORPHANS[@]} orphaned resource(s):"
    for line in "${ORPHANS[@]}"; do
      IFS='|' read -r kind id _ <<< "$line"
      case "$kind" in
        container)
          echo "  removing orphaned container: $id"
          docker stop "$id" 2>/dev/null || true
          docker rm "$id" 2>/dev/null || true
          ;;
        network)
          echo "  removing orphaned network: $id"
          docker network rm "$id" 2>/dev/null || true
          ;;
        volume)
          echo "  removing orphaned volume: $id"
          docker volume rm "$id" 2>/dev/null || true
          ;;
      esac
    done
    DID_WORK=true
  fi
  
  [[ "$DID_WORK" == true ]] || echo "Nothing to prune."
  echo "Prune complete."
}

# Guard: only run main() when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
