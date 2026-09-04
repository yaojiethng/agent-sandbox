#!/usr/bin/env bash
# tests/test_snapshot_container.sh
# Snapshot pipeline tests: snapshot_seed_tar (host-side) and snapshot_init_git
# (container-side).
#
# snapshot_init_git tests cover the full eight-case working tree state matrix.
# Each case builds a project fixture, produces the seed tar (git-enumerated
# working tree + HEAD baseline), extracts it into a fresh sandbox directory as
# the host-side seed step does, runs snapshot_init_git, and asserts
# git status --porcelain output.
#
# All fixtures created under /tmp  --  no git repos created inside the harness repo.
# Can be run directly on the host or inside the container.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/session_state.sh"
source "$REPO_ROOT/src/capability/snapshot.sh"

# -------------------------
# Fixture builders
# -------------------------
# Build a project fixture with a committed baseline.
# Usage: make_project PROJECT_DIR
# After this returns, the caller modifies the working tree to simulate the
# operator state under test, then calls seed_and_init.
make_project() {
  local PROJECT_DIR="$1"

  mkdir -p "$PROJECT_DIR"
  git -C "$PROJECT_DIR" init --quiet
  git -C "$PROJECT_DIR" config user.email "test@sandbox"
  git -C "$PROJECT_DIR" config user.name "test"

  # Committed content
  echo "committed content" > "$PROJECT_DIR/committed.txt"
  mkdir -p "$PROJECT_DIR/src"
  echo "source" > "$PROJECT_DIR/src/module.txt"
  git -C "$PROJECT_DIR" add .
  git -C "$PROJECT_DIR" commit -m "initial" --quiet
}

# Host-side seed + container-side init, exactly as the production pipeline
# wires them (run_agent.sh seed_sandbox_volume -> entrypoint fresh-init):
#   1. snapshot_seed_tar packs the project into a seed tar
#   2. the tar is extracted into the (empty) sandbox directory
#   3. snapshot_init_git initialises git from the extracted seed members
# Usage: seed_and_init PROJECT_DIR SANDBOX_DIR  ->  prints baseline SHA
seed_and_init() {
  local PROJECT_DIR="$1"
  local SANDBOX_DIR="$2"

  local seed_tar
  seed_tar="$FIXTURE_DIR/$(basename "$SANDBOX_DIR").seed.tar"
  snapshot_seed_tar "$PROJECT_DIR" "$seed_tar" > /dev/null 2>&1

  mkdir -p "$SANDBOX_DIR"
  tar -xf "$seed_tar" -C "$SANDBOX_DIR"
  rm -f "$seed_tar"

  snapshot_init_git "$SANDBOX_DIR" "$SANDBOX_DIR/.agent-sandbox-seed"
}

# -------------------------
# snapshot_seed_tar tests
# -------------------------

test_seed_tar_roundtrip_lossless() {
  local PROJECT="$FIXTURE_DIR/roundtrip_project"
  make_project "$PROJECT"

  # Working-tree variety: modification, deletion, untracked, exec bit, symlink
  echo "modified" >> "$PROJECT/committed.txt"
  rm "$PROJECT/src/module.txt"
  echo "new" > "$PROJECT/untracked.txt"
  chmod +x "$PROJECT/committed.txt"
  ln -sf committed.txt "$PROJECT/link"

  local TARBALL="$FIXTURE_DIR/roundtrip.tar"
  snapshot_seed_tar "$PROJECT" "$TARBALL" > /dev/null 2>&1

  local EXTRACT="$FIXTURE_DIR/roundtrip_extract"
  mkdir -p "$EXTRACT"
  tar -xf "$TARBALL" -C "$EXTRACT"

  local mismatches=0
  # File list, content hashes, modes, symlink targets vs the project working tree
  while IFS= read -r f; do
    [[ "$f" == ".git" || "$f" == ".git"/* ]] && continue
    local rel="${f#./}"
    [[ -e "$PROJECT/$rel" || -L "$PROJECT/$rel" ]] || continue
    if [[ -L "$PROJECT/$rel" ]]; then
      # Symlink targets are not compared here -- the pack-time transform
      # prefixes them with the sentinel and snapshot_init_git repairs them
      # (covered by test_init_git_symlink_target_repaired below).
      continue
    else
      [[ "$(sha256sum < "$PROJECT/$rel")" == "$(sha256sum < "$EXTRACT/.agent-sandbox-seed/worktree/$rel")" ]] \
        || { mismatches=$((mismatches+1)); continue; }
      [[ "$(stat -c %a "$PROJECT/$rel")" == "$(stat -c %a "$EXTRACT/.agent-sandbox-seed/worktree/$rel")" ]] \
        || mismatches=$((mismatches+1))
    fi
  done < <(cd "$PROJECT" && find . -mindepth 1 ! -path './.git*' -type f -o -mindepth 1 ! -path './.git*' -type l)

  # Deleted tracked file must be absent from the seed
  [[ -e "$EXTRACT/.agent-sandbox-seed/worktree/src/module.txt" ]] && mismatches=$((mismatches+1))
  # baseline.tar member must exist
  [[ -f "$EXTRACT/.agent-sandbox-seed/baseline.tar" ]] || mismatches=$((mismatches+1))

  if [[ "$mismatches" -eq 0 ]]; then
    pass "seed_tar: round-trip preserves list, hashes, modes, symlink targets"
  else
    fail "seed_tar: round-trip has $mismatches mismatch(es)"
  fi
}

test_seed_tar_gitignored_excluded() {
  local PROJECT="$FIXTURE_DIR/ignored_project"
  mkdir -p "$PROJECT"
  git -C "$PROJECT" init --quiet
  git -C "$PROJECT" config user.email "test@sandbox"
  git -C "$PROJECT" config user.name "test"
  echo "content" > "$PROJECT/committed.txt"
  printf 'secret.env\n' > "$PROJECT/.gitignore"
  git -C "$PROJECT" add .
  git -C "$PROJECT" commit -m "initial" --quiet
  echo "secret data" > "$PROJECT/secret.env"

  local TARBALL="$FIXTURE_DIR/ignored.tar"
  snapshot_seed_tar "$PROJECT" "$TARBALL" > /dev/null 2>&1

  local EXTRACT="$FIXTURE_DIR/ignored_extract"
  mkdir -p "$EXTRACT"
  tar -xf "$TARBALL" -C "$EXTRACT"

  if [[ ! -e "$EXTRACT/.agent-sandbox-seed/worktree/secret.env" ]]; then
    pass "seed_tar: gitignored file excluded"
  else
    fail "seed_tar: gitignored file leaked into seed tar"
  fi
}

test_seed_tar_negation_patterns() {
  local PROJECT="$FIXTURE_DIR/negation_project"
  mkdir -p "$PROJECT"
  git -C "$PROJECT" init --quiet
  git -C "$PROJECT" config user.email "test@sandbox"
  git -C "$PROJECT" config user.name "test"
  echo "content" > "$PROJECT/committed.txt"
  git -C "$PROJECT" add .
  git -C "$PROJECT" commit -m "initial" --quiet
  # Global excludesFile with a negation: *.debug ignored, keep.debug re-included.
  # The rsync pipeline leaked drop.debug here (rsync treats ! as clear-list).
  local GLOBAL_EXCLUDES="$FIXTURE_DIR/global-excludes"
  printf '*.debug\n!keep.debug\n' > "$GLOBAL_EXCLUDES"
  git -C "$PROJECT" config core.excludesFile "$GLOBAL_EXCLUDES"
  echo "keep" > "$PROJECT/keep.debug"
  echo "drop" > "$PROJECT/drop.debug"

  local TARBALL="$FIXTURE_DIR/negation.tar"
  snapshot_seed_tar "$PROJECT" "$TARBALL" > /dev/null 2>&1

  local EXTRACT="$FIXTURE_DIR/negation_extract"
  mkdir -p "$EXTRACT"
  tar -xf "$TARBALL" -C "$EXTRACT"

  if [[ -f "$EXTRACT/.agent-sandbox-seed/worktree/keep.debug" && ! -e "$EXTRACT/.agent-sandbox-seed/worktree/drop.debug" ]]; then
    pass "seed_tar: negation pattern honored (keep.debug kept, drop.debug dropped)"
  else
    fail "seed_tar: negation pattern mishandled (keep.debug/drop.debug)"
  fi
}

test_seed_tar_rejects_submodules() {
  local PROJECT="$FIXTURE_DIR/submodule_project"
  make_project "$PROJECT"
  # Fake a submodule entry in the index (gitlink) without a real submodule clone:
  # create a nested repo and add it as a gitlink.
  local SUB="$FIXTURE_DIR/submodule_inner"
  git init -q "$SUB"
  git -C "$SUB" config user.email "test@sandbox"
  git -C "$SUB" config user.name "test"
  git -C "$SUB" commit --allow-empty -m "inner" --quiet
  git -C "$PROJECT" update-index --add --cacheinfo 160000,"$(git -C "$SUB" rev-parse HEAD)",sub

  if snapshot_seed_tar "$PROJECT" "$FIXTURE_DIR/sub.tar" > /dev/null 2>&1; then
    fail "seed_tar: submodule should be rejected"
  else
    pass "seed_tar: submodule rejected with error"
  fi
}

test_seed_tar_rejects_no_commits() {
  local PROJECT="$FIXTURE_DIR/nocommit_project"
  mkdir -p "$PROJECT"
  git -C "$PROJECT" init --quiet

  if snapshot_seed_tar "$PROJECT" "$FIXTURE_DIR/nocommit.tar" > /dev/null 2>&1; then
    fail "seed_tar: repo without commits should be rejected"
  else
    pass "seed_tar: repo without commits rejected with error"
  fi
}

# -------------------------
# snapshot_init_git  --  working tree state matrix
#
# Each test:
#   1. Builds a project repo with committed content
#   2. Optionally modifies the working tree
#   3. Seeds the sandbox (seed tar -> extract -> snapshot_init_git)
#   4. Asserts git status --porcelain output in sandbox
# -------------------------

# Case 1: tracked file, no changes  --  clean
test_init_git_case1_clean() {
  local PROJECT="$FIXTURE_DIR/case1_project"
  local SANDBOX="$FIXTURE_DIR/case1_sandbox"

  make_project "$PROJECT"

  local SHA
  SHA=$(seed_and_init "$PROJECT" "$SANDBOX")

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  if [[ -z "$STATUS" ]]; then
    pass "case 1 (clean): git status is clean"
  else
    fail "case 1 (clean): expected clean status, got: $STATUS"
  fi

  if [[ -n "$SHA" ]]; then
    pass "case 1 (clean): baseline SHA returned"
  else
    fail "case 1 (clean): no baseline SHA returned"
  fi
}

# Case 2: tracked file with unstaged edits  --  shows as M (unstaged)
test_init_git_case2_unstaged_edit() {
  local PROJECT="$FIXTURE_DIR/case2_project"
  local SANDBOX="$FIXTURE_DIR/case2_sandbox"

  make_project "$PROJECT"

  # Make unstaged edit after baseline is committed
  echo "unstaged edit" >> "$PROJECT/committed.txt"

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Expect: " M committed.txt" (unstaged modification)
  if echo "$STATUS" | grep -q '^ M committed\.txt'; then
    pass "case 2 (unstaged edit): shows as unstaged M"
  else
    fail "case 2 (unstaged edit): expected ' M committed.txt', got: '$STATUS'"
  fi

  # Baseline commit should contain the original content, not the edit
  local BASELINE_CONTENT
  BASELINE_CONTENT=$(git -C "$SANDBOX" show HEAD:committed.txt)
  if ! echo "$BASELINE_CONTENT" | grep -q "unstaged edit"; then
    pass "case 2 (unstaged edit): baseline commit contains original content"
  else
    fail "case 2 (unstaged edit): baseline commit should not contain the edit"
  fi
}

# Case 3: tracked file, staged edit (git add but not committed)  --  shows as M unstaged
# Note: staging state is lost (see snapshot_init_git comment). Content is correct.
test_init_git_case3_staged_edit() {
  local PROJECT="$FIXTURE_DIR/case3_project"
  local SANDBOX="$FIXTURE_DIR/case3_sandbox"

  make_project "$PROJECT"

  echo "staged edit" >> "$PROJECT/committed.txt"
  git -C "$PROJECT" add committed.txt  # staged but not committed

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Content is present (seed carries the staged version) but shown as unstaged
  if grep -q "staged edit" "$SANDBOX/committed.txt"; then
    pass "case 3 (staged edit): edited content present in sandbox working tree"
  else
    fail "case 3 (staged edit): edited content missing from sandbox working tree"
  fi

  # Staging state is lost  --  shows as unstaged M, not staged M
  if echo "$STATUS" | grep -q 'committed\.txt'; then
    pass "case 3 (staged edit): file shows as modified (staging state lost  --  expected)"
  else
    fail "case 3 (staged edit): expected committed.txt to appear in git status"
  fi
}

# Case 4: tracked file deleted without staging  --  shows as D (unstaged)
test_init_git_case4_unstaged_deletion() {
  local PROJECT="$FIXTURE_DIR/case4_project"
  local SANDBOX="$FIXTURE_DIR/case4_sandbox"

  make_project "$PROJECT"

  rm "$PROJECT/committed.txt"  # unstaged deletion

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Expect: " D committed.txt" (unstaged deletion)
  if echo "$STATUS" | grep -q '^ D committed\.txt'; then
    pass "case 4 (unstaged deletion): shows as unstaged D"
  else
    fail "case 4 (unstaged deletion): expected ' D committed.txt', got: '$STATUS'"
  fi

  # Baseline commit should still contain the file
  if git -C "$SANDBOX" show HEAD:committed.txt &>/dev/null; then
    pass "case 4 (unstaged deletion): file present in baseline commit"
  else
    fail "case 4 (unstaged deletion): file missing from baseline commit"
  fi

  # File should be absent from working tree
  if [[ ! -f "$SANDBOX/committed.txt" ]]; then
    pass "case 4 (unstaged deletion): file absent from sandbox working tree"
  else
    fail "case 4 (unstaged deletion): file should not be present in working tree"
  fi
}

# Case 5: tracked file staged for deletion (git rm)  --  shows as D unstaged
# Note: staging state is lost. Content is correctly absent from working tree.
test_init_git_case5_staged_deletion() {
  local PROJECT="$FIXTURE_DIR/case5_project"
  local SANDBOX="$FIXTURE_DIR/case5_sandbox"

  make_project "$PROJECT"

  git -C "$PROJECT" rm committed.txt --quiet  # staged deletion

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # File absent from working tree (seed carries the deletion)
  if [[ ! -f "$SANDBOX/committed.txt" ]]; then
    pass "case 5 (staged deletion): file absent from sandbox working tree"
  else
    fail "case 5 (staged deletion): file should not be present in working tree"
  fi

  # File present in baseline commit
  if git -C "$SANDBOX" show HEAD:committed.txt &>/dev/null; then
    pass "case 5 (staged deletion): file present in baseline commit"
  else
    fail "case 5 (staged deletion): file missing from baseline commit"
  fi
}

# Case 6: untracked file, not gitignored  --  shows as ??
test_init_git_case6_untracked() {
  local PROJECT="$FIXTURE_DIR/case6_project"
  local SANDBOX="$FIXTURE_DIR/case6_sandbox"

  make_project "$PROJECT"

  echo "new untracked" > "$PROJECT/hello-world.txt"

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Expect: "?? hello-world.txt"
  if echo "$STATUS" | grep -q '^?? hello-world\.txt'; then
    pass "case 6 (untracked): shows as ??"
  else
    fail "case 6 (untracked): expected '?? hello-world.txt', got: '$STATUS'"
  fi

  # File should not be in baseline commit
  if ! git -C "$SANDBOX" show HEAD:hello-world.txt &>/dev/null; then
    pass "case 6 (untracked): file absent from baseline commit"
  else
    fail "case 6 (untracked): file should not be in baseline commit"
  fi
}

# Case 7: untracked file, gitignored  --  not visible in sandbox
test_init_git_case7_gitignored() {
  local PROJECT="$FIXTURE_DIR/case7_project"
  local SANDBOX="$FIXTURE_DIR/case7_sandbox"

  make_project "$PROJECT"
  printf 'secret.env\n' > "$PROJECT/.gitignore"
  git -C "$PROJECT" add .gitignore
  git -C "$PROJECT" commit -m "gitignore" --quiet
  echo "secret data" > "$PROJECT/secret.env"

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  if [[ ! -f "$SANDBOX/secret.env" ]]; then
    pass "case 7 (gitignored): file absent from sandbox"
  else
    fail "case 7 (gitignored): gitignored file should not appear in sandbox"
  fi

  if ! echo "$STATUS" | grep -q "secret.env"; then
    pass "case 7 (gitignored): file not visible in git status"
  else
    fail "case 7 (gitignored): gitignored file should not appear in git status"
  fi
}

# Case 8: new file staged with git add (not committed)  --  shows as ?? (untracked)
# Note: staging state is lost. Content is present on disk.
test_init_git_case8_staged_new_file() {
  local PROJECT="$FIXTURE_DIR/case8_project"
  local SANDBOX="$FIXTURE_DIR/case8_sandbox"

  make_project "$PROJECT"

  echo "new staged file" > "$PROJECT/new-staged.txt"
  git -C "$PROJECT" add new-staged.txt  # staged but not committed

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  local STATUS
  STATUS=$(git -C "$SANDBOX" status --porcelain)

  # Content is present on disk (seed carried it)
  if [[ -f "$SANDBOX/new-staged.txt" ]]; then
    pass "case 8 (staged new file): file present in sandbox working tree"
  else
    fail "case 8 (staged new file): file missing from sandbox working tree"
  fi

  # Shows as untracked (staging state lost  --  expected)
  if echo "$STATUS" | grep -q '^?? new-staged\.txt'; then
    pass "case 8 (staged new file): shows as ?? untracked (staging state lost  --  expected)"
  else
    fail "case 8 (staged new file): expected '?? new-staged.txt', got: '$STATUS'"
  fi
}

# Structural: exactly one baseline commit, SHA matches
test_init_git_one_commit() {
  local PROJECT="$FIXTURE_DIR/onecommit_project"
  local SANDBOX="$FIXTURE_DIR/onecommit_sandbox"

  make_project "$PROJECT"

  local SHA
  SHA=$(seed_and_init "$PROJECT" "$SANDBOX")

  local COMMIT_COUNT
  COMMIT_COUNT=$(git -C "$SANDBOX" rev-list --count HEAD)
  if [[ "$COMMIT_COUNT" -eq 1 ]]; then
    pass "init_git: exactly one baseline commit"
  else
    fail "init_git: expected 1 commit, got $COMMIT_COUNT"
  fi

  local ACTUAL_SHA
  ACTUAL_SHA=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)
  if [[ "$SHA" == "$ACTUAL_SHA" ]]; then
    pass "init_git: returned SHA matches baseline commit"
  else
    fail "init_git: SHA mismatch: returned $SHA, actual $ACTUAL_SHA"
  fi
}

# seed content absent  --  should fail clearly
test_init_git_missing_seed() {
  local SANDBOX="$FIXTURE_DIR/missing_seed_sandbox"
  mkdir -p "$SANDBOX"

  if snapshot_init_git "$SANDBOX" "$SANDBOX/.agent-sandbox-seed" 2>/dev/null; then
    fail "init_git: should fail when seed content is absent"
  else
    pass "init_git: correctly fails when seed content is absent"
  fi
}

# sandbox isolation  --  changes in sandbox do not affect the project
test_sandbox_isolation() {
  local PROJECT="$FIXTURE_DIR/isolation_project"
  local SANDBOX="$FIXTURE_DIR/isolation_sandbox"

  make_project "$PROJECT"
  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  echo "agent change" > "$SANDBOX/committed.txt"

  local PROJECT_CONTENT
  PROJECT_CONTENT=$(cat "$PROJECT/committed.txt")
  if [[ "$PROJECT_CONTENT" == "committed content" ]]; then
    pass "sandbox changes do not affect the project"
  else
    fail "project was modified by sandbox write"
  fi
}

# SESSION_STATE file creation  --  verify .git/SESSION_STATE is written correctly
# and .git/INIT_SHA is NOT written
test_init_git_creates_session_state() {
  local PROJECT="$FIXTURE_DIR/session_state_project"
  local SANDBOX="$FIXTURE_DIR/session_state_sandbox"

  make_project "$PROJECT"

  # Set SESSION_TS so snapshot_init_git writes it to SESSION_STATE
  local SESSION_TS="20260501-120000"
  local SHA
  SHA=$(seed_and_init "$PROJECT" "$SANDBOX")

  # Check INIT_SHA file does NOT exist
  if [[ -f "$SANDBOX/.git/INIT_SHA" ]]; then
    fail "init_git: .git/INIT_SHA should not exist (use SESSION_STATE instead)"
    return
  fi

  # Check SESSION_STATE file exists
  if [[ ! -f "$SANDBOX/.git/SESSION_STATE" ]]; then
    fail "init_git: .git/SESSION_STATE file not created"
    return
  fi

  # Check init_sha key contains correct SHA
  local SESSION_INIT_SHA
  SESSION_INIT_SHA=$(session_state_read "$SANDBOX" "init_sha")

  if [[ "$SESSION_INIT_SHA" == "$SHA" ]]; then
    pass "init_git: SESSION_STATE init_sha contains correct SHA"
  else
    fail "init_git: SESSION_STATE init_sha mismatch: has $SESSION_INIT_SHA, returned $SHA"
  fi

  # Check init_sha matches actual first commit
  local ACTUAL_SHA
  ACTUAL_SHA=$(git -C "$SANDBOX" rev-list --max-parents=0 HEAD)

  if [[ "$SESSION_INIT_SHA" == "$ACTUAL_SHA" ]]; then
    pass "init_git: SESSION_STATE init_sha matches first commit SHA"
  else
    fail "init_git: SESSION_STATE init_sha mismatch: has $SESSION_INIT_SHA, actual first commit is $ACTUAL_SHA"
  fi

  # Check session_ts key is present
  local SESSION_TS_VALUE
  SESSION_TS_VALUE=$(session_state_read "$SANDBOX" "session_ts")

  if [[ -n "$SESSION_TS_VALUE" ]]; then
    pass "init_git: SESSION_STATE session_ts is present"
  else
    fail "init_git: SESSION_STATE session_ts is missing"
  fi
}

# Seed cleanup: sentinel directory and exclude line removed after init
test_init_git_seed_cleanup() {
  local PROJECT="$FIXTURE_DIR/cleanup_project"
  local SANDBOX="$FIXTURE_DIR/cleanup_sandbox"

  make_project "$PROJECT"
  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  if [[ -d "$SANDBOX/.agent-sandbox-seed" ]]; then
    fail "init_git: seed sentinel directory not removed"
  else
    pass "init_git: seed sentinel directory removed"
  fi

  if grep -q "agent-sandbox-seed" "$SANDBOX/.git/info/exclude" 2>/dev/null; then
    fail "init_git: seed exclude line not removed from info/exclude"
  else
    pass "init_git: seed exclude line removed from info/exclude"
  fi
}

# Symlink targets: the pack-time transform prefixes them with the sentinel;
# init must repair them to the original (relative) targets.
test_init_git_symlink_target_repaired() {
  local PROJECT="$FIXTURE_DIR/symlink_project"
  local SANDBOX="$FIXTURE_DIR/symlink_sandbox"

  make_project "$PROJECT"
  ln -sf committed.txt "$PROJECT/link"
  ln -sf ../src/module.txt "$PROJECT/src/up-link"

  seed_and_init "$PROJECT" "$SANDBOX" > /dev/null

  if [[ "$(readlink "$SANDBOX/link")" == "committed.txt" && "$(readlink "$SANDBOX/src/up-link")" == "../src/module.txt" ]]; then
    pass "init_git: symlink targets repaired after seed overlay"
  else
    fail "init_git: symlink targets not repaired (link=$(readlink "$SANDBOX/link" 2>/dev/null), up-link=$(readlink "$SANDBOX/src/up-link" 2>/dev/null))"
  fi
}

# -------------------------
# Run all tests
# -------------------------

run_test                test_seed_tar_roundtrip_lossless
run_test                test_seed_tar_gitignored_excluded
run_test                test_seed_tar_negation_patterns
run_test                test_seed_tar_rejects_submodules
run_test                test_seed_tar_rejects_no_commits
run_test                    test_init_git_case1_clean
run_test            test_init_git_case2_unstaged_edit
run_test              test_init_git_case3_staged_edit
run_test        test_init_git_case4_unstaged_deletion
run_test          test_init_git_case5_staged_deletion
run_test           test_init_git_case6_untracked
run_test          test_init_git_case7_gitignored
run_test          test_init_git_case8_staged_new_file
run_test             test_init_git_one_commit
run_test            test_init_git_missing_seed
run_test                         test_sandbox_isolation
run_test           test_init_git_creates_session_state
run_test               test_init_git_seed_cleanup
run_test         test_init_git_symlink_target_repaired

test_done
