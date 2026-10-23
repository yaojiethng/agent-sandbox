#!/usr/bin/env bash
# providers/pi/onboard.sh

echo "Running Pi provider onboard hook..."

# Pre-create the host-side subdirectories so the provider overlay has a mount
# on the first session (before any prior state exists in SANDBOX_DIR).
mkdir -p "$SANDBOX_DIR/.pi/agent/sessions"
mkdir -p "$SANDBOX_DIR/.pi/agent/prompts"
mkdir -p "$SANDBOX_DIR/.pi/agent/skills"
mkdir -p "$SANDBOX_DIR/.pi/agent/extensions"

# Give the container its copy of the role table. A single-file bind mount needs
# its source present before compose runs. The repository copy at
# `.agents/model-recommendations.md` is the authority, so a present one replaces
# the container's copy; without one the slug-free skeleton is seeded.
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_recommendations="$SANDBOX_DIR/.pi/model-recommendations.md"
_canonical="${PROJECT_DIR:-}/.agents/model-recommendations.md"
if [[ -n "${PROJECT_DIR:-}" && -f "$_canonical" ]]; then
  cp "$_canonical" "$_recommendations"
elif [[ ! -e "$_recommendations" ]]; then
  cp "${_self_dir}/model-recommendations.skeleton.md" "$_recommendations"
fi


