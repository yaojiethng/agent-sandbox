#!/usr/bin/env bash
# tests/test_build_context.sh — Tests for libs/build_context.sh build_context.
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

source "$REPO_ROOT/libs/build_context.sh"

# ---------------------------------------------------------------------------
# Test harness
# ---------------------------------------------------------------------------

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

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
    dir=$(mktemp -d)

    mkdir -p "$dir/libs"
    echo "dirs-content"        > "$dir/libs/dirs.sh"
    echo "snapshot-content"   > "$dir/libs/snapshot.sh"
    echo "diff-content"       > "$dir/libs/diff.sh"

    mkdir -p "$dir/scripts"
    echo "entrypoint-content" > "$dir/libs/sandbox-entrypoint.sh"

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
# build_context prints a path to stdout; that path is a directory.

REPO=$(make_fixture)

context=$(build_context sandbox "$REPO")
assert_exit_zero    "sandbox: exits 0"       build_context sandbox "$REPO"
assert_equal        "sandbox: output is a directory" "directory" "$([ -d "$context" ] && echo directory || echo not-a-directory)"
cleanup "$context"

context=$(build_context agent "$REPO")
assert_exit_zero    "agent: exits 0"         build_context agent "$REPO"
assert_equal        "agent: output is a directory" "directory" "$([ -d "$context" ] && echo directory || echo not-a-directory)"
cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File contents: sandbox image type --"
# sandbox context must contain exactly: sandbox-entrypoint.sh, snapshot.sh,
# diff.sh, dirs.sh — and nothing else.

REPO=$(make_fixture)
context=$(build_context sandbox "$REPO")

assert_file_exists  "sandbox: contains sandbox-entrypoint.sh" "$context/sandbox-entrypoint.sh"
assert_file_exists  "sandbox: contains snapshot.sh"           "$context/snapshot.sh"
assert_file_exists  "sandbox: contains diff.sh"               "$context/diff.sh"
assert_file_exists  "sandbox: contains dirs.sh"               "$context/dirs.sh"
assert_dir_file_count "sandbox: contains exactly 4 files"     "$context" 4

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File contents: agent image type --"
# agent context must contain exactly: dirs.sh — and nothing else.

REPO=$(make_fixture)
context=$(build_context agent "$REPO")

assert_file_exists    "agent: contains dirs.sh"              "$context/dirs.sh"
assert_file_absent    "agent: does not contain entrypoint"   "$context/sandbox-entrypoint.sh"
assert_file_absent    "agent: does not contain snapshot.sh"  "$context/snapshot.sh"
assert_file_absent    "agent: does not contain diff.sh"      "$context/diff.sh"
assert_dir_file_count "agent: contains exactly 1 file"       "$context" 1

cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- File content fidelity --"
# Files in the context must have identical content to the source files.

REPO=$(make_fixture)
context=$(build_context sandbox "$REPO")

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
context_a=$(build_context sandbox "$REPO")
context_b=$(build_context sandbox "$REPO")

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
fixed_context=$(mktemp -d)

# First build: populate fixed_context by copying from build_context output
context_tmp=$(build_context sandbox "$REPO")
cp "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d1=$(digest_of_context "$fixed_context")

# Second build: wipe and repopulate the same fixed path
rm -f "$fixed_context"/*
context_tmp=$(build_context sandbox "$REPO")
cp "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d2=$(digest_of_context "$fixed_context")

assert_equal "same source files produce same digest" "$d1" "$d2"
assert_equal "digest is 64 hex chars" 64 "${#d1}"

# Change a source file — digest must change
echo "modified-content" > "$REPO/libs/dirs.sh"
rm -f "$fixed_context"/*
context_tmp=$(build_context sandbox "$REPO")
cp "$context_tmp"/* "$fixed_context/"
cleanup "$context_tmp"
d3=$(digest_of_context "$fixed_context")

assert_not_equal "digest changes when source file changes" "$d1" "$d3"

# Change a different source file
echo "modified-entrypoint" > "$REPO/libs/sandbox-entrypoint.sh"
rm -f "$fixed_context"/*
context_tmp=$(build_context sandbox "$REPO")
cp "$context_tmp"/* "$fixed_context/"
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
context=$(build_context sandbox "$REPO")
assert_equal "context dir still exists after build_context returns" \
    "directory" "$([ -d "$context" ] && echo directory || echo not-a-directory)"
cleanup "$context"
cleanup "$REPO"

# ---------------------------------------------------------------------------
echo ""
echo "-- Error cases --"

# Missing required arguments
assert_exit_nonzero "fails when image_type arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context'
assert_exit_nonzero "fails when repo_root arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context sandbox'

# Unknown image type
REPO=$(make_fixture)
assert_exit_nonzero "fails on unknown image type" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context unknown '"$REPO"
cleanup "$REPO"

# Missing source file: sandbox-entrypoint.sh
REPO=$(make_fixture)
rm "$REPO/libs/sandbox-entrypoint.sh"
assert_exit_nonzero "fails when sandbox-entrypoint.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: snapshot.sh
REPO=$(make_fixture)
rm "$REPO/libs/snapshot.sh"
assert_exit_nonzero "fails when snapshot.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: diff.sh
REPO=$(make_fixture)
rm "$REPO/libs/diff.sh"
assert_exit_nonzero "fails when diff.sh is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: dirs.sh (sandbox)
REPO=$(make_fixture)
rm "$REPO/libs/dirs.sh"
assert_exit_nonzero "fails when dirs.sh is missing (sandbox)" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context sandbox '"$REPO"
cleanup "$REPO"

# Missing source file: dirs.sh (agent)
REPO=$(make_fixture)
rm "$REPO/libs/dirs.sh"
assert_exit_nonzero "fails when dirs.sh is missing (agent)" \
    bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context agent '"$REPO"
cleanup "$REPO"

# No partial output on error: build_context must clean up the temp dir
# before returning on failure — the ERR trap handles this.
REPO=$(make_fixture)
rm "$REPO/libs/snapshot.sh"
partial_output=$(bash -c 'source '"$REPO_ROOT"'/libs/build_context.sh && build_context sandbox '"$REPO" 2>/dev/null || true)
if [[ -n "$partial_output" && -d "$partial_output" ]]; then
    fail "no partial output on error: partial context dir left behind at $partial_output"
    rm -rf "$partial_output"
else
    pass "no partial output on error: no directory left behind"
fi
cleanup "$REPO"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

[[ $FAIL -eq 0 ]]