#!/usr/bin/env bash
# tests/extensions/pi/model-refresh/knowledge/knowledge_model_refresh_real_load.sh
# TEST_DEADLINE: 240
#
# Knowledge test: the extension loads and its `session_start` handler runs in a
# real pi session, in the TUI branch the unit suite cannot reach.
#
# The unit suite loads the extension under jiti and drives its handlers with
# hand-built contexts. That proves the module parses and registers, and it
# proves each handler against its stub, but the stub is written by the same hand
# that wrote the extension, so it can encode the extension's assumption about pi
# instead of pi's API. A wrong receiver - `ctx.getSettings()` for
# `pi.getSettings()` - passed the suite and threw on every real start.
#
# `pi -p` does not cover this: the handler returns before the default-model
# guard when `ctx.mode !== "tui"`, so only interactive mode reaches the branch.
# This runs the interactive mode under a pseudo-terminal with one prompt, then
# looks for the error pi prints for a throwing handler and for the notice only
# the TUI branch renders.
#
# It needs a model and a network, so it is a knowledge test and not part of
# make test.
#
# Reference:
#   src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md
#     -- the default-model guard this exercises.
#
# Not run by make test. Run manually:
#   OPENCODE_API_KEY=... bash tests/extensions/pi/model-refresh/knowledge/knowledge_model_refresh_real_load.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(cd "$HERE/.." && pwd)"
REPO_TOP="$(cd "$SUITE_DIR/../../../.." && pwd)"
# shellcheck source=../../../libs/test_common.sh
source "$REPO_TOP/tests/libs/test_common.sh"

test_setup

EXTENSION_ENTRY="$REPO_TOP/src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts"

# -------------------------
# Tests
# -------------------------

test_the_key_is_present() {
  if [[ -n "${OPENCODE_API_KEY:-}" ]]; then
    pass "OPENCODE_API_KEY is set"
  else
    skip "OPENCODE_API_KEY is not set: pi cannot reach a model"
  fi
}

test_the_extension_entry_is_present() {
  if [[ -f "$EXTENSION_ENTRY" ]]; then
    pass "the extension entry exists"
  else
    fail "the extension entry exists at $EXTENSION_ENTRY"
  fi
}

test_the_tui_branch_runs_without_an_extension_error() {
  if ! command -v script >/dev/null 2>&1; then
    skip "script(1) is unavailable: no pseudo-terminal for the TUI"
    return
  fi
  local log
  log="$FIXTURE_DIR/real-load.log"
  # `-ne` disables extension discovery, so only the `-e` path loads and no
  # installed copy can contribute an error. The fixture config keeps the user's
  # settings and credentials out of the run, and the cache override keeps the
  # extension from writing its cache into the repository. The interactive mode
  # redraws until killed, so the timeout terminates it and the log, not the
  # exit status, is the subject.
  PI_CODING_AGENT_DIR="$FIXTURE_DIR" MODEL_REFRESH_CACHE="$FIXTURE_DIR/cache.json" timeout 90 script -qec \
    "pi -ne -np -nc -e '$EXTENSION_ENTRY' --provider opencode-go --model space-bunny-free --thinking low --no-session 'reply ok'" \
    /dev/null </dev/null >"$log" 2>&1 || true
  if grep -qE 'Extension .* error|is not a function' "$log"; then
    fail "no extension error in a real TUI session (found: $(grep -oE 'is not a function|Extension "[^"]*" error' "$log" | head -1))"
    return
  fi
  if ! grep -q "model-refresh" "$log"; then
    fail "the extension appears in the real session"
    return
  fi
  # The TUI branch is the one under test; the print branch is not reached here.
  # A notice is what that branch renders, so its absence means the branch did
  # not run and the error check above proved nothing.
  if ! grep -qE 'updated catalog:|endpoint fetch failed|models.dev metadata unavailable|saved default ' "$log"; then
    fail "the TUI branch rendered a notice (updated catalog, a failure, or a discarded default)"
    return
  fi
  pass "the extension loads and its TUI branch runs with no error"
}

# -------------------------
# Run
# -------------------------

run_test test_the_key_is_present
run_test test_the_extension_entry_is_present
run_test test_the_tui_branch_runs_without_an_extension_error

test_done
