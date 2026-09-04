#!/usr/bin/env bash
# tests/test_dry_run_record.sh
# Unit tests for src/libs/dry_run_record.sh -- the diagnostics-record read /
# correct-container-verification consumed by compose_dry_run.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

source "$REPO_ROOT/src/libs/dry_run_record.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

write_record() {
  local record="$1"; shift
  : > "$record"
  printf 'container=%s\n'            "$1" >> "$record"
  printf 'layer.docker_image=%s\n'   "$2" >> "$record"
  printf 'layer.workspace_mounts=%s\n' "$3" >> "$record"
  printf 'layer.session_state=%s\n'  "$4" >> "$record"
  printf 'layer.session_data=%s\n'   "$5" >> "$record"
  printf 'layer.container_network=%s\n' "$6" >> "$record"
  printf 'layer.agent_runtime=%s\n'  "$7" >> "$record"
  printf 'status=%s\n'               "$8" >> "$record"
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

test_record_value_key() {
  local record="$FIXTURE_DIR/r1.record"
  write_record "$record" "img:tag" PASS PASS PASS PASS PASS PASS PASS
  assert_eq "$(dry_run_record_value "$record" "container")" "img:tag" "container value read"
  assert_eq "$(dry_run_record_value "$record" "status")" "PASS" "status value read"
  assert_eq "$(dry_run_record_value "$record" "layer.session_state")" "PASS" "layer value read"
  assert_eq "$(dry_run_record_value "$record" "missing")" "" "absent key returns empty"
}

test_verify_passes_on_healthy_record() {
  local record="$FIXTURE_DIR/r2.record"
  write_record "$record" "expected-img:tag" PASS PASS PASS PASS PASS PASS PASS
  local rc output
  output=$(dry_run_record_verify "sandbox(capability)" "expected-img:tag" "$record" 2>&1)
  rc=$?
  assert_rc 0 "$rc" "healthy record passes"
  assert_contains "$output" "identity matched" "identity matched reported"
  assert_contains "$output" "overall status PASS" "status PASS reported"
  assert_contains "$output" "layer.session_data = PASS" "per-layer PASS reported"
}

test_verify_fails_on_identity_mismatch() {
  local record="$FIXTURE_DIR/r3.record"
  write_record "$record" "expected-img:tag" PASS PASS PASS PASS PASS PASS PASS
  local rc output
  output=$(dry_run_record_verify "agent(reasoning)" "other-img:tag" "$record" 2>&1)
  rc=$?
  assert_ne "$rc" "0" "mismatched identity returns non-zero"
  assert_contains "$output" "expected 'other-img:tag' got 'expected-img:tag'" "mismatch reported"
}

test_verify_fails_on_layer_fail() {
  local record="$FIXTURE_DIR/r4.record"
  # workspace mounts off -- L5 fails -> overall status FAIL
  write_record "$record" "img:tag" PASS PASS PASS PASS FAIL PASS FAIL
  local rc output
  output=$(dry_run_record_verify "sandbox(capability)" "img:tag" "$record" 2>&1)
  rc=$?
  assert_ne "$rc" "0" "FAIL layer returns non-zero"
  assert_contains "$output" "layer.container_network = FAIL" "failed layer reported"
  assert_contains "$output" "overall status 'FAIL'" "status FAIL reported"
}

test_verify_fails_on_missing_record() {
  local rc output
  output=$(dry_run_record_verify "sandbox(capability)" "img:tag" "$FIXTURE_DIR/nope.record" 2>&1)
  rc=$?
  assert_ne "$rc" "0" "missing record returns non-zero"
  assert_contains "$output" "record missing" "missing-record reported"
}

test_verify_passes_record_within_container() {
  # Regression: identity echo-back equal, one layer FAIL but status PASS is
  # inconsistent -- a correct record must not mix; here all PASS must pass.
  local record="$FIXTURE_DIR/r5.record"
  write_record "$record" "img:tag" PASS PASS PASS PASS PASS PASS PASS
  local rc
  (dry_run_record_verify "sandbox(capability)" "img:tag" "$record" >/dev/null 2>&1)
  rc=$?
  assert_rc 0 "$rc" "clean record verifies cleanly"
}

# --- image-signature (option c) gate ---------------------------------------

STUB_DIR="$TEST_DIR/../tests/stubs"
source "$REPO_ROOT/src/libs/container_sig.sh"

# Minimal fake repo root containing every path the sig sources reference.
make_sig_repo() {
  local ROOT="$1"
  mkdir -p "$ROOT/src/libs" \
           "$ROOT/src/capability" \
           "$ROOT/docs/architecture" \
           "$ROOT/docs/concepts" \
           "$ROOT/src/reasoning/agent/skills" \
           "$ROOT/src/reasoning/agent/prompts"
  touch "$ROOT/src/reasoning/entrypoint.sh"
  echo one > "$ROOT/src/libs/a.sh"
  echo two > "$ROOT/src/capability/entrypoint.sh"
  echo three > "$ROOT/src/capability/snapshot.sh"
}

run_with_docker_stub() {
  (
    export PATH="$STUB_DIR:$PATH"
    export DOCKER_TRACE_LOG="${DOCKER_TRACE_LOG:-$FIXTURE_DIR/docker-stub.log}"
    "$@"
  )
}
run_test test_record_value_key
run_test test_verify_passes_on_healthy_record
run_test test_verify_fails_on_identity_mismatch
run_test test_verify_fails_on_layer_fail
run_test test_verify_fails_on_missing_record
run_test test_verify_passes_record_within_container

# ----------------------------------------------------------------------------
# dry_run_image_verify -- digest roundtrip gate (ADR harness_versioning.md)
# ----------------------------------------------------------------------------

# run_digest_verify IMAGE RECORD TYPE  --  sources both libs, runs the gate.
run_digest_verify() {
  local image="$1" record="$2" type="$3"
  bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; source '$REPO_ROOT/src/libs/dry_run_record.sh'; dry_run_image_verify '$image' '$record' '$type'" 2>&1
}

test_digest_gate_passes_when_digests_match() {
  local rec="$FIXTURE_DIR/rt_pass.yml"
  printf 'labels:\n  agent-sandbox.sandbox-image-digest: sha256:aaa\n' > "$rec"
  local out rc
  out=$(DOCKER_STUB_IMAGE_DIGESTS="img1:sha256:aaa" run_with_docker_stub run_digest_verify img1 "$rec" sandbox)
  rc=$?
  assert_rc 0 "$rc" "digest roundtrip passes when record digest == image digest"
  assert_contains "$out" "matches the record (roundtrip)" "roundtrip pass reported"
}

test_digest_gate_fails_when_digest_diverges() {
  local rec="$FIXTURE_DIR/rt_fail.yml"
  printf 'labels:\n  agent-sandbox.agent-image-digest: sha256:old\n' > "$rec"
  local out rc
  out=$(DOCKER_STUB_IMAGE_DIGESTS="img1:sha256:new" run_with_docker_stub run_digest_verify img1 "$rec" agent)
  rc=$?
  assert_ne "0" "$rc" "digest roundtrip fails when the image changed since generation"
  assert_contains "$out" "digest changed since the record was written" "roundtrip failure reported"
}

test_digest_gate_fails_on_missing_record_label() {
  local rec="$FIXTURE_DIR/rt_missing.yml"
  printf 'services:\n  sandbox:\n    image: img1\n' > "$rec"
  local out rc
  out=$(DOCKER_STUB_IMAGE_DIGESTS="img1:sha256:aaa" run_with_docker_stub run_digest_verify img1 "$rec" sandbox)
  rc=$?
  assert_ne "0" "$rc" "missing digest label fails the gate (no unknown-fallback)"
  assert_contains "$out" "no sandbox-image-digest label" "missing label reported"
}

test_digest_gate_fails_on_dangling_image() {
  local rec="$FIXTURE_DIR/rt_dangling.yml"
  printf 'labels:\n  agent-sandbox.sandbox-image-digest: sha256:pruned\n' > "$rec"
  local out rc
  # Stub returns empty digest for the image -> dangling record digest.
  out=$(DOCKER_STUB_IMAGE_DIGEST="" run_with_docker_stub run_digest_verify img1 "$rec" sandbox)
  rc=$?
  assert_ne "0" "$rc" "dangling digest (image pruned) fails the gate"
  assert_contains "$out" "no longer present in the local daemon" "dangling condition named"
  assert_contains "$out" "rebuild the images" "remediation named"
}

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]

run_test test_digest_gate_passes_when_digests_match
run_test test_digest_gate_fails_when_digest_diverges
run_test test_digest_gate_fails_on_missing_record_label
run_test test_digest_gate_fails_on_dangling_image

