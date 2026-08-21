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
#
# Functions:
#   record_image FILE SERVICE  — image value for a named service
#   record_provider FILE       — provider name from the agent service image
#   record_label FILE LABEL    — value of an agent-sandbox.<label> record label
#   session_stale FILE [SHA]   — registry-truth sandbox staleness
#                               (fresh|stale|unknown)
#
# Staleness semantics (see docs/concepts/terminology.md `## staleness`,
# sandbox staleness): a session is stale when its recorded `host-head-sha`
# differs from the current project HEAD.

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
  if [[ -z "$current_sha" && -n "${PROJECT_DIR:-}" ]]; then
    current_sha="$(git -C "$PROJECT_DIR" rev-parse HEAD 2>/dev/null || true)"
  fi
  if [[ -n "$current_sha" ]]; then
    if [[ "$rec_sha" == "$current_sha" ]]; then echo "fresh"; else echo "stale"; fi
  else
    echo "unknown"
  fi
}