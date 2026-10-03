#!/usr/bin/env bash
# tests/test_image.sh
# Unit tests for src/build/image.sh  --  image naming and identity functions.
#
# Covers image_digest (the image-ID digest recorded per session, ADR
# harness_versioning.md) via the docker stub. These tests relocated from the
# retired container-sig unit file when container-sig was stripped (P3,
# interface-contract rollover).

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

STUB_DIR="$TEST_DIR/../tests/stubs"
source "$REPO_ROOT/src/build/image.sh"

# run_with_docker_stub <fn>  --  execute $fn with tests/stubs shadowing docker.
run_with_docker_stub() {
  (
    PATH="$STUB_DIR:$PATH"
    export DOCKER_TRACE_LOG="${DOCKER_TRACE_LOG:-$FIXTURE_DIR/docker-stub.log}"
    "$@"
  )
}

# Given: the docker stub reports sha256:abc123 for img1
# When:  image_digest runs
# Then:  it prints that digest
# Asserts: the stub value passes through the inspect call
# Note:  the format string {{.Id}} is pinned only by the stub's literal routing on
#        ".Id}"; finding 89
test_image_digest_returns_stub_digest() {
  local OUT
  OUT=$(DOCKER_STUB_IMAGE_DIGEST="sha256:abc123" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/build/image.sh'; image_digest img1")
  assert_eq "$OUT" "sha256:abc123" "image_digest returns the image ID digest"
}

# Given: a stub per-image map carrying a different digest for each of two images
# When:  image_digest runs for each
# Then:  each call prints its own image's digest
# Asserts: the digest is read per image, not cached or shared
test_image_digest_per_image_map() {
  local OUT_A OUT_B
  OUT_A=$(DOCKER_STUB_IMAGE_DIGESTS="imgA:sha256:aaa imgB:sha256:bbb" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/build/image.sh'; image_digest imgA")
  OUT_B=$(DOCKER_STUB_IMAGE_DIGESTS="imgA:sha256:aaa imgB:sha256:bbb" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/build/image.sh'; image_digest imgB")
  if [[ "$OUT_A" == "sha256:aaa" && "$OUT_B" == "sha256:bbb" ]]; then
    pass "image_digest resolves per-image digests"
  else
    fail "image_digest per-image map wrong (A='$OUT_A' B='$OUT_B')"
  fi
}

# Given: a stub whose digest fallback is empty and an image with no map entry
# When:  image_digest runs
# Then:  stdout is empty
# Asserts: an absent digest yields empty, which compose_generate treats as a hard error
# Note:  a docker that cannot run yields the same empty value; finding 88. The
#        comment's "per-image map" describes a map this unit does not set
test_image_digest_empty_for_missing_image() {
  local OUT
  # Per-image map with no entry AND empty fallback = missing image.
  OUT=$(DOCKER_STUB_IMAGE_DIGEST="" run_with_docker_stub \
    bash -c "source '$REPO_ROOT/src/build/image.sh'; image_digest nosuchimage")
  assert_empty "$OUT" "image_digest returns empty for missing image (compose_generate fails hard)"
}

# =============================================================================
# Run all
# =============================================================================

run_test test_image_digest_returns_stub_digest
run_test test_image_digest_per_image_map
run_test test_image_digest_empty_for_missing_image
test_done test_image
