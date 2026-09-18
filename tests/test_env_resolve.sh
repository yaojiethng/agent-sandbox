#!/usr/bin/env bash
# tests/test_env_resolve.sh
# Unit tests for src/libs/env_resolve.sh  --  the centralized precedence
# resolver for the sandbox identity triple.
#
# Precedence under test: explicit > AGENT_SANDBOX_* env var > .env > error.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/env_resolve.sh"

# make_envfile DIR  --  a .env naming all three identity keys to the fixture dir
make_envfile() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/.env" <<EOF
PROJECT_NAME=envname
PROJECT_DIR=$dir/envproj
SANDBOX_DIR=$dir
EOF
}

test_resolve_explicit_wins_over_env_and_file() {
  local dir="$FIXTURE_DIR/explicit"; make_envfile "$dir"
  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_PROJECT_NAME=envvar \
        env_resolve_identity flagName /explicit "$dir" "$dir/.env" \
        && printf '%s|%s|%s' "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "flagName|/explicit|$dir" ]]; then
    pass "explicit flag value beats the AGENT_SANDBOX_* env var and .env"
  else
    fail "explicit-wins broken: rc=$RC out='$OUT'"
  fi
}

test_resolve_env_var_wins_over_file() {
  local dir="$FIXTURE_DIR/envvar"; make_envfile "$dir"
  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_PROJECT_NAME=fromenv \
        env_resolve_identity "" "" "$dir" "$dir/.env" \
        && printf '%s' "$PROJECT_NAME") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "fromenv" ]]; then
    pass "AGENT_SANDBOX_* env var beats .env"
  else
    fail "envvar-wins broken: rc=$RC out='$OUT'"
  fi
}

test_resolve_file_provides_value() {
  local dir="$FIXTURE_DIR/fileonly"; make_envfile "$dir"
  local OUT RC=0
  OUT=$(set -e; env_resolve_identity "" "" "$dir" "$dir/.env" \
        && printf '%s|%s' "$PROJECT_NAME" "$PROJECT_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname|$dir/envproj" ]]; then
    pass ".env provides the identity when no flag and no AGENT_SANDBOX_* var"
  else
    fail ".env-fallback broken: rc=$RC out='$OUT'"
  fi
}

test_resolve_missing_all_is_hard_error() {
  local OUT RC=0
  OUT=$(env_resolve_identity "" "" "" "$FIXTURE_DIR/absent.env" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"onboard"* && "$OUT" == *"PROJECT_NAME"* ]]; then
    pass "no value at any level is a hard error pointing at onboard"
  else
    fail "missing-all should error with onboard hint, rc=$RC out='$OUT'"
  fi
}

test_resolve_env_file_in_provided_sandbox_dir() {
  # Sandbox dir given (explicit); .env location derives from it, not the CWD.
  local dir="$FIXTURE_DIR/indir"; make_envfile "$dir"
  local OUT RC=0
  OUT=$(set -e; cd "$FIXTURE_DIR" && env_resolve_identity "" "" "$dir" \
        && printf '%s' "$PROJECT_NAME") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname" ]]; then
    pass ".env is located in the provided sandbox dir"
  else
    fail "provided-dir .env lookup broken: rc=$RC out='$OUT'"
  fi
}

test_resolve_env_file_cwd_fallback() {
  # No sandbox dir known -> the resolver falls back to the invocation CWD's .env.
  local dir="$FIXTURE_DIR/cwdfb"; make_envfile "$dir"
  local OUT RC=0
  OUT=$(set -e; cd "$dir" && env_resolve_identity "" "" "" \
        && printf '%s|%s|%s' "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname|$dir/envproj|$dir" ]]; then
    pass ".env is located in the invocation CWD when no sandbox dir is known"
  else
    fail "cwd .env fallback broken: rc=$RC out='$OUT'"
  fi
}

test_resolve_ignores_leaked_plain_export() {
  # A plain exported PROJECT_NAME (leaked by a sourced script) must NOT beat
  # .env: only the AGENT_SANDBOX_* keys are the env level.
  local dir="$FIXTURE_DIR/leak"; make_envfile "$dir"
  local OUT RC=0
  OUT=$(set -e; PROJECT_NAME=leaked \
        env_resolve_identity "" "" "$dir" "$dir/.env" \
        && printf '%s' "$PROJECT_NAME") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname" ]]; then
    pass "a leaked plain PROJECT_NAME export does not bypass .env"
  else
    fail "leak guard broken: rc=$RC out='$OUT'"
  fi
}

run_test test_resolve_explicit_wins_over_env_and_file
run_test test_resolve_env_var_wins_over_file
run_test test_resolve_file_provides_value
run_test test_resolve_missing_all_is_hard_error
run_test test_resolve_env_file_in_provided_sandbox_dir
run_test test_resolve_env_file_cwd_fallback
run_test test_resolve_ignores_leaked_plain_export

test_done test_env_resolve.sh