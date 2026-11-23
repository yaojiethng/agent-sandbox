#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_agent_cli_dispatch.sh
# The CLI surface as one contract: the dispatcher's list, its help index, its
# no-argument message and its dispatch agree with one declared set, and
# `help --json` renders that set.
#
# Every case runs the CLI as a subprocess -- the only test that does -- because
# the contract is what a user invokes, not what a sourced function returns.
#
# Run:
#   bash tests/test_agent_cli_dispatch.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

CLI="$REPO_ROOT/scripts/agent-sandbox.sh"

# The declared set, written out here so a lost row fails this test rather than
# passing it. The dispatcher's catalog is the single source; this is the
# independent statement of what that source must say.
EXPECTED="onboard build start dry-run resume stop prune apply draft confirm reject package-branch"

cli() { bash "$CLI" "$@" 2>&1; }

# names_from TEXT: print the subcommand names TEXT names, one per line, in order.
# Accepts the comma-separated "Valid subcommands:" line and the pipe-separated
# no-argument usage line.
names_from() {
  printf '%s\n' "$1" \
    | grep -o 'Valid subcommands: .*' \
    | sed 's/^Valid subcommands: //' \
    | tr ',' '\n' \
    | tr -d ' ' \
    | sed '/^$/d'
}

names_from_usage() {
  printf '%s\n' "$1" \
    | grep -o 'agent-sandbox <[^>]*>' \
    | sed 's/^agent-sandbox <//; s/>$//' \
    | tr '|' '\n' \
    | sed '/^$/d'
}

# The help index and the no-argument message print the same set.
test_help_index_names_the_declared_set() {
  assert_eq "$EXPECTED" "$(names_from "$(cli help)" | tr '\n' ' ' | sed 's/ $//')" \
    'the help index names every subcommand'
}

test_no_argument_message_names_the_declared_set() {
  local out
  out="$(cli)"
  assert_eq "$EXPECTED" "$(names_from_usage "$out" | tr '\n' ' ' | sed 's/ $//')" \
    'the no-argument message names the same set as the help index'
}

test_unknown_subcommand_exits_1_and_names_itself() {
  local out rc=0
  out="$(cli bogus-subcommand)" || rc=$?
  assert_rc 1 "$rc" 'an unknown subcommand exits 1'
  assert_contains "$out" 'bogus-subcommand' 'and the message names it'
}

# Help is the leaf's: every subcommand answers --help without its flags.
test_every_subcommand_help_exits_0() {
  local name rc out
  for name in $EXPECTED; do
    rc=0
    out="$(cli "$name" --help)" || rc=$?
    assert_rc 0 "$rc" "$name --help exits 0"
    assert_contains "$out" 'Usage' "$name --help prints a usage line"
  done
}

# The one status map: an unknown flag never succeeds. The dispatcher resolves
# identity before the leaf parses, so the status is what it asserts; the leaf's
# own message is the case below.
test_every_subcommand_rejects_an_unknown_flag() {
  local name rc failing=""
  for name in $EXPECTED; do
    rc=0
    cli "$name" --bogus-flag >/dev/null || rc=$?
    [[ $rc -ne 0 ]] || failing+="$name "
  done
  assert_empty "$failing" 'no subcommand succeeds on an unknown flag'
}

# The sweep's witness: each leaf maps a usage error to 1 and names the flag,
# where before six of them let set -e take the exit.
test_every_leaf_names_the_flag_it_rejects() {
  local leaf lead out rc failing=""
  while IFS=$'\t' read -r leaf lead; do
    rc=0
    out="$(bash "$REPO_ROOT/$leaf" $lead --bogus-flag 2>&1)" || rc=$?
    if [[ $rc -ne 1 ]] || ! grep -q 'bogus-flag' <<<"$out"; then
      failing+="$leaf "
    fi
  done < <(cli help --json | jq -r '.subcommands[] | "\(.leaf)\t\(.args[0] // ""\)"')
  assert_empty "$failing" 'every leaf exits 1 and names the flag'
}

# The JSON rendering carries the same rows as the bash surfaces.
test_json_renders_the_declared_set() {
  local names
  names="$(cli help --json | jq -r '.subcommands[].name' | tr '\n' ' ' | sed 's/ $//')"
  assert_eq "$EXPECTED" "$names" 'the JSON names the same set, in order'
}

test_json_is_valid_and_carries_a_schema() {
  local schema
  schema="$(cli help --json | jq -r 'if .schema == 1 then "ok" else "missing" end' 2>/dev/null)"
  assert_eq "ok" "$schema" 'the rendering carries schema 1'
}

test_json_rows_carry_a_leaf_that_exists() {
  local leaf missing=""
  while read -r leaf; do
    [[ -f "$REPO_ROOT/$leaf" ]] || missing+="$leaf "
  done < <(cli help --json | jq -r '.subcommands[].leaf')
  assert_empty "$missing" 'every declared leaf is a file in the tree'
}

test_json_rows_carry_a_summary() {
  local blank
  blank="$(cli help --json | jq -r '.subcommands[] | select(.summary == "" or .summary == null) | .name')"
  assert_empty "$blank" 'every row carries a summary'
}

# -h is the same request as --help, and the dispatch stays out of a sourced file.
test_short_help_is_the_same_request() {
  local name rc out
  for name in $EXPECTED; do
    rc=0
    out="$(cli "$name" -h)" || rc=$?
    assert_rc 0 "$rc" "$name -h exits 0"
    assert_contains "$out" 'Usage' "$name -h prints a usage line"
  done
}

test_sourcing_the_dispatcher_dispatches_nothing() {
  local out
  out="$(bash -c 'source "$1" help' _ "$CLI")"
  assert_empty "$out" 'sourcing the file defines its functions and runs no subcommand'
  out="$(bash -c 'source "$1"; type -t main' _ "$CLI")"
  assert_eq "function" "$out" 'and defines main for the direct-call guard'
}

# A declared identity field is a flag its own leaf accepts.
test_declared_identity_fields_appear_in_the_leaf_help() {
  local name field missing=""
  while IFS=$'\t' read -r name field; do
    cli "$name" --help | grep -q -- "--$field" || missing+="$name:$field "
  done < <(cli help --json | jq -r '.subcommands[] | .name as $n | .identity[] | "\($n)\t\(. )"' | tr -d ' ')
  assert_empty "$missing" 'every declared identity field appears in its leaf help'
}

# The dispatcher execs the leaf, so the leaf's status is the caller's status.
test_leaf_exit_status_reaches_the_caller() {
  local rc=0
  cli apply --project=/nonexistent --sandbox=/nonexistent >/dev/null || rc=$?
  assert_rc 1 "$rc" 'a leaf usage error reaches the caller as 1'
}

# The identity is resolved after the flags are parsed, so a leaf must receive
# the value the resolver read from .env. Passing only --env and letting
# confirm's own refusal prove the project path arrived is the witness.
test_resolved_identity_reaches_the_leaf() {
  local project sandbox env_file out
  project="$FIXTURE_DIR/project"
  sandbox="$FIXTURE_DIR/sandbox"
  env_file="$FIXTURE_DIR/identity.env"
  mkdir -p "$project" "$sandbox"
  git -C "$project" init -q
  git -C "$project" -c user.email=test@example.com -c user.name=test \
    commit -q --allow-empty -m base
  printf 'PROJECT_NAME=fixture\nPROJECT_DIR=%s\nSANDBOX_DIR=%s\n' \
    "$project" "$sandbox" > "$env_file"
  out="$(cli confirm --env="$env_file")"
  assert_contains "$out" "not on a draft branch" \
    'the leaf receives the project path the resolver read from .env'
  assert_not_contains "$out" "Usage: agent-sandbox confirm" \
    'the leaf does not receive an empty --project'
}

run_test test_help_index_names_the_declared_set
run_test test_no_argument_message_names_the_declared_set
run_test test_unknown_subcommand_exits_1_and_names_itself
run_test test_every_subcommand_help_exits_0
run_test test_every_subcommand_rejects_an_unknown_flag
run_test test_every_leaf_names_the_flag_it_rejects
run_test test_json_renders_the_declared_set
run_test test_json_is_valid_and_carries_a_schema
run_test test_json_rows_carry_a_leaf_that_exists
run_test test_json_rows_carry_a_summary
run_test test_short_help_is_the_same_request
run_test test_sourcing_the_dispatcher_dispatches_nothing
run_test test_declared_identity_fields_appear_in_the_leaf_help
run_test test_leaf_exit_status_reaches_the_caller
run_test test_resolved_identity_reaches_the_leaf
test_done test_agent_cli_dispatch
