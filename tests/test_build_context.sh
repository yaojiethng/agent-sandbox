#!/usr/bin/env bash
# tests/test_build_context.sh  --  COPY contract tests
#
# Asserts that every COPY source in every Dockerfile exists at its
# repo-relative path. This is the invariant that matters  --  if a COPY
# instruction references a file that doesn't exist, the build fails.
#
# Run:
#   bash tests/test_build_context.sh
#
# Exit code: 0 if all tests pass, 1 if any fail.

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# List all Dockerfiles in the repo that have COPY instructions
_dockerfiles() {
  find "$REPO_ROOT/src" -name "*.dockerfile" -o -name "Dockerfile*" | grep -v node_modules
}

# Extract repo-relative COPY source paths from a Dockerfile.
# Filters to paths that look like repo-relative path components (not absolute
# or bare filenames from the old flat-context era).
_copy_sources() {
  local dockerfile="$1"
  grep "^COPY " "$dockerfile" \
    | grep -v -- '--from=' `# skip multi-stage builds` \
    | awk '{print $2}' \
    | grep -v "^/"        `# skip absolute paths` \
    | grep -v "^\."      `# skip .dockerignore-style paths` \
    || true
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_all_copy_sources_exist() {
  local failures=0
  local dockerfile

  for dockerfile in $(_dockerfiles); do
    local rel_path="${dockerfile#$REPO_ROOT/}"

    while IFS= read -r source; do
      [[ -z "$source" ]] && continue

      # Trim trailing slash for directory copies
      local check_path="${source%/}"
      local full_path="$REPO_ROOT/$check_path"

      if [[ ! -e "$full_path" ]]; then
        echo "  FAIL: $rel_path: COPY source not found: $source"
        failures=$((failures + 1))
      fi
    done < <(_copy_sources "$dockerfile")
  done

  if [[ "$failures" -eq 0 ]]; then
    pass "All COPY sources exist at their repo-relative paths"
  else
    fail "$failures COPY source(s) missing"
  fi
}

# test_no_flat_temp_dir_paths was deleted (test-quality campaign): its filter
# chain was dead logic -- it pre-filtered COPY lines to those without a slash
# and then excluded agent//docs/ prefixes, which a slash-free path can never
# match -- and it duplicated the existence guarantee of
# test_all_copy_sources_exist above.

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

run_test test_all_copy_sources_exist

test_done
