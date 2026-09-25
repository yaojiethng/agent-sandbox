#!/usr/bin/env bash
# tests/test_session_env.sh
# Unit tests for src/libs/session_env.sh  --  host-side session environment
# Pins cite: docs/architecture/tool_interface.md (naming, l.17);
#             devlog/discussions/20260730-design-settled-mount_model.md (delivery defaults).

# bootstrap (.env loading, git validation, name/branch derivation).
#
# Covers:
#   session_env_common_init  --  missing-.env failure, non-git and commit-less
#                             project rejection, HOST_UID/GID + ENV_FILE exports,
#                             and the explicit-identity-beats-.env precedence pin
#                             (flag-wins). The .env parse rules this loader calls
#                             are pinned in tests/test_env.sh, with the parser.
#   session_env_names        --  branch sanitisation, detached-HEAD fallback,
#                             deterministic image/container naming, delivery
#                             var defaults vs preserved overrides

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/session_env.sh"

# make_sandbox DIR  --  onboarding-minimal sandbox skeleton (only what the lib reads)
make_sandbox() {
  local DIR="$1"
  mkdir -p "$DIR"
}

# =============================================================================
# session_env_common_init  --  .env parsing
# =============================================================================

# Given: a sandbox dir with no .env, a committed project, and explicit name and dir args
# When:  session_env_common_init runs
# Then:  rc is non-zero and the message says ".env not found" and names the onboard command
# Asserts: the missing-.env failure points at the remedy (the two hint lines are redundant: either alone satisfies the unit)
test_env_missing_file_fails_with_onboard_hint() {
  local SBX="$FIXTURE_DIR/sbx_missing" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"

  local OUT RC=0
  OUT=$(session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *".env not found"* && "$OUT" == *"onboard"* ]]; then
    pass "missing .env fails with onboard guidance"
  else
    fail "expected onboard-hint failure, rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# session_env_common_init  --  validation + derived exports
# =============================================================================

# Given: a sandbox with a .env and a project dir that is not a git repository
# When:  session_env_common_init runs
# Then:  rc non-zero and the message says "not a git repository"
# Asserts: the .git-is-a-directory guard (bite V4 proven)
test_common_init_rejects_non_git_project() {
  local SBX="$FIXTURE_DIR/sbx_ng" PROJ="$FIXTURE_DIR/proj_nogit"
  make_sandbox "$SBX"; mkdir -p "$PROJ"
  printf 'A=1\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"not a git repository"* ]]; then
    pass "non-git PROJECT_DIR rejected with explicit error"
  else
    fail "non-git repo should fail, rc=$RC out='$OUT'"
  fi
}

# Given: a .env and an initialised repo with no commit
# When:  session_env_common_init runs
# Then:  rc non-zero and the message says "has no commits"
# Asserts: the rev-parse HEAD guard (bite V5 proven)
test_common_init_rejects_commitless_repo() {
  local SBX="$FIXTURE_DIR/sbx_nc" PROJ="$FIXTURE_DIR/proj_nocommit"
  make_sandbox "$SBX"; make_repo "$PROJ"
  printf 'A=1\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"has no commits"* ]]; then
    pass "commit-less PROJECT_DIR rejected with init guidance"
  else
    fail "commit-less repo should fail, rc=$RC out='$OUT'"
  fi
}

# Given: a .env holding DELIVERABLE_MODE=all
# When:  session_env_common_init runs with an explicit name
# Then:  PROJECT_NAME, PROJECT_DIR, ENV_FILE and HOST_UID/GID match the inputs and DELIVERABLE_MODE is loaded
# Asserts: the phase 1 export contract (bite V15: a hardcoded HOST_UID fails it)
test_common_init_exports_identity_and_paths() {
  local SBX="$FIXTURE_DIR/sbx_ok" PROJ="$FIXTURE_DIR/proj_exports"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf 'DELIVERABLE_MODE=all\n' > "$SBX/.env"

  if session_env_common_init myproj "$PROJ" "$SBX" >/dev/null 2>&1; then
    if [[ "$PROJECT_NAME" == "myproj" && "$PROJECT_DIR" == "$PROJ" \
       && "$ENV_FILE" == "$SBX/.env" && -n "${HOST_UID:-}" && -n "${HOST_GID:-}" \
       && "$HOST_UID" == "$(id -u)" && "$HOST_GID" == "$(id -g)" && "${DELIVERABLE_MODE:-}" == "all" ]]
    then
      pass "common_init exports PROJECT_*, ENV_FILE, HOST_UID/GID and .env vars"
    else
      fail "export contract incomplete: PN=$PROJECT_NAME PD=$PROJECT_DIR EF=$ENV_FILE UID=${HOST_UID:-unset} ENVV=${DELIVERABLE_MODE:-unset}"
    fi
  else
    fail "common_init failed on valid inputs"
  fi
}

# Given: a .env with PROJECT_NAME=envname and AGENT_SANDBOX_PROJECT_NAME=envvar
# When:  session_env_common_init runs with the explicit name explicitName
# Then:  PROJECT_NAME is explicitName
# Asserts: flag-wins at the name level (bite V1 proven)
test_env_project_name_explicit_arg_beats_env_and_envvar() {
  # PIN (S2 flip): the explicit name argument beats both a conflicting
  # PROJECT_NAME in .env and a conflicting AGENT_SANDBOX_PROJECT_NAME env var.
  local SBX="$FIXTURE_DIR/sbx_name_wins" PROJ="$FIXTURE_DIR/proj_name_wins"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  make_envfile "$SBX" envname "$PROJ" "$SBX"

  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_PROJECT_NAME=envvar \
        session_env_common_init explicitName "$PROJ" "$SBX" 2>&1 </dev/null \
        && printf '%s|' "${PROJECT_NAME:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "explicitName|" ]]; then
    pass "explicit name argument beats .env and AGENT_SANDBOX_PROJECT_NAME (flag-wins)"
  else
    fail "expected explicit name to win, rc=$RC out='$OUT'"
  fi
}

# Given: a .env whose PROJECT_DIR points at a second directory
# When:  session_env_common_init runs with an explicit project dir
# Then:  PROJECT_DIR is the explicit directory
# Asserts: flag-wins at the project dir level (bite V2 proven)
test_env_project_dir_explicit_arg_beats_env() {
  # PIN (S2 flip): the explicit directory argument beats a conflicting
  # PROJECT_DIR in .env, while git validation still reads the explicit repo arg.
  local SBX="$FIXTURE_DIR/sbx_dir_wins" PROJ="$FIXTURE_DIR/proj_dir_wins"
  local ENVDIR="$FIXTURE_DIR/env_dir_loser"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  make_envfile "$SBX" envname "$ENVDIR" "$SBX"

  local OUT RC=0
  OUT=$(set -e; session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null \
        && printf '%s|' "${PROJECT_DIR:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "$PROJ|" ]]; then
    pass "explicit directory argument beats a conflicting .env PROJECT_DIR (flag-wins)"
  else
    fail "expected explicit dir to win, rc=$RC out='$OUT'"
  fi
}

# Given: a .env that declares both identity keys
# When:  session_env_common_init runs with both explicit arguments
# Then:  both resolved values are the explicit ones
# Asserts: no .env can shadow both explicit arguments in one call (bites V1 and V2 both fail it)
test_env_identity_explicit_args_beat_env() {
  # PIN (S2 flip): a .env declaring BOTH identity keys cannot shadow BOTH
  # explicit arguments in one call.
  local SBX="$FIXTURE_DIR/sbx_id_wins" PROJ="$FIXTURE_DIR/proj_id_wins"
  local ENVDIR="$FIXTURE_DIR/env_id_loser"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  make_envfile "$SBX" envname "$ENVDIR" "$SBX"

  local OUT RC=0
  OUT=$(set -e; session_env_common_init explicitName "$PROJ" "$SBX" 2>&1 </dev/null \
        && printf '%s|%s' "${PROJECT_NAME:-unset}" "${PROJECT_DIR:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "explicitName|$PROJ" ]]; then
    pass "explicit name+dir both beat a conflicting .env identity (flag-wins)"
  else
    fail "expected explicit identity to win, rc=$RC out='$OUT'"
  fi
}

# Given: a sandbox with a .env, called with empty name and dir
# When:  session_env_common_init runs with only the sandbox dir
# Then:  PROJECT_NAME and PROJECT_DIR come from .env
# Asserts: the .env fallback level of the resolver
test_env_resolves_identity_from_env_when_args_empty() {
  # SANDBOX given, no name/dir args: the resolver falls to .env for them.
  local SBX="$FIXTURE_DIR/sbx_env_fb" PROJ="$FIXTURE_DIR/proj_env_fb"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  make_envfile "$SBX" envname "$PROJ" "$SBX"

  local OUT RC=0
  OUT=$(set -e; session_env_common_init "" "" "$SBX" 2>&1 </dev/null \
        && printf '%s|%s' "${PROJECT_NAME:-unset}" "${PROJECT_DIR:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "envname|$PROJ" ]]; then
    pass "empty name/dir args resolve from .env in the sandbox dir"
  else
    fail ".env fallback broken, rc=$RC out='$OUT'"
  fi
}

# Given: a .env plus AGENT_SANDBOX_PROJECT_NAME, called with empty name and dir
# When:  session_env_common_init runs
# Then:  PROJECT_NAME is the env-var value
# Asserts: the AGENT_SANDBOX_* level beats .env
test_env_ag_sandbox_envvar_beats_env() {
  # No explicit name; AGENT_SANDBOX_PROJECT_NAME beats the .env value.
  local SBX="$FIXTURE_DIR/sbx_envvar" PROJ="$FIXTURE_DIR/proj_envvar"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  make_envfile "$SBX" envname "$PROJ" "$SBX"

  local OUT RC=0
  OUT=$(set -e; AGENT_SANDBOX_PROJECT_NAME=envvar \
        session_env_common_init "" "" "$SBX" 2>&1 </dev/null \
        && printf '%s|' "${PROJECT_NAME:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "envvar|" ]]; then
    pass "AGENT_SANDBOX_PROJECT_NAME beats .env when no explicit name"
  else
    fail "envvar level broken, rc=$RC out='$OUT'"
  fi
}

# Given: ENV_REL is an absolute path to custom.env
# When:  session_env_common_init runs with empty name and dir
# Then:  identity resolves from that file and ENV_FILE is that absolute path
# Asserts: env_resolve's absolute default_env_file contract, exercised through this loader
test_env_resolves_with_absolute_env_pointer() {
  # An absolute --env pointer (the Makefile's $(CURDIR)/.env) is honored for
  # both identity resolution and the run's env load when name/dir are omitted.
  local SBX="$FIXTURE_DIR/sbx_abs" PROJ="$FIXTURE_DIR/proj_abs"
  local ENVDIR="$FIXTURE_DIR/env_abs_dir"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  mkdir -p "$ENVDIR"
  make_envfile "$ENVDIR" envname "$PROJ" "$SBX"
  mv "$ENVDIR/.env" "$ENVDIR/custom.env"

  local OUT RC=0
  OUT=$(set -e; ENV_REL="$ENVDIR/custom.env" \
        session_env_common_init "" "" "$SBX" 2>&1 </dev/null \
        && printf '%s|%s' "${PROJECT_NAME:-unset}" "${ENV_FILE:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "envname|$ENVDIR/custom.env" ]]; then
    pass "absolute --env pointer resolves identity and loads the named file"
  else
    fail "absolute --env broken, rc=$RC out='$OUT'"
  fi
}

# Given: ENV_REL is a bare file name and <sandbox>/custom.env exists
# When:  session_env_common_init runs with empty name and dir
# Then:  identity resolves and ENV_FILE is <sandbox>/custom.env
# Asserts: the sandbox-relative env pointer contract
test_env_resolves_with_relative_env_pointer() {
  # A relative --env name is sandbox-relative for both resolution and load.
  local SBX="$FIXTURE_DIR/sbx_rel" PROJ="$FIXTURE_DIR/proj_rel"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  make_envfile "$SBX" envname "$PROJ" "$SBX"
  mv "$SBX/.env" "$SBX/custom.env"

  local OUT RC=0
  OUT=$(set -e; ENV_REL=custom.env \
        session_env_common_init "" "" "$SBX" 2>&1 </dev/null \
        && printf '%s|%s' "${PROJECT_NAME:-unset}" "${ENV_FILE:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "envname|$SBX/custom.env" ]]; then
    pass "relative --env name resolves identity and loads <sandbox>/<name>"
  else
    fail "relative --env broken, rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# session_env_names
# =============================================================================

setup_named_project() {
  # Returns via globals: NAMED_PROJ (git repo with feature branch checked out)
  NAMED_PROJ="$FIXTURE_DIR/named_proj"
  make_committed_repo "$NAMED_PROJ"
  git -C "$NAMED_PROJ" checkout --quiet -b "feature/42-fix_bug"
}

# Given: a project on branch feature/42-fix_bug with PROJECT_DIR set
# When:  session_env_names runs
# Then:  SANITIZED_HOST_BRANCH is feature-42-fix_bug
# Asserts: the sanitisation character class (bite V7 proven)
test_names_sanitises_host_branch() {
  setup_named_project
  PROJECT_DIR="$NAMED_PROJ"

  session_env_names myproj pi "$FIXTURE_DIR/sbx_names" sess-abc >/dev/null 2>&1

  if [[ "${SANITIZED_HOST_BRANCH:-}" == "feature-42-fix_bug" ]]; then
    pass "host branch sanitised: only [A-Za-z0-9._-] survive, rest -> '-'"
  else
    fail "branch sanitisation wrong: '${SANITIZED_HOST_BRANCH:-unset}'"
  fi
}

# Given: a project with a detached HEAD
# When:  session_env_names runs
# Then:  SANITIZED_HOST_BRANCH is the short SHA
# Asserts: the detached-HEAD fallback (bite V6 proven)
test_names_detached_head_falls_back_to_short_sha() {
  setup_named_project
  PROJECT_DIR="$NAMED_PROJ"
  git -C "$NAMED_PROJ" checkout --quiet --detach HEAD

  session_env_names myproj pi "$FIXTURE_DIR/sbx_det" sess-abc >/dev/null 2>&1

  local SHORT
  SHORT="$(git -C "$NAMED_PROJ" rev-parse --short HEAD)"
  if [[ "${SANITIZED_HOST_BRANCH:-}" == "$SHORT" && "$SHORT" =~ ^[0-9a-f]{7,}$ ]]; then
    pass "detached HEAD falls back to short SHA as host branch"
  else
    fail "detached-HEAD fallback broken: '${SANITIZED_HOST_BRANCH:-unset}' vs '$SHORT'"
  fi
}

# Given: mixed-case project and provider names plus a session id
# When:  session_env_names runs
# Then:  the container names embed the raw case and the image names embed the lowercased project
# Asserts: name derivation from the four inputs (bites V8 and V18 proven); the sandbox image name is asserted by substring only
test_names_deterministic_container_and_image_names() {
  setup_named_project
  PROJECT_DIR="$NAMED_PROJ"

  session_env_names MyProj PI "$FIXTURE_DIR/sbx_names2" 20260821-120000-abcdef >/dev/null 2>&1

  if [[ "${SANDBOX_CONTAINER_NAME:-}" == "sandbox-MyProj-20260821-120000-abcdef" \
     && "${AGENT_CONTAINER_NAME:-}" == "PI-MyProj-20260821-120000-abcdef" \
     && "${SANDBOX_IMAGE_NAME:-}" == *myproj* && "${AGENT_IMAGE_NAME:-}" == "PI-agent-myproj" ]]
  then
    pass "container/image names derive deterministically from inputs (project lowercased in images)"
  else
    fail "name derivation wrong: SBX='${SANDBOX_CONTAINER_NAME:-}' AGT='${AGENT_CONTAINER_NAME:-}' IMG='${SANDBOX_IMAGE_NAME:-}' AIMG='${AGENT_IMAGE_NAME:-}'"
  fi
}

# Given: WORKTREE_DIR unset, then WORKTREE_DIR=/custom/wt, with SANDBOX_TYPE unset
# When:  session_env_names runs twice
# Then:  the default is <sandbox>/.worktree, the override wins, and SANDBOX_TYPE stays unset
# Asserts: the default-with-override read of a global, and that delivery is not this function's business (bite V9 proven)
test_names_worktree_var_defaults_and_overrides() {
  setup_named_project
  PROJECT_DIR="$NAMED_PROJ"
  unset SANDBOX_TYPE WORKTREE_DIR

  session_env_names myproj pi "$FIXTURE_DIR/sbx_def" s1 >/dev/null 2>&1
  local DEF_WT="${WORKTREE_DIR:-}"

  unset SANDBOX_TYPE WORKTREE_DIR
  WORKTREE_DIR=/custom/wt \
    session_env_names myproj pi "$FIXTURE_DIR/sbx_def" s2 >/dev/null 2>&1

  # Delivery (SANDBOX_TYPE) is NOT session_env_names' business: it is a
  # command input owned by start_agent (parsed) / resume_agent (record).
  # The lib must leave it untouched.
  if [[ "$DEF_WT" == "$FIXTURE_DIR/sbx_def/.worktree" \
     && "${WORKTREE_DIR:-}" == "/custom/wt" \
     && -z "${SANDBOX_TYPE:-}" ]]
  then
    pass "worktree var defaults (<sandbox>/.worktree), respects overrides, delivery untouched"
  else
    fail "worktree defaults/overrides broken: DEF=$DEF_WT OVR=${WORKTREE_DIR:-} TYPE=${SANDBOX_TYPE:-}"
  fi
  unset SANDBOX_TYPE WORKTREE_DIR
}

# =============================================================================
# Run all
# =============================================================================

run_test test_env_missing_file_fails_with_onboard_hint
run_test test_common_init_rejects_non_git_project
run_test test_common_init_rejects_commitless_repo
run_test test_common_init_exports_identity_and_paths
run_test test_env_project_name_explicit_arg_beats_env_and_envvar
run_test test_env_project_dir_explicit_arg_beats_env
run_test test_env_identity_explicit_args_beat_env
run_test test_env_resolves_identity_from_env_when_args_empty
run_test test_env_ag_sandbox_envvar_beats_env
run_test test_env_resolves_with_absolute_env_pointer
run_test test_env_resolves_with_relative_env_pointer
run_test test_names_sanitises_host_branch
run_test test_names_detached_head_falls_back_to_short_sha
run_test test_names_deterministic_container_and_image_names
run_test test_names_worktree_var_defaults_and_overrides

test_done test_session_env.sh
