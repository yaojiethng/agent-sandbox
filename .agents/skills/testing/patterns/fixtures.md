# Fixture patterns

Open this when you create, name or clean a fixture, or share a helper between files. Every pattern here applies the skill's judgements: isolation, clean before create, no shared state between calls, and self-contained files.

## Unique paths per test

When two tests build a fixture, give each one paths derived from its own test name, under the per-test `$FIXTURE_DIR`.

```bash
test_draft_creates_branch() {
  local P="$FIXTURE_DIR/draft_branch_p"
  local S="$FIXTURE_DIR/draft_branch_s"
  make_project "$P"
  make_session "$P" "$S"
  ...
}

test_draft_applies_patches() {
  local P="$FIXTURE_DIR/draft_patches_p"
  local S="$FIXTURE_DIR/draft_patches_s"
  make_project "$P"
  make_session "$P" "$S"
  ...
}
```

## Unique paths per helper call

When a helper creates subdirectories, scope them to the caller's path, not to a shared fixture root.

```bash
# Right: the sandbox path is unique per SANDBOX_DIR
make_session() {
  local SANDBOX_DIR="$1"
  local SANDBOX="$SANDBOX_DIR/sandbox-work"
  rm -rf "$SANDBOX"
  ...
}

# Wrong: the sandbox path is shared across tests
make_session() {
  local SESSION="$1"
  local SANDBOX="$FIXTURE_DIR/sandbox-${SESSION}"
  ...
}
```

## Clean only what you own

When a helper is called more than once in a test, create the parent it needs and remove only its own target. Removing the parent destroys state an earlier call created.

```bash
# Right: creates the parent if needed and cleans only this session
make_session() {
  local SANDBOX_DIR="$1"
  local SESSION="$2"
  mkdir -p "$SANDBOX_DIR/.workspace"
  local SESSION_DIR="$SANDBOX_DIR/.workspace/session-diffs/$SESSION"
  rm -rf "$SESSION_DIR"
  mkdir -p "$SESSION_DIR/patches"
  ...
}

# Wrong: destroys every session, including the ones just created
make_session() {
  local SANDBOX_DIR="$1"
  local SESSION="$2"
  rm -rf "$SANDBOX_DIR/.workspace"
  mkdir -p "$SANDBOX_DIR/.workspace"
  ...
}
```

## Clean before create

When a helper creates a directory, remove stale state first. An implicit assumption that the directory is empty fails on a re-run or in a different order.

```bash
# Right
make_project() {
  rm -rf "$DIR"
  mkdir -p "$DIR"
  git -C "$DIR" init
  ...
}

# Wrong: assumes the directory is empty
make_project() {
  mkdir -p "$DIR"
  git -C "$DIR" init
  ...
}
```

## Source shared fixtures, never a test file

When a helper is needed by two files, move it to `tests/libs/` and source it from both. Sourcing a test file to reuse its helpers executes that file's tests as a side effect.

```bash
# Wrong
source "$REPO_ROOT/test_draft_workflow.sh"

# Right
source "$REPO_ROOT/tests/libs/git_fixtures.sh"
```

## Where a helper belongs

A `tests/libs/` file holds helper functions and no test execution. A helper belongs there if and only if two or more test files use it; otherwise it lives in the test file that uses it. A new file needs a category boundary: if the helper fits no existing file, name the new file for its distinct scope. Every helper follows the judgements above.

## Where the helpers live

Helpers used by more than one test file live in `tests/libs/` and are sourced explicitly. The directory is the source of truth; this table is a reading of it.

| File | Contains |
|---|---|
| `tests/libs/test_common.sh` | per-test accounting and isolation: `pass()`, `fail()`, `run_test()`, `test_done()`, `get_fixture_dir()` |
| `tests/libs/git_fixtures.sh` | git repo setup: `make_repo()`, `make_committed_repo()`, `make_sandbox_fixture()`, `get_init_sha()`, `write_session_state()`, `commit_change()` |
| `tests/libs/session_fixtures.sh` | the session fixture: `make_session_fixture()`, the unified session directory creator with optional patches and `uncommitted.diff` |
| `tests/libs/draft_fixtures.sh` | draft workflow fixtures: the helpers shared by the draft, confirm and reject tests |

Every test file sources `test_common.sh` instead of defining `pass()` and `fail()` inline.

```bash
source "$REPO_ROOT/tests/libs/test_common.sh"
```

## In knowledge, workflow and diagnostic files

A `knowledge_*.sh` or `workflow_*.sh` file sources the shared fixtures instead of defining the accounting inline:

| Boilerplate | Source instead | Files |
|---|---|---|
| `pass()`, `fail()`, `PASS=0`, `FAIL=0` | `tests/libs/test_common.sh` | every `knowledge_*.sh` and `workflow_*.sh` |
| `make_repo()`, `make_committed_repo()` | `tests/libs/git_fixtures.sh` | any file that creates git repositories |
| `make_session_fixture()`, `make_draft_fixture()` | `tests/libs/session_fixtures.sh` | workflow tests needing session or draft fixtures |

A domain-specific helper one file uses stays local; do not add it to a shared library until a second consumer exists.

A diagnostic script that runs in a container keeps inline `pass()` and `fail()`: `tests/libs/` is not on the container filesystem.
