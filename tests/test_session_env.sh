#!/usr/bin/env bash
# tests/test_session_env.sh
# Unit tests for src/libs/session_env.sh — host-side session environment
# bootstrap (.env loading, git validation, name/branch derivation).
#
# Covers:
#   session_env_common_init — .env parse rules (comments, blanks, CR/LF/TAB in
#                             keys, space-trimmed values), missing-.env failure,
#                             non-git and commit-less project rejection,
#                             HOST_UID/GID + ENV_FILE exports
#   session_env_names       — branch sanitisation, detached-HEAD fallback,
#                             deterministic image/container naming, delivery
#                             var defaults vs preserved overrides

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/session_env.sh"

# make_sandbox DIR — onboarding-minimal sandbox skeleton (only what the lib reads)
make_sandbox() {
  local DIR="$1"
  mkdir -p "$DIR"
}

# =============================================================================
# session_env_common_init — .env parsing
# =============================================================================

test_env_missing_file_fails_with_onboard_hint() {
  local SBX="$FIXTURE_DIR/sbx_missing" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"

  local OUT RC=0
  OUT=$(session_env_common_init "$SBX" proj "$PROJ" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *".env not found"* && "$OUT" == *"onboard"* ]]; then
    pass "missing .env fails with onboard guidance"
  else
    fail "expected onboard-hint failure, rc=$RC out='$OUT'"
  fi
}

test_env_comments_and_blanks_skipped() {
  local SBX="$FIXTURE_DIR/sbx_cmt" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf '# a comment\n\n   \nFOO=bar\n\t# tab-comment\n' > "$SBX/.env"

  session_env_common_init "$SBX" proj "$PROJ" >/dev/null 2>&1

  if [[ "${FOO:-}" == "bar" && -z "${a:-}" ]]; then
    pass ".env parser skips comments and blank lines"
  else
    fail "comment/blank parsing broken: FOO='${FOO:-}' a='${a:-}'"
  fi
}

test_env_key_whitespace_stripped_value_trimmed() {
  # KEY with trailing TAB + CRLF line ending; VALUE padded with spaces.
  local SBX="$FIXTURE_DIR/sbx_ws" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf 'MYKEY\t\r=  padded value  \r\n' > "$SBX/.env"

  session_env_common_init "$SBX" proj "$PROJ" >/dev/null 2>&1

  if [[ "${MYKEY:-}" == "padded value" ]]; then
    pass ".env parser strips key whitespace/CRLF and trims value padding"
  else
    fail "whitespace handling broken: MYKEY='[${MYKEY:-}]'"
  fi
}

test_env_inline_comment_is_kept_as_value() {
  # PINNED behavior: there is no inline-comment rule. `K=v # c` keeps the
  # whole tail as the value (trimmed). Documented so nobody assumes otherwise.
  local SBX="$FIXTURE_DIR/sbx_inline" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf 'K=val # not-a-comment\n' > "$SBX/.env"

  session_env_common_init "$SBX" proj "$PROJ" >/dev/null 2>&1

  if [[ "${K:-}" == "val # not-a-comment" ]]; then
    pass ".env parser keeps inline text after value (no inline comments) — pinned"
  else
    fail "inline handling changed: K='[${K:-}]' — update this pin if intentional"
  fi
}

# =============================================================================
# session_env_common_init — validation + derived exports
# =============================================================================

test_common_init_rejects_non_git_project() {
  local SBX="$FIXTURE_DIR/sbx_ng" PROJ="$FIXTURE_DIR/proj_nogit"
  make_sandbox "$SBX"; mkdir -p "$PROJ"
  printf 'A=1\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(session_env_common_init "$SBX" proj "$PROJ" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"not a git repository"* ]]; then
    pass "non-git PROJECT_DIR rejected with explicit error"
  else
    fail "non-git repo should fail, rc=$RC out='$OUT'"
  fi
}

test_common_init_rejects_commitless_repo() {
  local SBX="$FIXTURE_DIR/sbx_nc" PROJ="$FIXTURE_DIR/proj_nocommit"
  make_sandbox "$SBX"; make_repo "$PROJ"
  printf 'A=1\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(session_env_common_init "$SBX" proj "$PROJ" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"has no commits"* ]]; then
    pass "commit-less PROJECT_DIR rejected with init guidance"
  else
    fail "commit-less repo should fail, rc=$RC out='$OUT'"
  fi
}

test_common_init_exports_identity_and_paths() {
  local SBX="$FIXTURE_DIR/sbx_ok" PROJ="$FIXTURE_DIR/proj_exports"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf 'DELIVERABLE_MODE=all\n' > "$SBX/.env"

  if session_env_common_init "$SBX" myproj "$PROJ" >/dev/null 2>&1; then
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

# =============================================================================
# session_env_names
# =============================================================================

setup_named_project() {
  # Returns via globals: NAMED_PROJ (git repo with feature branch checked out)
  NAMED_PROJ="$FIXTURE_DIR/named_proj"
  make_committed_repo "$NAMED_PROJ"
  git -C "$NAMED_PROJ" checkout --quiet -b "feature/42-fix_bug"
}

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

test_names_delivery_var_defaults_and_overrides() {
  setup_named_project
  PROJECT_DIR="$NAMED_PROJ"
  unset SANDBOX_TYPE WORKTREE_DIR

  session_env_names myproj pi "$FIXTURE_DIR/sbx_def" s1 >/dev/null 2>&1
  local DEF_TYPE="${SANDBOX_TYPE:-}" DEF_WT="${WORKTREE_DIR:-}"

  unset SANDBOX_TYPE WORKTREE_DIR
  SANDBOX_TYPE=hardlink WORKTREE_DIR=/custom/wt \
    session_env_names myproj pi "$FIXTURE_DIR/sbx_def" s2 >/dev/null 2>&1

  if [[ "$DEF_TYPE" == "copy" && "$DEF_WT" == "$FIXTURE_DIR/sbx_def/.worktree" \
     && "${SANDBOX_TYPE:-}" == "hardlink" && "${WORKTREE_DIR:-}" == "/custom/wt" ]]
  then
    pass "delivery vars default (copy, <sandbox>/.worktree) but respect preset overrides"
  else
    fail "delivery defaults/overrides broken: DEF=$DEF_TYPE/$DEF_WT OVR=${SANDBOX_TYPE:-}/${WORKTREE_DIR:-}"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_env_missing_file_fails_with_onboard_hint
run_test test_env_comments_and_blanks_skipped
run_test test_env_key_whitespace_stripped_value_trimmed
run_test test_env_inline_comment_is_kept_as_value
run_test test_common_init_rejects_non_git_project
run_test test_common_init_rejects_commitless_repo
run_test test_common_init_exports_identity_and_paths
run_test test_names_sanitises_host_branch
run_test test_names_detached_head_falls_back_to_short_sha
run_test test_names_deterministic_container_and_image_names
run_test test_names_delivery_var_defaults_and_overrides

test_done test_session_env.sh
