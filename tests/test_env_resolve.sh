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


# Given: a fixture .env, an explicit name flagName and dir /explicit, and AGENT_SANDBOX_PROJECT_NAME=envvar
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=flagName, PROJECT_DIR=/explicit, SANDBOX_DIR=<dir>
# Asserts: the explicit level beats both the AGENT_SANDBOX_* env var and .env.
test_resolve_explicit_wins_over_env_and_file() {
  local dir="$FIXTURE_DIR/explicit"; make_envfile "$dir" envname "$dir/envproj" "$dir"
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

# Given: a fixture .env and AGENT_SANDBOX_PROJECT_NAME=fromenv
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=fromenv
# Asserts: the AGENT_SANDBOX_* env var beats .env.
test_resolve_env_var_wins_over_file() {
  local dir="$FIXTURE_DIR/envvar"; make_envfile "$dir" envname "$dir/envproj" "$dir"
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

# Given: a fixture .env only
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=envname and PROJECT_DIR=<dir>/envproj
# Asserts: .env supplies the identity when no flag and no AGENT_SANDBOX_* var.
test_resolve_file_provides_value() {
  local dir="$FIXTURE_DIR/fileonly"; make_envfile "$dir" envname "$dir/envproj" "$dir"
  local OUT RC=0
  OUT=$(set -e; env_resolve_identity "" "" "$dir" "$dir/.env" \
        && printf '%s|%s' "$PROJECT_NAME" "$PROJECT_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname|$dir/envproj" ]]; then
    pass ".env provides the identity when no flag and no AGENT_SANDBOX_* var"
  else
    fail ".env-fallback broken: rc=$RC out='$OUT'"
  fi
}

# Given: no value at any level and an absent .env
# When:  env_resolve_identity runs
# Then:  rc is non-zero and stderr names "not set" and "onboard"
# Asserts: a missing value at every level is a hard error with the onboard remedy.
test_resolve_missing_all_is_hard_error() {
  local OUT RC=0
  OUT=$(env_resolve_identity "" "" "" "$FIXTURE_DIR/absent.env" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"onboard"* && "$OUT" == *"not set"* ]]; then
    pass "no value at any level is a hard error pointing at onboard"
  else
    fail "missing-all should error with onboard hint, rc=$RC out='$OUT'"
  fi
}

# Given: an explicit sandbox dir and the CWD moved elsewhere
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=envname from that dir's .env
# Asserts: the .env location derives from the provided sandbox dir, not the CWD.
test_resolve_env_file_in_provided_sandbox_dir() {
  # Sandbox dir given (explicit); .env location derives from it, not the CWD.
  local dir="$FIXTURE_DIR/indir"; make_envfile "$dir" envname "$dir/envproj" "$dir"
  local OUT RC=0
  OUT=$(set -e; cd "$FIXTURE_DIR" && env_resolve_identity "" "" "$dir" \
        && printf '%s' "$PROJECT_NAME") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname" ]]; then
    pass ".env is located in the provided sandbox dir"
  else
    fail "provided-dir .env lookup broken: rc=$RC out='$OUT'"
  fi
}

# Given: no sandbox dir and the CWD holding a .env
# When:  env_resolve_identity runs
# Then:  all three fields come from the CWD .env
# Asserts: with no sandbox known, the .env comes from the invocation CWD.
test_resolve_env_file_cwd_fallback() {
  # No sandbox dir known -> the resolver falls back to the invocation CWD's .env.
  local dir="$FIXTURE_DIR/cwdfb"; make_envfile "$dir" envname "$dir/envproj" "$dir"
  local OUT RC=0
  OUT=$(set -e; cd "$dir" && env_resolve_identity "" "" "" \
        && printf '%s|%s|%s' "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname|$dir/envproj|$dir" ]]; then
    pass ".env is located in the invocation CWD when no sandbox dir is known"
  else
    fail "cwd .env fallback broken: rc=$RC out='$OUT'"
  fi
}

# Given: a plain exported PROJECT_NAME=leaked, a fixture .env, and an explicit sandbox dir
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=envname
# Asserts: only the AGENT_SANDBOX_* keys form the env level; a leaked plain name does not bypass .env.
test_resolve_ignores_leaked_plain_export() {
  # A plain exported PROJECT_NAME (leaked by a sourced script) must NOT beat
  # .env: only the AGENT_SANDBOX_* keys are the env level.
  local dir="$FIXTURE_DIR/leak"; make_envfile "$dir" envname "$dir/envproj" "$dir"
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