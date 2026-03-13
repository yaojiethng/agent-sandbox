#!/usr/bin/env bash
# .vault/tests/checkpoint-test.sh
#
# Validates checkpoint-create.sh, checkpoint-rollback.sh, and checkpoint-prune.sh
# against a real vault initialized via vault-init.sh.
#
# Creates a scratch copy of the vault, initializes it, then runs the checkpoint
# scripts against it. The original vault is never modified.
#
# Usage:
#   bash .vault/tests/checkpoint-test.sh --vault=<path> [--scratch=<path>]
#
# --vault    Path to vault root (required)
# --scratch  Scratch directory for test copy (default: /tmp/checkpoint-test)
#
# Prerequisites: git, git-lfs

set -uo pipefail

# -------------------------
# Locate scripts relative to this file
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$(cd "${SCRIPT_DIR}/../scripts" && pwd)"

INIT="${SCRIPTS_DIR}/vault-init.sh"
CREATE="${SCRIPTS_DIR}/checkpoint-create.sh"
ROLLBACK="${SCRIPTS_DIR}/checkpoint-rollback.sh"
PRUNE="${SCRIPTS_DIR}/checkpoint-prune.sh"

# -------------------------
# Args
# -------------------------
VAULT_DIR=""
SCRATCH_DIR="/tmp/checkpoint-test"

for arg in "$@"; do
  case "$arg" in
    --vault=*)   VAULT_DIR="${arg#--vault=}" ;;
    --scratch=*) SCRATCH_DIR="${arg#--scratch=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "Usage: bash .vault/tests/checkpoint-test.sh --vault=<path> [--scratch=<path>]" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "ERROR: vault directory not found: $VAULT_DIR" >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"

# -------------------------
# Cleanup on exit
# -------------------------
cleanup() { rm -rf "$SCRATCH_DIR"; }
trap cleanup EXIT

# -------------------------
# Test helpers
# -------------------------
PASS=0
FAIL=0

log()     { echo "  $*"; }
ok()      { echo "  [PASS] $*"; ((PASS++)); }
fail()    { echo "  [FAIL] $*"; ((FAIL++)); }
section() { echo; echo "=== $* ==="; }

require() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: required tool '$1' not found." >&2; exit 1
  fi
}

# Run a script, return its exit code without aborting the test suite
run() { bash "$@"; }

# -------------------------
# Preflight
# -------------------------
require git
require git-lfs

for s in "$INIT" "$CREATE" "$ROLLBACK" "$PRUNE"; do
  if [[ ! -f "$s" ]]; then
    echo "ERROR: script not found: $s" >&2; exit 1
  fi
done

# -------------------------
# Setup — scratch vault
# -------------------------
section "Setup"
log "Vault source:  $VAULT_DIR"
log "Scratch dir:   $SCRATCH_DIR"

export GIT_AUTHOR_NAME="checkpoint-test"
export GIT_AUTHOR_EMAIL="checkpoint-test@local"
export GIT_COMMITTER_NAME="checkpoint-test"
export GIT_COMMITTER_EMAIL="checkpoint-test@local"

rm -rf "$SCRATCH_DIR"
rsync -a --exclude='.git' --exclude='.workspace' "$VAULT_DIR/" "$SCRATCH_DIR/" 2>/dev/null \
  || { cp -r "$VAULT_DIR/." "$SCRATCH_DIR/"; log "rsync unavailable, used cp"; }
log "Vault content copied to scratch"

section "Initializing scratch vault"
bash "$INIT" --vault="$SCRATCH_DIR"

cd "$SCRATCH_DIR"
BASELINE_SHA=$(git rev-parse HEAD)
log "Baseline SHA: ${BASELINE_SHA:0:8}"

TODAY="$(date +%Y-%m-%d)"

# Create marker file before any checkpoint so it exists at checkpoint SHA with known content
echo "initial" > "$SCRATCH_DIR/checkpoint-test-marker.md"
git -C "$SCRATCH_DIR" add checkpoint-test-marker.md
git -C "$SCRATCH_DIR" commit --quiet -m "test: add marker file"

# -------------------------
# Test group: checkpoint-create
# -------------------------
section "create — basic"

create_out=$(run "$CREATE" --root="$SCRATCH_DIR" 2>&1) && create_exit=0 || create_exit=$?
if [[ "$create_exit" -ne 0 ]]; then
  fail "checkpoint-create.sh exited $create_exit — output:"
  echo "$create_out" | while IFS= read -r line; do log "    $line"; done
elif git -C "$SCRATCH_DIR" show-ref --verify --quiet "refs/heads/checkpoint/${TODAY}"; then
  ok "creates checkpoint/${TODAY} branch"
else
  fail "checkpoint/${TODAY} branch not found"
fi

if git -C "$SCRATCH_DIR" show-ref --verify --quiet "refs/tags/checkpoint/latest"; then
  ok "creates checkpoint/latest tag"
else
  fail "checkpoint/latest tag not found"
fi

TAG_SHA=$(git -C "$SCRATCH_DIR" rev-parse refs/tags/checkpoint/latest)
HEAD_SHA=$(git -C "$SCRATCH_DIR" rev-parse HEAD)
if [[ "$TAG_SHA" == "$HEAD_SHA" ]]; then
  ok "checkpoint/latest points to HEAD"
else
  fail "checkpoint/latest does not point to HEAD"
fi

section "create — with label"

run "$CREATE" --root="$SCRATCH_DIR" --label="pre-migration" >/dev/null 2>&1
if git -C "$SCRATCH_DIR" show-ref --verify --quiet "refs/heads/checkpoint/${TODAY}-pre-migration"; then
  ok "creates checkpoint/${TODAY}-pre-migration branch with --label"
else
  fail "labeled branch not found"
fi

section "create — duplicate rejected"

output=$(run "$CREATE" --root="$SCRATCH_DIR" 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero when branch already exists"
else
  fail "should have rejected duplicate branch"
fi
if echo "$output" | grep -qi "already exists"; then
  ok "error message mentions 'already exists'"
else
  fail "error message did not mention 'already exists'"
fi

section "create — dirty tree rejected"

echo "dirty" > "$SCRATCH_DIR/dirty.txt"
git -C "$SCRATCH_DIR" add dirty.txt

output=$(run "$CREATE" --root="$SCRATCH_DIR" --label="dirty" 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero with uncommitted changes"
else
  fail "should have rejected dirty working tree"
fi

git -C "$SCRATCH_DIR" restore --staged dirty.txt 2>/dev/null \
  || git -C "$SCRATCH_DIR" reset HEAD dirty.txt 2>/dev/null
rm -f "$SCRATCH_DIR/dirty.txt"

section "create — non-git-repo rejected"

NOTGIT="$(mktemp -d)"
output=$(run "$CREATE" --root="$NOTGIT" 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero for non-git directory"
else
  fail "should have rejected non-git directory"
fi
rm -rf "$NOTGIT"

section "create — checkpoint/latest updates on second checkpoint"

echo "update" >> "$SCRATCH_DIR/checkpoint-test-marker.md"
git -C "$SCRATCH_DIR" add checkpoint-test-marker.md
git -C "$SCRATCH_DIR" commit --quiet -m "test: update marker for second checkpoint"
SECOND_SHA=$(git -C "$SCRATCH_DIR" rev-parse HEAD)

run "$CREATE" --root="$SCRATCH_DIR" --label="second" >/dev/null 2>&1
TAG_SHA=$(git -C "$SCRATCH_DIR" rev-parse refs/tags/checkpoint/latest)
if [[ "$TAG_SHA" == "$SECOND_SHA" ]]; then
  ok "checkpoint/latest force-updated to new HEAD after second create"
else
  fail "checkpoint/latest not updated — still at old SHA"
fi

# -------------------------
# Test group: checkpoint-rollback
# -------------------------
section "rollback — restores content from named branch"

CHECKPOINT_BRANCH="checkpoint/${TODAY}"
CHECKPOINT_SHA=$(git -C "$SCRATCH_DIR" rev-parse "$CHECKPOINT_BRANCH")
EXPECTED_CONTENT=$(git -C "$SCRATCH_DIR" show "${CHECKPOINT_SHA}:checkpoint-test-marker.md" 2>/dev/null || true)

# Modify marker after checkpoint so rollback has something to restore
echo "post-checkpoint" >> "$SCRATCH_DIR/checkpoint-test-marker.md"
git -C "$SCRATCH_DIR" add checkpoint-test-marker.md
git -C "$SCRATCH_DIR" commit --quiet -m "test: post-checkpoint change"
PRE_ROLLBACK_SHA=$(git -C "$SCRATCH_DIR" rev-parse HEAD)

run "$ROLLBACK" --root="$SCRATCH_DIR" --checkpoint="$CHECKPOINT_BRANCH" >/dev/null 2>&1

ACTUAL_CONTENT=$(cat "$SCRATCH_DIR/checkpoint-test-marker.md" 2>/dev/null || true)
if [[ "$ACTUAL_CONTENT" == "$EXPECTED_CONTENT" ]]; then
  ok "file content restored to checkpoint state"
else
  fail "file content does not match checkpoint state"
  log "  Expected: $(echo "$EXPECTED_CONTENT" | head -1)"
  log "  Got:      $(echo "$ACTUAL_CONTENT" | head -1)"
fi

section "rollback — does not rewrite history"

ROLLBACK_SHA=$(git -C "$SCRATCH_DIR" rev-parse HEAD)
if [[ "$ROLLBACK_SHA" != "$PRE_ROLLBACK_SHA" ]]; then
  ok "rollback created a new commit (history not rewritten)"
else
  fail "HEAD unchanged — rollback may have failed silently"
fi

PARENT_SHA=$(git -C "$SCRATCH_DIR" rev-parse HEAD~1)
if [[ "$PARENT_SHA" == "$PRE_ROLLBACK_SHA" ]]; then
  ok "pre-rollback commit is parent of rollback commit"
else
  fail "commit history not linear — unexpected parent"
fi

section "rollback — defaults to checkpoint/latest"

LATEST_SHA=$(git -C "$SCRATCH_DIR" rev-parse refs/tags/checkpoint/latest)
EXPECTED_LATEST=$(git -C "$SCRATCH_DIR" show "${LATEST_SHA}:checkpoint-test-marker.md" 2>/dev/null || true)

echo "after-rollback" >> "$SCRATCH_DIR/checkpoint-test-marker.md"
git -C "$SCRATCH_DIR" add checkpoint-test-marker.md
git -C "$SCRATCH_DIR" commit --quiet -m "test: change to trigger default rollback"

run "$ROLLBACK" --root="$SCRATCH_DIR" >/dev/null 2>&1

ACTUAL_LATEST=$(cat "$SCRATCH_DIR/checkpoint-test-marker.md" 2>/dev/null || true)
if [[ "$ACTUAL_LATEST" == "$EXPECTED_LATEST" ]]; then
  ok "defaults to checkpoint/latest when no --checkpoint given"
else
  fail "content after default rollback does not match checkpoint/latest state"
fi

section "rollback — dirty tree rejected"

echo "dirty" > "$SCRATCH_DIR/dirty2.txt"
git -C "$SCRATCH_DIR" add dirty2.txt

output=$(run "$ROLLBACK" --root="$SCRATCH_DIR" 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero with uncommitted changes"
else
  fail "should have rejected dirty working tree"
fi

git -C "$SCRATCH_DIR" restore --staged dirty2.txt 2>/dev/null \
  || git -C "$SCRATCH_DIR" reset HEAD dirty2.txt 2>/dev/null
rm -f "$SCRATCH_DIR/dirty2.txt"

section "rollback — invalid ref rejected"

output=$(run "$ROLLBACK" --root="$SCRATCH_DIR" --checkpoint="checkpoint/nonexistent" 2>&1) \
  && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero for invalid checkpoint ref"
else
  fail "should have rejected nonexistent checkpoint ref"
fi

# -------------------------
# Test group: checkpoint-prune
# -------------------------
section "prune — setup: create additional checkpoints"

for label in alpha beta gamma; do
  echo "$label" >> "$SCRATCH_DIR/checkpoint-test-marker.md"
  git -C "$SCRATCH_DIR" add checkpoint-test-marker.md
  git -C "$SCRATCH_DIR" commit --quiet -m "test: commit for $label"
  run "$CREATE" --root="$SCRATCH_DIR" --label="$label" >/dev/null 2>&1
done

TOTAL_BEFORE=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*' | wc -l | tr -d ' ')
log "Total checkpoint branches before prune: $TOTAL_BEFORE"

# Capture the 2 branches expected to survive --keep=2 (last 2 in sorted order)
EXPECTED_KEPT=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*'   --format='%(refname:short)' | sort | tail -2 | sort)

section "prune — no checkpoints exits cleanly"

EMPTY_SCRATCH="$(mktemp -d)"
rsync -a --exclude='.git' --exclude='.workspace' "$VAULT_DIR/" "$EMPTY_SCRATCH/" 2>/dev/null   || cp -r "$VAULT_DIR/." "$EMPTY_SCRATCH/"
bash "$INIT" --vault="$EMPTY_SCRATCH" >/dev/null 2>&1
# Empty scratch has no checkpoint branches — only the default branch from init
bash "$PRUNE" --root="$EMPTY_SCRATCH" --keep=3 >/dev/null 2>&1 && exit_code=0 || exit_code=$?
if [[ "$exit_code" -eq 0 ]]; then
  ok "exits cleanly when no checkpoint branches exist"
else
  fail "non-zero exit when no checkpoint branches exist"
fi
rm -rf "$EMPTY_SCRATCH"

section "prune — keeps N most recent, deletes oldest"

echo "y" | run "$PRUNE" --root="$SCRATCH_DIR" --keep=2 >/dev/null 2>&1

TOTAL_AFTER=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*' | wc -l | tr -d ' ')
if [[ "$TOTAL_AFTER" -eq 2 ]]; then
  ok "exactly 2 checkpoint branches remain after --keep=2"
else
  fail "expected 2 branches, got $TOTAL_AFTER"
fi

ACTUAL_KEPT=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*'   --format='%(refname:short)' | sort)
if [[ "$ACTUAL_KEPT" == "$EXPECTED_KEPT" ]]; then
  ok "2 most recent checkpoint branches retained after prune"
  log "  Kept: $(echo "$ACTUAL_KEPT" | tr '
' ' ')"
else
  fail "wrong branches retained after prune"
  log "  Expected: $(echo "$EXPECTED_KEPT" | tr '
' ' ')"
  log "  Got:      $(echo "$ACTUAL_KEPT" | tr '
' ' ')"
fi

section "prune — checkpoint/latest tag not touched"

TAG_SHA_AFTER=$(git -C "$SCRATCH_DIR" rev-parse refs/tags/checkpoint/latest 2>/dev/null || true)
if [[ -n "$TAG_SHA_AFTER" ]]; then
  ok "checkpoint/latest tag still exists after prune"
else
  fail "checkpoint/latest tag was deleted by prune"
fi

section "prune — non-checkpoint branches not touched"

NON_CP_BEFORE=$(git -C "$SCRATCH_DIR" branch --list --format='%(refname:short)'   | grep -v '^checkpoint/' | wc -l | tr -d ' ')
echo "y" | bash "$PRUNE" --root="$SCRATCH_DIR" --keep=1 >/dev/null 2>&1
NON_CP_AFTER=$(git -C "$SCRATCH_DIR" branch --list --format='%(refname:short)'   | grep -v '^checkpoint/' | wc -l | tr -d ' ')
if [[ "$NON_CP_AFTER" -eq "$NON_CP_BEFORE" ]]; then
  ok "non-checkpoint branch count unchanged after prune ($NON_CP_BEFORE branch(es))"
else
  fail "non-checkpoint branches deleted by prune — before: $NON_CP_BEFORE, after: $NON_CP_AFTER"
fi

# Restore pruned branches so later tests have enough checkpoints
for label in alpha beta gamma; do
  echo "$label-restore" >> "$SCRATCH_DIR/checkpoint-test-marker.md"
  git -C "$SCRATCH_DIR" add checkpoint-test-marker.md
  git -C "$SCRATCH_DIR" commit --quiet -m "test: restore commit for $label"
  bash "$CREATE" --root="$SCRATCH_DIR" --label="${label}-restore" >/dev/null 2>&1
done

section "prune — nothing to prune when keep >= total"

CURRENT_TOTAL=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*' | wc -l | tr -d ' ')
echo "y" | run "$PRUNE" --root="$SCRATCH_DIR" --keep=99 >/dev/null 2>&1
AFTER=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*' | wc -l | tr -d ' ')
if [[ "$AFTER" -eq "$CURRENT_TOTAL" ]]; then
  ok "no branches deleted when --keep exceeds total"
else
  fail "branches were deleted when --keep exceeded total"
fi

section "prune — invalid --keep rejected"

output=$(run "$PRUNE" --root="$SCRATCH_DIR" --keep=0 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "--keep=0 rejected"
else
  fail "--keep=0 should be rejected"
fi

output=$(run "$PRUNE" --root="$SCRATCH_DIR" --keep=abc 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "--keep=abc rejected"
else
  fail "non-integer --keep should be rejected"
fi

section "prune — abort on 'n' confirmation"

BEFORE=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*' | wc -l | tr -d ' ')
echo "n" | run "$PRUNE" --root="$SCRATCH_DIR" --keep=1 >/dev/null 2>&1
AFTER=$(git -C "$SCRATCH_DIR" branch --list 'checkpoint/*' | wc -l | tr -d ' ')
if [[ "$AFTER" -eq "$BEFORE" ]]; then
  ok "no branches deleted when confirmation declined"
else
  fail "branches deleted despite 'n' confirmation"
fi

# -------------------------
# Summary
# -------------------------
section "Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""
echo "  Vault source:  $VAULT_DIR"
echo "  Scratch dir:   $SCRATCH_DIR"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "All tests passed."
  exit 0
else
  echo "Some tests failed. Review output above."
  exit 1
fi
