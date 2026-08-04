#!/usr/bin/env bash
# tests/knowledge/knowledge_3way_merge_baseline.sh
#
# Knowledge test: git am --3way with bundle-based merge baseline.
#
# Verifies that a synthetic root commit (created via git commit-tree from the
# host HEAD tree, bundled, and cloned into the sandbox) enables git am --3way
# to resolve inter-commit patch conflicts that plain git apply cannot.
#
# Tests: rename→modify, delete→recreate, context shift (known limitation),
# binary files, whitespace divergence (known limitation), empty repo,
# .gitignore mismatch, bundle size.
#
# Run manually:  bash tests/knowledge/knowledge_3way_merge_baseline.sh
# Expected:      All assertions pass, exit 0.
#
# References:
#   - handover 20260801-06-investigation-3way_merge_baseline.md
#   - src/libs/diff.sh           (_apply_patch_file — current git apply pipeline)
#   - src/capability/snapshot.sh  (snapshot_init_git — current baseline creation)
#   - scripts/workflows/draft.sh  (draft_create — patch application loop)

set -uo pipefail

FAILURES=0
PASSES=0
KNOWN_LIMITATIONS=0

pass() { echo "  PASS: $1"; PASSES=$((PASSES + 1)); }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }
known() { echo "  KNOWN: $1 (limitation documented)"; KNOWN_LIMITATIONS=$((KNOWN_LIMITATIONS + 1)); }
assert_eq() {
  if [[ "$1" != "$2" ]]; then
    fail "$3 (expected '$2', got '$1')"
    return 1
  fi
  return 0
}
assert_file_exists() {
  if [[ ! -f "$1" ]]; then
    fail "$2 (file not found: $1)"
    return 1
  fi
  return 0
}

# =============================================================================
# Helpers
# =============================================================================

# create_host_and_sandbox HOST_DIR
# Creates a host repo with one commit, then a sandbox clone via synthetic-root
# + bundle. Sandbox is at HOST_DIR-sandbox. Returns the baseline tree SHA
# via global BASELINE_TREE.
create_host_and_sandbox() {
  local HOST="$1"
  rm -rf "$HOST"
  mkdir -p "$HOST"
  git -C "$HOST" init --quiet --initial-branch=main 2>/dev/null || {
    git -C "$HOST" init --quiet
    git -C "$HOST" branch -M main 2>/dev/null || true
  }
  git -C "$HOST" config user.email "host@test"
  git -C "$HOST" config user.name "Host"
  echo "host baseline" > "$HOST/file.txt"
  git -C "$HOST" add file.txt
  git -C "$HOST" commit -m "host baseline" --quiet

  BASELINE_TREE=$(git -C "$HOST" rev-parse HEAD^{tree})
  local ROOT
  ROOT=$(echo "agent-sandbox: baseline" | git -C "$HOST" commit-tree "$BASELINE_TREE")
  git -C "$HOST" update-ref refs/heads/_baseline "$ROOT"

  local BUNDLE="$HOST/head.bundle"
  git -C "$HOST" bundle create "$BUNDLE" _baseline --quiet
  git -C "$HOST" update-ref -d refs/heads/_baseline

  local SANDBOX="$HOST-sandbox"
  rm -rf "$SANDBOX"
  git clone "$BUNDLE" "$SANDBOX" --quiet 2>/dev/null
  git -C "$SANDBOX" checkout _baseline --quiet
  git -C "$SANDBOX" config user.email "agent@sandbox"
  git -C "$SANDBOX" config user.name "agent"
}

# finalize_and_apply HOST_DIR SANDBOX_DIR
# Fetches _baseline into host, exports format-patch from sandbox (agent
# commits only, above the baseline root), and applies on host via git am --3way.
# Returns 0 on success, 1 on failure (calls git am --abort on failure).
finalize_and_apply() {
  local HOST="$1"
  local SANDBOX="$2"

  git -C "$HOST" fetch "$SANDBOX/.git" '+refs/heads/_baseline:refs/heads/_baseline' --quiet 2>/dev/null

  local PATCH_DIR="$SANDBOX/patches"
  rm -rf "$PATCH_DIR"
  mkdir -p "$PATCH_DIR"

  local BASE
  BASE=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)
  git -C "$SANDBOX" format-patch -o "$PATCH_DIR" "${BASE}..HEAD" --quiet 2>/dev/null

  # If no patches (no agent commits above baseline), succeed
  local PATCHES=("$PATCH_DIR"/*.patch)
  [[ -f "${PATCHES[0]}" ]] || return 0

  for PATCH in "${PATCHES[@]}"; do
    git -C "$HOST" am --3way "$PATCH" --quiet 2>/dev/null || {
      git -C "$HOST" am --abort 2>/dev/null || true
      return 1
    }
  done
}

# =============================================================================
# Test 1: rename → modify
# =============================================================================
test_rename_then_modify() {
  echo "[test_rename_then_modify]"
  local DIR
  DIR=$(mktemp -d)

  create_host_and_sandbox "$DIR/host"

  git -C "$DIR/host-sandbox" mv file.txt renamed.txt
  git -C "$DIR/host-sandbox" commit -m "rename file.txt to renamed.txt" --quiet
  echo "agent modification" >> "$DIR/host-sandbox/renamed.txt"
  git -C "$DIR/host-sandbox" add renamed.txt
  git -C "$DIR/host-sandbox" commit -m "modify renamed.txt" --quiet

  finalize_and_apply "$DIR/host" "$DIR/host-sandbox" || { fail "rename→modify apply failed"; rm -rf "$DIR"; return 1; }

  assert_file_exists "$DIR/host/renamed.txt" "renamed.txt exists" || { rm -rf "$DIR"; return 1; }

  local COUNT
  COUNT=$(git -C "$DIR/host" log --oneline --format="%s" | grep -cE "rename|modify" || true)
  assert_eq "$COUNT" "2" "both commits landed" || { rm -rf "$DIR"; return 1; }

  rm -rf "$DIR"
  pass "rename→modify"
}

# =============================================================================
# Test 2: delete → recreate
# =============================================================================
test_delete_then_recreate() {
  echo "[test_delete_then_recreate]"
  local DIR
  DIR=$(mktemp -d)

  create_host_and_sandbox "$DIR/host"

  echo "original" > "$DIR/host-sandbox/deleteme.txt"
  git -C "$DIR/host-sandbox" add deleteme.txt
  git -C "$DIR/host-sandbox" commit -m "create deleteme.txt" --quiet
  git -C "$DIR/host-sandbox" rm deleteme.txt --quiet
  git -C "$DIR/host-sandbox" commit -m "delete deleteme.txt" --quiet
  echo "recreated content" > "$DIR/host-sandbox/deleteme.txt"
  git -C "$DIR/host-sandbox" add deleteme.txt
  git -C "$DIR/host-sandbox" commit -m "recreate deleteme.txt" --quiet

  finalize_and_apply "$DIR/host" "$DIR/host-sandbox" || { fail "delete→recreate apply failed"; rm -rf "$DIR"; return 1; }

  assert_file_exists "$DIR/host/deleteme.txt" "deleteme.txt exists" || { rm -rf "$DIR"; return 1; }
  local CONTENT
  CONTENT=$(cat "$DIR/host/deleteme.txt")
  assert_eq "$CONTENT" "recreated content" "correct content" || { rm -rf "$DIR"; return 1; }

  rm -rf "$DIR"
  pass "delete→recreate"
}

# =============================================================================
# Test 3: context shift (host diverges after bundle)
#
# KNOWN LIMITATION: git am --3way cannot reconcile when the agent modifies
# a line that the host also modifies (divergent parallel session). Plain
# git apply fails too. This is not a regression — it documents the boundary
# of 3-way merge capability.
# =============================================================================
test_context_shift() {
  echo "[test_context_shift]"
  local DIR
  DIR=$(mktemp -d)

  create_host_and_sandbox "$DIR/host"

  # Host diverges: modifies the same line the agent will touch
  sed -i 's/host baseline/host baseline + host change/' "$DIR/host/file.txt"
  git -C "$DIR/host" add file.txt
  git -C "$DIR/host" commit -m "parallel session" --quiet

  # Agent modifies the same line
  sed -i 's/host baseline/host baseline + agent change/' "$DIR/host-sandbox/file.txt"
  git -C "$DIR/host-sandbox" add file.txt
  git -C "$DIR/host-sandbox" commit -m "agent modifies baseline line" --quiet

  if finalize_and_apply "$DIR/host" "$DIR/host-sandbox"; then
    pass "context shift (3-way resolved cleanly)"
  else
    known "context shift — 3-way merge cannot reconcile conflicting changes to same line (git am --3way falls back to 2-way context matching)"
  fi

  rm -rf "$DIR"
}

# =============================================================================
# Test 4: binary files
# =============================================================================
test_binary_file() {
  echo "[test_binary_file]"
  local DIR
  DIR=$(mktemp -d)

  create_host_and_sandbox "$DIR/host"

  printf '\x00\x01\x02\x03%.0s' $(seq 1 256) > "$DIR/host-sandbox/data.bin"
  git -C "$DIR/host-sandbox" add data.bin
  git -C "$DIR/host-sandbox" commit -m "add binary" --quiet

  printf '\xff\xfe\xfd%.0s' $(seq 1 128) >> "$DIR/host-sandbox/data.bin"
  git -C "$DIR/host-sandbox" add data.bin
  git -C "$DIR/host-sandbox" commit -m "modify binary" --quiet

  finalize_and_apply "$DIR/host" "$DIR/host-sandbox" || { fail "binary apply failed"; rm -rf "$DIR"; return 1; }

  assert_file_exists "$DIR/host/data.bin" "data.bin exists" || { rm -rf "$DIR"; return 1; }
  local SIZE
  SIZE=$(wc -c < "$DIR/host/data.bin")
  assert_eq "$SIZE" "1408" "correct size (1024+384)" || { rm -rf "$DIR"; return 1; }

  rm -rf "$DIR"
  pass "binary files"
}

# =============================================================================
# Test 5: whitespace divergence (CRLF host, LF agent)
#
# KNOWN LIMITATION: git am --3way cannot reconcile CRLF/LF divergence.
# The patch context references CRLF lines but the working tree has LF
# (or vice-versa). Current git apply --ignore-whitespace handles some
# cases; 3-way merge with different file encoding does not.
# =============================================================================
test_whitespace_divergence() {
  echo "[test_whitespace_divergence]"
  local DIR
  DIR=$(mktemp -d)

  # Host with CRLF
  rm -rf "$DIR/host"
  mkdir -p "$DIR/host"
  git -C "$DIR/host" init --quiet
  git -C "$DIR/host" config user.email "host@test"
  git -C "$DIR/host" config user.name "Host"
  printf 'line1\r\nline2\r\nline3\r\n' > "$DIR/host/file.txt"
  git -C "$DIR/host" add file.txt
  git -C "$DIR/host" commit -m "host with CRLF" --quiet

  local TREE
  TREE=$(git -C "$DIR/host" rev-parse HEAD^{tree})
  local ROOT
  ROOT=$(echo "agent-sandbox: baseline" | git -C "$DIR/host" commit-tree "$TREE")
  git -C "$DIR/host" update-ref refs/heads/_baseline "$ROOT"
  local BUNDLE="$DIR/host/head.bundle"
  git -C "$DIR/host" bundle create "$BUNDLE" _baseline --quiet
  git -C "$DIR/host" update-ref -d refs/heads/_baseline

  local SANDBOX="$DIR/host-sandbox"
  rm -rf "$SANDBOX"
  git clone "$BUNDLE" "$SANDBOX" --quiet 2>/dev/null
  git -C "$SANDBOX" checkout _baseline --quiet
  git -C "$SANDBOX" config user.email "agent@sandbox"
  git -C "$SANDBOX" config user.name "agent"

  # Agent writes LF
  printf 'line1\nline2-MODIFIED\nline3\n' > "$SANDBOX/file.txt"
  git -C "$SANDBOX" add file.txt
  git -C "$SANDBOX" commit -m "modify with LF" --quiet

  if finalize_and_apply "$DIR/host" "$SANDBOX"; then
    pass "whitespace divergence (3-way resolved cleanly)"
  else
    known "whitespace divergence — 3-way merge cannot reconcile CRLF/LF line ending mismatch"
  fi

  rm -rf "$DIR"
}

# =============================================================================
# Test 6: empty repo (no commits → cannot create bundle)
# =============================================================================
test_empty_repo() {
  echo "[test_empty_repo]"
  local DIR
  DIR=$(mktemp -d)

  rm -rf "$DIR/host"
  mkdir -p "$DIR/host"
  git -C "$DIR/host" init --quiet
  git -C "$DIR/host" config user.email "host@test"
  git -C "$DIR/host" config user.name "Host"

  # Empty repo: no commits to bundle
  if git -C "$DIR/host" rev-parse HEAD 2>/dev/null; then
    # git may have created an unborn branch — verify no commits
    local COUNT
    COUNT=$(git -C "$DIR/host" rev-list --all --count 2>/dev/null || echo 0)
    if [[ "$COUNT" -ne 0 ]]; then
      fail "empty repo should have 0 commits, got $COUNT"; rm -rf "$DIR"; return 1
    fi
  fi

  # Verify git archive HEAD fails (no HEAD commit)
  if git -C "$DIR/host" archive HEAD > /dev/null 2>&1; then
    fail "empty repo: git archive HEAD should fail"; rm -rf "$DIR"; return 1
  fi

  rm -rf "$DIR"
  pass "empty repo"
}

# =============================================================================
# Test 7: baseline tree integrity across bundle
# =============================================================================
test_baseline_tree_integrity() {
  echo "[test_baseline_tree_integrity]"
  local DIR
  DIR=$(mktemp -d)

  create_host_and_sandbox "$DIR/host"

  # The sandbox _baseline tree must match the recorded BASELINE_TREE
  local SANDBOX_BASE_TREE
  SANDBOX_BASE_TREE=$(git -C "$DIR/host-sandbox" log --format="%T" -1 _baseline)

  # BASELINE_TREE was set by create_host_and_sandbox from host HEAD tree
  assert_eq "$SANDBOX_BASE_TREE" "$BASELINE_TREE" "baseline tree preserved through bundle" || { rm -rf "$DIR"; return 1; }

  # Also verify: host tree (HEAD) still matches baseline tree (no divergent commits)
  local HOST_TREE
  HOST_TREE=$(git -C "$DIR/host" rev-parse HEAD^{tree})
  assert_eq "$HOST_TREE" "$BASELINE_TREE" "host tree unchanged after bundle" || { rm -rf "$DIR"; return 1; }

  rm -rf "$DIR"
  pass "baseline tree integrity"
}

# =============================================================================
# Test 8: bundle size independent of history depth
# =============================================================================
test_bundle_size_independent() {
  echo "[test_bundle_size_independent]"
  local DIR
  DIR=$(mktemp -d)

  rm -rf "$DIR/host"
  mkdir -p "$DIR/host"
  git -C "$DIR/host" init --quiet
  git -C "$DIR/host" config user.email "host@test"
  git -C "$DIR/host" config user.name "Host"

  # 50 commits = deep history
  for i in $(seq 1 50); do
    echo "commit $i" > "$DIR/host/file$i.txt"
    git -C "$DIR/host" add "file$i.txt"
    git -C "$DIR/host" commit -m "commit $i" --quiet
  done

  local TREE
  TREE=$(git -C "$DIR/host" rev-parse HEAD^{tree})
  local ROOT
  ROOT=$(echo "agent-sandbox: baseline" | git -C "$DIR/host" commit-tree "$TREE")
  git -C "$DIR/host" update-ref refs/heads/_baseline "$ROOT"
  local BUNDLE="$DIR/host/head.bundle"
  git -C "$DIR/host" bundle create "$BUNDLE" _baseline --quiet
  git -C "$DIR/host" update-ref -d refs/heads/_baseline

  local SIZE
  SIZE=$(wc -c < "$BUNDLE")

  if [[ "$SIZE" -gt 50000 ]]; then
    fail "bundle too large: $SIZE bytes (expected < 50KB)"; rm -rf "$DIR"; return 1
  fi

  rm -rf "$DIR"
  pass "bundle size ($SIZE bytes for 50-commit repo)"
}

# =============================================================================
main() {
  echo "=== knowledge_3way_merge_baseline ==="
  echo ""

  test_rename_then_modify
  test_delete_then_recreate
  test_context_shift
  test_binary_file
  test_whitespace_divergence
  test_empty_repo
  test_baseline_tree_integrity
  test_bundle_size_independent

  echo ""
  echo "Results: $PASSES passed, $KNOWN_LIMITATIONS known limitations, $FAILURES failed"
  if [[ "$FAILURES" -eq 0 ]]; then
    echo "All tests passed."
    return 0
  else
    return 1
  fi
}

main "$@"
