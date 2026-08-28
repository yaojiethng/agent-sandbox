#!/usr/bin/env bash
# tests/test_binary_roundtrip.sh
#
# Binary file handling through the diff pipeline end-to-end:
# git diff --binary → strip_index_lines → git apply → content verified.
#
# Sections 1–2 pin external git behaviour our pipeline relies on
# (default diffs carry no applyable binary payload; index-line SHA
# mismatch does not block cross-repo apply). Sections 3–7 assert our
# pipeline contract: selective index stripping keeps binary patches
# applyable while stripping cosmetic text index lines.
#
# Promoted from tests/knowledge/knowledge_binary_diff_apply.sh — the
# seams are deterministic (git only), so per testing_policy.md this
# belongs in the discovered suite, not in knowledge/.
#
# Origin: handover 20260503-02-study-binary_file_handling_in_patch_pipeline.md;
# Section 6 reproduces the patch-003 failure from
# 20260504-03-study-patch_003_binary_diff_failure.md.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
source "$TEST_DIR/libs/git_fixtures.sh"
source "$REPO_ROOT/src/libs/diff.sh"

test_setup

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------

# make_binary FILE — 1500 bytes of known 0x00-01-02 pattern
make_binary() {
  local FILE="$1"
  printf '\x00\x01\x02%.0s' $(seq 1 500) > "$FILE"
}

make_other_binary() {
  local FILE="$1"
  printf '\xff\xfe\xfd%.0s' $(seq 1 500) > "$FILE"
}

_init_repo_with_binary() {
  local DIR="$1"
  make_repo "$DIR"
  make_binary "$DIR/file.bin"
  echo "text" > "$DIR/file.txt"
  git -C "$DIR" add . && git -C "$DIR" commit -m "init" --quiet
}

# ===============================================================
# Section 1: default git diff does NOT produce applyable patches
# for binary files, even WITH the index line present.
# ===============================================================
test_default_diff_has_no_applyable_binary_payload() {
  make_repo "$FIXTURE_DIR/s1"
  make_binary "$FIXTURE_DIR/s1/file.bin"
  echo "text" > "$FIXTURE_DIR/s1/file.txt"
  git -C "$FIXTURE_DIR/s1" add . && git -C "$FIXTURE_DIR/s1" commit -m "initial" --quiet
  make_other_binary "$FIXTURE_DIR/s1/file.bin"
  git -C "$FIXTURE_DIR/s1" diff > "$FIXTURE_DIR/default.diff"
  git -C "$FIXTURE_DIR/s1" diff --binary > "$FIXTURE_DIR/binary.diff"

  _init_repo_with_binary "$FIXTURE_DIR/s1_apply"

  if git -C "$FIXTURE_DIR/s1_apply" apply "$FIXTURE_DIR/default.diff" 2>/dev/null; then
    fail "default diff (with index) applied — unexpected"
  else
    pass "default diff (with index) fails to apply (expected — no binary content)"
  fi

  if git -C "$FIXTURE_DIR/s1_apply" apply "$FIXTURE_DIR/binary.diff" 2>/dev/null; then
    pass "--binary diff (with index) applies cleanly"
  else
    fail "--binary diff (with index) failed to apply"
  fi
}

# ===============================================================
# Section 2: index-line SHA mismatch does not prevent apply
# (different git history, same file state)
# ===============================================================
test_cross_repo_apply_tolerates_sha_mismatch() {
  # Repo A (simulates container)
  make_repo "$FIXTURE_DIR/repo_a"
  make_binary "$FIXTURE_DIR/repo_a/file.bin"
  echo "text content" > "$FIXTURE_DIR/repo_a/file.txt"
  git -C "$FIXTURE_DIR/repo_a" add . && git -C "$FIXTURE_DIR/repo_a" commit -m "a: initial" --quiet
  git -C "$FIXTURE_DIR/repo_a" commit --allow-empty -m "a: extra commit" --quiet

  make_other_binary "$FIXTURE_DIR/repo_a/file.bin"
  echo "text line 2" >> "$FIXTURE_DIR/repo_a/file.txt"
  git -C "$FIXTURE_DIR/repo_a" diff --binary > "$FIXTURE_DIR/cross_repo.diff"

  # Repo B (simulates host — same files, different history)
  make_repo "$FIXTURE_DIR/repo_b"
  make_binary "$FIXTURE_DIR/repo_b/file.bin"
  echo "text content" > "$FIXTURE_DIR/repo_b/file.txt"
  git -C "$FIXTURE_DIR/repo_b" add . && git -C "$FIXTURE_DIR/repo_b" commit -m "b: initial" --quiet

  local SHA_A SHA_B
  SHA_A=$(git -C "$FIXTURE_DIR/repo_a" rev-parse HEAD)
  SHA_B=$(git -C "$FIXTURE_DIR/repo_b" rev-parse HEAD)

  if [[ "$SHA_A" != "$SHA_B" ]]; then
    pass "repo A and B have different HEAD SHAs"
  else
    fail "repo A and B have the same SHA — test setup broken"
    return
  fi

  if git -C "$FIXTURE_DIR/repo_b" apply "$FIXTURE_DIR/cross_repo.diff" 2>/dev/null; then
    pass "cross-repo apply (different SHAs, same file state) succeeds"
  else
    fail "cross-repo apply failed despite same file state"
    return
  fi

  if head -1 "$FIXTURE_DIR/repo_b/file.bin" | grep -q $'\xff\xfe\xfd'; then
    pass "binary content correctly applied cross-repo"
  else
    fail "binary content incorrect after cross-repo apply"
  fi

  if grep -q "text line 2" "$FIXTURE_DIR/repo_b/file.txt"; then
    pass "text content correctly applied cross-repo"
  else
    fail "text content incorrect after cross-repo apply"
  fi
}

# ===============================================================
# Section 3: selective index stripping — exactly one index line
# survives (the binary file's), and the patch applies cleanly.
# ===============================================================
test_selective_strip_keeps_single_binary_index() {
  _init_repo_with_binary "$FIXTURE_DIR/s3"
  make_other_binary "$FIXTURE_DIR/s3/file.bin"
  echo "text line 2" >> "$FIXTURE_DIR/s3/file.txt"

  git -C "$FIXTURE_DIR/s3" diff --binary | strip_index_lines > "$FIXTURE_DIR/selective.diff"

  local INDEX_COUNT
  INDEX_COUNT=$(grep -c "^index " "$FIXTURE_DIR/selective.diff" || true)
  if [[ "$INDEX_COUNT" -eq 1 ]]; then
    pass "selective strip: exactly 1 index line remains (binary file)"
  else
    fail "selective strip: expected 1 index line, got $INDEX_COUNT"
  fi

  _init_repo_with_binary "$FIXTURE_DIR/s3_apply"
  if git -C "$FIXTURE_DIR/s3_apply" apply "$FIXTURE_DIR/selective.diff" 2>/dev/null; then
    pass "selective-strip patch applies cleanly"
  else
    fail "selective-strip patch failed to apply"
  fi
}

# ===============================================================
# Section 4: binary deletion via --binary + selective strip
# ===============================================================
test_binary_deletion_patch_applies() {
  _init_repo_with_binary "$FIXTURE_DIR/s4"
  git -C "$FIXTURE_DIR/s4" rm file.bin --quiet
  git -C "$FIXTURE_DIR/s4" commit -m "remove binary" --quiet
  git -C "$FIXTURE_DIR/s4" diff --binary HEAD~1..HEAD | strip_index_lines > "$FIXTURE_DIR/delete.diff"

  _init_repo_with_binary "$FIXTURE_DIR/s4_apply"
  if git -C "$FIXTURE_DIR/s4_apply" apply "$FIXTURE_DIR/delete.diff" 2>/dev/null; then
    pass "binary deletion patch applies cleanly"
  else
    fail "binary deletion patch failed to apply"
    return
  fi

  if [[ ! -f "$FIXTURE_DIR/s4_apply/file.bin" ]]; then
    pass "binary file correctly deleted after apply"
  else
    fail "binary file still exists after deletion apply"
  fi
}

# ===============================================================
# Section 5: binary addition via --binary + selective strip
# ===============================================================
test_binary_addition_patch_applies() {
  make_repo "$FIXTURE_DIR/s5"
  echo "text" > "$FIXTURE_DIR/s5/file.txt"
  git -C "$FIXTURE_DIR/s5" add . && git -C "$FIXTURE_DIR/s5" commit -m "init" --quiet

  make_binary "$FIXTURE_DIR/s5/new.bin"
  git -C "$FIXTURE_DIR/s5" add new.bin
  git -C "$FIXTURE_DIR/s5" commit -m "add binary" --quiet
  git -C "$FIXTURE_DIR/s5" diff --binary HEAD~1..HEAD | strip_index_lines > "$FIXTURE_DIR/add.diff"

  make_repo "$FIXTURE_DIR/s5_apply"
  echo "text" > "$FIXTURE_DIR/s5_apply/file.txt"
  git -C "$FIXTURE_DIR/s5_apply" add . && git -C "$FIXTURE_DIR/s5_apply" commit -m "init" --quiet

  if git -C "$FIXTURE_DIR/s5_apply" apply "$FIXTURE_DIR/add.diff" 2>/dev/null; then
    pass "binary addition patch applies cleanly"
  else
    fail "binary addition patch failed to apply"
    return
  fi

  if [[ -f "$FIXTURE_DIR/s5_apply/new.bin" ]]; then
    pass "binary file correctly created after apply"
  else
    fail "binary file missing after addition apply"
  fi
}

# ===============================================================
# Section 6: naive `grep -v '^index '` destroys binary patches —
# the root cause of the patch-003 failure (20260504-03). The
# selective filter must keep such patches applyable.
# ===============================================================
test_grep_v_index_destroys_binary_patches() {
  _init_repo_with_binary "$FIXTURE_DIR/s6_src"
  make_other_binary "$FIXTURE_DIR/s6_src/file.bin"
  echo "line 2" >> "$FIXTURE_DIR/s6_src/file.txt"
  git -C "$FIXTURE_DIR/s6_src" add .
  git -C "$FIXTURE_DIR/s6_src" commit -m "change both" --quiet

  local BASELINE HEAD_SHA
  BASELINE=$(git -C "$FIXTURE_DIR/s6_src" rev-list --max-parents=0 HEAD)
  HEAD_SHA=$(git -C "$FIXTURE_DIR/s6_src" rev-parse HEAD)

  git -C "$FIXTURE_DIR/s6_src" diff --binary "${BASELINE}..${HEAD_SHA}" | strip_index_lines > "$FIXTURE_DIR/good.diff"
  git -C "$FIXTURE_DIR/s6_src" diff --binary "${BASELINE}..${HEAD_SHA}" | grep -v '^index ' > "$FIXTURE_DIR/broken.diff"

  _init_repo_with_binary "$FIXTURE_DIR/s6_good"
  if git -C "$FIXTURE_DIR/s6_good" apply "$FIXTURE_DIR/good.diff" 2>/dev/null; then
    pass "selective-strip patch (correct) applies cleanly"
  else
    fail "selective-strip patch failed to apply"
  fi

  _init_repo_with_binary "$FIXTURE_DIR/s6_bad"
  if git -C "$FIXTURE_DIR/s6_bad" apply "$FIXTURE_DIR/broken.diff" 2>/dev/null; then
    fail "grep -v '^index ' patch applied unexpectedly (binary data may have been lost)"
  else
    pass "grep -v '^index ' patch fails to apply (expected — index line missing for binary)"
  fi

  if grep -q "line 2" "$FIXTURE_DIR/s6_good/file.txt"; then
    pass "text content correctly applied alongside binary"
  else
    fail "text content missing after binary+text apply"
  fi
}

# ===============================================================
# Section 7: sequential mixed patches (text → binary → text+binary),
# generated per-commit as package_commits would.
# ===============================================================
test_sequential_mixed_patches_apply() {
  make_repo "$FIXTURE_DIR/s7"
  echo "init" > "$FIXTURE_DIR/s7/readme.txt"
  git -C "$FIXTURE_DIR/s7" add . && git -C "$FIXTURE_DIR/s7" commit -m "init" --quiet
  local BASELINE SHA1 SHA2 SHA3
  BASELINE=$(git -C "$FIXTURE_DIR/s7" rev-parse HEAD)

  echo "feature a" > "$FIXTURE_DIR/s7/feature-a.txt"
  git -C "$FIXTURE_DIR/s7" add . && git -C "$FIXTURE_DIR/s7" commit -m "text: feature a" --quiet
  SHA1=$(git -C "$FIXTURE_DIR/s7" rev-parse HEAD)

  mkdir -p "$FIXTURE_DIR/s7/assets"
  make_binary "$FIXTURE_DIR/s7/assets/icon.bin"
  git -C "$FIXTURE_DIR/s7" add . && git -C "$FIXTURE_DIR/s7" commit -m "binary: icon" --quiet
  SHA2=$(git -C "$FIXTURE_DIR/s7" rev-parse HEAD)

  make_other_binary "$FIXTURE_DIR/s7/assets/icon.bin"
  echo "feature b" > "$FIXTURE_DIR/s7/feature-b.txt"
  git -C "$FIXTURE_DIR/s7" add . && git -C "$FIXTURE_DIR/s7" commit -m "binary+text: icon v2 + feature b" --quiet
  SHA3=$(git -C "$FIXTURE_DIR/s7" rev-parse HEAD)

  mkdir -p "$FIXTURE_DIR/patches"
  git -C "$FIXTURE_DIR/s7" diff --binary "${BASELINE}..${SHA1}" | strip_index_lines > "$FIXTURE_DIR/patches/0001-test.diff"
  git -C "$FIXTURE_DIR/s7" diff --binary "${SHA1}..${SHA2}" | strip_index_lines > "$FIXTURE_DIR/patches/0002-test.diff"
  git -C "$FIXTURE_DIR/s7" diff --binary "${SHA2}..${SHA3}" | strip_index_lines > "$FIXTURE_DIR/patches/0003-test.diff"

  make_repo "$FIXTURE_DIR/s7_apply"
  echo "init" > "$FIXTURE_DIR/s7_apply/readme.txt"
  git -C "$FIXTURE_DIR/s7_apply" add . && git -C "$FIXTURE_DIR/s7_apply" commit -m "init" --quiet

  local ALL_APPLIED=true i PF
  for i in 1 2 3; do
    PF="$FIXTURE_DIR/patches/000${i}-test.diff"
    if git -C "$FIXTURE_DIR/s7_apply" apply < <(strip_index_lines < "$PF") 2>/dev/null; then
      git -C "$FIXTURE_DIR/s7_apply" add -A
      git -C "$FIXTURE_DIR/s7_apply" commit -m "apply patch $i" --quiet
    else
      fail "patch $i failed to apply in sequence"
      ALL_APPLIED=false
    fi
  done

  if [[ "$ALL_APPLIED" == true ]]; then
    pass "all 3 sequential patches (text → binary → text+binary) apply cleanly"
  fi

  if [[ -f "$FIXTURE_DIR/s7_apply/feature-a.txt" && -f "$FIXTURE_DIR/s7_apply/feature-b.txt" ]]; then
    pass "text files present after sequential apply"
  else
    fail "text files missing after sequential apply"
  fi

  if [[ -f "$FIXTURE_DIR/s7_apply/assets/icon.bin" ]]; then
    pass "binary file present after sequential apply"
  else
    fail "binary file missing after sequential apply"
  fi

  if head -1 "$FIXTURE_DIR/s7_apply/assets/icon.bin" | grep -q $'\xff\xfe\xfd'; then
    pass "binary content is final version (icon v2)"
  else
    fail "binary content is not the final version"
  fi
}

# =============================================================================
# Run
# =============================================================================

run_test test_default_diff_has_no_applyable_binary_payload
run_test test_cross_repo_apply_tolerates_sha_mismatch
run_test test_selective_strip_keeps_single_binary_index
run_test test_binary_deletion_patch_applies
run_test test_binary_addition_patch_applies
run_test test_grep_v_index_destroys_binary_patches
run_test test_sequential_mixed_patches_apply

test_done
