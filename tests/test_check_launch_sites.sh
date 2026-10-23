#!/usr/bin/env bash
# tests/test_check_launch_sites.sh
# The launch-site gate: `scripts/check_launch_sites.sh` over a fixture tree.
#
# The gate exists for a defect that reading found twice: a consumer that takes
# its model from the role table and names the provider itself. Each case plants
# one such site and asserts the gate names it, then asserts the same tree is
# clean without the plant, so a gate that always passes cannot pass this file.
#
# Covers:
#   clean      --  a tree whose only launcher call is the library, and whose
#                  examples are in a document and a test, is clean
#   house      --  a new launch site in the house style is named
#   provider   --  a provider flag beside a pi call in the same line is named
#   opencode   --  an `opencode run` call is named

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_launch_sites.sh"

# fixture_tree --  a tree with the library, the entrypoint, a document that quotes
# a launcher, and a test that asserts one. All are clean by construction.
fixture_tree() {
  local root="$FIXTURE_DIR/tree"
  mkdir -p "$root/src/libs/dispatch" "$root/scripts" "$root/tests" "$root/docs" \
    "$root/src/reasoning/providers/pi/config/agent/bin"
  printf 'export function argvFor() { return ["pi"]; }\n' >"$root/src/libs/dispatch/launch.ts"
  printf '#!/usr/bin/env bash\nbash "$CLI" command --role _R\n' >"$root/scripts/dispatch.sh"
  printf '#!/usr/bin/env bash\nexec pi -p "$brief" --provider p --model m\n' \
    >"$root/src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh"
  printf 'Run `pi -p "$(cat brief.md)" --provider p` to dispatch.\n' >"$root/docs/guide.md"
  printf 'assert_contains "$out" "pi --provider p"\n' >"$root/tests/test_argv.sh"
  printf '%s\n' "$root"
}

run_gate() {
  local root="$1" out rc
  out="$(LAUNCH_SITE_SCAN_ROOT="$root" bash "$GATE" 2>&1)"; rc=$?
  assert_rc "$rc" 0 "the gate accepts a tree whose launches are behind the library"
  assert_contains "$out" "launch sites: clean" "the clean tree reports clean"
}

test_clean_tree_passes() {
  run_gate "$(fixture_tree)"
}

test_a_new_launch_site_is_named() {
  local root out rc
  root="$(fixture_tree)"
  printf '#!/usr/bin/env bash\nexec pi -p "$(cat brief.md)"\n' >"$root/scripts/eval_case.sh"
  out="$(LAUNCH_SITE_SCAN_ROOT="$root" bash "$GATE" 2>&1)"; rc=$?
  assert_rc "$rc" 1 "a launch site outside the allowlist fails the gate"
  assert_contains "$out" "scripts/eval_case.sh:2" "the gate names the file and the line"
}

test_a_named_provider_beside_a_pi_call_is_named() {
  local root out rc
  root="$(fixture_tree)"
  printf '#!/usr/bin/env bash\npi --provider opencode-go --model m -p "$b"\n' >"$root/scripts/case.sh"
  out="$(LAUNCH_SITE_SCAN_ROOT="$root" bash "$GATE" 2>&1)"; rc=$?
  assert_rc "$rc" 1 "a consumer naming its own provider fails the gate"
  assert_contains "$out" "scripts/case.sh:2" "the gate names the second line"
}

test_an_opencode_run_is_named() {
  local root out rc
  root="$(fixture_tree)"
  printf '#!/usr/bin/env bash\nopencode run --auto -m opencode/x-free "$b"\n' >"$root/scripts/oc.sh"
  out="$(LAUNCH_SITE_SCAN_ROOT="$root" bash "$GATE" 2>&1)"; rc=$?
  assert_rc "$rc" 1 "a consumer building an OpenCode argv fails the gate"
  assert_contains "$out" "scripts/oc.sh:2" "the gate names the OpenCode site"
}

run_test test_clean_tree_passes
run_test test_a_new_launch_site_is_named
run_test test_a_named_provider_beside_a_pi_call_is_named
run_test test_an_opencode_run_is_named

test_done
