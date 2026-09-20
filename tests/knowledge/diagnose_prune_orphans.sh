#!/usr/bin/env bash
# diagnose_prune_orphans.sh
# Run on the docker HOST (docker is required), e.g.:
#   bash tests/knowledge/diagnose_prune_orphans.sh \
#       --sandbox="$HOME/sandbox/agent-sandbox" \
#       [--name=agent-sandbox]
#
# NOTE: a leading `~` is expanded and the path canonicalized (readlink -f)
# here, so any spelling of the folder converges to the canonical label form.
# Passing an unexpanded `~/...` no longer breaks the filters.
#
# Report-only. Lists the docker resources labeled with this sandbox's
# `agent-sandbox.sandbox-dir` and whether each has a .compose session record.
# A resource whose session record is gone (record=MISSING) is an orphan that
# prune's Rule 2 failed to remove for this sandbox.
#
# Matching is STRICTLY label-based, mirroring prune's own Rule 2 discovery.
# Do NOT infer ownership from docker name patterns (e.g. a `-sandbox-data`
# suffix): volume names under a multi-SANDBOX_DIR host are ambiguous across
# sandboxes, and name-pattern matching would be trigger-happy and claim other
# sandboxes' resources. See the handover Finding on label reliability.
#
# This diagnostic never mutates docker. Cleanup of confirmed orphans is done
# on the host by hand (e.g. `docker system prune -a --volumes -f` or targeted
# `docker volume rm`), since prune is a host-run command.

set -uo pipefail

PASS=0
FAIL=0
pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

SANDBOX_DIR=""
PROJECT_NAME=""

for ARG in "$@"; do
  case "$ARG" in
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    *) echo "Unknown arg: $ARG (use --sandbox=<path> [--name=<name>])" >&2; exit 1 ;;
  esac
done

# Expand a leading ~ (can't rely on the caller having expanded it), then
# canonicalize to its absolute form so the label filters match the canonical
# `agent-sandbox.sandbox-dir` label baked at create time, mirroring prune's own
# Rule 2 discovery (sandbox_dir_canon in src/libs/common.sh).
if [[ "$SANDBOX_DIR" == \~/* ]]; then
  SANDBOX_DIR="${HOME}${SANDBOX_DIR#\~}"
fi
if ! SANDBOX_DIR="$(readlink -f "$SANDBOX_DIR" 2>/dev/null)"; then
  echo "Error: cannot canonicalize SANDBOX_DIR: $SANDBOX_DIR" >&2
  exit 1
fi

if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Error: --sandbox=<path> is required." >&2
  exit 1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker not found -- this diagnostic must run on the docker host." >&2
  exit 1
fi

echo "sandbox: $SANDBOX_DIR"

# --- registry lookup ---
has_record() {
  local sid="$1"
  [[ -n "$sid" ]] || return 1
  [[ -f "$SANDBOX_DIR/.compose/$sid.yml" ]]
}

echo ""
echo "=== 1. Registry records ==="
if [[ -d "$SANDBOX_DIR/.compose" ]]; then
  mapfile -t RECORDS < <(find "$SANDBOX_DIR/.compose" -maxdepth 1 -name '*.yml' -printf '%f\n' 2>/dev/null | sed 's/\.yml$//' | sort)
  echo "  .compose records: ${#RECORDS[@]}"
else
  RECORDS=()
  echo "  .compose dir absent (no records)"
fi

echo ""
echo "=== 2. Resources labeled sandbox-dir ==="
# Label-based discovery, mirroring prune's Rule 2.
CONTAINER_FILTER=(--filter "label=agent-sandbox.sandbox-dir=$SANDBOX_DIR")
NETWORK_FILTER=(--filter "label=agent-sandbox.sandbox-dir=$SANDBOX_DIR")
[[ -n "$PROJECT_NAME" ]] && CONTAINER_FILTER+=(--filter "label=agent-sandbox.project-name=$PROJECT_NAME")
[[ -n "$PROJECT_NAME" ]] && NETWORK_FILTER+=(--filter "label=agent-sandbox.project-name=$PROJECT_NAME")

LEAKS=0
SCANNED=0
report_resource() {
  local kind="$1" id="$2" sid="$3"
  SCANNED=$((SCANNED + 1))
  if has_record "$sid"; then
    echo "  $kind ${id}  session-id='${sid}'  record=present (kept)"
  else
    echo "  $kind ${id}  session-id='${sid:-?}'  record=MISSING  -> leak"
    LEAKS=$((LEAKS + 1))
  fi
}

echo "-- Containers --"
CONTAINERS=$(docker ps -aq --no-trunc "${CONTAINER_FILTER[@]}" 2>/dev/null || true)
if [[ -n "$CONTAINERS" ]]; then
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    sid=$(docker inspect "$c" --format '{{index .Config.Labels "agent-sandbox.session-id"}}' 2>/dev/null || true)
    report_resource "container" "${c:0:12}" "$sid"
  done <<< "$CONTAINERS"
else
  echo "  (none labeled sandbox-dir)"
fi

echo "-- Volumes --"
VOLUMES=$(docker volume ls -q --filter "label=agent-sandbox.sandbox-dir=$SANDBOX_DIR" 2>/dev/null || true)
if [[ -n "$VOLUMES" ]]; then
  while IFS= read -r v; do
    [[ -n "$v" ]] || continue
    sid=$(docker volume inspect "$v" --format '{{index .Labels "agent-sandbox.session-id"}}' 2>/dev/null || true)
    report_resource "volume" "$v" "$sid"
  done <<< "$VOLUMES"
else
  echo "  (none labeled sandbox-dir)"
fi

echo "-- Networks --"
NETWORKS=$(docker network ls -q "${NETWORK_FILTER[@]}" 2>/dev/null || true)
if [[ -n "$NETWORKS" ]]; then
  while IFS= read -r n; do
    [[ -n "$n" ]] || continue
    sid=$(docker network inspect "$n" --format '{{index .Labels "agent-sandbox.session-id"}}' 2>/dev/null || true)
    report_resource "network" "$n" "$sid"
  done <<< "$NETWORKS"
else
  echo "  (none labeled sandbox-dir)"
fi

echo ""
echo "=== Summary ==="
echo "  labeled resources scanned: $SCANNED"
echo "  leaked (record MISSING):   $LEAKS"
if [[ "$LEAKS" -eq 0 ]]; then
  pass "no leaked resources for this sandbox (by label)"
else
  fail "$LEAKS labeled resource(s) have no session record (prune missed them)"
  echo ""
  echo "Remove confirmed leaks on the host by hand (prune is not a reporter):"
  echo "  docker system prune -a --volumes -f   # all unused resources (all sandboxes)"
  echo "  # or targeted: docker volume rm <name> ; docker rm <id>"
fi

[[ "$FAIL" -eq 0 ]]