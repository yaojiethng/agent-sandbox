#!/usr/bin/env bash
# tests/test_shared_base_contract.sh  --  the shared runtime base is the single
# owner of the runtimes and lint gates every reasoning layer inherits.
#
# The drift this guards against: a provider base reinstalls Node, Python, uv,
# or a linter, and the copies pin different versions from the shared base. The
# copy is invisible in review because the provider base is a small file, and the
# result is that two containers stop having the same toolchain.
#
# Pins cite: docs/architecture/tool_interface.md provider interface table;
# docs/adr/git_hooks.md ("the linter ships in every provider base").
#
# Run:
#   bash tests/test_shared_base_contract.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

SHARED_BASE="$REPO_ROOT/src/reasoning/base.dockerfile"
PROVIDER_DIR="$REPO_ROOT/src/reasoning/providers"

# The shared base is the one file that owns the runtime set. If it is missing,
# no provider has a runtime, and the build fails with a clearer message here.
# Given: the repository source tree
# When:  the shared base file is read
# Then:  it exists and the former node.dockerfile is gone
# Asserts: the shared base is the single runtime owner
test_shared_base_exists_and_node_dockerfile_is_gone() {
  [[ -f "$SHARED_BASE" ]] || { fail "shared base missing: $SHARED_BASE"; return; }
  [[ ! -e "$REPO_ROOT/src/reasoning/node.dockerfile" ]] \
    || { fail "node.dockerfile still present; the shared base is base.dockerfile"; return; }
  pass "shared base present, node.dockerfile gone"
}

# The shared base names the whole runtime set, including the Python floor the
# operator set. A dropped install line would leave an image without the tool.
# Given: the shared base file
# When:  its content is grepped
# Then:  it installs Node (the FROM line), uv, Python 3.11, hadolint, and markdownlint-cli2
# Asserts: the shared base installs the full runtime set
test_shared_base_installs_the_full_runtime_set() {
  local content; content="$(cat "$SHARED_BASE")"
  local missing=""
  grep -q "^FROM node:" <<< "$content" || missing="$missing node"
  grep -q "astral.sh/uv/install.sh" <<< "$content" || missing="$missing uv"
  grep -q "uv python install 3.11" <<< "$content" || missing="$missing python"
  grep -q "hadolint" <<< "$content" || missing="$missing hadolint"
  grep -q "markdownlint-cli2" <<< "$content" || missing="$missing markdownlint-cli2"
  assert_eq "$missing" "" "shared base installs every runtime and lint gate"
}

# Every provider base inherits the shared base by its canonical default. A
# provider that pins a different default builds a different image than the one
# the build orchestrator passes in, and the two drift silently.
# Given: each providers/<n>/base.dockerfile
# When:  the file's BASE_IMAGE default is read
# Then:  it equals agent-base
# Asserts: the provider bases inherit the shared base
test_provider_bases_inherit_the_shared_base() {
  local out=""
  local df
  for df in "$PROVIDER_DIR"/*/base.dockerfile; do
    [[ -e "$df" ]] || continue
    grep -q "^ARG BASE_IMAGE=agent-base$" "$df" \
      || out="$out $(basename "$(dirname "$df")")"
  done
  assert_eq "$out" "" "every provider base defaults BASE_IMAGE to agent-base"
}

# The single rule the consolidation exists to hold: a provider base adds the
# agent and nothing else. A runtime or linter install reappearing here is the
# regression this file exists to catch.
# Given: each providers/<n>/base.dockerfile
# When:  the file is grepped for runtime and linter installs
# Then:  no match
# Asserts: the shared base is the only owner of the runtime set
test_provider_bases_install_no_runtime_or_linter() {
  local out=""
  local df
  for df in "$PROVIDER_DIR"/*/base.dockerfile; do
    [[ -e "$df" ]] || continue
    local hits
    hits="$(grep -nE 'nodesource|astral\.sh/uv|install python3|hadolint|markdownlint-cli2' "$df" || true)"
    [[ -z "$hits" ]] || out="$out $(basename "$(dirname "$df")"):$(wc -l <<< "$hits")"
  done
  assert_eq "$out" "" "no provider base installs a runtime or a linter"
}

run_test test_shared_base_exists_and_node_dockerfile_is_gone
run_test test_shared_base_installs_the_full_runtime_set
run_test test_provider_bases_inherit_the_shared_base
run_test test_provider_bases_install_no_runtime_or_linter

test_done
