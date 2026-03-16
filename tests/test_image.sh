#!/usr/bin/env bash
# tests/test_image.sh — Tests for libs/image.sh image_compute_digest.
#
# Uses a temporary directory to simulate the repo layout.
# Each test is self-contained; the fixture is rebuilt per test.
#
# Run:
#   bash tests/test_image.sh
#
# Exit code: 0 if all tests pass, 1 if any fail.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/libs/image.sh"

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

# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

make_fixture() {
    local dir
    dir=$(mktemp -d)

    mkdir -p "$dir/libs"
    echo "lib-content-a" > "$dir/libs/a.sh"
    echo "lib-content-b" > "$dir/libs/b.sh"

    mkdir -p "$dir/providers/opencode"
    echo "entrypoint-content" > "$dir/providers/opencode/container-entrypoint.sh"
    echo "dockerfile-content"  > "$dir/providers/opencode/Dockerfile"

    cat > "$dir/providers/opencode/image-files.txt" <<EOF
providers/opencode/Dockerfile
providers/opencode/container-entrypoint.sh
EOF

    echo "$dir"
}

cleanup() { rm -rf "$1"; }

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

echo ""
echo "=== test_image.sh ==="
echo ""

# --- Happy path ---

echo "-- Happy path --"

REPO=$(make_fixture)

digest=$(image_compute_digest "$REPO" "opencode")
assert_exit_zero    "returns exit 0"          image_compute_digest "$REPO" "opencode"
assert_equal        "output is 64 hex chars"  64 "${#digest}"
assert_exit_zero    "idempotent on re-run"     image_compute_digest "$REPO" "opencode"

digest2=$(image_compute_digest "$REPO" "opencode")
assert_equal        "same inputs produce same digest" "$digest" "$digest2"

cleanup "$REPO"

# --- Digest changes when lib file changes ---

echo ""
echo "-- Digest sensitivity --"

REPO=$(make_fixture)
d1=$(image_compute_digest "$REPO" "opencode")

echo "lib-content-changed" > "$REPO/libs/a.sh"
d2=$(image_compute_digest "$REPO" "opencode")
assert_not_equal "digest changes when lib file changes" "$d1" "$d2"

cleanup "$REPO"

# --- Digest changes when provider file changes ---

REPO=$(make_fixture)
d1=$(image_compute_digest "$REPO" "opencode")

echo "entrypoint-changed" > "$REPO/providers/opencode/container-entrypoint.sh"
d2=$(image_compute_digest "$REPO" "opencode")
assert_not_equal "digest changes when provider file changes" "$d1" "$d2"

cleanup "$REPO"

# --- Digest changes when image-files.txt adds a new file ---

REPO=$(make_fixture)
d1=$(image_compute_digest "$REPO" "opencode")

echo "extra-content" > "$REPO/providers/opencode/extra.sh"
echo "providers/opencode/extra.sh" >> "$REPO/providers/opencode/image-files.txt"
d2=$(image_compute_digest "$REPO" "opencode")
assert_not_equal "digest changes when image-files.txt adds a file" "$d1" "$d2"

cleanup "$REPO"

# --- Error: missing image-files.txt ---

echo ""
echo "-- Error cases --"

REPO=$(make_fixture)
rm "$REPO/providers/opencode/image-files.txt"
assert_exit_nonzero "fails when image-files.txt is missing" \
    image_compute_digest "$REPO" "opencode"
cleanup "$REPO"

# --- Error: listed file does not exist ---

REPO=$(make_fixture)
echo "providers/opencode/nonexistent.sh" >> "$REPO/providers/opencode/image-files.txt"
assert_exit_nonzero "fails when listed file does not exist" \
    image_compute_digest "$REPO" "opencode"
cleanup "$REPO"

# --- Error: empty libs/ ---

REPO=$(make_fixture)
rm "$REPO/libs/"*.sh
assert_exit_nonzero "fails when libs/ is empty" \
    image_compute_digest "$REPO" "opencode"
cleanup "$REPO"

# --- Error: missing required arguments ---

assert_exit_nonzero "fails when REPO arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/image.sh && image_compute_digest'
assert_exit_nonzero "fails when PROVIDER arg is missing" \
    bash -c 'source '"$REPO_ROOT"'/libs/image.sh && image_compute_digest "/some/path"'

# --- image-files.txt: blank lines and comments are ignored ---

echo ""
echo "-- image-files.txt parsing --"

REPO=$(make_fixture)
cat > "$REPO/providers/opencode/image-files.txt" <<EOF
# This is a comment
providers/opencode/Dockerfile

providers/opencode/container-entrypoint.sh
EOF

assert_exit_zero "blank lines and comments in image-files.txt are ignored" \
    image_compute_digest "$REPO" "opencode"

d_clean=$(image_compute_digest "$REPO" "opencode")

# Digest should equal one produced from a clean image-files.txt with same files
REPO2=$(make_fixture)
d_plain=$(image_compute_digest "$REPO2" "opencode")
assert_equal "digest matches equivalent clean image-files.txt" "$d_clean" "$d_plain"

cleanup "$REPO"
cleanup "$REPO2"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
echo ""

[[ $FAIL -eq 0 ]]
