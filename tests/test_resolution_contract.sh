#!/usr/bin/env bash
# tests/test_resolution_contract.sh
# The resolution and dispatch contract as one gate over its carriers: every
# catalogue row that declares `env` uses the identity resolver, every such leaf
# accepts `--env`, the dispatcher forwards the normalized path, and the path
# constructor returns an absolute value.
#
# Run:
#   bash tests/test_resolution_contract.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/src/libs/env_resolve.sh"

CLI="$REPO_ROOT/scripts/agent-sandbox.sh"

catalog_rows() {
  bash -c 'source "$1"; printf "%s\n" "${CLI_CATALOG[@]}"' _ "$CLI"
}

# Every row that declares `env` must resolve identity, because ENV_FILE is what
# resolution exports; a base-resolver row would forward an empty path.
test_every_env_row_uses_the_identity_resolver() {
  local name leaf ident resolve bad=""
  while IFS='|' read -r name leaf ident _ resolve _; do
    [[ " $ident " == *" env "* ]] || continue
    [[ "$resolve" == "identity" ]] || bad+="$name "
  done < <(catalog_rows)
  assert_empty "$bad" 'every env row uses the identity resolver'
}

# The leaf a row names must parse the --env flag the dispatcher forwards.
test_every_env_leaf_accepts_env() {
  local name leaf ident resolve bad=""
  while IFS='|' read -r name leaf ident _ resolve _; do
    [[ " $ident " == *" env "* ]] || continue
    grep -q -- '--env=' "$REPO_ROOT/$leaf" || bad+="$leaf "
  done < <(catalog_rows)
  assert_empty "$bad" 'every env leaf accepts --env'
}

# The dispatcher hands the leaf the resolver's normalized path, never the raw
# --env spelling that would make the leaf resolve it again.
test_dispatcher_forwards_the_normalized_path() {
  local source
  source="$(cat "$CLI")"
  assert_contains "$source" 'forwarded+=("--env=$ENV_FILE")' 'the dispatcher forwards $ENV_FILE'
  assert_not_contains "$source" 'forwarded+=("--env=$ENV_REL")' 'the dispatcher never forwards $ENV_REL'
}

# The path constructor is the one normalizer; a relative input is absolute.
test_default_env_file_returns_an_absolute_path() {
  local out
  out=$(cd "$FIXTURE_DIR" && mkdir -p sbx && default_env_file "session.env" "sbx")
  assert_matches "$out" '^/' 'default_env_file returns an absolute path'
}

run_test test_every_env_row_uses_the_identity_resolver
run_test test_every_env_leaf_accepts_env
run_test test_dispatcher_forwards_the_normalized_path
run_test test_default_env_file_returns_an_absolute_path

test_done test_resolution_contract
