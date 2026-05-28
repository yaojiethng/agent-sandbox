#!/usr/bin/env bash
# tests/test_packaging_symmetry.sh
# Tests that all provider Dockerfiles and the capability Dockerfile
# deploy the same set of packaging pipeline files.
#
# The packaging pipeline (diff.sh, package_branch.sh, package_diff.sh,
# diff_export.sh) must be deployed to both the capability and reasoning
# containers. This test asserts that every Dockerfile includes all of them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/libs/test_common.sh"

# The canonical set of packaging files that must be deployed to every container
REQUIRED_PACKAGING=(
  "diff.sh"
  "package_branch.sh"
  "package_diff.sh"
  "diff_export.sh"
)

# Each Dockerfile's COPY lines (source filenames only, stripped of path)
test_capability_dockerfile_has_all_packaging() {
  local dockerfile="$REPO_ROOT/src/capability/capability.dockerfile"
  local copied
  copied=$(grep '^COPY' "$dockerfile" | awk '{print $2}' | xargs -n1 basename 2>/dev/null || true)
  for pkg in "${REQUIRED_PACKAGING[@]}"; do
    if ! echo "$copied" | grep -q "$pkg"; then
      fail "capability dockerfile missing: $pkg"
      return
    fi
  done
  pass "capability dockerfile has all packaging files"
}

test_provider_dockerfiles_have_all_packaging() {
  local all_ok=true
  for dockerfile in "$REPO_ROOT/src/reasoning/providers/"*/provider.dockerfile; do
    local provider
    provider=$(basename "$(dirname "$dockerfile")")
    local copied
    copied=$(grep '^COPY' "$dockerfile" | awk '{print $2}' | xargs -n1 basename 2>/dev/null || true)
    for pkg in "${REQUIRED_PACKAGING[@]}"; do
      if ! echo "$copied" | grep -q "$pkg"; then
        fail "$provider provider dockerfile missing: $pkg"
        all_ok=false
      fi
    done
  done
  if [[ "$all_ok" == true ]]; then
    pass "all provider dockerfiles have all packaging files"
  fi
}

run_test test_capability_dockerfile_has_all_packaging
run_test test_provider_dockerfiles_have_all_packaging
