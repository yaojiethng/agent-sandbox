#!/usr/bin/env bash
# providers/pi/setup.sh
# Pre-run host setup hook for the Pi provider.
# Sourced by scripts/run_agent.sh before compose generation.
# Has access to all variables exported by scripts/start_agent.sh and all libs/ functions.

# _ensure_pi_config_dirs -- pre-create the host-side provider config directory
# and seed the operator-owned model recommendations with the slug-free
# skeleton. A single-file bind mount needs its source present before compose
# runs, and the recommendations file is never committed, so only the skeleton
# lives in the repository. The operator or the setup-model-recommendations
# skill fills in the values.
#
# The function is called last so the hook's exit status is this work's: a
# failed mkdir or cp must abort the run before compose, not fall through to a
# later successful command.
_ensure_pi_config_dirs() {
  local self_dir recommendations
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  recommendations="${SANDBOX_DIR}/.pi/model-recommendations.md"
  mkdir -p "${SANDBOX_DIR}/.pi"
  if [[ ! -e "$recommendations" ]]; then
    cp "${self_dir}/model-recommendations.skeleton.md" "$recommendations"
  fi
}

_ensure_pi_config_dirs
