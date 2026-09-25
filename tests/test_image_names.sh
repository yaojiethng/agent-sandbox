#!/usr/bin/env bash
# tests/test_image_names.sh  --  Unit tests for src/build/image.sh naming.
#
# Pins cite: docs/architecture/tool_interface.md naming table (l.15, l.28).

# These four functions are the docker tag contract. Build and compose consume
# the names directly, so any drift here breaks cross-layer resource addressing
# silently. Prune addresses resources by label and never names an image; resume
# parses the provider back out of the tag, consuming the shape rather than
# re-deriving it.
#
# Run:
#   bash tests/test_image_names.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/build/image.sh"

# agent_base_image_name lowercases the provider.
# Given: provider "Pi" (uppercase)
# When:  agent_base_image_name runs
# Then:  it prints pi-base
# Asserts: the provider is lowercased in the base tag
# Note:  the sibling agent_image_name must keep the provider verbatim; that half is
#        unasserted here and recorded as finding 86
test_agent_base_image_name_lowercases_provider() {
  local out
  out=$(agent_base_image_name "Pi")
  assert_eq "$out" "pi-base" "agent_base_image_name lowercases provider"
}

# agent_image_name lowercases the PROJECT position only. The provider is used
# verbatim: providers come from directory names under src/reasoning/providers/
# and are lowercase by construction. An uppercase provider would leak into a
# docker tag (invalid)  --  pinned here so a future change to that behavior is a
# deliberate decision, not an accident.
# Given: provider "pi" and project "MyProject"
# When:  agent_image_name runs
# Then:  it prints pi-agent-myproject
# Asserts: the project is lowercased
# Note:  the provider is already lowercase, so the verbatim half of the rule this
#        comment states is not exercised; bite V3 survives. Finding 86
test_agent_image_name_lowercases_project_only() {
  local out
  out=$(agent_image_name "pi" "MyProject")
  assert_eq "$out" "pi-agent-myproject" "agent_image_name lowercases project, keeps provider verbatim"
}

# Given: project "TeSt-Prj"
# When:  sandbox_image_name runs
# Then:  it prints sandbox-test-prj
# Asserts: the project is lowercased in the capability tag
test_sandbox_image_name_lowercases_project() {
  local out
  out=$(sandbox_image_name "TeSt-Prj")
  assert_eq "$out" "sandbox-test-prj" "sandbox_image_name lowercases project"
}

# shared_base_image_name is a single canonical constant; all providers inherit
# from it, so it must not drift between build orchestrators.
# Given: no arguments
# When:  shared_base_image_name runs
# Then:  it prints agent-node-base
# Asserts: the shared reasoning-layer base is one canonical constant
test_shared_base_image_name_is_constant() {
  local out
  out=$(shared_base_image_name)
  assert_eq "$out" "agent-node-base" "shared_base_image_name returns canonical constant"
}

# Missing arguments are hard errors (:? expansions), never empty-tag builds.
# Given: a required argument omitted from the call
# When:  each naming function runs in a subshell
# Then:  the subshell returns non-zero
# Asserts: the ${n:?} guards keep an empty tag out of a docker build
# Note:  image_digest carries the same guard and is not covered here; finding 87
test_missing_args_are_hard_errors() {
  local ok=true
  (agent_base_image_name 2>/dev/null) && ok=false
  (agent_image_name "pi" 2>/dev/null) && ok=false
  (sandbox_image_name 2>/dev/null) && ok=false
  if [[ "$ok" == true ]]; then
    pass "naming functions fail hard on missing args"
  else
    fail "a naming function accepted missing args (empty tag risk)"
  fi
}

echo "=== image name derivation tests ==="
echo

run_test test_agent_base_image_name_lowercases_provider
run_test test_agent_image_name_lowercases_project_only
run_test test_sandbox_image_name_lowercases_project
run_test test_shared_base_image_name_is_constant
run_test test_missing_args_are_hard_errors

test_done

