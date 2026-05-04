#!/usr/bin/env bash
# tests/knowledge/knowledge_binary_diff_apply.sh
#
# Knowledge test: binary file handling in git diff + git apply.
#
# This file is NOT run by `make test` or `scripts/run_tests.sh`.
# It is a one-off script that documents and verifies assumptions about
# how git diff and git apply handle binary files, specifically in the
# context of the agent-sandbox diff pipeline where:
#
#   - The container and host have the same file state but different
#     git histories (different commit SHAs).
#   - Index lines must be stripped from text diffs (cosmetic).
#   - Binary diffs still need to apply cleanly without index lines.
#
# Run manually:  bash tests/knowledge/knowledge_binary_diff_apply.sh
# Expected:     All assertions pass, exit 0.
#
# References:
#   - handover 20260503-02-study-binary_file_handling_in_patch_pipeline.md
#   - libs/package_branch.sh  (package_commits uses the selective strip approach for per-commit diffs)
#   - libs/package_diff.sh    (strips all index lines via write_uncommitted_diff; no selective strip)

set -uo pipefail

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

# ---------------------------------------------------------------
# Helper: create a git repo with known content
# ---------------------------------------------------------------
make_repo() {
  local DIR="$1"
  git init --quiet "$DIR"
  git -C "$DIR" config user.email "test@test"
  git -C "$DIR" config user.name "test"
}

# ---------------------------------------------------------------
# Helper: create a binary file (1500 bytes of known pattern)
# ---------------------------------------------------------------
make_binary() {
  local FILE="$1"
  printf '\x00\x01\x02%.0s' $(seq 1 500) > "$FILE"
}

make_other_binary() {
  local FILE="$1"
  printf '\xff\xfe\xfd%.0s' $(seq 1 500) > "$FILE"
}

# ---------------------------------------------------------------
# Helper: apply the selective index-stripping awk filter
# ---------------------------------------------------------------
strip_index_selectively() {
  awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1'
}

echo "=== Knowledge: binary file diff + apply behavior ==="
echo ""
echo "Fixture: $FIXTURE"
echo ""

# ===============================================================
# Section 1: Default git diff does NOT produce applyable patches
# for binary files, even WITH the index line present.
# ===============================================================
echo "--- Section 1: default git diff vs --binary ---"

make_repo "$FIXTURE/section1"
make_binary "$FIXTURE/section1/file.bin"
echo "text" > "$FIXTURE/section1/file.txt"
git -C "$FIXTURE/section1" add . && git -C "$FIXTURE/section1" commit -m "initial" --quiet

# Modify binary
make_other_binary "$FIXTURE/section1/file.bin"

# Default diff
git -C "$FIXTURE/section1" diff > "$FIXTURE/default.diff" 2>&1

# --binary diff
git -C "$FIXTURE/section1" diff --binary > "$FIXTURE/binary.diff" 2>&1

# Reset file
git -C "$FIXTURE/section1" checkout -- .

# Test: default diff (with index line) fails to apply
make_repo "$FIXTURE/section1_apply1"
make_binary "$FIXTURE/section1_apply1/file.bin"
echo "text" > "$FIXTURE/section1_apply1/file.txt"
git -C "$FIXTURE/section1_apply1" add . && git -C "$FIXTURE/section1_apply1" commit -m "init" --quiet

if git -C "$FIXTURE/section1_apply1" apply "$FIXTURE/default.diff" 2>/dev/null; then
  fail "default diff (with index) applied — unexpected"
else
  pass "default diff (with index) fails to apply (expected — no binary content)"
fi

# Test: --binary diff (with index line) applies
if git -C "$FIXTURE/section1_apply1" apply "$FIXTURE/binary.diff" 2>/dev/null; then
  pass "--binary diff (with index) applies cleanly"
else
  fail "--binary diff (with index) failed to apply"
fi

# ===============================================================
# Section 2: Index line SHA mismatch does not prevent apply
# (different git history, same file state)
# ===============================================================
echo ""
echo "--- Section 2: cross-repo apply with different SHAs ---"

# Repo A (simulates container)
make_repo "$FIXTURE/repo_a"
make_binary "$FIXTURE/repo_a/file.bin"
echo "text content" > "$FIXTURE/repo_a/file.txt"
git -C "$FIXTURE/repo_a" add . && git -C "$FIXTURE/repo_a" commit -m "a: initial" --quiet
git -C "$FIXTURE/repo_a" commit --allow-empty -m "a: extra commit" --quiet  # diverge history

# Modify binary in repo A
make_other_binary "$FIXTURE/repo_a/file.bin"
echo "text line 2" >> "$FIXTURE/repo_a/file.txt"
git -C "$FIXTURE/repo_a" diff --binary > "$FIXTURE/cross_repo.diff" 2>&1
git -C "$FIXTURE/repo_a" checkout -- .

# Repo B (simulates host — same files, different history)
make_repo "$FIXTURE/repo_b"
make_binary "$FIXTURE/repo_b/file.bin"
echo "text content" > "$FIXTURE/repo_b/file.txt"
git -C "$FIXTURE/repo_b" add . && git -C "$FIXTURE/repo_b" commit -m "b: initial" --quiet

SHA_A=$(git -C "$FIXTURE/repo_a" rev-parse HEAD)
SHA_B=$(git -C "$FIXTURE/repo_b" rev-parse HEAD)

if [[ "$SHA_A" != "$SHA_B" ]]; then
  pass "repo A and B have different HEAD SHAs"
else
  fail "repo A and B have the same SHA — test setup broken"
fi

# Apply repo A's diff to repo B
if git -C "$FIXTURE/repo_b" apply "$FIXTURE/cross_repo.diff" 2>/dev/null; then
  pass "cross-repo apply (different SHAs, same file state) succeeds"
else
  fail "cross-repo apply failed despite same file state"
fi

# Verify binary content was correctly applied
if head -1 "$FIXTURE/repo_b/file.bin" | grep -q $'\xff\xfe\xfd'; then
  pass "binary content correctly applied cross-repo"
else
  fail "binary content incorrect after cross-repo apply"
fi

# Verify text content correctly applied
if grep -q "text line 2" "$FIXTURE/repo_b/file.txt"; then
  pass "text content correctly applied cross-repo"
else
  fail "text content incorrect after cross-repo apply"
fi

# ===============================================================
# Section 3: Selective index stripping works
# (index kept for binary diffs, stripped for text diffs)
# ===============================================================
echo ""
echo "--- Section 3: selective index stripping (the fix) ---"

make_repo "$FIXTURE/section3"
make_binary "$FIXTURE/section3/file.bin"
echo "text line" > "$FIXTURE/section3/file.txt"
git -C "$FIXTURE/section3" add . && git -C "$FIXTURE/section3" commit -m "init" --quiet

# Modify both binary and text
make_other_binary "$FIXTURE/section3/file.bin"
echo "text line 2" >> "$FIXTURE/section3/file.txt"

# Apply selective index stripping
git -C "$FIXTURE/section3" diff --binary | strip_index_selectively > "$FIXTURE/selective.diff"
git -C "$FIXTURE/section3" checkout -- .

echo "--- Selective patch output ---"
cat "$FIXTURE/selective.diff"
echo "---"

# Check: binary diff keeps index line
if grep -q "^index .*\.\..*GIT" "$FIXTURE/selective.diff" 2>/dev/null; then
  :  # no direct check; instead check that the patch parses
fi

# Check: text diff index line is stripped
if grep -q "^index " "$FIXTURE/selective.diff" | head -1 | grep -q "GIT binary patch"; then
  :  # the only remaining index line should be for the binary file
fi

# Count index lines remaining — should be exactly 1 (binary file only)
INDEX_COUNT=$(grep -c "^index " "$FIXTURE/selective.diff" 2>/dev/null || true)
if [[ "$INDEX_COUNT" -eq 1 ]]; then
  pass "selective strip: exactly 1 index line remains (binary file)"
else
  fail "selective strip: expected 1 index line, got $INDEX_COUNT"
fi

# Apply to fresh repo to verify the patch is valid
make_repo "$FIXTURE/section3_apply"
make_binary "$FIXTURE/section3_apply/file.bin"
echo "text line" > "$FIXTURE/section3_apply/file.txt"
git -C "$FIXTURE/section3_apply" add . && git -C "$FIXTURE/section3_apply" commit -m "init" --quiet

if git -C "$FIXTURE/section3_apply" apply "$FIXTURE/selective.diff" 2>/dev/null; then
  pass "selective-strip patch applies cleanly"
else
  fail "selective-strip patch failed to apply"
fi

# ===============================================================
# Section 4: Binary file deletion (--binary + selective strip)
# ===============================================================
echo ""
echo "--- Section 4: binary file deletion ---"

make_repo "$FIXTURE/section4"
make_binary "$FIXTURE/section4/file.bin"
echo "text" > "$FIXTURE/section4/file.txt"
git -C "$FIXTURE/section4" add . && git -C "$FIXTURE/section4" commit -m "init" --quiet

git -C "$FIXTURE/section4" rm file.bin --quiet
git -C "$FIXTURE/section4" commit -m "remove binary" --quiet

git -C "$FIXTURE/section4" diff --binary HEAD~1..HEAD | strip_index_selectively > "$FIXTURE/delete.diff"

echo "--- Delete patch output ---"
cat "$FIXTURE/delete.diff"
echo "---"

# Apply to fresh repo
make_repo "$FIXTURE/section4_apply"
make_binary "$FIXTURE/section4_apply/file.bin"
echo "text" > "$FIXTURE/section4_apply/file.txt"
git -C "$FIXTURE/section4_apply" add . && git -C "$FIXTURE/section4_apply" commit -m "init" --quiet

if git -C "$FIXTURE/section4_apply" apply "$FIXTURE/delete.diff" 2>/dev/null; then
  pass "binary deletion patch applies cleanly"
else
  fail "binary deletion patch failed to apply"
fi

if [[ ! -f "$FIXTURE/section4_apply/file.bin" ]]; then
  pass "binary file correctly deleted after apply"
else
  fail "binary file still exists after deletion apply"
fi

# ===============================================================
# Section 5: Binary file addition (--binary + selective strip)
# ===============================================================
echo ""
echo "--- Section 5: binary file addition ---"

make_repo "$FIXTURE/section5"
echo "text" > "$FIXTURE/section5/file.txt"
git -C "$FIXTURE/section5" add . && git -C "$FIXTURE/section5" commit -m "init" --quiet

make_binary "$FIXTURE/section5/new.bin"
git -C "$FIXTURE/section5" add new.bin
git -C "$FIXTURE/section5" commit -m "add binary" --quiet

git -C "$FIXTURE/section5" diff --binary HEAD~1..HEAD | strip_index_selectively > "$FIXTURE/add.diff"

# Apply to fresh repo
make_repo "$FIXTURE/section5_apply"
echo "text" > "$FIXTURE/section5_apply/file.txt"
git -C "$FIXTURE/section5_apply" add . && git -C "$FIXTURE/section5_apply" commit -m "init" --quiet

if git -C "$FIXTURE/section5_apply" apply "$FIXTURE/add.diff" 2>/dev/null; then
  pass "binary addition patch applies cleanly"
else
  fail "binary addition patch failed to apply"
fi

if [[ -f "$FIXTURE/section5_apply/new.bin" ]]; then
  pass "binary file correctly created after apply"
else
  fail "binary file missing after addition apply"
fi

# ===============================================================
# Summary
# ===============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
