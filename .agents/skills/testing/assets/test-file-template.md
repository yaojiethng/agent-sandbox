# The test file template

Copy the block into `tests/test_<subject>.sh` and replace the example. The shape is mandatory: one `test_setup` at file scope, one registration block, one `test_done`, and nothing after it.

```bash
#!/usr/bin/env bash
# tests/test_example.sh

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_SCRIPT="$TEST_DIR/../scripts/example.sh"

# Shared fixtures - source only from tests/libs/
source "$TEST_DIR/libs/test_common.sh"
source "$TEST_DIR/libs/git_fixtures.sh"

test_setup

# -------------------------
# Local helpers (not shared across files)
# -------------------------

make_fixture() {
  local DIR="$1"
  rm -rf "$DIR"
  mkdir -p "$DIR"
  ...
}

# -------------------------
# Tests
# -------------------------

test_example_feature() {
  local P="$FIXTURE_DIR/example_p"
  local S="$FIXTURE_DIR/example_s"
  make_fixture "$P"
  make_fixture "$S"
  if [[ condition ]]; then
    pass "description"
  else
    fail "description"
  fi
}

# -------------------------
# Run all tests
# -------------------------

run_test test_example_feature

test_done
```
