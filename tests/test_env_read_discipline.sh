#!/usr/bin/env bash
# TEST_DEADLINE: 10
# tests/test_env_read_discipline.sh
# The env-load contract for the command chain: the .env is parsed at exactly
# one boundary per chain, through the one loader, and no second parser reads
# it. This gate pins the site census. A new site, a new call inside a site, or
# a shell-level parser fails here. The census shrinks as the migration units
# land (U2 collapses the prelude's two parses, U3 removes the resume
# enrichment site, U5 removes the Makefile read).

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"
test_setup

REPO="$REPO_ROOT"

# The read idioms that parse a .env, and the file each site lives in.
READ_IDIOS='env_load |env_file_value |env_resolve_one |env_resolve_identity |grep .*\.env|-include \.env|cut -d.='

sites() {
  grep -rnE "$READ_IDIOS" --include="*.sh" --include="Makefile.template" \
    "$REPO/src" "$REPO/scripts" 2>/dev/null | grep -vE ":[0-9]+: *#" | cut -d: -f1 | sort | uniq -c | awk '{print $2" "$1}'
}

# Given: the tree's env read sites
# When:  the census runs
# Then:  the site set matches the pinned census exactly, per file
# Asserts: the load boundary is a fact about the tree. A new site, or a new
#          call inside an existing site, fails this gate until the census is
#          deliberately amended.
test_env_read_sites_match_the_census() {
  local expected actual
  expected=$(
    printf '%s\n' \
      "scripts/agent-sandbox.sh 1" \
      "scripts/install.sh 1" \
      "scripts/onboard.sh 1" \
      "scripts/resume_agent.sh 1" \
      "scripts/start_agent.sh 1" \
      "src/libs/env.sh 1" \
      "src/libs/env_resolve.sh 4" \
      "src/libs/session_env.sh 1"
  )
  actual="$(sites | sed "s|$REPO/||")"
  assert_eq "$expected" "$actual" "the env read sites match the pinned census"
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
# Then:  it carries exactly the one named site, the bulk load. The identity
#        resolution moved to the chain entry in unit U2, so the prelude reads
#        the .env once and only once
# Asserts: the single-load boundary holds: the prelude is a consumer of the
#          resolved identity, not a second resolver.
test_prelude_carries_exactly_one_read_site() {
  local n
  n=$(grep -vE '^\s*#' "$REPO/src/libs/session_env.sh" | grep -cE "env_load " || true)
  assert_eq "1" "$n" "the prelude reads the .env exactly once, for the bulk load"
}

run_test test_env_read_sites_match_the_census
run_test test_no_second_env_parser
run_test test_prelude_carries_exactly_one_read_site

test_done test_env_read_discipline.sh
