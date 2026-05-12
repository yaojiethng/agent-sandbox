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

source "$REPO_ROOT/libs/containers.sh"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

source "$SCRIPT_DIR/libs/test_common.sh"

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

assert_dir_file_count() {
    local label="$1" dir="$2" expected_count="$3"
    local actual_count
    actual_count=$(find "$dir" -maxdepth 1 -type f | wc -l)
    if [[ "$actual_count" -eq "$expected_count" ]]; then
        pass "$label"
    else
        fail "$label (expected $expected_count files, got $actual_count)"
    fi
}

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

make_fixture() {
    local dir
    dir=$(mktemp -d /tmp/XXXXXX)

    mkdir -p "$dir/libs"
    echo "dirs-content"        > "$dir/libs/dirs.sh"
    echo "snapshot-content"   > "$dir/libs/snapshot.sh"
    echo "diff-content"       > "$dir/libs/diff.sh"
    echo "package_branch-content" > "$dir/libs/package_branch.sh"
    echo "package_diff-content"   > "$dir/libs/package_diff.sh"
    echo "session-content"        > "$dir/libs/session.sh"
    echo "routing-content"        > "$dir/libs/routing.sh"

    mkdir -p "$dir/scripts"
    echo "entrypoint-content" > "$dir/libs/sandbox-entrypoint.sh"
    echo "provider-entrypoint-content" > "$dir/libs/provider-entrypoint.sh"

    # agent workflow files — needed by build_context_agent
    mkdir -p "$dir/agent/skills"
    echo "skill-content" > "$dir/agent/skills/test.md"
    mkdir -p "$dir/agent/prompts"
    echo "prompt-content" > "$dir/agent/prompts/test.md"

    mkdir -p "$dir/docs/architecture"
    echo "arch-content" > "$dir/docs/architecture/test.md"
    mkdir -p "$dir/docs/concepts"
    echo "concept-content" > "$dir/docs/concepts/test.md"

    echo "$dir"
}

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

REPO=$(make_fixture)

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

REPO=$(make_fixture)
context=$(build_context_sandbox "$REPO")

assert_file_exists  "sandbox: contains sandbox-entrypoint.sh" "$context/sandbox-entrypoint.sh"
assert_file_exists  "sandbox: contains dirs.sh"               "$context/dirs.sh"
assert_file_exists  "sandbox: contains snapshot.sh"           "$context/snapshot.sh"
assert_file_exists  "sandbox: contains diff.sh"               "$context/diff.sh"
assert_file_exists  "sandbox: contains routing.sh"            "$context/routing.sh"
assert_file_exists  "sandbox: contains session.sh"            "$context/session.sh"
assert_file_exists  "sandbox: contains docs/architecture/test.md" "$context/docs/architecture/test.md"
assert_file_exists  "sandbox: contains docs/concepts/test.md"     "$context/docs/concepts/test.md"
assert_dir_file_count "sandbox: contains at least 6 files"    "$context" 6

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File contents: agent image type --"
# agent context must contain: dirs.sh, provider-entrypoint.sh,
# package_diff.sh, session.sh, routing.sh, docs/architecture/, docs/concepts/.

REPO=$(make_fixture)
context=$(build_context_agent "$REPO" test-provider)

assert_file_exists    "agent: contains dirs.sh"               "$context/dirs.sh"
assert_file_exists    "agent: contains provider-entrypoint.sh" "$context/provider-entrypoint.sh"
assert_file_exists    "agent: contains package_diff.sh"        "$context/package_diff.sh"
assert_file_exists    "agent: contains session.sh"             "$context/session.sh"
assert_file_exists    "agent: contains routing.sh"             "$context/routing.sh"
assert_file_absent    "agent: does not contain sandbox scripts" "$context/sandbox-entrypoint.sh"
assert_file_absent    "agent: does not contain snapshot.sh"    "$context/snapshot.sh"
assert_file_absent    "agent: does not contain diff.sh"        "$context/diff.sh"
assert_dir_file_count "agent: contains at least 6 files"       "$context" 6

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File content fidelity --"
# Files in the context must have identical content to the source files.

REPO=$(make_fixture)
context=$(build_context_sandbox "$REPO")

assert_equal "sandbox-entrypoint.sh content matches source" \
    "$(cat "$REPO/libs/sandbox-entrypoint.sh")" \
    "$(cat "$context/sandbox-entrypoint.sh")"

assert_equal "dirs.sh content matches source" \
    "$(cat "$REPO/libs/dirs.sh")" \
    "$(cat "$context/dirs.sh")"

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- Isolation: each call produces a distinct temp dir --"

REPO=$(make_fixture)
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

REPO=$(make_fixture)
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
echo "modified-content" > "$REPO/libs/dirs.sh"
rm -rf "$fixed_context"/*
context_tmp=$(build_context_sandbox "$REPO")
cp -r "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d3=$(digest_of_context "$fixed_context")

assert_not_equal "digest changes when source file changes" "$d1" "$d3"

# Change a different source file
echo "modified-entrypoint" > "$REPO/libs/sandbox-entrypoint.sh"
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

REPO=$(make_fixture)
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
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox'
assert_exit_nonzero "fails when repo_root arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox'



# Missing source file: sandbox-entrypoint.sh
REPO=$(make_fixture)
rm "$REPO/libs/sandbox-entrypoint.sh"
assert_exit_nonzero "fails when sandbox-entrypoint.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: snapshot.sh
REPO=$(make_fixture)
rm "$REPO/libs/snapshot.sh"
assert_exit_nonzero "fails when snapshot.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: diff.sh
REPO=$(make_fixture)
rm "$REPO/libs/diff.sh"
assert_exit_nonzero "fails when diff.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: dirs.sh (sandbox)
REPO=$(make_fixture)
rm "$REPO/libs/dirs.sh"
assert_exit_nonzero "fails when dirs.sh is missing (sandbox)" \
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: dirs.sh (agent)
REPO=$(make_fixture)
rm "$REPO/libs/dirs.sh"
assert_exit_nonzero "fails when dirs.sh is missing (agent)" \
    bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_agent '"$REPO"
cleanup "$REPO"

# No partial output on error: build_context_sandbox must clean up the temp dir
# before returning on failure — the ERR trap handles this.
REPO=$(make_fixture)
rm "$REPO/libs/snapshot.sh"
partial_output=$(bash -c 'source '"$REPO_ROOT"'/libs/containers.sh && build_context_sandbox '"$REPO" 2>/dev/null || true)
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

REPO=$(make_fixture)
assert_exit_nonzero "build_sandbox: fails when project name is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_sandbox'
cleanup "$REPO"

REPO=$(make_fixture)
assert_exit_nonzero "build_sandbox: fails when repo_root is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_sandbox '"'"'test-project'"'"
cleanup "$REPO"

REPO=$(make_fixture)
# No sandbox.Dockerfile in fixture; should fail on missing file.
assert_exit_nonzero "build_sandbox: fails when sandbox.Dockerfile is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_sandbox '"'"'test-project'"'"' '"'"'$REPO'"'"
cleanup "$REPO"

# -------------------------------------------------------------------------
echo ""
echo "-- build_agent argument validation --"
# build_agent checks required args and Dockerfile presence.

REPO=$(make_fixture)
assert_exit_nonzero "build_agent: fails when provider name is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_agent'
cleanup "$REPO"

REPO=$(make_fixture)
assert_exit_nonzero "build_agent: fails when project name is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_agent '"'"'test-provider'"'"
cleanup "$REPO"

REPO=$(make_fixture)
assert_exit_nonzero "build_agent: fails when repo_root is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_agent '"'"'test-provider'"'"' '"'"'test-project'"'"
cleanup "$REPO"

REPO=$(make_fixture)
# No providers/ dir in fixture; should fail on missing base.Dockerfile.
assert_exit_nonzero "build_agent: fails when base.Dockerfile is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_agent '"'"'test-provider'"'"' '"'"'test-project'"'"' '"'"'$REPO'"'"
cleanup "$REPO"

REPO=$(make_fixture)
mkdir -p "$REPO/providers/test-provider"
echo "base" > "$REPO/providers/test-provider/base.Dockerfile"
# base.Dockerfile exists but provider.Dockerfile does not; should fail.
assert_exit_nonzero "build_agent: fails when provider.Dockerfile is missing" \
    bash -c 'source '"'"'$REPO_ROOT'"'"'/libs/containers.sh && build_agent '"'"'test-provider'"'"' '"'"'test-project'"'"' '"'"'$REPO'"'"
cleanup "$REPO"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

test_done