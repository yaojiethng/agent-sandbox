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

# The path constructor is the one normalizer; a relative input is absolute.
test_default_env_file_returns_an_absolute_path() {
  local out
  out=$(cd "$FIXTURE_DIR" && mkdir -p sbx && default_env_file "session.env" "sbx")
  assert_matches "$out" '^/' 'default_env_file returns an absolute path'
}

# Every catalogue field is declared in CLI_FIELDS. A row naming `dir`, a typo
# or a raw flag fails here before any surface derives from it.
test_catalog_fields_are_in_the_field_vocabulary() {
  local out rc=0
  out=$(bash -c 'source "$1"; catalog_validate' _ "$CLI" 2>&1) || rc=$?
  assert_rc 0 "$rc" 'the current catalogue validates'
  assert_empty "$out" 'a valid catalogue prints no error'
}

# Given: a catalogue row naming a field outside CLI_FIELDS
# When:  the dispatcher starts
# Then:  it exits 1 before help, naming the row and field
# Asserts: an unknown field is a declaration error, not a silent omission.
test_unknown_catalog_field_fails_the_contract_gate() {
  local out rc=0
  out=$(bash -c 'source "$1"; CLI_CATALOG[0]="${CLI_CATALOG[0]/name project/name bogus}"; main help' _ "$CLI" 2>&1) || rc=$?
  assert_rc 1 "$rc" 'an unknown field fails before help'
  assert_contains "$out" "bogus" 'the error names the unknown field'
  assert_contains "$out" "onboard" 'and the row that declares it'
  assert_not_contains "$out" "Valid subcommands:" 'no help surface is printed'
}

run_test test_every_env_row_uses_the_identity_resolver
run_test test_every_env_leaf_accepts_env
run_test test_default_env_file_returns_an_absolute_path
run_test test_catalog_fields_are_in_the_field_vocabulary
run_test test_unknown_catalog_field_fails_the_contract_gate

test_done test_resolution_contract
