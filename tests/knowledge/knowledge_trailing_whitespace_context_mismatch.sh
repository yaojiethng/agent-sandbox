#!/usr/bin/env bash
# tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh
#
# Knowledge test: trailing whitespace in source file context lines causes
# git apply to reject patches, because the diff pipeline strips trailing
# whitespace from ALL lines (including context lines) via:
#
#   | sed 's/[[:space:]]*$//'
#
# This sed command is used in:
#   - src/libs/package_branch.sh (package_commits — per-commit diffs)
#   - src/libs/diff.sh          (write_uncommitted_diff, write_all_changes_diff)
#
# When the source file has intentional trailing whitespace (e.g. Markdown
# hard line breaks: two spaces before newline), the strip makes context
# lines in the generated patch not match the target file. git apply
# requires exact context matching even with --ignore-whitespace.
#
# This file is NOT run by `make test` or `scripts/run_tests.sh`.
# Run manually:  bash tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh
# Expected:     All assertions pass, exit 0.
#
# References:
#   - devlog/discussions/story-patch_application_failures.md (Case 7)
#   - src/libs/package_branch.sh
#   - src/libs/diff.sh
#   - scripts/workflows/draft.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../libs/test_common.sh"
source "$SCRIPT_DIR/../libs/git_fixtures.sh"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "$FIXTURE"' EXIT

echo "=== Knowledge: trailing whitespace context line mismatch ==="
echo ""
echo "Fixture: $FIXTURE"
echo ""

# =========================================================================
# Helpers
# =========================================================================

# strip_all_trailing_ws — the current pipeline behaviour (buggy for context lines)
strip_all_trailing_ws() {
  sed 's/[[:space:]]*$//'
}

# strip_change_lines_only — proposed fix: only strip + and - lines
strip_change_lines_only() {
  sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//'
}

strip_index_lines() {
  awk '/^index / { saved=$0; getline nl; if (nl ~ /^GIT binary patch/) print saved; print nl; next } 1'
}

# =========================================================================
# Fixture: create a repo with a baseline state, then an edit commit.
#
# Returns (via global):  PRE_SHA, POST_SHA, PATCH_BASELINE
# PATCH_BASELINE is the commit before the edit to use in git diff PRE..POST.
# =========================================================================

create_two_commit_fixture() {
  local DIR="$1"

  make_committed_repo "$DIR"

  # Record the baseline commit that make_committed_repo created
  local COMMITTED_SHA
  COMMITTED_SHA=$(git -C "$DIR" rev-parse HEAD)

  PRE_SHA="$COMMITTED_SHA"
  POST_SHA=""  # Will be set after edit commit
}

# =========================================================================
# Section A: strip_all_trailing_ws strips context lines, breaking git apply
#
# Scenario: file with trailing whitespace on some lines (Markdown hard breaks).
# The diff pipeline strips trailing whitespace from ALL lines in the patch,
# including context (' ' prefixed) lines. git apply finds the context doesn't
# match the file, and rejects the patch.
# =========================================================================
echo "=== Section A: strip_all_trailing_ws breaks git apply on context lines ==="
echo ""

# --- Section A setup ---
make_committed_repo "$FIXTURE/sectionA_src"

# A file with trailing whitespace on context lines (like Markdown hard breaks)
cat > "$FIXTURE/sectionA_src/doc.md" <<'EOF'
# Title

Status: original

See also: ref.md
Baseline: base.md

## Body

Body content.

## Footer

Footer content.
EOF

git -C "$FIXTURE/sectionA_src" add -A
git -C "$FIXTURE/sectionA_src" commit -m "baseline: add doc.md" --quiet
BASELINE_A=$(git -C "$FIXTURE/sectionA_src" rev-parse HEAD)

# Edit a line that's surrounded by trailing-whitespace context lines
sed -i 's/Status: original/Status: updated/' \
  "$FIXTURE/sectionA_src/doc.md"

git -C "$FIXTURE/sectionA_src" commit -a -m "update status" --quiet
HEAD_A=$(git -C "$FIXTURE/sectionA_src" rev-parse HEAD)

# Generate patch as the pipeline does (strip_all_trailing_ws)
git -C "$FIXTURE/sectionA_src" diff --binary "${BASELINE_A}..${HEAD_A}" \
  | strip_index_lines \
  | strip_all_trailing_ws \
  > "$FIXTURE/sectionA_stripped.diff"

echo "--- Patch after strip_all_trailing_ws (current pipeline) ---"
cat -A "$FIXTURE/sectionA_stripped.diff"
echo ""

echo "--- Verifying trailing whitespace was stripped from ALL lines ---"
if grep -q '  $' "$FIXTURE/sectionA_stripped.diff"; then
  fail "A0: some lines retained trailing whitespace after strip_all_trailing_ws"
else
  pass "A0: all trailing whitespace stripped from EVERY line in patch (including context)"
fi

# A1: default git apply fails
echo ""
echo "--- A1: default git apply fails when context lines have trailing whitespace stripped ---"
git -C "$FIXTURE/sectionA_src" reset --hard "$BASELINE_A" 2>/dev/null

if git -C "$FIXTURE/sectionA_src" apply --ignore-whitespace "$FIXTURE/sectionA_stripped.diff" 2>/dev/null; then
  fail "A1: apply succeeded despite trailing whitespace context mismatch"
else
  pass "A1: apply fails when context lines have trailing whitespace stripped (expected)"
fi

# A2: --ignore-space-change also fails
echo ""
echo "--- A2: --ignore-space-change also fails (flag only relaxes +/-, not context) ---"
git -C "$FIXTURE/sectionA_src" reset --hard "$BASELINE_A" 2>/dev/null

if git -C "$FIXTURE/sectionA_src" apply --ignore-space-change "$FIXTURE/sectionA_stripped.diff" 2>/dev/null; then
  fail "A2: apply with --ignore-space-change succeeded (unexpected)"
else
  pass "A2: apply with --ignore-space-change also fails (expected)"
fi

# =========================================================================
# Section A3: -C1 as fallback — works when OTHER context lines exist
# =========================================================================
echo ""
echo "--- A3: -C1 as fallback ---"
git -C "$FIXTURE/sectionA_src" reset --hard "$BASELINE_A" 2>/dev/null

if git -C "$FIXTURE/sectionA_src" apply -C1 --ignore-whitespace "$FIXTURE/sectionA_stripped.diff" 2>/dev/null; then
  echo "  (-C1 matched using other non-trailing-space context lines)"
  pass "A3: -C1 works as fallback when other context lines are available"
else
  fail "A3: -C1 fallback failed unexpectedly"
fi

# =========================================================================
# Section A4: -C1 FAILS when ALL context lines near the hunk have trailing ws
# =========================================================================
echo ""
echo "--- A4: -C1 fails when ALL nearby context lines have trailing whitespace ---"

make_committed_repo "$FIXTURE/sectionA4_src"

# Create a file with only trailing-spaced lines
cat > "$FIXTURE/sectionA4_src/results.md" <<'EOF'
line A
line B
line C
EOF

git -C "$FIXTURE/sectionA4_src" add -A
git -C "$FIXTURE/sectionA4_src" commit -m "baseline" --quiet
BASELINE_A4=$(git -C "$FIXTURE/sectionA4_src" rev-parse HEAD)

# Change line C
cat > "$FIXTURE/sectionA4_src/results.md" <<'EOF'
line A
line B
line C updated
EOF

git -C "$FIXTURE/sectionA4_src" commit -a -m "update C" --quiet
HEAD_A4=$(git -C "$FIXTURE/sectionA4_src" rev-parse HEAD)

git -C "$FIXTURE/sectionA4_src" diff --binary "${BASELINE_A4}..${HEAD_A4}" \
  | strip_index_lines \
  | strip_all_trailing_ws \
  > "$FIXTURE/sectionA4_stripped.diff"

echo "--- Patch for minimal trailing-space case ---"
cat -A "$FIXTURE/sectionA4_stripped.diff"
echo ""

git -C "$FIXTURE/sectionA4_src" reset --hard "$BASELINE_A4" 2>/dev/null

echo "--- Default apply ---"
git -C "$FIXTURE/sectionA4_src" apply --ignore-whitespace "$FIXTURE/sectionA4_stripped.diff" 2>/dev/null \
  && echo "  FAIL: default apply unexpectedly succeeded" \
  || echo "  OK: default apply failed (expected)"

git -C "$FIXTURE/sectionA4_src" reset --hard "$BASELINE_A4" 2>/dev/null

echo ""
echo "--- -C1 apply also fails (no single matching context line) ---"
if git -C "$FIXTURE/sectionA4_src" apply -C1 --ignore-whitespace "$FIXTURE/sectionA4_stripped.diff" 2>/dev/null; then
  fail "A4a: -C1 unexpectedly succeeded when ALL context lines had trailing whitespace"
else
  pass "A4a: -C1 also fails when no single context line matches (all had trailing ws)"
fi

# =========================================================================
# Section B: strip_change_lines_only fixes the problem
# =========================================================================
echo ""
echo "=== Section B: strip_change_lines_only preserves context line fidelity ==="
echo ""

make_committed_repo "$FIXTURE/sectionB_src"

cat > "$FIXTURE/sectionB_src/doc.md" <<'EOF'
# Title

Status: original

See also: ref.md
Baseline: base.md

## Body

Body content.
EOF

git -C "$FIXTURE/sectionB_src" add -A
git -C "$FIXTURE/sectionB_src" commit -m "baseline" --quiet
BASELINE_B=$(git -C "$FIXTURE/sectionB_src" rev-parse HEAD)

# Edit status line — add trailing whitespace on the new content line too
sed -i 's/Status: original/Status: updated    /' \
  "$FIXTURE/sectionB_src/doc.md"

git -C "$FIXTURE/sectionB_src" commit -a -m "update status" --quiet
HEAD_B=$(git -C "$FIXTURE/sectionB_src" rev-parse HEAD)

# Generate patch with strip_change_lines_only
git -C "$FIXTURE/sectionB_src" diff --binary "${BASELINE_B}..${HEAD_B}" \
  | strip_index_lines \
  | strip_change_lines_only \
  > "$FIXTURE/sectionB_fixed.diff"

echo "--- Patch after strip_change_lines_only (proposed fix) ---"
cat -A "$FIXTURE/sectionB_fixed.diff"
echo ""

# B1/2: context lines retain trailing whitespace
echo "--- Checking context lines preserved their trailing whitespace ---"
if grep -q 'See also.*  $' "$FIXTURE/sectionB_fixed.diff"; then
  pass "B1: context line 'See also:' retains trailing whitespace"
else
  fail "B1: context line 'See also:' lost trailing whitespace"
fi

if grep -q 'Baseline.*  $' "$FIXTURE/sectionB_fixed.diff"; then
  pass "B2: context line 'Baseline:' retains trailing whitespace"
else
  fail "B2: context line 'Baseline:' lost trailing whitespace"
fi

# B3: added and removed lines still have their trailing ws stripped (cleanliness)
echo ""
echo "--- Checking +/- lines have trailing whitespace stripped (cleanliness) ---"
if grep -q '^+.*updated  $' "$FIXTURE/sectionB_fixed.diff"; then
  fail "B3a: added line (+) retained trailing whitespace (cleanliness lost)"
else
  pass "B3a: added line (+) trailing whitespace stripped (cleanliness preserved)"
fi
if grep -q '^-.*original  $' "$FIXTURE/sectionB_fixed.diff"; then
  fail "B3b: removed line (-) retained trailing whitespace (cleanliness lost)"
else
  pass "B3b: removed line (-) trailing whitespace stripped (cleanliness preserved)"
fi

# B4: default git apply succeeds
echo ""
echo "--- B4: default git apply succeeds with fixed patch ---"
git -C "$FIXTURE/sectionB_src" reset --hard "$BASELINE_B" 2>/dev/null

if git -C "$FIXTURE/sectionB_src" apply --ignore-whitespace "$FIXTURE/sectionB_fixed.diff" 2>/dev/null; then
  pass "B4: fixed patch applies cleanly at default context level"
else
  fail "B4: fixed patch failed at default context level"
fi

# B5: content change correctly applied
echo ""
echo "--- B5: content verification ---"
if grep -q "updated" "$FIXTURE/sectionB_src/doc.md"; then
  pass "B5: content change correctly applied from fixed patch"
else
  fail "B5: content change missing after fixed patch apply"
fi

# B6: trailing whitespace in context lines preserved in target file
echo ""
echo "--- B6: trailing whitespace preserved in target file for context lines ---"
if grep -q 'See also.*  $' "$FIXTURE/sectionB_src/doc.md"; then
  pass "B6a: trailing whitespace preserved for 'See also:' in target file"
else
  fail "B6a: trailing whitespace lost for 'See also:' in target file"
fi
if grep -q 'Baseline.*  $' "$FIXTURE/sectionB_src/doc.md"; then
  pass "B6b: trailing whitespace preserved for 'Baseline:' in target file"
else
  fail "B6b: trailing whitespace lost for 'Baseline:' in target file"
fi

# =========================================================================
# Section C: strip_change_lines_only — does it degrade clean-diff behavior?
#
# The original strip_all_trailing_ws was added "for clean git apply" — it
# prevents trailing whitespace from appearing as "real" changes in diffs.
# strip_change_lines_only preserves this benefit for +/- lines while fixing
# the context mismatch. This section verifies there's no degradation.
# =========================================================================
echo ""
echo "=== Section C: no degradation for clean-diff scenarios ==="
echo ""

make_committed_repo "$FIXTURE/sectionC_src"

# Create a file where the added line has incidental trailing whitespace
cat > "$FIXTURE/sectionC_src/code.py" <<'EOF'
def foo():
    pass

def bar():
    return True
EOF

git -C "$FIXTURE/sectionC_src" add -A
git -C "$FIXTURE/sectionC_src" commit -m "baseline" --quiet
BASELINE_C=$(git -C "$FIXTURE/sectionC_src" rev-parse HEAD)

# Edit: change bar() to have trailing spaces on the return line (sloppy edit)
cat > "$FIXTURE/sectionC_src/code.py" <<'EOF'
def foo():
    pass

def bar():
    return False
EOF

git -C "$FIXTURE/sectionC_src" commit -a -m "update bar" --quiet
HEAD_C=$(git -C "$FIXTURE/sectionC_src" rev-parse HEAD)

# Generate both stripped and fixed patches
git -C "$FIXTURE/sectionC_src" diff "${BASELINE_C}..${HEAD_C}" \
  | strip_index_lines \
  > "$FIXTURE/sectionC_raw.diff"

git -C "$FIXTURE/sectionC_src" diff "${BASELINE_C}..${HEAD_C}" \
  | strip_index_lines \
  | strip_all_trailing_ws \
  > "$FIXTURE/sectionC_stripped_all.diff"

git -C "$FIXTURE/sectionC_src" diff "${BASELINE_C}..${HEAD_C}" \
  | strip_index_lines \
  | strip_change_lines_only \
  > "$FIXTURE/sectionC_stripped_changes.diff"

echo "--- Raw diff (whitespace visible as changes) ---"
cat -A "$FIXTURE/sectionC_raw.diff"
echo ""

echo "--- strip_all_trailing_ws (current, clean) ---"
cat -A "$FIXTURE/sectionC_stripped_all.diff"
echo ""

echo "--- strip_change_lines_only (proposed, also clean) ---"
cat -A "$FIXTURE/sectionC_stripped_changes.diff"
echo ""

# C1: strip_change_lines_only should NOT show the trailing whitespace on +/- lines
echo "--- C1: no trailing whitespace creep into +/- lines ---"
if grep -q '^+.*    $' "$FIXTURE/sectionC_stripped_changes.diff"; then
  fail "C1: fixed patch shows trailing whitespace on changed lines (regression)"
else
  pass "C1: fixed patch hides trailing whitespace on changed lines (same as current)"
fi

# C2: strip_change_lines_only applies cleanly (same as current)
echo ""
echo "--- C2: fixed patch applies cleanly ---"
git -C "$FIXTURE/sectionC_src" reset --hard "$BASELINE_C" 2>/dev/null
if git -C "$FIXTURE/sectionC_src" apply --ignore-whitespace "$FIXTURE/sectionC_stripped_changes.diff" 2>/dev/null; then
  pass "C2: fixed patch applies cleanly"
else
  fail "C2: fixed patch failed to apply"
fi

# =========================================================================
# Summary
# =========================================================================
echo ""
echo "=== Summary ==="
echo ""
echo "Findings:"
echo "  1. strip_all_trailing_ws strips ALL lines including context lines."
echo "     This breaks git apply when source files have trailing whitespace."
echo "  2. --ignore-whitespace and --ignore-space-change do NOT fix this"
echo "     because they only relax matching for +/- lines, not context lines."
echo "  3. -C1 can help as a fallback IF other context lines exist in the hunk"
echo "     that don't have trailing whitespace mismatch."
echo "  4. -C1 is NOT a complete fix — it fails when ALL context lines"
echo "     adjacent to the hunk have trailing whitespace."
echo "  5. strip_change_lines_only preserves context line fidelity while"
echo "     still cleaning +/- lines. No degradation for clean-diff scenarios."
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
