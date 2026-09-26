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

# docker double: `docker image inspect --format {{.Id}} NAME` reports a digest
# on stdout and a diagnostic on stderr, so a unit can tell suppression from
# leakage. Every other invocation is a no-op.
docker() {
  if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
    echo "sha256:stubid"
    echo "docker-stub: inspect diagnostic" >&2
    return 0
  fi
  return 0
}

# agent_base_image_name lowercases the provider.
# Given: provider "Pi" (uppercase)
# When:  agent_base_image_name runs
# Then:  it prints pi-base
# Asserts: the provider is lowercased in the base tag
# Note:  the sibling agent_image_name must keep the provider verbatim; that half is
#        unasserted here
test_agent_base_image_name_lowercases_provider() {
  local out
  out=$(agent_base_image_name "Pi")
  assert_eq "$out" "pi-base" "agent_base_image_name lowercases provider"
}

# agent_image_name lowercases the PROJECT position only. The provider is used
# verbatim inside the tag, so the unit passes an uppercase provider and
# asserts that it survives. The project is lowercased.
# Given: provider "Pi" and project "MyProject"
# When:  agent_image_name runs
# Then:  it prints Pi-agent-myproject
# Asserts: the provider is kept verbatim while the project is lowercased.
test_agent_image_name_lowercases_project_only() {
  local out
  out=$(agent_image_name "Pi" "MyProject")
  assert_eq "$out" "Pi-agent-myproject" "agent_image_name lowercases project, keeps provider verbatim"
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
# When:  each naming function and image_digest runs in a subshell with a docker double that succeeds
# Then:  the subshell returns non-zero for every function
# Asserts: the ${n:?} guards keep an empty tag out of a docker build, including image_digest
test_missing_args_are_hard_errors() {
  local ok=true
  (agent_base_image_name 2>/dev/null) && ok=false
  (agent_image_name "pi" 2>/dev/null) && ok=false
  (sandbox_image_name 2>/dev/null) && ok=false
  (image_digest 2>/dev/null) && ok=false
  if [[ "$ok" == true ]]; then
    pass "naming functions and image_digest fail hard on missing args"
  else
    fail "a function accepted missing args (empty tag risk)"
  fi
}

# Given: a docker double that writes a diagnostic to stderr and a digest to stdout
# When:  image_digest runs
# Then:  stdout carries the digest and stderr carries nothing
# Asserts: the command's stderr is suppressed so a probe's diagnostic cannot pollute the caller's output
test_image_digest_suppresses_stderr() {
  local err out
  err="$FIXTURE_DIR/docker-stderr"
  out="$(image_digest "some-image" 2>"$err")"
  assert_eq "$out" "sha256:stubid" "image_digest returns the image id on stdout"
  assert_empty "$(cat "$err")" "image_digest suppresses the docker stderr diagnostic"
}

# Given: a docker double that records its arguments
# When:  image_digest runs
# Then:  the inspect call carries the documented {{.Id}} format
# Asserts: the digest format string is named directly, not inferred from the stub's routing.
test_image_digest_uses_documented_format() {
  local args_file="$FIXTURE_DIR/docker-args"
  docker() {
    if [[ "${1:-}" == "image" && "${2:-}" == "inspect" ]]; then
      printf '%s\n' "$*" > "$args_file"
      echo "sha256:stubid"
      return 0
    fi
    return 0
  }
  : > "$args_file"
  image_digest "some-image" >/dev/null 2>&1
  if grep -qF -- "--format {{.Id}} some-image" "$args_file"; then
    pass "image_digest asks docker for the image ID with {{.Id}}"
  else
    fail "image_digest format changed: $(cat "$args_file")"
  fi
}

echo "=== image name derivation tests ==="
echo

run_test test_agent_base_image_name_lowercases_provider
run_test test_agent_image_name_lowercases_project_only
run_test test_sandbox_image_name_lowercases_project
run_test test_shared_base_image_name_is_constant
run_test test_missing_args_are_hard_errors
run_test test_image_digest_suppresses_stderr
run_test test_image_digest_uses_documented_format

test_done

