#!/usr/bin/env bash
# providers/pi/setup.sh
# Pre-run host setup hook for the Pi provider.
# Sourced by scripts/run_agent.sh before compose generation.
# Has access to all variables exported by scripts/start_agent.sh and all libs/ functions.

# _ensure_pi_config_dirs -- pre-create the host-side provider config directory
# and give the container its copy of the role table. A single-file bind mount
# needs its source present before compose runs.
#
# The repository copy at `$PROJECT_DIR/.agents/model-recommendations.md` is the
# authority, so the container's copy is refreshed from it on every start. A
# session still reading the fallback path, because its library predates the
# repository copy, then reads the table the repository holds rather than whatever
# the file was when it was first seeded. Without a repository copy the slug-free
# skeleton is seeded once and an existing file is left alone.
#
# The function is called last so the hook's exit status is this work's: a
# failed mkdir or cp must abort the run before compose, not fall through to a
# later successful command.
_ensure_pi_config_dirs() {
  local self_dir recommendations canonical
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  recommendations="${SANDBOX_DIR}/.pi/model-recommendations.md"
  canonical="${PROJECT_DIR:-}/.agents/model-recommendations.md"
  mkdir -p "${SANDBOX_DIR}/.pi"
  if [[ -n "${PROJECT_DIR:-}" && -f "$canonical" ]]; then
    cp "$canonical" "$recommendations"
    return 0
  fi
  if [[ ! -e "$recommendations" ]]; then
    cp "${self_dir}/model-recommendations.skeleton.md" "$recommendations"
  fi
}

_ensure_pi_config_dirs
