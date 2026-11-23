#!/usr/bin/env bash
# TEST_DEADLINE: 10
# tests/test_env_read_discipline.sh
# The read-discipline contract for the sandbox record: one parser, and no
# record key in a child's environment. This gate pins the parser's home, the
# resolution call census and the export boundary. A new call site, a new
# export, or a new parser fails here until the contract is deliberately
# amended.
#
# What the census counts, and what it does not. It counts read *calls*, matched
# at a command position so a function name inside an error message is not a
# site. It is a static census, so it cannot see how many passes a chain makes.
#
# The boundary itself is asserted at runtime, by test_record_key_reaches_no_child.

source "$(dirname "${BASH_SOURCE[0]}")/libs/test_common.sh"
test_setup

REPO="$REPO_ROOT"

# The read idioms, matched at a command position: start of line, after
# whitespace, after an opening parenthesis or after a semicolon. The trailing
# space keeps a function definition, which ends in '()', out of the census.
# env_load and env_file_value are in the list as tripwires: the library no
# longer defines either, so a future call to one is a read that bypasses the
# contract.
READ_IDIOS='(^|[[:space:](;])(env_load|env_file_value|env_get|env_parse|env_resolve_one|env_resolve_identity) |grep .*\.env|-include \.env|cut -d.='

sites() {
  grep -rnE "$READ_IDIOS" --include="*.sh" --include="Makefile.template" \
    "$REPO/src" "$REPO/scripts" 2>/dev/null | grep -vE ":[0-9]+: *#" | cut -d: -f1 | sort | uniq -c | awk '{print $2" "$1}'
}

# Given: the tree's read call sites
# When:  the census runs
# Then:  the call set matches the pinned census exactly, per file
# Asserts: the call census is a fact about the tree. A new call fails this gate
#          until the census is deliberately amended. src/libs/env.sh is not in
#          the pin: the parser is defined there and called nowhere in it.
test_env_resolution_call_census() {
  local expected actual
  expected=$(
    printf '%s\n' \
      "scripts/agent-sandbox.sh 1" \
      "scripts/install.sh 1" \
      "scripts/onboard.sh 1" \
      "scripts/resume_agent.sh 1" \
      "scripts/start_agent.sh 1" \
      "src/build/compose.sh 1" \
      "src/libs/env.sh 1" \
      "src/libs/env_resolve.sh 4"
  )
  actual="$(sites | sed "s|$REPO/||")"
  assert_eq "$expected" "$actual" "the read call sites match the pinned census"
}

# Given: every read site
# When:  a scan for shell-level .env parsers runs
# Then:  no grep, awk or cut pipeline parses a .env
# Asserts: one parser, one home.
test_no_second_env_parser() {
  local hits
  hits=$(grep -rnE "grep .*\.env|awk .*\.env" --include="*.sh" \
    "$REPO/src" "$REPO/scripts" 2>/dev/null | grep -vE ":[0-9]+: *#" || true)
  assert_eq "" "$hits" "no shell pipeline parses a .env"
}

# Given: the parser home
# When:  its export statements are counted
# Then:  there are none
# Asserts: the parser prints and never exports, so a record key cannot become a
#          child's environment through the parser.
test_parser_exports_nothing() {
  local n
  n=$(grep -cE '^[[:space:]]*export ' "$REPO/src/libs/env.sh" || true)
  assert_eq "0" "$n" "the parser exports nothing"
}

# Given: the prelude in session_env.sh
# When:  its read calls are counted
# Then:  it carries none
# Asserts: the prelude consumes a resolved identity and asks for a record value
#          by key at the point of use; it never loads the record.
test_prelude_carries_no_read_site() {
  local n
  n=$(grep -vE '^\s*#' "$REPO/src/libs/session_env.sh" | grep -cE "(env_load|env_parse|env_get) " || true)
  assert_eq "0" "$n" "the prelude reads no record key"
}

# Given: the resolver
# When:  AGENT_SANDBOX_ references are counted
# Then:  there are none
# Asserts: a record key has no environment level. The identity resolver is the
#          only place the environment could stand in for a record key.
test_no_environment_level_for_a_record_key() {
  local n
  n=$(grep -vE '^[[:space:]]*#' "$REPO/src/libs/env_resolve.sh" | grep -cE 'AGENT_SANDBOX_' || true)
  assert_eq "0" "$n" "the resolver honours no AGENT_SANDBOX_* level"
}

# Given: an onboarded sandbox whose record holds a key nothing else sets
# When:  the host entry resolves and initialises, then a child process reads its environment
# Then:  the child does not see the key
# Asserts: the record boundary end to end. A record value is read by key; it
#          never becomes ambient for a child, so no descendant can inherit it.
test_record_key_reaches_no_child() {
  local SBX PROJ OUT
  SBX="$(mktemp -d)"; PROJ="$(mktemp -d)"
  mkdir -p "$SBX"; make_committed_repo "$PROJ" 2>/dev/null || {
    git -C "$PROJ" init -q && git -C "$PROJ" -c user.email=t@t -c user.name=t commit -q --allow-empty -m initial
  }
  make_envfile "$SBX" probe "$PROJ" "$SBX" 2>/dev/null || {
    printf 'PROJECT_NAME=probe\nPROJECT_DIR=%s\nSANDBOX_DIR=%s\n' "$PROJ" "$SBX" > "$SBX/.env"
  }
  printf 'RECORD_BOUNDARY_PROBE=leaked\n' >> "$SBX/.env"
  OUT=$(bash -c '
    source "$1/src/libs/env.sh"
    source "$1/src/libs/env_resolve.sh"
    source "$1/src/libs/session_env.sh"
    env_resolve_identity "" "" "$2" >/dev/null || exit 1
    resolve_and_init "$PROJECT_NAME" "$PROJECT_DIR" "$2" >/dev/null || exit 1
    printf "%s" "${RECORD_BOUNDARY_PROBE:-absent}"
  ' _ "$REPO" "$SBX" 2>&1)
  assert_not_contains "$OUT" "leaked" "a record key does not reach the process that resolved it"
  rm -rf "$SBX" "$PROJ"
}

# Given: a project directory, no --sandbox, and a CWD holding no .env
# When:  start_agent.sh resolves the sandbox path
# Then:  it refuses, naming onboard, and names no path computed from PROJECT_DIR
# Asserts: the sandbox path is a ladder value. A PROJECT_DIR-derived default
#          occupies the explicit level, so the value onboard writes into the
#          .env could never win (docs/adr/resolution_model.md, R3).
test_sandbox_path_is_a_ladder_value() {
  local work out status
  work="$(mktemp -d)"
  mkdir -p "$work/proj"
  if out=$(cd "$work" && bash "$REPO/scripts/start_agent.sh" standard \
      --name=probe --project="$work/proj" --provider=pi 2>&1); then
    status=0
  else
    status=$?
  fi
  assert_eq "1" "$status" "start refuses to invent a sandbox path"
  assert_contains "$out" "onboard" "the refusal names the onboard remedy"
  assert_not_contains "$out" "proj-sandbox" "no path is computed from PROJECT_DIR"
  rm -rf "$work"
}

run_test test_env_resolution_call_census
run_test test_no_second_env_parser
run_test test_parser_exports_nothing
run_test test_prelude_carries_no_read_site
run_test test_no_environment_level_for_a_record_key
run_test test_record_key_reaches_no_child
run_test test_sandbox_path_is_a_ladder_value

test_done test_env_read_discipline.sh
