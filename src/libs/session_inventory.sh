#!/usr/bin/env bash
# libs/session_inventory.sh
#
# Shared registry-record helpers for the `.compose/<session-id>.yml` session
# inventory. Consumed by both `resume_agent.sh` (list / interactive picker /
# identity recovery) and `prune.sh` (Rule 1 stale-record selection). Keeps the
# record helpers in one place — the registry is the single source of truth for
# session identity and staleness.
#
# Pure helper library: defines functions only, sets no caller-owned globals.
# Sources src/libs/container_sig.sh for the image-staleness signal
# (record_image_stale uses image_is_stale/current_sig). Layering is
# one-directional: this record lib depends on the pure sig lib, never vice
# versa.
#
# Functions:
#   record_image FILE SERVICE   — image value for a named service
#   record_provider FILE        — provider name from the agent service image
#   record_label FILE LABEL     — value of an agent-sandbox.<label> record label
#   record_image_stale FILE R   — session-record image staleness (agent+sandbox)
#   project_current_sha      — current HEAD SHA of the caller's project
#   enumerate_records           — per-record `sid|provider|ts|branch` enumeration
#   session_stale FILE [SHA]    — registry-truth sandbox staleness
#                               (fresh|stale|unknown)
#
# Staleness semantics (see docs/concepts/terminology.md `## staleness`,
# sandbox staleness): a session is stale when its recorded `host-head-sha`
# differs from the current project HEAD.

# Image-staleness criterion + recompute (image_is_stale / current_sig).
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/container_sig.sh"

# record_image FILE SERVICE — print the `image:` value for a named service in
# a `.compose/<session-id>.yml` registry record, or nothing if the service (or
# its image) is absent. Service-scoped (awk tracks the service block), so a
# comment or stray `image:` elsewhere cannot shadow the real value.
record_image() {
  local file="$1" service="$2"
  awk -v svc="$service" '
    $0 ~ "^  " svc ":" { in_svc=1; next }
    in_svc && /^  [A-Za-z0-9_-]+:/ { in_svc=0 }
    in_svc && /image:/ {
      sub(/^.*image:[[:space:]]*/, "")
      print
      exit
    }
  ' "$file"
}

# record_provider FILE — recover the provider from the agent service image
# (`<provider>-agent-<lower-project>`, the canonical agent_image_name shape).
# Prints the provider name, or nothing if it cannot be recovered.
record_provider() {
  local file="$1" agent_img
  agent_img="$(record_image "$file" agent)"
  # An agent image is always `<provider>-agent-<project>`; anything else is not
  # a recoverable provider (mirrors the prior anchored `...-agent-...` gate).
  [[ "$agent_img" == *"-agent-"* ]] || return 0
  echo "${agent_img%%-agent-*}"
}

# record_label FILE LABEL — recover `agent-sandbox.<label>` from a registry
# record. Prints the label value, or nothing if absent. Pipefail-safe: a
# no-match grep must not abort a caller under `set -o pipefail`.
record_label() {
  local file="$1" label="$2"
  grep -m1 -E '[[:space:]]*agent-sandbox\.'"$label"':' "$file" \
    | sed -E 's/.*'"$label"':[[:space:]]*//' || true
}

# record_image_stale FILE REPO_ROOT
# Image-staleness of a session record: "stale" when either referenced image
# (agent / sandbox) is image-stale, "fresh" when both are fresh, "unknown"
# when not determinable. Both images are read from the record's own service
# image lines (the rendered compose record carries `sandbox:` and `agent:`
# images — src/build/docker-compose.yml), so no naming reconstruction is
# needed. Only the provider prefix of the agent image is derived, to resolve
# the provider-specific current sig.
record_image_stale() {
  local file="$1"
  local repo_root="$2"
  local agent_img sandbox_img provider as ss
  agent_img="$(record_image "$file" agent)"
  sandbox_img="$(record_image "$file" sandbox)"
  [[ -n "$agent_img" && -n "$sandbox_img" ]] || { echo "unknown"; return 0; }
  provider="${agent_img%%-agent-*}"

  as="$(image_is_stale "$agent_img" agent "$repo_root" "$provider")"
  ss="$(image_is_stale "$sandbox_img" sandbox "$repo_root")"

  if [[ "$as" == "stale" || "$ss" == "stale" ]]; then echo "stale"
  elif [[ "$as" == "fresh" && "$ss" == "fresh" ]]; then echo "fresh"
  else echo "unknown"; fi
}

# project_current_sha — print the current HEAD SHA of the caller's project
# (PROJECT_DIR), or empty when unset or not a git repo. The single shared
# derivation of the current project HEAD for staleness.
project_current_sha() {
  local dir="${PROJECT_DIR:-}"
  [[ -n "$dir" ]] || { echo ""; return 0; }
  git -C "$dir" rev-parse HEAD 2>/dev/null || true
}

# enumerate_records — print one `sid|provider|ts|branch` line per registry
# record (glob `.compose/*.yml`; skips unreadable / unrecoverable-provider
# records), optionally narrowed by PROVIDER_FILTER (caller scope). The shared
# session-inventory core: prune Rule 1 and resume --list/--interactive layer
# their own per-record work (staleness, age, delivery, image) on top.
enumerate_records() {
  local compose_dir="${SANDBOX_DIR:-}/.compose"
  [[ -n "$SANDBOX_DIR" && -d "$compose_dir" ]] || return 0
  local f sid provider ts branch
  for f in "$compose_dir"/*.yml; do
    [[ -f "$f" ]] || continue
    sid="$(basename "$f" .yml)"
    provider="$(record_provider "$f")"
    [[ -n "$provider" ]] || continue
    if [[ -n "${PROVIDER_FILTER:-}" && "$provider" != "$PROVIDER_FILTER" ]]; then
      continue
    fi
    ts="$(record_label "$f" session-ts)"
    branch="$(record_label "$f" host-branch)"
    printf '%s|%s|%s|%s\n' "$sid" "$provider" "${ts:-}" "${branch:-}"
  done
}

# session_stale FILE [CURRENT_SHA] — print the registry-truth sandbox
# staleness of a session record: "fresh" if its host-head-sha matches the
# current project HEAD, "stale" if it differs, "unknown" if the record has no
# host-head-sha or the current HEAD cannot be determined. CURRENT_SHA may be
# passed explicitly, or derived from the caller's PROJECT_DIR git HEAD.
session_stale() {
  local file="$1" current_sha="${2:-}"
  local rec_sha
  rec_sha="$(record_label "$file" host-head-sha)"
  [[ -n "$rec_sha" ]] || { echo "unknown"; return 0; }
  if [[ -z "$current_sha" ]]; then
    current_sha="$(project_current_sha)"
  fi
  if [[ -n "$current_sha" ]]; then
    if [[ "$rec_sha" == "$current_sha" ]]; then echo "fresh"; else echo "stale"; fi
  else
    echo "unknown"
  fi
}