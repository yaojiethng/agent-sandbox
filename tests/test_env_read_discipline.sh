#!/usr/bin/env bash
# TEST_DEADLINE: 10
# tests/test_env_read_discipline.sh
# The env-load contract for the command chain: one loader opens the .env, and
# no second parser reads it. This gate pins the resolution call census. A new
# call site, or a new call inside a site, fails here until the census is
# deliberately amended.
#
# What the census counts, and what it does not. It counts resolution *calls*,
# matched at a command position so a function name inside an error message is
# not a site. It is a static census, so it cannot see how many passes a chain
# makes. A chain makes up to two: the entry resolves the identity, then the
# prelude bulk-loads configuration for the child. Both go through the one
# loader, and that is what this gate holds. A call whose arguments are already
# resolved reads no file and this gate counts it anyway, because the count is
# textual and the alternative is a trace the unit tests cannot run Docker for.
#
# The parser question is pinned separately, by test_no_second_env_parser.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"
test_setup

REPO="$REPO_ROOT"

# The resolution idioms, matched at a command position: start of line, after
# whitespace, after an opening parenthesis or after a semicolon. The trailing
# space keeps a function definition, which ends in '()', out of the census.
# env_file_value is in the list as a tripwire: the library no longer defines
# it, so a future call to that name is a read that bypasses the ladder.
READ_IDIOS='(^|[[:space:](;])(env_load|env_file_value|env_resolve_one|env_resolve_identity) |grep .*\.env|-include \.env|cut -d.='

sites() {
  grep -rnE "$READ_IDIOS" --include="*.sh" --include="Makefile.template" \
    "$REPO/src" "$REPO/scripts" 2>/dev/null | grep -vE ":[0-9]+: *#" | cut -d: -f1 | sort | uniq -c | awk '{print $2" "$1}'
}

# Given: the tree's resolution call sites
# When:  the census runs
# Then:  the call set matches the pinned census exactly, per file
# Asserts: the call census is a fact about the tree. A new call fails this gate
#          until the census is deliberately amended. src/libs/env.sh is not in
#          the pin: env_load is defined there and called nowhere in it, and the
#          one textual hit was its own argument error message.
test_env_resolution_call_census() {
  local expected actual
  expected=$(
    printf '%s\n' \
      "scripts/agent-sandbox.sh 1" \
      "scripts/install.sh 1" \
      "scripts/onboard.sh 1" \
      "scripts/resume_agent.sh 1" \
      "scripts/start_agent.sh 1" \
      "src/libs/env_resolve.sh 4" \
      "src/libs/session_env.sh 1"
  )
  actual="$(sites | sed "s|$REPO/||")"
  assert_eq "$expected" "$actual" "the resolution call sites match the pinned census"
}

# Given: every read site
# When:  a scan for shell-level .env parsers runs
# Then:  no grep, awk or cut pipeline parses a .env
# Asserts: one parser, one home. The install.sh grep|cut read was the last
#          one and it moved onto env_file_value in this unit.
test_no_second_env_parser() {
  local hits
  hits=$(grep -rnE "grep .*\.env|awk .*\.env" --include="*.sh" \
    "$REPO/src" "$REPO/scripts" 2>/dev/null | grep -vE ":[0-9]+: *#" || true)
  assert_eq "" "$hits" "no shell pipeline parses a .env"
}

# Given: the prelude in session_env.sh
# When:  its parse count is read
# Then:  it carries exactly the one named call, the bulk load. The identity
#        resolution moved to the chain entry, so the prelude consumes a
#        resolved triple instead of resolving it.
# Asserts: the single-load boundary holds: the prelude is a consumer of the
#          resolved identity, not a second resolver.
test_prelude_carries_exactly_one_call_site() {
  local n
  n=$(grep -vE '^\s*#' "$REPO/src/libs/session_env.sh" | grep -cE "env_load " || true)
  assert_eq "1" "$n" "the prelude reads the .env exactly once, for the bulk load"
}

run_test test_env_resolution_call_census
run_test test_no_second_env_parser
run_test test_prelude_carries_exactly_one_call_site

test_done test_env_read_discipline.sh
