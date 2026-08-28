#!/usr/bin/env bash
# tests/test_image_names.sh — Unit tests for src/build/image.sh naming.
#
# These four functions are the docker tag contract. Prune, resume, build and
# compose re-derive image names independently, so any drift here breaks
# cross-layer resource addressing silently.
#
# Run:
#   bash tests/test_image_names.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/build/image.sh"

# agent_base_image_name lowercases the provider.
test_agent_base_image_name_lowercases_provider() {
  local out
  out=$(agent_base_image_name "Pi")
  if [[ "$out" == "pi-base" ]]; then
    pass "agent_base_image_name lowercases provider"
  else
    fail "agent_base_image_name Pi → '$out', want 'pi-base'"
  fi
}

# agent_image_name lowercases the PROJECT position only. The provider is used
# verbatim: providers come from directory names under src/reasoning/providers/
# and are lowercase by construction. An uppercase provider would leak into a
# docker tag (invalid) — pinned here so a future change to that behavior is a
# deliberate decision, not an accident.
test_agent_image_name_lowercases_project_only() {
  local out
  out=$(agent_image_name "pi" "MyProject")
  if [[ "$out" == "pi-agent-myproject" ]]; then
    pass "agent_image_name lowercases project, keeps provider verbatim"
  else
    fail "agent_image_name pi MyProject → '$out', want 'pi-agent-myproject'"
  fi
}

test_sandbox_image_name_lowercases_project() {
  local out
  out=$(sandbox_image_name "TeSt-Prj")
  if [[ "$out" == "sandbox-test-prj" ]]; then
    pass "sandbox_image_name lowercases project"
  else
    fail "sandbox_image_name TeSt-Prj → '$out', want 'sandbox-test-prj'"
  fi
}

# shared_base_image_name is a single canonical constant; all providers inherit
# from it, so it must not drift between build orchestrators.
test_shared_base_image_name_is_constant() {
  local out
  out=$(shared_base_image_name)
  if [[ "$out" == "agent-node-base" ]]; then
    pass "shared_base_image_name returns canonical constant"
  else
    fail "shared_base_image_name → '$out', want 'agent-node-base'"
  fi
}

# Missing arguments are hard errors (:? expansions), never empty-tag builds.
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
