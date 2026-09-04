#!/usr/bin/env bash
# tests/test_session_inventory.sh
# Unit tests for src/libs/session_inventory.sh  --  registry-record parsing and
# staleness classification.
#
# Covers:
#   record_image         --  service-block extraction, boundary handling
#   record_provider      --  canonical <provider>-agent-<project> recovery
#   record_label         --  label extraction incl. pipefail-safety on no-match
#   record_image_stale   --  stale/fresh/unknown aggregation (docker stubbed)
#   project_current_sha  --  empty/non-git/git branches
#   enumerate_records    --  registry enumeration, provider filter, skip rules
#   session_stale        --  registry-truth staleness vs explicit/derived SHA

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"
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
  if [[ "$TS" == "20260821-100000" ]]; then
    pass "record_label: extracts present label value"
  else
    fail "label extraction wrong: '$TS'"
  fi
}

# =============================================================================
# record_image_stale (docker via stubs)
# =============================================================================

# fresh_sigs REPO_ROOT PROVIDER  --  print "<agentsig> <sandboxsig>" computed in
# fresh shells (process isolation; each call sources the lib cleanly).
fresh_sigs() {
  local root="$1" provider="$2"
  local a s
  a=$(bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; current_sig agent '$root' '$provider'" </dev/null)
  s=$(bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; current_sig sandbox '$root'" </dev/null)
  echo "$a $s"
}

test_record_image_stale_fresh_when_both_match() {
  local ROOT="$FIXTURE_DIR/sigrepo_fresh"
  mkdir -p "$ROOT/src/libs" "$ROOT/src/capability" "$ROOT/docs/architecture" \
           "$ROOT/docs/concepts" "$ROOT/src/reasoning/agent/skills" \
           "$ROOT/src/reasoning/agent/prompts"
  touch "$ROOT/src/reasoning/entrypoint.sh" "$ROOT/src/capability/entrypoint.sh" \
        "$ROOT/src/capability/snapshot.sh"
  echo x > "$ROOT/src/libs/a"

  read -r A_SIG S_SIG <<< "$(fresh_sigs "$ROOT" pi)"

  local f="$FIXTURE_DIR/stale_fresh.yml"
  make_record "$f" "pi-agent-proj" "proj-sandbox"

  local OUT
  OUT=$(DOCKER_STUB_IMAGE_SIG_LABELS="pi-agent-proj:$A_SIG proj-sandbox:$S_SIG" \
    DOCKER_TRACE_LOG="$FIXTURE_DIR/d.log" PATH="$STUB_DIR:$PATH" \
    bash -c "source '$REPO_ROOT/src/libs/session_inventory.sh'; record_image_stale '$f' '$ROOT'")

  if [[ "$OUT" == "fresh" ]]; then
    pass "record_image_stale: both images current -> fresh"
  else
    fail "expected fresh, got '$OUT' (A=$A_SIG S=$S_SIG)"
  fi
}

test_record_image_stale_stale_when_either_diverges() {
  local ROOT="$FIXTURE_DIR/sigrepo_stale"
  mkdir -p "$ROOT/src/libs" "$ROOT/src/capability" "$ROOT/docs/architecture" \
           "$ROOT/docs/concepts" "$ROOT/src/reasoning/agent/skills" \
           "$ROOT/src/reasoning/agent/prompts"
  touch "$ROOT/src/reasoning/entrypoint.sh" "$ROOT/src/capability/entrypoint.sh" \
        "$ROOT/src/capability/snapshot.sh"
  echo x > "$ROOT/src/libs/a"

  read -r A_SIG S_SIG <<< "$(fresh_sigs "$ROOT" pi)"
  local f="$FIXTURE_DIR/stale_one.yml"
  make_record "$f" "pi-agent-proj" "proj-sandbox"

  # Only the SANDBOX image diverges; aggregate must still say stale.
  local OUT
  OUT=$(DOCKER_STUB_IMAGE_SIG_LABELS="pi-agent-proj:$A_SIG proj-sandbox:0000" \
    DOCKER_TRACE_LOG="$FIXTURE_DIR/d.log" PATH="$STUB_DIR:$PATH" \
    bash -c "source '$REPO_ROOT/src/libs/session_inventory.sh'; record_image_stale '$f' '$ROOT'")

  if [[ "$OUT" == "stale" ]]; then
    pass "record_image_stale: one divergent layer -> stale"
  else
    fail "expected stale, got '$OUT'"
  fi
}

test_record_image_stale_unknown_when_images_missing() {
  local f="$FIXTURE_DIR/stale_unk.yml"
  printf 'services:\n  agent:\n    image: only-agent\n' > "$f"

  local OUT
  OUT=$(DOCKER_TRACE_LOG="$FIXTURE_DIR/d.log" PATH="$STUB_DIR:$PATH" \
    bash -c "source '$REPO_ROOT/src/libs/session_inventory.sh'; record_image_stale '$f' '/tmp'")
  local RC=$?

  if [[ $RC -eq 0 && "$OUT" == "unknown" ]]; then
    pass "record_image_stale: incomplete record -> unknown, never aborts"
  else
    fail "expected unknown/rc0, got '$OUT' rc=$RC"
  fi
}

# =============================================================================
# project_current_sha / session_stale
# =============================================================================

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
  if [[ "$OUT" == "fresh" ]]; then
    pass "session_stale: derives current SHA from PROJECT_DIR when not passed"
  else
    fail "derived-SHA path broken: '$OUT'"
  fi
}

# =============================================================================
# enumerate_records
# =============================================================================

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

  if [[ "$ALL" == *"sess-a|pi|20260820-100000|main"* \
     && "$ALL" == *"sess-b|opencode|20260821-090000|dev"* \
     && "$ALL" != *sess-c* \
     && "$PI_ONLY" == "sess-a|pi|20260820-100000|main" ]]
  then
    pass "enumerate_records: emits sid|provider|ts|branch, skips bad records, honors filter"
  else
    fail "enumeration broken: ALL=[$ALL] PI=[$PI_ONLY]"
  fi
}

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

# =============================================================================
# Run all
# =============================================================================

run_test test_record_image_extracts_service_image
run_test test_record_image_stops_at_next_service
run_test test_record_image_missing_service_empty_rc0
run_test test_record_provider_recovers_prefix_and_rejects_noncanonical
run_test test_record_label_pipefail_safe_on_no_match
run_test test_record_image_stale_fresh_when_both_match
run_test test_record_image_stale_stale_when_either_diverges
run_test test_record_image_stale_unknown_when_images_missing
run_test test_project_current_sha_branches
run_test test_session_stale_classification
run_test test_session_stale_derives_sha_from_project_dir
run_test test_enumerate_records_filters_and_skips
run_test test_enumerate_records_no_dir_or_empty_is_silent_rc0

test_done test_session_inventory.sh
