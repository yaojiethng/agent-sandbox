#!/usr/bin/env bash
# Mutation bites for scripts/run_agent.sh, each against the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/run_agent.sh
ORIG=/tmp/ra.orig
cp "$SRC" "$ORIG"

mut() { # mut <label> <literal-old> <literal-new>
  local label="$1"
  cp "$ORIG" "$SRC"
  local n
  n=$(grep -cF -e "$2" "$SRC" || true)
  if [[ "$n" != "1" ]]; then
    printf '%-4s SKIP  (literal matches=%s)\n' "$label" "$n"
    return 0
  fi
  OLD="$2" NEW="$3" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  cmp -s "$ORIG" "$SRC" && { printf '%-4s NO-OP (identical after edit)\n' "$label"; return 0; }
  timeout 900 bash scripts/run_tests.sh > "/tmp/bite_ra_$label.log" 2>&1
  local rc=$?
  cp "$ORIG" "$SRC"
  if grep -q '^FAIL ' "/tmp/bite_ra_$label.log"; then
    printf '%-4s PROVEN    rc=%s  %s\n' "$label" "$rc" "$(grep '^FAIL ' "/tmp/bite_ra_$label.log" | sed 's/^FAIL //' | tr '\n' ' ')"
  else
    printf '%-4s SURVIVED  rc=%s  %s\n' "$label" "$rc" "$(tail -1 "/tmp/bite_ra_$label.log")"
  fi
}

# R1  the dead help handler after parse_args
mut R1 '[ $? -eq 2 ] && exit 0' ':'
# R2  the delivery case's empty-string arm
mut R2 'copy|mount|"")' 'copy|mount)'
# R3  the required --delivery check
mut R3 'if [[ -z "$DELIVERY" ]]; then' 'if [[ -z "$DELIVERY" && false ]]; then'
# R5  the provider setup hook presence guard
mut R5 'if [[ -f "$PROVIDER_SETUP" ]]; then' 'if false; then'
# R6  the inversion that turns a hook failure into an abort
mut R6 'if ! source "$PROVIDER_SETUP"; then' 'if source "$PROVIDER_SETUP"; then'
# R7  pre-creating the provider config dir
mut R7 'mkdir -p "$SANDBOX_DIR/.$PROVIDER_NAME"' ':'
# R8  the seeder's -T flag
mut R8 'run --rm -T seeder < /dev/null' 'run --rm seeder < /dev/null'
# R9  the seeder timeout attribution
mut R9 'if (( rc == 124 )); then' 'if (( rc == 123 )); then'
# R10 discarding a half-seeded volume
mut R10 'down --volumes --remove-orphans >/dev/null 2>&1 || true' 'true'
# R12 arming teardown before the session runs
mut R12 'agent_rc=0
TEARDOWN_NEEDED=1' 'agent_rc=0
TEARDOWN_NEEDED=0'
# R13 capturing the agent's exit code
mut R13 'agent || agent_rc=$?' 'agent'
# R14 propagating the agent's exit code
mut R14 'exit "$agent_rc"' 'exit 0'
# R15 swallowing docker wait's status in serve mode
mut R15 'docker wait "$AGENT_CONTAINER_NAME" >/dev/null 2>&1 || true' 'docker wait "$AGENT_CONTAINER_NAME" >/dev/null 2>&1'
# R17 the sandbox health gate
mut R17 'compose_sandbox_wait "$PROJECT_NAME"' ':'
# R18 naming the sandbox service on up
mut R18 'up -d sandbox < /dev/null' 'up -d < /dev/null'
# R19 the persisted compose file name
mut R19 'COMPOSE_OUT="$COMPOSE_DIR/$SESSION_ID.yml"' 'COMPOSE_OUT="$COMPOSE_DIR/static.yml"'
# R20 the last_started activity log
mut R20 'session_log_set "$SESSION_ID" last_started "$(date -u +%Y%m%d-%H%M%S)"' ':'
# R21 the compose template presence guard
mut R21 'if [[ ! -f "$COMPOSE_TEMPLATE" ]]; then' 'if false; then'
# R22 the mount overlay selection
mut R22 'COMPOSE_FILES+=("$MOUNT_OVERLAY")' 'COMPOSE_FILES+=("$COPY_OVERLAY")'
# R23 the FLATTEN export
mut R23 'export FLATTEN' '# export FLATTEN'
# R24 the serve-only SERVE_PORT warning
mut R24 '[[ "$MODE" == "serve" ]]; then
    echo "Warning: SERVE_PORT is not set' '[[ "$MODE" == "standard" ]]; then
    echo "Warning: SERVE_PORT is not set'
# R25 the SERVE_PORT default
mut R25 'SERVE_PORT_DEFAULT=46553' 'SERVE_PORT_DEFAULT=12345'
# R27 the dry-run overlay presence guard
mut R27 'if [[ ! -f "$DRY_RUN_OVERLAY" ]]; then' 'if false; then'
# R28 realpath on the dry-run script paths
mut R28 'DRY_RUN_SCRIPT="$(realpath "$REPO_ROOT/scripts/dry_run_reasoning.sh")"' 'DRY_RUN_SCRIPT="$REPO_ROOT/scripts/dry_run_reasoning.sh"'

echo "--- final integrity ---"
cp "$ORIG" "$SRC"
cmp -s "$ORIG" "$SRC" && echo "source restored byte-identical"
