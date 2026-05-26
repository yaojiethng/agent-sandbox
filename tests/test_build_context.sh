#!/usr/bin/env bash
# tests/test_build_context.sh — Tests for libs/containers.sh build_context.
#
# Uses a temporary directory to simulate the repo layout.
# Each test is self-contained; the fixture is rebuilt per test.
#
# Run:
#   bash tests/test_build_context.sh
#
# Exit code: 0 if all tests pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/build/context.sh"
source "$REPO_ROOT/scripts/build.sh"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

source "$SCRIPT_DIR/libs/test_common.sh"
source "$SCRIPT_DIR/libs/mock_repo_fixtures.sh"

assert_exit_zero() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label (expected exit 0, got non-zero)"
    fi
}

assert_exit_nonzero() {
    local label="$1"; shift
    if ! "$@" >/dev/null 2>&1; then
        pass "$label"
    else
        fail "$label (expected non-zero exit, got 0)"
    fi
}

assert_equal() {
    local label="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        pass "$label"
    else
        fail "$label (expected '$expected', got '$actual')"
    fi
}

assert_not_equal() {
    local label="$1" a="$2" b="$3"
    if [[ "$a" != "$b" ]]; then
        pass "$label"
    else
        fail "$label (expected values to differ, but both were '$a')"
    fi
}

assert_file_exists() {
    local label="$1" path="$2"
    if [[ -f "$path" ]]; then
        pass "$label"
    else
        fail "$label (file not found: $path)"
    fi
}

assert_file_absent() {
    local label="$1" path="$2"
    if [[ ! -e "$path" ]]; then
        pass "$label"
    else
        fail "$label (expected absent, found: $path)"
    fi
}

assert_file_set() {
    local label="$1" dir="$2" expected_set="$3"
    local actual_files
    actual_files=$(find "$dir" -maxdepth 1 -type f -printf '%f\n' | sort | tr '\n' ' ')
    # Remove trailing space
    actual_files="${actual_files% }"
    if [[ "$actual_files" == "$expected_set" ]]; then
        pass "$label"
    else
        fail "$label (expected: '$expected_set', got: '$actual_files')"
    fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

digest_of_context() {
    local context_dir="$1"
    # Must match the digest computation in build_sandbox.sh and build_agent.sh exactly.
    find "$context_dir" -type f | sort | xargs sha256sum | sha256sum | awk '{print $1}'
}

cleanup() { rm -rf "$1"; }

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

echo ""
echo "=== test_build.sh ==="
echo ""

# ---------------------------------------------------------------------------
echo "-- Output contract --"
# build_context_sandbox prints a path to stdout; that path is a directory.

REPO=$(make_mock_repo)

context=$(build_context_sandbox "$REPO")
assert_exit_zero    "sandbox: exits 0"       build_context_sandbox "$REPO"
assert_equal        "sandbox: output is a directory" "directory" "$([ -d "$context" ] && echo directory || echo not-a-directory)"
cleanup "$context"

context=$(build_context_agent "$REPO" test-provider)
assert_exit_zero    "agent: exits 0"         build_context_agent "$REPO" test-provider
assert_equal        "agent: output is a directory" "directory" "$([ -d "$context" ] && echo directory || echo not-a-directory)"
cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File contents: sandbox image type --"
# sandbox context must contain: sandbox-entrypoint.sh, dirs.sh, snapshot.sh,
# diff.sh, routing.sh, session.sh, docs/architecture/, docs/concepts/.

REPO=$(make_mock_repo)
context=$(build_context_sandbox "$REPO")

assert_file_exists  "sandbox: contains docs/architecture/test.md" "$context/docs/architecture/test.md"
assert_file_exists  "sandbox: contains docs/concepts/test.md"     "$context/docs/concepts/test.md"
assert_file_set "sandbox: correct file set (sandbox build)" "$context" "diff.sh diff_export.sh dirs.sh entrypoint.sh package_branch.sh package_diff.sh routing.sh session_state.sh snapshot.sh"

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File contents: agent image type --"
# agent context must contain: dirs.sh, provider-entrypoint.sh,
# package_diff.sh, session.sh, routing.sh, docs/architecture/, docs/concepts/.

REPO=$(make_mock_repo)
context=$(build_context_agent "$REPO" test-provider)

assert_file_set "agent: correct file set (agent build)" "$context" "diff.sh diff_export.sh dirs.sh entrypoint.sh package_branch.sh package_diff.sh routing.sh session_state.sh"

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File content fidelity --"
# Files in the context must have identical content to the source files.

REPO=$(make_mock_repo)
context=$(build_context_sandbox "$REPO")

assert_equal "entrypoint.sh content matches source" \
    "$(cat "$REPO/src/capability/entrypoint.sh")" \
    "$(cat "$context/entrypoint.sh")"

assert_equal "dirs.sh content matches source" \
    "$(cat "$REPO/src/libs/dirs.sh")" \
    "$(cat "$context/dirs.sh")"

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- Isolation: each call produces a distinct temp dir --"

REPO=$(make_mock_repo)
context_a=$(build_context_sandbox "$REPO")
context_b=$(build_context_sandbox "$REPO")

assert_not_equal "two calls produce different paths" "$context_a" "$context_b"
assert_equal     "both paths are valid directories" \
    "directory:directory" \
    "$([ -d "$context_a" ] && echo directory || echo not):$([ -d "$context_b" ] && echo directory || echo not)"

cleanup "$context_a"
cleanup "$context_b"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- Digest properties --"
# Digest computed from the context dir contents must be deterministic and
# sensitive to file changes. We test idempotency by building into a known
# fixed directory twice — same path both times — so the sha256sum output
# (which includes the file path) is identical between runs.

REPO=$(make_mock_repo)
fixed_context=$(mktemp -d /tmp/XXXXXX)

# First build: populate fixed_context by copying from build_context output
context_tmp=$(build_context_sandbox "$REPO")
cp -r "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d1=$(digest_of_context "$fixed_context")

# Second build: wipe and repopulate the same fixed path
rm -rf "$fixed_context"/*
context_tmp=$(build_context_sandbox "$REPO")
cp -r "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d2=$(digest_of_context "$fixed_context")

assert_equal "same source files produce same digest" "$d1" "$d2"
assert_equal "digest is 64 hex chars" 64 "${#d1}"

# Change a source file — digest must change
echo "modified-content" > "$REPO/src/libs/dirs.sh"
rm -rf "$fixed_context"/*
context_tmp=$(build_context_sandbox "$REPO")
cp -r "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d3=$(digest_of_context "$fixed_context")

assert_not_equal "digest changes when source file changes" "$d1" "$d3"

# Change a different source file
echo "modified-entrypoint" > "$REPO/src/capability/entrypoint.sh"
rm -rf "$fixed_context"/*
context_tmp=$(build_context_sandbox "$REPO")
cp -r "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d4=$(digest_of_context "$fixed_context")

assert_not_equal "digest changes when entrypoint changes" "$d1" "$d4"
assert_not_equal "digest changes when both files changed vs one" "$d3" "$d4"

cleanup "$fixed_context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- Caller is responsible for cleanup (temp dir persists after call) --"

REPO=$(make_mock_repo)
context=$(build_context_sandbox "$REPO")
assert_equal "context dir still exists after build_context_sandbox returns" \
    "directory" "$([ -d "$context" ] && echo directory || echo not-a-directory)"
cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- Error cases --"

# Missing required arguments
assert_exit_nonzero "fails when image_type arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox'
assert_exit_nonzero "fails when repo_root arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox'



# Missing source file: sandbox-entrypoint.sh
REPO=$(make_mock_repo)
rm "$REPO/src/capability/entrypoint.sh"
assert_exit_nonzero "fails when entrypoint.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: snapshot.sh
REPO=$(make_mock_repo)
rm "$REPO/src/capability/snapshot.sh"
assert_exit_nonzero "fails when snapshot.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: diff.sh
REPO=$(make_mock_repo)
rm "$REPO/src/libs/diff.sh"
assert_exit_nonzero "fails when diff.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: dirs.sh (sandbox)
REPO=$(make_mock_repo)
rm "$REPO/src/libs/dirs.sh"
assert_exit_nonzero "fails when dirs.sh is missing (sandbox)" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: dirs.sh (agent)
REPO=$(make_mock_repo)
rm "$REPO/src/libs/dirs.sh"
assert_exit_nonzero "fails when dirs.sh is missing (agent)" \
    bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_agent '"$REPO"
cleanup "$REPO"

# No partial output on error: build_context_sandbox must clean up the temp dir
# before returning on failure — the ERR trap handles this.
REPO=$(make_mock_repo)
rm "$REPO/src/capability/snapshot.sh"
partial_output=$(bash -c 'source '"$REPO_ROOT"'/build/image.sh && source '"$REPO_ROOT"'/build/context.sh && source '"$REPO_ROOT"'/scripts/build.sh && build_context_sandbox '"$REPO" 2>/dev/null || true)
if [[ -n "$partial_output" && -d "$partial_output" ]]; then
    fail "no partial output on error: partial context dir left behind at $partial_output"
    rm -rf "$partial_output"
else
    pass "no partial output on error: no directory left behind"
fi
cleanup "$REPO"

# -------------------------------------------------------------------------
echo ""
echo "-- build_sandbox argument validation --"
# build_sandbox checks required args and Dockerfile presence.

REPO=$(make_mock_repo)
assert_exit_nonzero "build_sandbox: fails when project name is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_sandbox'
cleanup "$REPO"

REPO=$(make_mock_repo)
assert_exit_nonzero "build_sandbox: fails when repo_root is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_sandbox '"'"'test-project'"'"
cleanup "$REPO"

REPO=$(make_mock_repo)
# No sandbox.Dockerfile in fixture; should fail on missing file.
assert_exit_nonzero "build_sandbox: fails when sandbox.Dockerfile is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_sandbox '"'"'test-project'"'"' '"'"'$REPO'"'"
cleanup "$REPO"

# -------------------------------------------------------------------------
echo ""
echo "-- build_agent argument validation --"
# build_agent checks required args and Dockerfile presence.

REPO=$(make_mock_repo)
assert_exit_nonzero "build_agent: fails when provider name is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_agent'
cleanup "$REPO"

REPO=$(make_mock_repo)
assert_exit_nonzero "build_agent: fails when project name is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_agent '"'"'test-provider'"'"
cleanup "$REPO"

REPO=$(make_mock_repo)
assert_exit_nonzero "build_agent: fails when repo_root is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_agent '"'"'test-provider'"'"' '"'"'test-project'"'"
cleanup "$REPO"

REPO=$(make_mock_repo)
# No src/reasoning/providers/ dir in fixture; should fail on missing base.Dockerfile.
assert_exit_nonzero "build_agent: fails when base.Dockerfile is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_agent '"'"'test-provider'"'"' '"'"'test-project'"'"' '"'"'$REPO'"'"
cleanup "$REPO"

REPO=$(make_mock_repo)
mkdir -p "$REPO/src/reasoning/providers/test-provider"
echo "base" > "$REPO/src/reasoning/providers/test-provider/base.Dockerfile"
# base.Dockerfile exists but provider.Dockerfile does not; should fail.
assert_exit_nonzero "build_agent: fails when provider.Dockerfile is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/build/image.sh && source '"'"'$REPO_ROOT'"'"'/build/context.sh && source '"'"'$REPO_ROOT'"'"'/scripts/build.sh && build_agent '"'"'test-provider'"'"' '"'"'test-project'"'"' '"'"'$REPO'"'"
cleanup "$REPO"

# -------------------------------------------------------------------------
echo ""
echo "-- Provider config in agent context --"
# build_context_agent must copy the entire provider config directory when it
# exists, and must not fail when it does not exist.

test_agent_context_includes_provider_config() {
  local repo; repo=$(make_mock_repo)
  mkdir -p "$repo/src/reasoning/providers/test-provider/config"
  echo '{"model":"test"}' > "$repo/src/reasoning/providers/test-provider/config/settings.json"
  echo 'auth-stub' > "$repo/src/reasoning/providers/test-provider/config/auth.json"
  echo 'models-content' > "$repo/src/reasoning/providers/test-provider/config/models.json"
  echo '# AGENTS.md stub' > "$repo/src/reasoning/providers/test-provider/config/AGENTS.md"
  mkdir -p "$repo/src/reasoning/providers/test-provider/config/prompts"
  echo 'prompt-stub' > "$repo/src/reasoning/providers/test-provider/config/prompts/pi-agent.md"

  local context
  context=$(build_context_agent "$repo" test-provider)

  assert_file_exists "agent: contains provider settings.json"     "$context/agent/config/settings.json"
  assert_file_exists "agent: contains provider auth.json"         "$context/agent/config/auth.json"
  assert_file_exists "agent: contains provider models.json"       "$context/agent/config/models.json"
  assert_file_exists "agent: contains provider AGENTS.md"         "$context/agent/config/AGENTS.md"
  assert_file_exists "agent: contains provider prompts/pi-agent.md" "$context/agent/config/prompts/pi-agent.md"

  assert_equal "agent: settings.json content matches source" \
    "$(cat "$repo/src/reasoning/providers/test-provider/config/settings.json")" \
    "$(cat "$context/agent/config/settings.json")"
  assert_equal "agent: AGENTS.md content matches source" \
    "$(cat "$repo/src/reasoning/providers/test-provider/config/AGENTS.md")" \
    "$(cat "$context/agent/config/AGENTS.md")"

  cleanup "$context"
  cleanup "$repo"
}

test_agent_context_without_provider_config() {
  local repo; repo=$(make_mock_repo)
  mkdir -p "$repo/src/reasoning/providers/test-provider"
  # No config/ dir

  assert_exit_zero "agent: succeeds when no provider config exists" \
    build_context_agent "$repo" test-provider

  local context
  context=$(build_context_agent "$repo" test-provider)
  assert_file_absent "agent: no agent/config/ when no provider config" \
    "$context/agent/config"
  cleanup "$context"
  cleanup "$repo"
}

test_agent_context_provider_config_and_preflight() {
  # Both provider config and preflight script should coexist
  local repo; repo=$(make_mock_repo)
  mkdir -p "$repo/src/reasoning/providers/test-provider/config"
  echo '{"model":"test"}' > "$repo/src/reasoning/providers/test-provider/config/settings.json"
  echo 'preflight-content' > "$repo/src/reasoning/providers/test-provider/preflight.sh"

  local context
  context=$(build_context_agent "$repo" test-provider)

  assert_file_exists "agent: provider config present alongside preflight" \
    "$context/agent/config/settings.json"
  assert_file_exists "agent: preflight script present alongside config" \
    "$context/provider-preflight.sh"

  cleanup "$context"
  cleanup "$repo"
}

test_agent_context_provider_config_entire_dir() {
  # Verify the entire config/dir is copied, not just known files
  local repo; repo=$(make_mock_repo)
  mkdir -p "$repo/src/reasoning/providers/test-provider/config/subdir/nested"
  echo 'deep-content' > "$repo/src/reasoning/providers/test-provider/config/subdir/nested/file.txt"

  local context
  context=$(build_context_agent "$repo" test-provider)

  assert_file_exists "agent: nested file in config/subdir/nested/" \
    "$context/agent/config/subdir/nested/file.txt"
  assert_equal "agent: deep file content matches" \
    "deep-content" \
    "$(cat "$context/agent/config/subdir/nested/file.txt")"

  cleanup "$context"
  cleanup "$repo"
}

test_agent_context_provider_config_skip_other_providers() {
  # Only the requested provider's config should be copied
  local repo; repo=$(make_mock_repo)
  mkdir -p "$repo/src/reasoning/providers/test-provider/config"
  echo 'our-config' > "$repo/src/reasoning/providers/test-provider/config/settings.json"
  mkdir -p "$repo/src/reasoning/providers/other-provider/config"
  echo 'other-config' > "$repo/src/reasoning/providers/other-provider/config/settings.json"

  local context
  context=$(build_context_agent "$repo" test-provider)

  assert_file_exists "agent: our provider config present" \
    "$context/agent/config/settings.json"
  assert_file_absent "agent: other provider config absent" \
    "$context/agent/config/../other-provider/config/settings.json"

  cleanup "$context"
  cleanup "$repo"
}

# -------------------------------------------------------------------------
# Run provider config tests
# -------------------------------------------------------------------------
test_agent_context_includes_provider_config
test_agent_context_without_provider_config
test_agent_context_provider_config_and_preflight
test_agent_context_provider_config_entire_dir
test_agent_context_provider_config_skip_other_providers

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

test_done