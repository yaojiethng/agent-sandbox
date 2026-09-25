#!/usr/bin/env bash
# tests/test_session_inventory.sh
# Unit tests for src/libs/session_inventory.sh  --  registry-record parsing and
# Pins cite: docs/architecture/tool_interface.md l.55 (list columns, staleness label),
#             naming table (l.15).

# staleness classification.
#
# Covers:
#   record_image         --  service-block extraction, boundary handling
#   record_provider      --  canonical <provider>-agent-<project> recovery
#   record_label         --  label extraction incl. pipefail-safety on no-match
#   (record_image_stale retired with the staleness signal -- ADR harness_versioning.md)
#   project_current_sha  --  empty/non-git/git branches
#   enumerate_records    --  registry enumeration, provider filter, skip rules
#   session_stale        --  registry-truth staleness vs explicit/derived SHA

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

source "$REPO_ROOT/src/libs/session_inventory.sh"

# make_record FILE AGENT_IMG SANDBOX_IMG [extra label lines...]
make_record() {
  local f="$1" agent="$2" sandbox="$3"; shift 3
  {
    echo "services:"
    echo "  sandbox:"
    echo "    image: $sandbox"
    echo "  agent:"
    echo "    image: $agent"
    local l
    for l in "$@"; do echo "    agent-sandbox.$l"; done
  } > "$f"
}

# =============================================================================
# record_image / record_provider / record_label
# =============================================================================

# Given: a record with a sandbox block and an agent block, each with its own image
# When:  record_image is called for each service
# Then:  each call returns that service's image
# Asserts: per-service extraction.
test_record_image_extracts_service_image() {
  local f="$FIXTURE_DIR/rec1.yml"
  make_record "$f" "pi-agent-myproj" "myproj-sandbox"

  if [[ "$(record_image "$f" agent)" == "pi-agent-myproj" \
     && "$(record_image "$f" sandbox)" == "myproj-sandbox" ]]
  then
    pass "record_image extracts the right image per service block"
  else
    fail "record_image broken: agent='$(record_image "$f" agent)' sandbox='$(record_image "$f" sandbox)'"
  fi
}

# Given: an agent block followed by another service block
# When:  record_image is called for agent
# Then:  it returns the agent image, not the later service's
# Asserts: the scan stops at the service boundary (asserted only for a block that has an image).
test_record_image_stops_at_next_service() {
  local f="$FIXTURE_DIR/rec2.yml"
  cat > "$f" <<'EOF'
services:
  sandbox:
    image: sbx-img
  agent:
    extra: x
    image: agt-img
  other:
    image: not-agent-image
EOF

  if [[ "$(record_image "$f" agent)" == "agt-img" ]]; then
    pass "record_image terminates at the next service boundary"
  else
    fail "service-boundary handling broken: '$(record_image "$f" agent)'"
  fi
}

# Given: a record with no block for the requested service
# When:  record_image is called
# Then:  output is empty and rc is 0
# Asserts: an absent service is not an error.
test_record_image_missing_service_empty_rc0() {
  local f="$FIXTURE_DIR/rec3.yml"
  make_record "$f" "pi-agent-p" "sbx-p"

  local OUT RC=0
  OUT=$(record_image "$f" ghost) || RC=$?
  if [[ $RC -eq 0 && -z "$OUT" ]]; then
    pass "record_image: absent service yields empty output, rc=0"
  else
    fail "absent service should be empty/rc0, got '$OUT' rc=$RC"
  fi
}

# Given: an agent image named <provider>-agent-<project>, then a non-canonical image
# When:  record_provider runs on each
# Then:  the canonical shape recovers the provider, the other yields empty
# Asserts: the -agent- gate.
test_record_provider_recovers_prefix_and_rejects_noncanonical() {
  local f="$FIXTURE_DIR/rec4.yml"
  make_record "$f" "opencode-agent-lowerproj" "sbx"

  local GOOD RC=0 BAD
  GOOD=$(record_provider "$f") || RC=$?

  printf 'services:\n  agent:\n    image: weirdimage\n' > "$f"
  BAD=$(record_provider "$f")

  if [[ $RC -eq 0 && "$GOOD" == "opencode" && -z "$BAD" ]]; then
    pass "record_provider: recovers '-agent-' prefixed name, empty for non-canonical"
  else
    fail "record_provider broken: good='$GOOD' rc=$RC bad='$BAD'"
  fi
}

# Given: a record with one label present and one absent, under set -o pipefail
# When:  record_label is called for each
# Then:  the absent label is empty at rc 0 and does not abort the caller
# Asserts: pipefail safety, the lib's documented contract.
test_record_label_pipefail_safe_on_no_match() {
  # The lib's own docstring promises a no-match grep must not abort a caller
  # under pipefail. Verify exactly that contract.
  local f="$FIXTURE_DIR/rec5.yml"
  make_record "$f" "a-agent-b" "c" "session-ts: 20260821-100000"

  local OUT RC=0
  OUT=$(set -o pipefail; record_label "$f" host-branch) || RC=$?
  if [[ $RC -eq 0 && -z "$OUT" ]]; then
    pass "record_label: no-match is empty and rc=0 under pipefail"
  else
    fail "no-match label broke pipefail safety: rc=$RC out='$OUT'"
  fi

  local TS
  TS=$(set -o pipefail; record_label "$f" session-ts)
  assert_eq "$TS" "20260821-100000" "record_label: extracts present label value"
}

# =============================================================================

# =============================================================================
# project_current_sha / session_stale
# =============================================================================

# Given: PROJECT_DIR unset, set to a non-git dir, and set to a git repo
# When:  project_current_sha runs
# Then:  empty, empty, and the repo HEAD respectively
# Asserts: the three branches.
test_project_current_sha_branches() {
  source "$TEST_DIR/libs/git_fixtures.sh"
  local PROJ="$FIXTURE_DIR/sha_proj"
  make_committed_repo "$PROJ"

  local UNSET_OUT NON_GIT OUT
  UNSET_OUT=$(unset PROJECT_DIR; project_current_sha)
  mkdir -p "$FIXTURE_DIR/notgit"
  NON_GIT=$(PROJECT_DIR="$FIXTURE_DIR/notgit" project_current_sha)
  OUT=$(PROJECT_DIR="$PROJ" project_current_sha)

  if [[ -z "$UNSET_OUT" && -z "$NON_GIT" && "$OUT" == "$(git -C "$PROJ" rev-parse HEAD)" ]]
  then
    pass "project_current_sha: unset->empty, non-git->empty, git->HEAD"
  else
    fail "branches wrong: unset='$UNSET_OUT' nongit='$NON_GIT' git='$OUT'"
  fi
}

# Given: a record whose host-head-sha matches, differs from, or is absent against CURRENT_SHA
# When:  session_stale runs
# Then:  fresh, stale, unknown respectively
# Asserts: registry-truth classification.
test_session_stale_classification() {
  source "$TEST_DIR/libs/git_fixtures.sh"
  local PROJ="$FIXTURE_DIR/st_proj"
  make_committed_repo "$PROJ"
  local CUR
  CUR="$(git -C "$PROJ" rev-parse HEAD)"

  local f="$FIXTURE_DIR/st1.yml"
  make_record "$f" "p-agent-q" "q-sbx" "host-head-sha: $CUR"
  local FRESH
  FRESH=$(session_stale "$f" "$CUR")

  local STALE
  STALE=$(session_stale "$f" "0000000000000000000000000000000000000000")

  local UNKNOWN
  printf 'services:\n  agent:\n    image: x\n' > "$f"
  UNKNOWN=$(session_stale "$f" "$CUR")

  if [[ "$FRESH" == "fresh" && "$STALE" == "stale" && "$UNKNOWN" == "unknown" ]]
  then
    pass "session_stale: match->fresh, differ->stale, missing-label->unknown"
  else
    fail "classification wrong: $FRESH/$STALE/$UNKNOWN"
  fi
}

# Given: a matching record and a PROJECT_DIR git repo
# When:  session_stale runs without an explicit SHA
# Then:  it derives the current SHA and reports fresh
# Asserts: the PROJECT_DIR fallback.
test_session_stale_derives_sha_from_project_dir() {
  source "$TEST_DIR/libs/git_fixtures.sh"
  local PROJ="$FIXTURE_DIR/st_proj2"
  make_committed_repo "$PROJ"
  local CUR
  CUR="$(git -C "$PROJ" rev-parse HEAD)"

  local f="$FIXTURE_DIR/st2.yml"
  make_record "$f" "p-agent-q" "q-sbx" "host-head-sha: $CUR"

  local OUT
  OUT=$(PROJECT_DIR="$PROJ" session_stale "$f")
  assert_eq "$OUT" "fresh" "session_stale: derives current SHA from PROJECT_DIR when not passed"
}

# =============================================================================
# enumerate_records
# =============================================================================

# Given: a registry with two recoverable records, one unrecoverable, and a dry-run record
# When:  enumerate_records runs with and without PROVIDER_FILTER
# Then:  it prints sid|provider|ts|branch, skips the unrecoverable record, honors the filter, and keeps dry-run records
# Asserts: the shared, unfiltered enumeration core.
test_enumerate_records_filters_and_skips() {
  local SBX="$FIXTURE_DIR/enumerate_sbx"
  mkdir -p "$SBX/.compose"

  make_record "$SBX/.compose/sess-a.yml" "pi-agent-proj" "proj-sbx" \
    "session-ts: 20260820-100000" "host-branch: main"
  make_record "$SBX/.compose/sess-b.yml" "opencode-agent-proj" "proj-sbx" \
    "session-ts: 20260821-090000" "host-branch: dev"
  # Unrecoverable provider -> must be skipped
  make_record "$SBX/.compose/sess-c.yml" "weird" "proj-sbx"

  local ALL PI_ONLY
  ALL=$(SANDBOX_DIR="$SBX" enumerate_records)
  PI_ONLY=$(SANDBOX_DIR="$SBX" PROVIDER_FILTER=pi enumerate_records)

  # Dry-run records are part of the shared inventory core (prune Rule 1 must
  # reach them); the resume listing is what filters them out.
  make_record "$SBX/.compose/dryrun-abc123.yml" "pi-agent-proj" "proj-sbx" \
    "session-ts: 20260822-110000" "host-branch: main"
  local WITH_DRYRUN
  WITH_DRYRUN=$(SANDBOX_DIR="$SBX" enumerate_records)

  if [[ "$ALL" == *"sess-a|pi|20260820-100000|main"* \
     && "$ALL" == *"sess-b|opencode|20260821-090000|dev"* \
     && "$ALL" != *sess-c* \
     && "$PI_ONLY" == "sess-a|pi|20260820-100000|main" \
     && "$WITH_DRYRUN" == *"dryrun-abc123|pi|20260822-110000|main"* ]]
  then
    pass "enumerate_records: emits sid|provider|ts|branch (incl. dry-run records for prune), skips bad records, honors filter"
  else
    fail "enumeration broken: ALL=[$ALL] PI=[$PI_ONLY] DRYRUN=[$WITH_DRYRUN]"
  fi
}

# Given: a missing registry directory and an empty one
# When:  enumerate_records runs
# Then:  both are silent at rc 0
# Asserts: the no-op edges.
test_enumerate_records_no_dir_or_empty_is_silent_rc0() {
  local OUT RC=0
  OUT=$(SANDBOX_DIR="$FIXTURE_DIR/no_such_sbx" enumerate_records) || RC=$?

  local EMPTY_RC=0 EMPTY
  mkdir -p "$FIXTURE_DIR/empty_sbx/.compose"
  EMPTY=$(SANDBOX_DIR="$FIXTURE_DIR/empty_sbx" enumerate_records) || EMPTY_RC=$?

  if [[ $RC -eq 0 && -z "$OUT" && $EMPTY_RC -eq 0 && -z "$EMPTY" ]]; then
    pass "enumerate_records: missing/empty registry -> silent success"
  else
    fail "edge cases not silent: rc=$RC empty_rc=$EMPTY_RC"
  fi
}

# ---------------------------------------------------------------------------
# env_field unit tests
#
# env_field  --  shared record-env parser in src/libs/session_inventory.sh
# (used by prune.sh for plan disclosure and resume_agent.sh for delivery
# recovery). Sourced from the lib directly.
# ---------------------------------------------------------------------------

# Given: a record carrying an `environment:` list
# When:  env_field reads SANDBOX_TYPE
# Then:  it prints `mount`
# Asserts: the environment-block read
test_env_field_reads_value_from_environment_block() {
  local f="$FIXTURE_DIR/envfield_record"
  printf '  environment:\n    - SANDBOX_TYPE=mount\n    - PROVIDER=pi\n' > "$f"
  local out
  out=$(env_field "$f" "SANDBOX_TYPE")
  assert_eq "$out" "mount" "env_field reads value from environment block"
}

# Given: NODE_PATH=/x and PATH=/bin in the environment block
# When:  env_field reads PATH
# Then:  it prints /bin
# Asserts: the key match is anchored to the whole key
test_env_field_no_substring_matches() {
  local f="$FIXTURE_DIR/envfield_substr"
  printf '    - NODE_PATH=/x\n    - PATH=/bin\n' > "$f"
  local out
  out=$(env_field "$f" "PATH")
  assert_eq "$out" "/bin" "env_field does not substring-match NODE_PATH when asked for PATH"
}

# Given: two A= lines in the environment block
# When:  env_field reads A
# Then:  it prints the first value
# Asserts: first match wins
test_env_field_first_match_wins() {
  local f="$FIXTURE_DIR/envfield_first"
  printf '    - A=1\n    - A=2\n' > "$f"
  local out
  out=$(env_field "$f" "A")
  assert_eq "$out" "1" "env_field returns first match only"
}

# Given: a record with no ABSENT key
# When:  env_field reads ABSENT
# Then:  it prints nothing and exits 0
# Asserts: a missing key is an empty read, not a failure
test_env_field_missing_key_is_empty_and_clean() {
  local f="$FIXTURE_DIR/envfield_missing"
  printf '    - OTHER=x\n' > "$f"
  local out rc
  out=$(env_field "$f" "ABSENT"); rc=$?
  if [[ $rc -eq 0 && -z "$out" ]]; then
    pass "env_field missing key -> empty output, exit 0"
  else
    fail "env_field ABSENT: rc=$rc out='$out'"
  fi
}

# Given: the environment line forms `- A=plain` and `  -   B=spaced`
# When:  env_field reads each key
# Then:  it prints `plain` and `spaced`
# Asserts: the dash and spacing tolerance of the line form
test_env_field_tolerates_dash_spacing_variants() {
  local f="$FIXTURE_DIR/envfield_spacing"
  printf -- '- A=plain\n  -   B=spaced\n' > "$f"
  local a b
  a=$(env_field "$f" "A")
  b=$(env_field "$f" "B")
  if [[ "$a" == "plain" && "$b" == "spaced" ]]; then
    pass "env_field tolerates dash/spacing variants"
  else
    fail "env_field spacing variants: A='$a' B='$b'"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_record_image_extracts_service_image
run_test test_record_image_stops_at_next_service
run_test test_record_image_missing_service_empty_rc0
run_test test_record_provider_recovers_prefix_and_rejects_noncanonical
run_test test_record_label_pipefail_safe_on_no_match
run_test test_project_current_sha_branches
run_test test_session_stale_classification
run_test test_session_stale_derives_sha_from_project_dir
run_test test_enumerate_records_filters_and_skips
run_test test_enumerate_records_no_dir_or_empty_is_silent_rc0
run_test test_env_field_reads_value_from_environment_block
run_test test_env_field_no_substring_matches
run_test test_env_field_first_match_wins
run_test test_env_field_missing_key_is_empty_and_clean
run_test test_env_field_tolerates_dash_spacing_variants

test_done test_session_inventory.sh

