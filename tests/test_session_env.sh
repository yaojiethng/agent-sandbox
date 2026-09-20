#!/usr/bin/env bash
# tests/test_session_env.sh
# Unit tests for src/libs/session_env.sh  --  host-side session environment
# Pins cite: docs/architecture/tool_interface.md (naming, l.17);
#             devlog/discussions/20260730-design-settled-mount_model.md (delivery defaults).

# bootstrap (.env loading, git validation, name/branch derivation).
#
# Covers:
#   session_env_common_init  --  .env parse rules (comments, blanks, CR/LF/TAB in
#                             keys, space-trimmed values, whitespace-only-key and
#                             invalid-identifier lines skipped), missing-.env
#                             failure, non-git and commit-less project rejection,
#                             HOST_UID/GID + ENV_FILE exports, and the
#                             explicit-identity-beats-.env precedence pin (flag-wins)
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

test_env_comments_and_blanks_skipped() {
  local SBX="$FIXTURE_DIR/sbx_cmt" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf '# a comment\n\n   \nFOO=bar\n\t# tab-comment\n' > "$SBX/.env"

  session_env_common_init proj "$PROJ" "$SBX" >/dev/null 2>&1

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

  session_env_common_init proj "$PROJ" "$SBX" >/dev/null 2>&1

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

  session_env_common_init proj "$PROJ" "$SBX" >/dev/null 2>&1

  if [[ "${K:-}" == "val # not-a-comment" ]]; then
    pass ".env parser keeps inline text after value (no inline comments)  --  pinned"
  else
    fail "inline handling changed: K='[${K:-}]'  --  update this pin if intentional"
  fi
}

test_env_whitespace_only_key_line_skipped() {
  # REGRESSION: a line of the form ` = ` (whitespace before '=', empty value)
  # reached `export "="` and aborted the caller under errexit with
  # `export: '=': not a valid identifier`. The same failure hits lines with no
  # '=' at all: pure-whitespace lines and CRLF blank lines (a bare CR) -- the
  # latter is how a CRLF .env crashes on its first blank line. All must be
  # skipped as blanks.
  local SBX="$FIXTURE_DIR/sbx_eq" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf 'FOO=bar\n = \n  =baz\n  \n\t\r\nMYKEY=ok\r\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(set -e; session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null \
        && printf '%s|%s|%s|' "${FOO:-unset}" "${baz:-unset}" "${MYKEY:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "bar|unset|ok|" ]]; then
    pass ".env parser skips whitespace-only-key lines without error"
  else
    fail "whitespace-only-key line broke parsing: rc=$RC out='$OUT'"
  fi
}

test_env_indented_comment_skipped() {
  # REGRESSION: a comment with leading whitespace passed the raw-key guard and
  # hit `export` with a comment-derived name (not a valid identifier). It must
  # scan as a comment once the key is trimmed.
  local SBX="$FIXTURE_DIR/sbx_lc" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf '  # indented comment\nFOO=bar\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(set -e; session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null \
        && printf '%s|' "${FOO:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == "bar|" ]]; then
    pass ".env parser skips indented comment lines"
  else
    fail "indented comment broke parsing: rc=$RC out='$OUT'"
  fi
}

test_env_invalid_identifier_key_skipped_with_warning() {
  # A non-identifier key (digit prefix, dash, and so on) can never be exported.
  # The parser must skip it with a warning instead of failing the call.
  local SBX="$FIXTURE_DIR/sbx_inv" PROJ="$FIXTURE_DIR/proj_ok"
  make_sandbox "$SBX"; make_committed_repo "$PROJ"
  printf '1BAD=odd\nGOOD=1\n' > "$SBX/.env"

  local OUT RC=0
  OUT=$(set -e; session_env_common_init proj "$PROJ" "$SBX" 2>&1 </dev/null \
        && printf '%s|' "${GOOD:-unset}") || RC=$?

  if [[ $RC -eq 0 && "$OUT" == *"invalid variable name"* && "$OUT" == *"1|" ]]; then
    pass ".env parser skips non-identifier keys with a warning"
  else
    fail "non-identifier key not handled: rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# session_env_common_init  --  validation + derived exports
# =============================================================================

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
run_test test_env_comments_and_blanks_skipped
run_test test_env_key_whitespace_stripped_value_trimmed
run_test test_env_inline_comment_is_kept_as_value
run_test test_env_whitespace_only_key_line_skipped
run_test test_env_indented_comment_skipped
run_test test_env_invalid_identifier_key_skipped_with_warning
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
