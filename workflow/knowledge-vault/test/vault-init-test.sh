#!/usr/bin/env bash
# .vault/tests/vault-init-test.sh
#
# Validates vault-init.sh behavior: first-run initialization, idempotency,
# .gitattributes regeneration, .gitignore stability, baseline commit format,
# and backup file handling.
#
# Creates a scratch copy of the vault and runs vault-init.sh against it.
# The original vault is never modified.
#
# Usage:
#   bash .vault/tests/vault-init-test.sh --vault=<path> [--scratch=<path>]
#
# --vault    Path to vault root (required)
# --scratch  Scratch directory for test copy (default: /tmp/vault-init-test)
#
# Prerequisites: git, git-lfs

set -uo pipefail

# -------------------------
# Locate scripts relative to this file
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT="${SCRIPT_DIR}/../scripts/vault-init.sh"

# -------------------------
# Args
# -------------------------
VAULT_DIR=""
SCRATCH_DIR="/tmp/vault-init-test"

for arg in "$@"; do
  case "$arg" in
    --vault=*)   VAULT_DIR="${arg#--vault=}" ;;
    --scratch=*) SCRATCH_DIR="${arg#--scratch=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "Usage: bash .vault/tests/vault-init-test.sh --vault=<path> [--scratch=<path>]" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "ERROR: vault directory not found: $VAULT_DIR" >&2
  exit 1
fi

if [[ ! -f "$INIT" ]]; then
  echo "ERROR: vault-init.sh not found at $INIT" >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"

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

# -------------------------
# Cleanup on exit
# -------------------------
cleanup() { rm -rf "$SCRATCH_DIR"; }
trap cleanup EXIT

# -------------------------
# Preflight
# -------------------------
require git
require git-lfs

# -------------------------
# Setup — scratch vault
# -------------------------
section "Setup"
log "Vault source:  $VAULT_DIR"
log "Scratch dir:   $SCRATCH_DIR"

export GIT_AUTHOR_NAME="vault-init-test"
export GIT_AUTHOR_EMAIL="vault-init-test@local"
export GIT_COMMITTER_NAME="vault-init-test"
export GIT_COMMITTER_EMAIL="vault-init-test@local"

rm -rf "$SCRATCH_DIR"
rsync -a --exclude='.git' --exclude='.workspace' "$VAULT_DIR/" "$SCRATCH_DIR/" 2>/dev/null \
  || { cp -r "$VAULT_DIR/." "$SCRATCH_DIR/"; log "rsync unavailable, used cp"; }
log "Vault content copied to scratch"

TODAY="$(date +%Y-%m-%d)"
VAULT_NAME="$(basename "$SCRATCH_DIR")"

# -------------------------
# First run
# -------------------------
section "First run"

bash "$INIT" --vault="$SCRATCH_DIR" >/dev/null 2>&1
exit_code=$?

if [[ "$exit_code" -eq 0 ]]; then
  ok "vault-init.sh exits 0 on first run"
else
  fail "vault-init.sh exited $exit_code on first run — aborting"
  exit 1
fi

section "First run — git repository"

if [[ -d "$SCRATCH_DIR/.git" ]]; then
  ok ".git directory created"
else
  fail ".git directory not found — init failed"
fi

if git -C "$SCRATCH_DIR" rev-parse HEAD &>/dev/null; then
  ok "repository has at least one commit"
else
  fail "repository has no commits"
fi

section "First run — LFS"

LFS_CONFIG=$(git -C "$SCRATCH_DIR" config --local --get filter.lfs.clean 2>/dev/null || true)
if [[ -n "$LFS_CONFIG" ]]; then
  ok "git-lfs filter installed in local config"
else
  fail "git-lfs filter not found in local config"
fi

section "First run — .gitattributes"

if [[ -f "$SCRATCH_DIR/.gitattributes" ]]; then
  ok ".gitattributes written"
else
  fail ".gitattributes not written"
fi

# Must have at least one filter=lfs or -filter line to be meaningful
if grep -qE "(filter=lfs|-filter)" "$SCRATCH_DIR/.gitattributes" 2>/dev/null; then
  ok ".gitattributes contains LFS or text override rules"
else
  fail ".gitattributes appears empty or has no LFS/override rules"
fi

# .gitattributes must be committed
if git -C "$SCRATCH_DIR" ls-files --error-unmatch .gitattributes &>/dev/null; then
  ok ".gitattributes is committed"
else
  fail ".gitattributes not committed in baseline"
fi

section "First run — .gitignore"

if [[ -f "$SCRATCH_DIR/.gitignore" ]]; then
  ok ".gitignore written"
else
  fail ".gitignore not written"
fi

if git -C "$SCRATCH_DIR" ls-files --error-unmatch .gitignore &>/dev/null; then
  ok ".gitignore is committed"
else
  fail ".gitignore not committed in baseline"
fi

section "First run — baseline commit message"

COMMIT_MSG=$(git -C "$SCRATCH_DIR" log -1 --format="%s")
EXPECTED_PREFIX="init: ${VAULT_NAME} ${TODAY}"

if [[ "$COMMIT_MSG" == "$EXPECTED_PREFIX" ]]; then
  ok "baseline commit message: '$COMMIT_MSG'"
else
  fail "commit message mismatch"
  log "  Expected: $EXPECTED_PREFIX"
  log "  Got:      $COMMIT_MSG"
fi

section "First run — working tree clean after init"

if git -C "$SCRATCH_DIR" diff --quiet && git -C "$SCRATCH_DIR" diff --cached --quiet; then
  ok "working tree clean after first run"
else
  fail "uncommitted changes remain after first run"
  git -C "$SCRATCH_DIR" status --short | while IFS= read -r line; do log "  $line"; done
fi

# -------------------------
# Backup file handling
# -------------------------
section "Backup — live exists, backup missing → backup created"

# Set up a controlled scratch for backup tests
BACKUP_SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR" "$BACKUP_SCRATCH"' EXIT

rsync -a --exclude='.git' --exclude='.workspace' "$VAULT_DIR/" "$BACKUP_SCRATCH/" 2>/dev/null \
  || cp -r "$VAULT_DIR/." "$BACKUP_SCRATCH/"

mkdir -p "$BACKUP_SCRATCH/.obsidian"
echo '{"live":true}' > "$BACKUP_SCRATCH/.obsidian/app.json"
rm -f "$BACKUP_SCRATCH/.obsidian/app.backup.json"

bash "$INIT" --vault="$BACKUP_SCRATCH" >/dev/null 2>&1

if [[ -f "$BACKUP_SCRATCH/.obsidian/app.backup.json" ]]; then
  ok "backup created from live file when backup was missing"
else
  fail "backup not created when live existed and backup was missing"
fi

section "Backup — live missing, backup exists → live seeded"

SEED_SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_DIR" "$BACKUP_SCRATCH" "$SEED_SCRATCH"' EXIT

rsync -a --exclude='.git' --exclude='.workspace' "$VAULT_DIR/" "$SEED_SCRATCH/" 2>/dev/null \
  || cp -r "$VAULT_DIR/." "$SEED_SCRATCH/"

mkdir -p "$SEED_SCRATCH/.obsidian"
rm -f "$SEED_SCRATCH/.obsidian/app.json"
echo '{"from_backup":true}' > "$SEED_SCRATCH/.obsidian/app.backup.json"

bash "$INIT" --vault="$SEED_SCRATCH" >/dev/null 2>&1

if [[ -f "$SEED_SCRATCH/.obsidian/app.json" ]]; then
  ok "live file seeded from backup when live was missing"
  SEEDED_CONTENT=$(cat "$SEED_SCRATCH/.obsidian/app.json")
  if [[ "$SEEDED_CONTENT" == '{"from_backup":true}' ]]; then
    ok "seeded live file content matches backup"
  else
    fail "seeded live file content does not match backup"
  fi
else
  fail "live file not created from backup"
fi

rm -rf "$BACKUP_SCRATCH" "$SEED_SCRATCH"
trap cleanup EXIT  # restore simple cleanup for remainder of tests

# -------------------------
# Idempotency — second run
# -------------------------
section "Idempotency — second run exits 0"

bash "$INIT" --vault="$SCRATCH_DIR" >/dev/null 2>&1
exit_code=$?
if [[ "$exit_code" -eq 0 ]]; then
  ok "vault-init.sh exits 0 on second run"
else
  fail "vault-init.sh exited $exit_code on second run"
fi

section "Idempotency — no new commit created"

COMMIT_COUNT=$(git -C "$SCRATCH_DIR" rev-list HEAD --count)
if [[ "$COMMIT_COUNT" -eq 1 ]]; then
  ok "commit count unchanged after second run (still 1)"
else
  fail "unexpected commit count after second run: $COMMIT_COUNT"
fi

section "Idempotency — .gitignore not modified"

GITIGNORE_STATUS=$(git -C "$SCRATCH_DIR" status --short .gitignore 2>/dev/null || true)
if [[ -z "$GITIGNORE_STATUS" ]]; then
  ok ".gitignore unchanged on second run"
else
  fail ".gitignore was modified on second run"
fi

section "Idempotency — .gitattributes regenerated and staged if changed"

# .gitattributes should be either unchanged (nothing staged) or staged (if vault has new exts)
# Either outcome is valid — what must not happen is an untracked or unstaged modification
ATTRS_UNTRACKED=$(git -C "$SCRATCH_DIR" ls-files --others .gitattributes 2>/dev/null || true)
if [[ -z "$ATTRS_UNTRACKED" ]]; then
  ok ".gitattributes is not untracked after second run"
else
  fail ".gitattributes is untracked after second run"
fi

# -------------------------
# Error handling
# -------------------------
section "Error — missing --vault flag"

output=$(bash "$INIT" 2>&1) && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero when --vault not provided"
else
  fail "should have exited non-zero with no --vault"
fi

section "Error — non-existent directory"

output=$(bash "$INIT" --vault="/tmp/does-not-exist-vault-init-test" 2>&1) \
  && exit_code=0 || exit_code=$?
if [[ "$exit_code" -ne 0 ]]; then
  ok "exits non-zero for non-existent directory"
else
  fail "should have exited non-zero for non-existent directory"
fi

# -------------------------
# Summary
# -------------------------
section "Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""
echo "  Vault source: $VAULT_DIR"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "All tests passed."
  exit 0
else
  echo "Some tests failed. Review output above."
  exit 1
fi
