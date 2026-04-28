#!/usr/bin/env bash
# tests/libs/git_fixtures.sh
# Canonical git repo setup helpers for test files.

# make_committed_repo DIR
#   Creates a fresh git repository with one baseline commit on 'main'.
make_committed_repo() {
  local DIR="$1"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init --quiet --initial-branch=main 2>/dev/null || {
    git -C "$DIR" init --quiet
    git -C "$DIR" branch -M main 2>/dev/null || true
  }
  git -C "$DIR" config user.email "test@fixture"
  git -C "$DIR" config user.name "Test Fixture"
  echo "baseline" > "$DIR/file.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "baseline" --quiet
}

# get_init_sha DIR
#   Returns the SHA of the first commit in the repository.
get_init_sha() {
  git -C "$1" rev-list --max-parents=0 HEAD
}

# commit_change DIR [MSG]
#   Creates a new file and commits it with the given message.
commit_change() {
  local DIR="$1"
  local MSG="${2:-agent commit}"
  echo "$MSG" > "$DIR/change-${RANDOM}.txt"
  git -C "$DIR" add .
  git -C "$DIR" commit -m "$MSG" --quiet
}
