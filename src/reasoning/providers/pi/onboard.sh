#!/usr/bin/env bash
# providers/pi/onboard.sh

echo "Running Pi provider onboard hook..."

# Pre-create the host-side subdirectories so the provider overlay has a mount
# on the first session (before any prior state exists in SANDBOX_DIR).
mkdir -p "$SANDBOX_DIR/.pi/agent/sessions"
mkdir -p "$SANDBOX_DIR/.pi/agent/prompts"
mkdir -p "$SANDBOX_DIR/.pi/agent/skills"
mkdir -p "$SANDBOX_DIR/.pi/agent/extensions"

# Seed the operator-owned model recommendations with the slug-free skeleton.
# A single-file bind mount needs its source present before compose runs, and
# the file is never committed, so only the skeleton lives in the repository.
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_recommendations="$SANDBOX_DIR/.pi/model-recommendations.md"
if [[ ! -e "$_recommendations" ]]; then
  cp "${_self_dir}/model-recommendations.skeleton.md" "$_recommendations"
fi


