#!/usr/bin/env bash
# .vault/tests/vault-lfs-test.sh
#
# Validates LFS setup and diff pipeline behavior against a real vault.
# Creates a scratch copy of the vault, runs verification tests, and
# reports results. The original vault is never modified.
#
# Sources classification and .gitattributes generation from .vault/lib/
# so tests run against the same implementation used by vault-init.sh.
#
# Usage:
#   bash .vault/tests/vault-lfs-test.sh --vault=<path> [--scratch=<path>]
#
# --vault    Path to vault root (required)
# --scratch  Scratch directory for test copy (default: /tmp/vault-lfs-test)
#
# Prerequisites: git, git-lfs

set -uo pipefail

# -------------------------
# Locate lib relative to this script
# -------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(cd "${SCRIPT_DIR}/../lib" && pwd)"

source "${LIB_DIR}/classify.sh"
source "${LIB_DIR}/gitattributes.sh"

# -------------------------
# Args
# -------------------------
VAULT_DIR=""
SCRATCH_DIR="/tmp/vault-lfs-test"

for arg in "$@"; do
  case "$arg" in
    --vault=*)   VAULT_DIR="${arg#--vault=}" ;;
    --scratch=*) SCRATCH_DIR="${arg#--scratch=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "Usage: bash .vault/tests/vault-lfs-test.sh --vault=<path> [--scratch=<path>]" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "ERROR: vault directory not found: $VAULT_DIR" >&2
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
skip()    { echo "  [SKIP] $*"; }
section() { echo; echo "=== $* ==="; }

require() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: required tool '$1' not found. Install it and re-run." >&2
    exit 1
  fi
}

# -------------------------
# Preflight
# -------------------------
require git
require git-lfs

section "Setup"
log "Vault source:  $VAULT_DIR"
log "Scratch dir:   $SCRATCH_DIR"

rm -rf "$SCRATCH_DIR"
mkdir -p "$SCRATCH_DIR"

export GIT_AUTHOR_NAME="vault-lfs-test"
export GIT_AUTHOR_EMAIL="vault-lfs-test@local"
export GIT_COMMITTER_NAME="vault-lfs-test"
export GIT_COMMITTER_EMAIL="vault-lfs-test@local"

# -------------------------
# Classify extensions (lib/classify.sh)
# -------------------------
section "Discovering file types in vault"

classify_extensions "$VAULT_DIR"
print_classification

# -------------------------
# Generate config files (lib/gitattributes.sh)
# -------------------------
GITATTRIBUTES_FILE="/tmp/vault-lfs-test-gitattributes"
GITIGNORE_FILE="/tmp/vault-lfs-test-gitignore"

generate_gitattributes "$GITATTRIBUTES_FILE"
generate_gitignore "$GITIGNORE_FILE"

# -------------------------
# Phase 1: Initialize scratch vault
# -------------------------
section "Phase 1 — Initialize scratch vault"

rsync -a --exclude='.git' --exclude='.workspace' "$VAULT_DIR/" "$SCRATCH_DIR/" 2>/dev/null \
  || { cp -r "$VAULT_DIR/." "$SCRATCH_DIR/"; log "rsync unavailable, used cp"; }

cp "$GITATTRIBUTES_FILE" "$SCRATCH_DIR/.gitattributes"
cp "$GITIGNORE_FILE" "$SCRATCH_DIR/.gitignore"
log "Vault content copied to scratch"

cd "$SCRATCH_DIR"

git init --quiet
git lfs install --local
log "git + LFS initialized"
log ".gitattributes written"
log ".gitignore written"
log "--- .gitattributes content ---"
while IFS= read -r line; do log "  $line"; done < "$SCRATCH_DIR/.gitattributes"
log "--- end ---"

git add -A
git commit --quiet -m "init: baseline vault state"
BASELINE_SHA=$(git rev-parse HEAD)
log "Baseline commit: $BASELINE_SHA"

# -------------------------
# Test 0: .gitattributes content validation
# -------------------------
section "Test 0 — .gitattributes content"

# Every LFS extension must have a filter=lfs rule
if [[ "${#LFS_EXTENSIONS[@]}" -eq 0 ]]; then
  skip "No LFS extensions — skipping LFS rule check"
else
  for ext in $(printf '%s\n' "${LFS_EXTENSIONS[@]}" | sort); do
    if grep -q "^\*\.${ext}[[:space:]].*filter=lfs" "$SCRATCH_DIR/.gitattributes" 2>/dev/null; then
      ok ".${ext} — filter=lfs rule present in .gitattributes"
    else
      fail ".${ext} — filter=lfs rule MISSING from .gitattributes"
    fi
  done
fi

# Every known-text extension present in vault must have a -filter override rule
for ext in $(printf '%s\n' "${KNOWN_TEXT_EXTENSIONS[@]}" | sort); do
  c="${EXT_COUNTS[$ext]:-0}"
  if [[ "$c" -eq 0 ]]; then continue; fi
  if grep -q "^\*\.${ext}[[:space:]].*-filter" "$SCRATCH_DIR/.gitattributes" 2>/dev/null; then
    ok ".${ext} — -filter override present in .gitattributes (${c} file(s) in vault)"
  else
    fail ".${ext} — -filter override MISSING from .gitattributes (${c} file(s) in vault)"
  fi
done

# No LFS extension should also have a -filter override (conflict check)
for ext in $(printf '%s\n' "${LFS_EXTENSIONS[@]}" | sort); do
  if grep -q "^\*\.${ext}[[:space:]].*-filter" "$SCRATCH_DIR/.gitattributes" 2>/dev/null; then
    fail ".${ext} — conflict: appears in both LFS rules and -filter override"
  fi
done

# -------------------------
# Test 1: LFS pointer storage per LFS extension
# -------------------------
section "Test 1 — LFS pointer storage by extension"

if [[ "${#LFS_EXTENSIONS[@]}" -eq 0 ]]; then
  skip "No LFS-tracked binary files present"
else
  for ext in $(printf '%s\n' "${LFS_EXTENSIONS[@]}" | sort); do
    c="${EXT_COUNTS[$ext]:-0}"
    if [[ "$c" -eq 0 ]]; then skip ".${ext} — no files found"; continue; fi

    find_first "$SCRATCH_DIR" "$ext" sample
    if [[ -z "$sample" ]]; then skip ".${ext} — file disappeared during setup"; continue; fi
    rel="${sample#$SCRATCH_DIR/}"
    fname="${sample##*/}"

    first_line=$(git cat-file blob "HEAD:${rel}" 2>/dev/null | head -1 || true)
    if [[ "$first_line" == "version https://git-lfs.github.com"* ]]; then
      ok ".${ext} — LFS pointer in git (sample: ${fname})"
    else
      fail ".${ext} — NOT stored as LFS pointer (sample: ${fname})"
      log "    First line: ${first_line}"
    fi

    real_size=$(cat -- "$sample" 2>/dev/null | wc -c || echo 0)
    if [[ "$real_size" -gt 150 ]]; then
      ok ".${ext} — working tree is real binary (${real_size} bytes)"
    else
      fail ".${ext} — working tree looks like pointer (${real_size} bytes) — LFS smudge not working"
    fi
  done
fi

# -------------------------
# Test 2: Text extensions not LFS-tracked
# -------------------------
section "Test 2 — Text extensions tracked normally (not LFS)"

if [[ "${#TEXT_EXTENSIONS[@]}" -eq 0 ]]; then
  skip "No text extensions to verify"
else
  for ext in $(printf '%s\n' "${TEXT_EXTENSIONS[@]}" | sort); do
    c="${EXT_COUNTS[$ext]:-0}"
    if [[ "$c" -eq 0 ]]; then continue; fi

    find_first "$SCRATCH_DIR" "$ext" sample_text
    if [[ -z "$sample_text" ]]; then continue; fi
    rel_text="${sample_text#$SCRATCH_DIR/}"
    fname_text="${sample_text##*/}"

    first_line=$(git cat-file blob "HEAD:${rel_text}" 2>/dev/null | head -1 || true)
    if [[ "$first_line" == "version https://git-lfs.github.com"* ]]; then
      fail ".${ext} — incorrectly stored as LFS pointer (sample: ${fname_text})"
    else
      ok ".${ext} — tracked as text, not LFS (sample: ${fname_text})"
    fi
  done
fi

# -------------------------
# Test 3: Text file rename detection (-M)
# -------------------------
section "Test 3 — Text rename detection (-M flag)"

find_first "$SCRATCH_DIR" "md" SAMPLE_MD
if [[ -z "$SAMPLE_MD" ]]; then
  skip "No .md files found"
else
  rel_md="${SAMPLE_MD#$SCRATCH_DIR/}"
  fname_md="${SAMPLE_MD##*/}"
  moved_md="${SAMPLE_MD%.md}-moved.md"
  rel_moved="${moved_md#$SCRATCH_DIR/}"

  git mv -- "$rel_md" "$rel_moved"
  git commit --quiet -m "test: rename ${fname_md}"

  if git diff -M "${BASELINE_SHA}..HEAD" | grep -q "rename from"; then
    ok "git diff -M detects rename for .md file"
  else
    fail "git diff -M did not produce rename record — check git version"
  fi

  git mv -- "$rel_moved" "$rel_md"
  git commit --quiet -m "test: restore ${fname_md}"
fi

# -------------------------
# Test 4: LFS attachment move (pointer rename detection)
# -------------------------
section "Test 4 — LFS attachment move diff"

if [[ "${#LFS_EXTENSIONS[@]}" -eq 0 ]]; then
  skip "No LFS-tracked files present"
else
  ext=$(printf '%s\n' "${LFS_EXTENSIONS[@]}" | sort | head -1)
  find_first "$SCRATCH_DIR" "$ext" SAMPLE_BIN
  if [[ -z "$SAMPLE_BIN" ]]; then
    skip ".${ext} — no file found"
  else
    rel_bin="${SAMPLE_BIN#$SCRATCH_DIR/}"
    fname_bin="${SAMPLE_BIN##*/}"
    moved_bin="${SAMPLE_BIN%.${ext}}-moved.${ext}"
    rel_moved_bin="${moved_bin#$SCRATCH_DIR/}"

    pre_move_sha=$(git rev-parse HEAD)
    git mv -- "$rel_bin" "$rel_moved_bin"
    git commit --quiet -m "test: move ${fname_bin}"

    move_diff=$(git diff -M "${pre_move_sha}..HEAD")
    if echo "$move_diff" | grep -q "rename from"; then
      ok ".${ext} move — rename record detected (efficient pointer rename)"
    elif echo "$move_diff" | grep -q "git-lfs"; then
      ok ".${ext} move — LFS pointer diff present (delete+add; rename threshold not met)"
      log "  Consider --find-renames=50% if attachment rename detection is important"
    else
      fail ".${ext} move — unexpected diff output"
      log "  Diff head: $(echo "$move_diff" | head -5)"
    fi

    git mv -- "$rel_moved_bin" "$rel_bin"
    git commit --quiet -m "test: restore ${fname_bin}"
  fi
fi

# -------------------------
# Test 5: --binary flag behavior with LFS
# -------------------------
section "Test 5 — --binary flag with LFS files"

if [[ "${#LFS_EXTENSIONS[@]}" -eq 0 ]]; then
  skip "No LFS-tracked files present"
else
  ext=$(printf '%s\n' "${LFS_EXTENSIONS[@]}" | sort | head -1)
  find_first "$SCRATCH_DIR" "$ext" SAMPLE_BIN5
  if [[ -z "$SAMPLE_BIN5" ]]; then
    skip ".${ext} — no file found"
  else
    fname_bin5="${SAMPLE_BIN5##*/}"
    new_bin="${SAMPLE_BIN5%.${ext}}-testcopy.${ext}"
    rel_new="${new_bin#$SCRATCH_DIR/}"

    pre_sha=$(git rev-parse HEAD)
    cp -- "$SAMPLE_BIN5" "$new_bin"
    git add -- "$rel_new"
    git commit --quiet -m "test: add copy of ${fname_bin5}"

    diff_with=$(git diff --binary "${pre_sha}..HEAD")
    diff_without=$(git diff "${pre_sha}..HEAD")

    if echo "$diff_with" | grep -q "git-lfs"; then
      ok "--binary with LFS: pointer text in diff (no raw binary blob) — correct"
    else
      fail "--binary with LFS: unexpected output — check LFS configuration"
    fi

    if echo "$diff_without" | grep -q "Binary files differ"; then
      fail "Without --binary: binary silently dropped from diff"
      log "  ACTION REQUIRED: patch lib/diff.sh — add --binary -M to diff_generate"
    elif echo "$diff_without" | grep -q "git-lfs"; then
      ok "Without --binary: LFS pointer still appears (pointer files are text — fine)"
    else
      fail "Without --binary: unexpected diff output"
      log "  Head: $(echo "$diff_without" | head -3)"
    fi

    git rm --quiet -- "$rel_new"
    git commit --quiet -m "test: remove copy of ${fname_bin5}"
  fi
fi

# -------------------------
# Test 6: Full diff pipeline simulation (--binary -M)
# -------------------------
section "Test 6 — Full diff pipeline (--binary -M)"

find_first "$SCRATCH_DIR" "md" SAMPLE_MD6
if [[ -n "$SAMPLE_MD6" ]]; then
  echo "" >> "$SAMPLE_MD6"
  echo "> vault-lfs-test pipeline edit" >> "$SAMPLE_MD6"
  git add -- "$SAMPLE_MD6"
  git commit --quiet -m "test: edit for pipeline test"
fi

STAGED_DIFF="/tmp/vault-staged.diff"
git diff --binary -M "${BASELINE_SHA}..HEAD" > "$STAGED_DIFF"
diff_size=$(wc -c < "$STAGED_DIFF")

if [[ "$diff_size" -gt 0 ]]; then
  ok "staged.diff generated with --binary -M (${diff_size} bytes)"
else
  skip "No changes from baseline — staged.diff empty"
fi

# -------------------------
# Test 7: git apply --3way on generated diff
# -------------------------
section "Test 7 — git apply --3way"

if [[ "$diff_size" -eq 0 ]]; then
  skip "No diff to apply"
else
  APPLY_TARGET="/tmp/vault-lfs-apply-target"
  rm -rf "$APPLY_TARGET"
  cp -r "$SCRATCH_DIR/." "$APPLY_TARGET/"
  git -C "$APPLY_TARGET" reset --hard "$BASELINE_SHA" --quiet

  if git -C "$APPLY_TARGET" apply --3way "$STAGED_DIFF" 2>/dev/null; then
    ok "git apply --3way succeeded on baseline target"
  else
    fail "git apply --3way failed — inspect $STAGED_DIFF"
  fi
fi

# -------------------------
# Test 8: git checkout restores LFS files
# -------------------------
section "Test 8 — git checkout restores LFS attachment state"

if [[ "${#LFS_EXTENSIONS[@]}" -eq 0 ]]; then
  skip "No LFS-tracked files present"
else
  current_head=$(git rev-parse HEAD)
  git checkout "$BASELINE_SHA" --quiet 2>/dev/null || true

  for ext in $(printf '%s\n' "${LFS_EXTENSIONS[@]}" | sort); do
    find_first "$SCRATCH_DIR" "$ext" sample8
    if [[ -z "$sample8" ]]; then skip ".${ext} — no file at baseline path"; continue; fi
    size8=$(cat -- "$sample8" 2>/dev/null | wc -c || echo 0)
    fname8="${sample8##*/}"
    if [[ "$size8" -gt 150 ]]; then
      ok ".${ext} — real binary restored after checkout (${size8} bytes, ${fname8})"
    else
      fail ".${ext} — looks like pointer after checkout (${size8} bytes) — LFS smudge not working"
    fi
  done

  git checkout "$current_head" --quiet 2>/dev/null \
    || git checkout - --quiet 2>/dev/null || true
fi

# -------------------------
# Summary
# -------------------------
section "Results"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo ""
echo "  LFS extensions:  ${LFS_EXTENSIONS[*]:-none}"
echo "  Text extensions: ${TEXT_EXTENSIONS[*]:-none}"
echo ""
echo "  Scratch vault:   $SCRATCH_DIR"
echo "  Staged diff:     $STAGED_DIFF"
echo ""

if [[ "$FAIL" -eq 0 ]]; then
  echo "All tests passed. LFS setup is valid for vault onboarding."
  exit 0
else
  echo "Some tests failed. Review output above before proceeding."
  exit 1
fi
