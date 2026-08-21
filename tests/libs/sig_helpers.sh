#!/usr/bin/env bash
# tests/libs/sig_helpers.sh
# Shared helpers for image-staleness tests: recompute the container-sig the
# docker stub should report for "fresh" images, so a test can set
# DOCKER_STUB_IMAGE_SIG_LABEL(S) to the value a genuinely-current image would
# carry. Sourced by test_prune.sh, test_resume.sh and test_trace_build.sh.
# Requires REPO_ROOT in the caller's scope.
#
#   sandbox_sig              — current container-sig of the sandbox layer
#   agent_sig <provider>     — current container-sig of an agent layer
#   fresh_sig_map            — per-image `image:sig` map marking the pi
#                              provider's agent + sandbox images fresh

sandbox_sig() {
  source "$REPO_ROOT/src/libs/container_sig.sh"
  local -a s=(); mapfile -t s < <(_sandbox_sig_sources)
  container_sig "$REPO_ROOT" "${s[@]}"
}

agent_sig() {
  source "$REPO_ROOT/src/libs/container_sig.sh"
  local -a s=(); mapfile -t s < <(_agent_sig_sources "$REPO_ROOT" "$1")
  container_sig "$REPO_ROOT" "${s[@]}"
}

fresh_sig_map() {
  echo "pi-agent-test-project:$(agent_sig pi) sandbox-test-project:$(sandbox_sig)"
}
