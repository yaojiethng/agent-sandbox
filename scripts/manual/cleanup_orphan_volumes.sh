#!/usr/bin/env bash
# scripts/manual/cleanup_orphan_volumes.sh
#
# Operator-run host cleanup: remove docker volumes whose session record is
# gone, after listing them and confirming. Manual counterpart of prune Rule 2
# (scripts/prune.sh), which cannot see these volumes today (see
# devlog/discussions/investigation_prune_rule2_orphan_visibility.md).
#
# A volume is an orphan when both hold:
#   - it carries the agent-sandbox.sandbox-dir label (this project's volume)
#   - its agent-sandbox.session-id label has no .compose/<sid>.yml record
#
# The script never removes a volume whose record exists; docker refuses to
# remove a volume in use by a container, so a live session is protected.
# Volumes with an empty session-id label are listed for individual review and
# never removed here.
#
# Run on the host, from anywhere inside the agent-sandbox checkout:
#   bash scripts/manual/cleanup_orphan_volumes.sh
#
# Or point it at another sandbox dir:
#   SANDBOX_DIR=/path/to/sandbox bash scripts/manual/cleanup_orphan_volumes.sh

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SANDBOX_DIR="${SANDBOX_DIR:-$REPO_ROOT}"

if [[ ! -d "$SANDBOX_DIR/.compose" ]]; then
  echo "Note: $SANDBOX_DIR/.compose does not exist; nothing to guard against."
fi

# Enumerate volumes labeled for this sandbox, split into orphans (record gone)
# and reviews (session-id label empty).
reviews=()
orphans=()
while IFS= read -r vol; do
  [[ -n "$vol" ]] || continue
  sid="$(docker volume inspect "$vol" --format '{{index .Labels "agent-sandbox.session-id"}}' 2>/dev/null || true)"
  if [[ -z "$sid" ]]; then
    reviews+=("$vol")
  elif [[ ! -f "$SANDBOX_DIR/.compose/$sid.yml" ]]; then
    orphans+=("$vol $sid")
  fi
done < <(docker volume ls --filter label=agent-sandbox.sandbox-dir --format '{{.Name}}' 2>/dev/null || true)

if [[ "${#orphans[@]}" -eq 0 ]]; then
  echo "No orphaned volumes to remove."
else
  echo "Orphaned volumes (record gone; safe to remove) -- ${#orphans[@]}:"
  printf '  %s\n' "${orphans[@]}"
  read -r -p "Remove these ${#orphans[@]} volume(s)? [y/N] " ans || ans=n
  case "${ans,,}" in
    y|yes)
      for entry in "${orphans[@]}"; do
        vol="${entry%% *}"
        echo "removing: $vol"
        docker volume rm "$vol" || echo "  skipped: $vol"
      done
      ;;
    *)
      echo "Aborted; nothing removed."
      ;;
  esac
fi

if [[ "${#reviews[@]}" -gt 0 ]]; then
  echo ""
  echo "Volumes with no session-id label -- ${#reviews[@]} (permanent orphans, review first, not removed):"
  printf '  %s\n' "${reviews[@]}"
  echo "  Remove individually with: docker volume rm <name>"
fi