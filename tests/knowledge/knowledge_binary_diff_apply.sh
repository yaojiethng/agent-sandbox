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
#   - libs/diff.sh    (strips all index lines via write_uncommitted_diff; no selective strip)

set -uo pipefail

TEST_KNOWLEDGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TEST_KNOWLEDGE_DIR/../libs/test_common.sh"
source "$TEST_KNOWLEDGE_DIR/../libs/git_fixtures.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

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
# Section 6: grep -v '^index ' destroys binary patches
#
# This section validates that the naive grep -v '^index ' filter
# (previously used in draft_run and apply_run) breaks binary patches,
# while the selective awk filter preserves them.
#
# This is the root cause of the patch-003 failure found in
# handover 20260504-03-study-patch_003_binary_diff_failure.md
# ===============================================================
echo ""
echo "--- Section 6: grep -v index destroys binary patches (the bug) ---"

make_repo "$FIXTURE/section6_src"
make_binary "$FIXTURE/section6_src/data.bin"
echo "text" > "$FIXTURE/section6_src/file.txt"
git -C "$FIXTURE/section6_src" add . && git -C "$FIXTURE/section6_src" commit -m "init" --quiet

# Modify binary + text in one commit (mixing both types)
make_other_binary "$FIXTURE/section6_src/data.bin"
echo "line 2" >> "$FIXTURE/section6_src/file.txt"
git -C "$FIXTURE/section6_src" add .
git -C "$FIXTURE/section6_src" commit -m "change both" --quiet

BASELINE=$(git -C "$FIXTURE/section6_src" rev-list --max-parents=0 HEAD)
HEAD_SHA=$(git -C "$FIXTURE/section6_src" rev-parse HEAD)

# Generate patch using the selective awk filter (correct, as package_commits does)
git -C "$FIXTURE/section6_src" diff --binary "${BASELINE}..${HEAD_SHA}" | strip_index_selectively > "$FIXTURE/selective.diff"

# Same patch, but stripped with grep -v '^index ' (as the buggy draft_run did)
git -C "$FIXTURE/section6_src" diff --binary "${BASELINE}..${HEAD_SHA}" | grep -v '^index ' > "$FIXTURE/broken.diff"

# Apply both patches to fresh repos with same initial state

# Fresh repo A — apply with selective strip
make_repo "$FIXTURE/section6_apply_good"
make_binary "$FIXTURE/section6_apply_good/data.bin"
echo "text" > "$FIXTURE/section6_apply_good/file.txt"
git -C "$FIXTURE/section6_apply_good" add . && git -C "$FIXTURE/section6_apply_good" commit -m "init" --quiet

if git -C "$FIXTURE/section6_apply_good" apply "$FIXTURE/selective.diff" 2>/dev/null; then
  pass "Section 6: selective-strip patch (correct) applies cleanly"
else
  fail "Section 6: selective-strip patch failed to apply"
fi

# Fresh repo B — apply with grep -v '^index ' (the bug)
make_repo "$FIXTURE/section6_apply_bad"
make_binary "$FIXTURE/section6_apply_bad/data.bin"
echo "text" > "$FIXTURE/section6_apply_bad/file.txt"
git -C "$FIXTURE/section6_apply_bad" add . && git -C "$FIXTURE/section6_apply_bad" commit -m "init" --quiet

if git -C "$FIXTURE/section6_apply_bad" apply "$FIXTURE/broken.diff" 2>/dev/null; then
  fail "Section 6: grep -v '^index ' patch applied unexpectedly (binary data may have been lost)"
else
  pass "Section 6: grep -v '^index ' patch fails to apply (expected — index line missing for binary)"
fi

# Verify content of the successful apply
if grep -q "line 2" "$FIXTURE/section6_apply_good/file.txt"; then
  pass "Section 6: text content correctly applied alongside binary"
else
  fail "Section 6: text content missing after binary+text apply"
fi

# ===============================================================
# Section 7: Sequential mixed patches (text, then binary, then text)
#
# Simulates a real session where the agent makes multiple commits
# alternating between text and binary changes. Validates that the
# selective strip filter produces patches that apply sequentially.
# ===============================================================
echo ""
echo "--- Section 7: sequential mixed patches (text → binary → text) ---"

make_repo "$FIXTURE/section7"
echo "init" > "$FIXTURE/section7/readme.txt"
git -C "$FIXTURE/section7" add . && git -C "$FIXTURE/section7" commit -m "init" --quiet
BASELINE=$(git -C "$FIXTURE/section7" rev-parse HEAD)

# Commit 1: text only
echo "feature a" > "$FIXTURE/section7/feature-a.txt"
git -C "$FIXTURE/section7" add .
git -C "$FIXTURE/section7" commit -m "text: feature a" --quiet
SHA1=$(git -C "$FIXTURE/section7" rev-parse HEAD)

# Commit 2: binary only
mkdir -p "$FIXTURE/section7/assets"
make_binary "$FIXTURE/section7/assets/icon.bin"
git -C "$FIXTURE/section7" add .
git -C "$FIXTURE/section7" commit -m "binary: icon" --quiet
SHA2=$(git -C "$FIXTURE/section7" rev-parse HEAD)

# Commit 3: text only (second binary - modify)
mkdir -p "$FIXTURE/section7/assets"
make_other_binary "$FIXTURE/section7/assets/icon.bin"
echo "feature b" > "$FIXTURE/section7/feature-b.txt"
git -C "$FIXTURE/section7" add .
git -C "$FIXTURE/section7" commit -m "binary+text: icon v2 + feature b" --quiet
SHA3=$(git -C "$FIXTURE/section7" rev-parse HEAD)

# Generate patches as package_commits would (consecutive diffs, selective strip)
mkdir -p "$FIXTURE/patches"
git -C "$FIXTURE/section7" diff --binary "${BASELINE}..${SHA1}" | strip_index_selectively > "$FIXTURE/patches/0001-test.diff"
git -C "$FIXTURE/section7" diff --binary "${SHA1}..${SHA2}" | strip_index_selectively > "$FIXTURE/patches/0002-test.diff"
git -C "$FIXTURE/section7" diff --binary "${SHA2}..${SHA3}" | strip_index_selectively > "$FIXTURE/patches/0003-test.diff"

# Apply to fresh repo simulating host
make_repo "$FIXTURE/section7_apply"
echo "init" > "$FIXTURE/section7_apply/readme.txt"
git -C "$FIXTURE/section7_apply" add . && git -C "$FIXTURE/section7_apply" commit -m "init" --quiet

ALL_APPLIED=true
for i in 1 2 3; do
  PF="$FIXTURE/patches/000${i}-test.diff"
  if git -C "$FIXTURE/section7_apply" apply < <(strip_index_selectively < "$PF") 2>/dev/null; then
    git -C "$FIXTURE/section7_apply" add -A
    git -C "$FIXTURE/section7_apply" commit -m "apply patch $i" --quiet
    : # pass is handled below
  else
    fail "Section 7: patch $i failed to apply in sequence"
    ALL_APPLIED=false
  fi
done

if [[ "$ALL_APPLIED" == true ]]; then
  pass "Section 7: all 3 sequential patches (text → binary → text+binary) apply cleanly"
fi

# Verify state after all patches
if [[ -f "$FIXTURE/section7_apply/feature-a.txt" && -f "$FIXTURE/section7_apply/feature-b.txt" ]]; then
  pass "Section 7: text files present after sequential apply"
else
  fail "Section 7: text files missing after sequential apply"
fi

if [[ -f "$FIXTURE/section7_apply/assets/icon.bin" ]]; then
  pass "Section 7: binary file present after sequential apply"
else
  fail "Section 7: binary file missing after sequential apply"
fi

# Verify binary content is from the final version (icon v2)
if head -1 "$FIXTURE/section7_apply/assets/icon.bin" | grep -q $'\xff\xfe\xfd'; then
  pass "Section 7: binary content is final version (icon v2)"
else
  fail "Section 7: binary content is not the final version"
fi

# ===============================================================
# Summary
# ===============================================================
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
