#!/usr/bin/env bash
# tests/test_container_sig.sh
# Unit tests for src/libs/container_sig.sh  --  deterministic source-tree hashing,
# current-sig resolution, and image staleness classification.
#
# Covers:
#   container_sig         --  determinism, order-independence, sensitivity to
#                          content changes, fail-closed missing-path guard,
#                          empty-set and empty-args edge cases
#   current_sig           --  unknown-type rejection, agent-without-provider
#                          rejection, sandbox/agent derivation, live recompute
#   _sandbox_sig_sources  --  static path list contract
#   _agent_sig_sources    --  conditional provider config/preflight inclusion
#   image_is_stale        --  fresh/stale/unknown classification (docker stubbed)

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"
source "$REPO_ROOT/src/libs/container_sig.sh"

# make_sig_repo <dir>  --  build a minimal fake repo root containing every path
# _sandbox_sig_sources/_agent_sig_sources reference, each with one tracked file.
make_sig_repo() {
  local ROOT="$1"
  mkdir -p "$ROOT/src/libs" \
           "$ROOT/src/capability" \
           "$ROOT/docs/architecture" \
           "$ROOT/docs/concepts" \
           "$ROOT/src/reasoning/agent/skills" \
           "$ROOT/src/reasoning/agent/prompts"
  # src/reasoning/entrypoint.sh is referenced as a FILE by _agent_sig_sources;
  # without it agent-layer sig derivation fails closed.
  touch "$ROOT/src/reasoning/entrypoint.sh"
  echo one > "$ROOT/src/libs/a.sh"
  echo two > "$ROOT/src/capability/entrypoint.sh"
  echo three > "$ROOT/src/capability/snapshot.sh"
  echo four > "$ROOT/docs/architecture/x.md"
  echo five > "$ROOT/docs/concepts/y.md"
}

# =============================================================================
# container_sig
# =============================================================================

test_container_sig_deterministic() {
  local ROOT="$FIXTURE_DIR/det"
  make_sig_repo "$ROOT"

  local S1 S2
  S1=$(container_sig "$ROOT" "src/libs" "docs/concepts"</dev/null)
  S2=$(container_sig "$ROOT" "src/libs" "docs/concepts"</dev/null)

  if [[ -n "$S1" && "$S1" == "$S2" ]]; then
    pass "container_sig is deterministic for identical input"
  else
    fail "container_sig differs across calls: '$S1' vs '$S2'"
  fi
}

test_container_sig_is_sha256_hex() {
  local ROOT="$FIXTURE_DIR/hex"
  make_sig_repo "$ROOT"

  local S
  S=$(container_sig "$ROOT" "src/libs"</dev/null)

  if [[ "$S" =~ ^[a-f0-9]{64}$ ]]; then
    pass "container_sig emits 64-char lowercase hex"
  else
    fail "container_sig output not sha256 hex: '$S'"
  fi
}

test_container_sig_order_independent() {
  local ROOT="$FIXTURE_DIR/order"
  make_sig_repo "$ROOT"

  local S1 S2
  S1=$(container_sig "$ROOT" "src/libs" "docs/concepts"</dev/null)
  S2=$(container_sig "$ROOT" "docs/concepts" "src/libs"</dev/null)

  if [[ "$S1" == "$S2" ]]; then
    pass "container_sig independent of source-path argument order"
  else
    fail "container_sig changed when argument order changed: '$S1' vs '$S2'"
  fi
}

test_container_sig_sensitive_to_content() {
  local ROOT="$FIXTURE_DIR/sensitive"
  make_sig_repo "$ROOT"

  local BEFORE AFTER
  BEFORE=$(container_sig "$ROOT" "src/libs"</dev/null)
  echo changed >> "$ROOT/src/libs/a.sh"
  AFTER=$(container_sig "$ROOT" "src/libs"</dev/null)

  if [[ "$BEFORE" != "$AFTER" ]]; then
    pass "container_sig changes when file content changes"
  else
    fail "container_sig ignored a content change"
  fi
}

test_container_sig_missing_path_fails_closed() {
  local ROOT="$FIXTURE_DIR/missing"
  make_sig_repo "$ROOT"
  rm -rf "$ROOT/docs/concepts"

  local OUT RC=0
  OUT=$(container_sig "$ROOT" "src/libs" "docs/concepts" 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"source path not found"* ]]; then
    pass "container_sig fails closed with explicit error on missing source path"
  else
    fail "container_sig should error on missing path, got rc=$RC out='$OUT'"
  fi
}

# Hazard guard: an all-directories-no-files set makes xargs run bare
# `sha256sum`, which reads STDIN. With stdin at EOF (/dev/null) the call must
# still return a valid hex sig instead of garbage. (timeout cannot wrap shell
# functions, so the hang itself is guarded by deterministic stdin redirection.)
test_container_sig_empty_set_returns_pinned_digest() {
  local ROOT="$FIXTURE_DIR/emptyset"
  mkdir -p "$ROOT/src/libs"

  # With `xargs -r`, an empty file set runs the hashing stage zero times; the
  # outer sha256sum then hashes empty input. Pin that exact digest: the old
  # no-`-r` behavior read stdin instead, producing a d41d8c-based value that
  # fails this pin.
  local EXPECTED="e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  local S RC=0
  S=$(container_sig "$ROOT" "src/libs" 2>/dev/null </dev/null) || RC=$?

  if [[ $RC -eq 0 && "$S" == "$EXPECTED" ]]; then
    pass "container_sig pins the empty-set digest (-r: no stdin read)"
  else
    fail "container_sig empty-set: got '$S' rc=$RC, want pinned digest rc=0"
  fi
}

test_container_sig_empty_sources_fails_closed() {
  # An empty sources array must error out, not fall back to bare `find`  -- 
  # which would silently hash whatever cwd the caller happens to be in.
  local OUT RC=0
  OUT=$(container_sig "${FIXTURE_DIR}/emptyargs_root" </dev/null 2>&1); RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"no source paths given"* ]]; then
    pass "container_sig rejects an empty sources array (no cwd fallback)"
  else
    fail "container_sig empty args: rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# _sandbox_sig_sources / _agent_sig_sources
# =============================================================================

test_sandbox_sig_sources_static_paths() {
  local OUT
  OUT=$(_sandbox_sig_sources)

  if grep -q "^src/libs$" <<<"$OUT" && grep -q "^src/capability/entrypoint.sh$" <<<"$OUT"; then
    pass "_sandbox_sig_sources emits canonical sandbox paths line-per-line"
  else
    fail "_sandbox_sig_sources missing expected paths, got: $OUT"
  fi
}

test_agent_sig_sources_conditional_config() {
  local ROOT="$FIXTURE_DIR/agentcfg"
  make_sig_repo "$ROOT"
  mkdir -p "$ROOT/src/reasoning/providers/pi/config"
  touch "$ROOT/src/reasoning/providers/pi/config/settings.json"

  local WITH WITHOUT
  WITH=$(_agent_sig_sources "$ROOT" "pi")
  WITHOUT=$(_agent_sig_sources "$ROOT" "opencode")

  if grep -q "providers/pi/config" <<<"$WITH" && ! grep -q "providers/opencode/config" <<<"$WITHOUT"; then
    pass "_agent_sig_sources includes provider config only when present"
  else
    fail "_agent_sig_sources config-dir conditionality broken"
  fi
}

test_agent_sig_sources_conditional_preflight() {
  local ROOT="$FIXTURE_DIR/agentpre"
  make_sig_repo "$ROOT"
  mkdir -p "$ROOT/src/reasoning/providers/pi"
  touch "$ROOT/src/reasoning/providers/pi/preflight.sh"

  local OUT
  OUT=$(_agent_sig_sources "$ROOT" "pi")

  if grep -q "providers/pi/preflight.sh" <<<"$OUT"; then
    pass "_agent_sig_sources includes preflight only when present"
  else
    fail "_agent_sig_sources missing preflight.sh despite existing file"
  fi
}

# =============================================================================
# current_sig
# =============================================================================

test_current_sig_unknown_type_rejected() {
  local ROOT="$FIXTURE_DIR/unk"
  make_sig_repo "$ROOT"

  local OUT RC=0
  OUT=$(current_sig "bogus-layer" "$ROOT" 2>/dev/null) || RC=$?

  if [[ $RC -ne 0 && -z "$OUT" ]]; then
    pass "current_sig rejects unknown layer type with rc!=0 and no output"
  else
    fail "current_sig should reject bogus type, got rc=$RC out='$OUT'"
  fi
}

test_current_sig_agent_requires_provider() {
  local ROOT="$FIXTURE_DIR/noprovider"
  make_sig_repo "$ROOT"

  local OUT RC=0
  OUT=$(current_sig "agent" "$ROOT" "" 2>/dev/null) || RC=$?

  if [[ $RC -ne 0 && -z "$OUT" ]]; then
    pass "current_sig agent type without provider fails cleanly"
  else
    fail "current_sig agent+empty provider should fail, got rc=$RC out='$OUT'"
  fi
}

test_current_sig_sandbox_matches_manual_hash() {
  local ROOT="$FIXTURE_DIR/sandboxmatch"
  make_sig_repo "$ROOT"

  local EXPECTED ACTUAL
  mapfile -t SRC < <(_sandbox_sig_sources)
  EXPECTED=$(container_sig "$ROOT" "${SRC[@]}"</dev/null)
  ACTUAL=$(current_sig "sandbox" "$ROOT"</dev/null)

  if [[ -n "$EXPECTED" && "$ACTUAL" == "$EXPECTED" ]]; then
    pass "current_sig sandbox equals manual hash of its declared sources"
  else
    fail "current_sig sandbox mismatch: '$ACTUAL' vs '$EXPECTED'"
  fi
}

test_current_sig_recomputes_on_live_tree() {
  local ROOT="$FIXTURE_DIR/live_recompute"
  make_sig_repo "$ROOT"

  # No memoization: consecutive calls must observe tree mutations between
  # them (guards against a cache regressing in with a stale key).
  local S1 S2
  S1=$(current_sig "sandbox" "$ROOT" </dev/null)
  echo mutated > "$ROOT/src/libs/a.sh"
  S2=$(current_sig "sandbox" "$ROOT" </dev/null)

  if [[ -n "$S1" && -n "$S2" && "$S1" != "$S2" ]]; then
    pass "current_sig recomputes per call (reflects live tree state)"
  else
    fail "current_sig returned identical sigs across a mutation: '$S1' vs '$S2'"
  fi
}

test_current_sig_distinct_providers_distinct_keys() {
  local ROOT="$FIXTURE_DIR/twoproviders"
  make_sig_repo "$ROOT"
  # opencode has no extra config; pi gets one  --  sigs must differ.
  mkdir -p "$ROOT/src/reasoning/providers/pi/config"
  echo cfg > "$ROOT/src/reasoning/providers/pi/config/extra.conf"

  local PI OC
  PI=$(current_sig "agent" "$ROOT" "pi"</dev/null)
  OC=$(current_sig "agent" "$ROOT" "opencode"</dev/null)

  if [[ -n "$PI" && -n "$OC" && "$PI" != "$OC" ]]; then
    pass "current_sig distinguishes providers by key"
  else
    fail "current_sig collapsed distinct providers: '$PI' vs '$OC'"
  fi
}

# =============================================================================
# image_is_stale  (docker via tests/stubs/docker)
# =============================================================================

# run_with_docker_stub <fn>  --  execute $fn with tests/stubs shadowing docker.
run_with_docker_stub() {
  (
    PATH="$STUB_DIR:$PATH"
    export DOCKER_TRACE_LOG="${DOCKER_TRACE_LOG:-$FIXTURE_DIR/docker-stub.log}"
    "$@"
  )
}

test_image_is_stale_unknown_when_no_label() {
  local ROOT="$FIXTURE_DIR/nolabel"
  make_sig_repo "$ROOT"

  local OUT
  OUT=$(DOCKER_STUB_IMAGE_SIG_LABEL="" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; image_is_stale img1 sandbox '$ROOT'")

  if [[ "$OUT" == "unknown" ]]; then
    pass "image_is_stale reports unknown when baked label missing"
  else
    fail "image_is_stale expected 'unknown' for missing label, got '$OUT'"
  fi
}

test_image_is_stale_fresh_when_labels_match() {
  local ROOT="$FIXTURE_DIR/fresh"
  make_sig_repo "$ROOT"
  # Compute the expected sig in a FRESH shell: current_sig recomputes per
  # (type,provider) WITHOUT repo_root, so a cached value from an unrelated
  # fixture root would poison the comparison.
  local SIG
  SIG=$(bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; current_sig sandbox '$ROOT'" </dev/null)

  local OUT
  OUT=$(DOCKER_STUB_IMAGE_SIG_LABEL="$SIG" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; image_is_stale img1 sandbox '$ROOT'")

  if [[ "$OUT" == "fresh" ]]; then
    pass "image_is_stale reports fresh when baked label matches recompute"
  else
    fail "image_is_stale expected 'fresh', got '$OUT'"
  fi
}

test_image_is_stale_stale_when_labels_diverge() {
  local ROOT="$FIXTURE_DIR/stalecase"
  make_sig_repo "$ROOT"

  local OUT
  OUT=$(DOCKER_STUB_IMAGE_SIG_LABEL="0000000000000000000000000000000000000000000000000000000000000000" \
    run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; image_is_stale img1 sandbox '$ROOT'")

  if [[ "$OUT" == "stale" ]]; then
    pass "image_is_stale reports stale when baked label diverges"
  else
    fail "image_is_stale expected 'stale', got '$OUT'"
  fi
}

test_image_is_stale_always_returns_zero() {
  local ROOT="$FIXTURE_DIR/rczero"
  make_sig_repo "$ROOT"

  local OUT RC=0
  OUT=$(DOCKER_STUB_IMAGE_SIG_LABEL="" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/libs/container_sig.sh'; image_is_stale nosuchimage agent '$ROOT' 'ghost-provider'")
  RC=$?

  if [[ $RC -eq 0 && "$OUT" == "unknown" ]]; then
    pass "image_is_stale never aborts caller (rc=0 even for unresolvable inputs)"
  else
    fail "image_is_stale must be best-effort rc=0, got rc=$RC out='$OUT'"
  fi
}

# =============================================================================
# Run all
# =============================================================================

run_test test_container_sig_deterministic
run_test test_container_sig_is_sha256_hex
run_test test_container_sig_order_independent
run_test test_container_sig_sensitive_to_content
run_test test_container_sig_missing_path_fails_closed
run_test test_container_sig_empty_set_returns_pinned_digest
run_test test_container_sig_empty_sources_fails_closed
run_test test_sandbox_sig_sources_static_paths
run_test test_agent_sig_sources_conditional_config
run_test test_agent_sig_sources_conditional_preflight
run_test test_current_sig_unknown_type_rejected
run_test test_current_sig_agent_requires_provider
run_test test_current_sig_sandbox_matches_manual_hash
run_test test_current_sig_recomputes_on_live_tree
run_test test_current_sig_distinct_providers_distinct_keys
run_test test_image_is_stale_unknown_when_no_label
run_test test_image_is_stale_fresh_when_labels_match
run_test test_image_is_stale_stale_when_labels_diverge
run_test test_image_is_stale_always_returns_zero

test_done test_container_sig.sh
