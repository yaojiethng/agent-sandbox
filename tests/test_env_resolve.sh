#!/usr/bin/env bash
# tests/test_env_resolve.sh
# Unit tests for src/libs/env_resolve.sh  --  the centralized precedence
# resolver for the sandbox identity triple.
#
# Precedence under test: explicit flag > .env > error. A record key has no
# environment level: AGENT_SANDBOX_<KEY> is not read for any key the record
# holds, because the record is read and never exported.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/env_resolve.sh"


# Given: a fixture .env, an explicit name flagName and dir /explicit, and AGENT_SANDBOX_PROJECT_NAME=envvar
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=flagName, PROJECT_DIR=/explicit, SANDBOX_DIR=<dir>
# Asserts: the explicit level beats both the .env.
test_resolve_explicit_wins_over_env_and_file() {
  local dir="$FIXTURE_DIR/explicit"; make_envfile "$dir" envname "$dir/envproj" "$dir"
  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_PROJECT_NAME=envvar \
        env_resolve_identity flagName /explicit "$dir" "$dir/.env" \
        && printf '%s|%s|%s' "$PROJECT_NAME" "$PROJECT_DIR" "$SANDBOX_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "flagName|/explicit|$dir" ]]; then
    pass "explicit flag value beats the .env"
  else
    fail "explicit-wins broken: rc=$RC out='$OUT'"
  fi
}

# Given: a fixture .env and AGENT_SANDBOX_PROJECT_NAME=fromenv
# When:  env_resolve_identity runs
# Then:  PROJECT_NAME=envname, the record's value
# Asserts: AGENT_SANDBOX_* is not a level for a key the record holds.
test_resolve_env_var_is_not_a_level() {
  local dir="$FIXTURE_DIR/envvar"; make_envfile "$dir" envname "$dir/envproj" "$dir"
  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_PROJECT_NAME=fromenv \
        env_resolve_identity "" "" "$dir" "$dir/.env" \
        && printf '%s' "$PROJECT_NAME") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "envname" ]]; then
    pass "AGENT_SANDBOX_* is not a level for a record key"
  else
    fail "env level still read: rc=$RC out='$OUT'"
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

# Given: a fixture .env whose SANDBOX_DIR differs from AGENT_SANDBOX_SANDBOX_DIR
# When:  env_resolve_identity resolves only the sandbox field
# Then:  SANDBOX_DIR holds the record's value
# Asserts: AGENT_SANDBOX_SANDBOX_DIR is not a level for the sandbox field.
test_resolve_sandbox_env_var_is_not_a_level() {
  local dir="$FIXTURE_DIR/sandboxenv"
  make_envfile "$dir" envname "$dir/envproj" "$dir/fromfile"
  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_SANDBOX_DIR="$dir/fromenv" \
        env_resolve_identity "" "" "" "$dir/.env" sandbox \
        && printf '%s' "$SANDBOX_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "$dir/fromfile" ]]; then
    pass "AGENT_SANDBOX_SANDBOX_DIR is not a level for the sandbox field"
  else
    fail "sandbox env level still read: rc=$RC out='$OUT'"
  fi
}

# Given: a key with no value at any level, and a caller that supplies a remedy
# When:  env_resolve_one runs with and without the remedy argument
# Then:  the default is the generic set-this-key line, the given one is printed
# Asserts: the remedy is the caller's, not the primitive's. The primitive cannot
#          know which command owns a setting, so it must not name one.
test_resolve_one_remedy_is_the_callers() {
  local dir="$FIXTURE_DIR/remedy" OUT RC=0
  mkdir -p "$dir"
  unset AGENT_SANDBOX_SANDBOX_DIR
  OUT=$(env_resolve_one SANDBOX_DIR "$dir/.env" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"Set SANDBOX_DIR in"* && "$OUT" != *"onboard"* ]]; then
    pass "no remedy argument prints the generic set-this-key line"
  else
    fail "generic remedy broken: rc=$RC out='$OUT'"
  fi
  RC=0
  OUT=$(env_resolve_one INSTALL_DIR "$dir/.env" "Run: install.sh --help" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"Run: install.sh --help"* && "$OUT" != *"onboard"* ]]; then
    pass "a caller's remedy replaces the default, so no onboard advice leaks"
  else
    fail "caller remedy broken: rc=$RC out='$OUT'"
  fi
}

# Given: an explicit identity, an explicit sandbox dir, and no .env there
# When:  env_resolve_identity runs with no env-ref
# Then:  it resolves, and never claims a specified path
# Asserts: the default .env is a default. It was reported as a specified path
#          when a caller passed its own default in as the value.
test_resolve_default_env_absent_is_not_specified() {
  local dir="$FIXTURE_DIR/default_absent" OUT RC=0
  mkdir -p "$dir"
  OUT=$(set -e; env_resolve_identity p "$dir/proj" "$dir" \
        && printf '%s|%s' "$PROJECT_NAME" "$PROJECT_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "p|$dir/proj" ]]; then
    pass "an absent default .env does not block a resolved identity"
  else
    fail "default-absent broken: rc=$RC out='$OUT'"
  fi
}

# Given: a sandbox dir and an explicitly named .env that does not exist
# When:  env_resolve_identity runs
# Then:  it fails naming the specified path, not a missing key
# Asserts: the paired negative -- a path the caller named is still a
#          specification, and its absence is reported as one.
test_resolve_specified_env_absent_names_the_path() {
  local dir="$FIXTURE_DIR/specified_absent" OUT RC=0
  mkdir -p "$dir"
  OUT=$(env_resolve_identity "" "" "$dir" "$dir/absent.env" 2>&1) || RC=$?
  if [[ $RC -ne 0 && "$OUT" == *"A specified --env path must exist"* ]]; then
    pass "a specified --env that is absent names the path"
  else
    fail "specified-absent broken: rc=$RC out='$OUT'"
  fi
}

# Given: a relative sandbox dir, a relative --env name, and the CWD at the
#        sandbox's parent
# When:  default_env_file resolves the path
# Then:  the path is absolute
# Asserts: the path a leaf receives names the same file, not a CWD-relative
#          spelling of it.
test_default_env_file_returns_an_absolute_path() {
  local base="$FIXTURE_DIR/absolute" out
  mkdir -p "$base/sbx"
  out=$(cd "$base" && default_env_file "session.env" "sbx")
  assert_eq "$base/sbx/session.env" "$out" "a relative env under a relative sandbox is absolute"

  out=$(cd "$base" && default_env_file "" "")
  assert_eq "$base/.env" "$out" "the CWD fallback is absolute"

  out=$(default_env_file "$base/records/session.env" "")
  assert_eq "$base/records/session.env" "$out" "an absolute input stays absolute"
}

# Given: a relative sandbox dir holding the identity record
# When:  env_resolve_identity resolves the triple
# Then:  ENV_FILE is the absolute path of that record
# Asserts: resolution exports the normalized path, so the dispatcher can hand a
#          process the file the resolver read.
test_resolve_exports_an_absolute_env_file() {
  local base="$FIXTURE_DIR/resolve_absolute" out
  mkdir -p "$base/sbx" "$base/proj"
  printf 'PROJECT_NAME=probe\nPROJECT_DIR=%s/proj\nSANDBOX_DIR=%s/sbx\n' "$base" "$base" > "$base/sbx/session.env"
  out=$(cd "$base" && set -e; env_resolve_identity "" "" "sbx" "session.env" name project sandbox >/dev/null && printf '%s' "$ENV_FILE") || out="FAILED"
  assert_eq "$base/sbx/session.env" "$out" "the resolver exports an absolute ENV_FILE"
}

# Given: a caller's ENV_REL pointing at another record, and an explicit empty
#        fourth argument
# When:  env_resolve_identity resolves the name
# Then:  it reads the sandbox's own record, not the caller's ENV_REL
# Asserts: an explicit empty env ref is authoritative; the global fallback is
#          only for an omitted argument.
test_explicit_empty_env_ref_does_not_fall_back() {
  local dir="$FIXTURE_DIR/explicit_empty" other="$FIXTURE_DIR/explicit_other" out
  make_envfile "$dir" envname "$dir/envproj" "$dir"
  make_envfile "$other" othername "$other/envproj" "$other"
  out=$(set -e; ENV_REL="$other/.env" env_resolve_identity "" "" "$dir" "" name \
    && printf '%s' "$PROJECT_NAME") || out="FAILED"
  assert_eq "envname" "$out" "an explicit empty ref does not fall back to ENV_REL"
}

# Given: a CWD record that names the sandbox, and a relative --env under it
# When:  env_resolve_identity runs with no explicit sandbox
# Then:  it bootstraps SANDBOX_DIR from the CWD record and opens that record
# Asserts: a relative --env with no sandbox is still resolvable, and the path
#          it opens is the one under the bootstrapped sandbox.
test_relative_env_without_sandbox_bootstraps_from_cwd() {
  local dir="$FIXTURE_DIR/bootstrap" out
  mkdir -p "$dir"
  printf 'PROJECT_NAME=cwdprobe\nPROJECT_DIR=%s/proj\nSANDBOX_DIR=%s\n' "$dir" "$dir" > "$dir/.env"
  printf 'PROJECT_NAME=envprobe\nPROJECT_DIR=%s/proj\nSANDBOX_DIR=%s\n' "$dir" "$dir" > "$dir/session.env"
  out=$(set -e; cd "$dir" && env_resolve_identity "" "" "" "session.env" name project sandbox \
    && printf '%s|%s' "$PROJECT_NAME" "$ENV_FILE") || out="FAILED"
  assert_eq "envprobe|$dir/session.env" "$out" \
    "a relative --env bootstraps the sandbox from the CWD record"
}

# Given: a fixture .env and only the project selector
# When:  env_resolve_identity resolves that field
# Then:  PROJECT_DIR is the record's value
# Asserts: `project` is the resolver's selector for the project path.
test_resolve_project_is_the_selector() {
  local dir="$FIXTURE_DIR/project_selector" OUT RC=0
  make_envfile "$dir" envname "$dir/envproj" "$dir"
  OUT=$(set -e; env_resolve_identity "" "" "$dir" "$dir/.env" project \
        && printf '%s' "$PROJECT_DIR") || RC=$?
  if [[ $RC -eq 0 && "$OUT" == "$dir/envproj" ]]; then
    pass "project is the resolver selector for PROJECT_DIR"
  else
    fail "project selector broken: rc=$RC out='$OUT'"
  fi
}

# Given: a fixture .env and only the retired dir selector
# When:  env_resolve_identity resolves that field
# Then:  PROJECT_DIR stays empty
# Asserts: `dir` is no longer a resolver selector; the rename is not an alias.
test_resolve_dir_is_not_a_selector() {
  local dir="$FIXTURE_DIR/dir_selector" OUT RC=0
  make_envfile "$dir" envname "$dir/envproj" "$dir"
  OUT=$(set -e; unset PROJECT_DIR; env_resolve_identity "" "" "$dir" "$dir/.env" dir \
        && printf '%s' "${PROJECT_DIR:-}") || RC=$?
  if [[ $RC -eq 0 && -z "$OUT" ]]; then
    pass "dir is no longer a resolver selector"
  else
    fail "dir selector still resolves PROJECT_DIR: rc=$RC out='$OUT'"
  fi
}

run_test test_relative_env_without_sandbox_bootstraps_from_cwd
run_test test_default_env_file_returns_an_absolute_path
run_test test_resolve_exports_an_absolute_env_file
run_test test_explicit_empty_env_ref_does_not_fall_back
run_test test_resolve_explicit_wins_over_env_and_file
run_test test_resolve_env_var_is_not_a_level
run_test test_resolve_file_provides_value
run_test test_resolve_missing_all_is_hard_error
run_test test_resolve_env_file_in_provided_sandbox_dir
run_test test_resolve_env_file_cwd_fallback
run_test test_resolve_ignores_leaked_plain_export
run_test test_resolve_sandbox_env_var_is_not_a_level
run_test test_resolve_project_is_the_selector
run_test test_resolve_dir_is_not_a_selector
run_test test_resolve_one_remedy_is_the_callers
run_test test_resolve_default_env_absent_is_not_specified
run_test test_resolve_specified_env_absent_names_the_path

test_done test_env_resolve.sh