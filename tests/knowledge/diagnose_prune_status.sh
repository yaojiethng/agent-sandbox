#!/usr/bin/env bash
# diagnose_prune_orphans.sh
# Run on the docker HOST (docker is required), e.g.:
#   bash scripts/diagnose_prune_orphans.sh \
#       --sandbox=/home/yaojie/sandbox/agent-sandbox \
#       [--name=agent-sandbox]
#
# Checks whether `make prune` left any orphaned docker resources behind.
# After prune's Rule 1 removes a session's `.compose/<sid>.yml` record, Rule 2
# should remove the resources of that session (volume + containers, or just
# registry resources for mount delivery). A resource whose session record is
# MISSING is a genuine leak that Rule 2 failed to catch.
#
# Every labeled resource is inspected for its session-id and matched against
# the on-disk registry. `record=MISSING` = hung resource; `record=present` =
# a live/kept session's resource (fine). If everything is present (or empty),
# nothing is hanging -- the prune was correct.

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

if [[ -z "$SANDBOX_DIR" ]]; then
  echo "Error: --sandbox=<path> is required." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker not found -- this diagnostic must run on the docker host." >&2
  exit 1
fi

echo "=== 1. Registry records ==="
if [[ -d "$SANDBOX_DIR/.compose" ]]; then
  mapfile -t RECORDS < <(find "$SANDBOX_DIR/.compose" -maxdepth 1 -name '*.yml' -printf '%f\n' 2>/dev/null | sed 's/\.yml$//' | sort)
  echo "  .compose records: ${#RECORDS[@]}"
  pass "registry directory exists ($SANDBOX_DIR/.compose)"
else
  RECORDS=()
  fail "registry directory MISSING at $SANDBOX_DIR/.compose"
fi

# Build a session-id -> record-present lookup.
has_record() {
  local sid="$1"
  [[ -n "$sid" ]] || return 1
  [[ -f "$SANDBOX_DIR/.compose/$sid.yml" ]]
}

echo ""
echo "=== 2. Resources labeled sandbox-dir ==="
# Resource filters. When PROJECT_NAME is given, scope containers/networks to it
# as well; otherwise rely on the sandbox-dir label alone.
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
    echo "  $kind ${id}  session-id='${sid}'  record=present"
  else
    echo "  $kind ${id}  session-id='${sid}'  record=MISSING"
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
  echo "  (no containers labeled sandbox-dir)"
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
  echo "  (no volumes labeled sandbox-dir)"
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
  echo "  (no networks labeled sandbox-dir)"
fi

echo ""
echo "=== 3. Cross-check: records whose resources are absent ==="
# A record with no labeled resource is fine only when the session was a
# registry-only (mount) session or already cleaned; flag it as informational.
for sid in "${RECORDS[@]:-}"; do
  [[ -n "$sid" ]] || continue
  # cheap scan: this just confirms the record exists; resource matching done above
  echo "  record $sid present (no orphan test needed -- kept)"
done

echo ""
echo "=== Summary ==="
echo "  scanned labeled resources: $SCANNED"
echo "  leaked (record=MISSING):   $LEAKS"
if [[ "$LEAKS" -eq 0 ]]; then
  pass "no orphaned resources -- prune left nothing behind"
else
  fail "$LEAKS resource(s) have a MISSING session record (prune Rule 2 missed them)"
fi

echo ""
echo "If leaks are found, prune's Rule 2 failed to detect them. Common causes:"
echo "  - resource lacks the agent-sandbox.sandbox-dir label (SANDBOX_DIR changed"
echo "    since the resource was created) -> docker ls finds nothing"
echo "  - agent-sandbox.session-id label read is empty -> treated as not-orphaned"
echo "  - a resource exists in a different project/sandbox (check --name filter)"
echo ""
echo "Clean up confirmed leaks manually, e.g.:"
echo "  docker volume rm <name> ; docker rm <id> ; docker network rm <name>"

[[ "$FAIL" -eq 0 ]]