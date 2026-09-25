#!/usr/bin/env bash
# src/libs/session_hints.sh
# Shared library: session-end command hints printed by start and stop.
# Sourced by run_agent.sh and stop.sh.
#
# Prints the operator-facing hint pair for a session that just ended:
#   Resume this session later: make resume SESSION_ID=<id>
#   Draft this session's changes: make draft BUNDLE=<name>
#
# The draft hint names the exact session export bundle, not the
# auto-resolved newest bundle. It is printed only when a draftable session
# export directory exists for the session.

source "$(dirname "${BASH_SOURCE[0]}")/dirs.sh"

# session_end_hints SANDBOX_DIR SESSION_ID
#   Prints the resume and draft hints for a session that just ended.
#   Resolves CHANGES_DIR from SANDBOX_DIR (host convention) so callers do
#   not need it in the environment. Suppress-on-absent: the draft hint is
#   printed only when the newest *-SESSION_ID export dir under
#   CHANGES_DIR/session/ exists and is draftable (patches/ or
#   uncommitted.diff -- the same check resolve_source_for_draft uses).
session_end_hints() {
  local _sandbox_dir="$1"
  local _session_id="$2"

  echo "Resume this session later: make resume SESSION_ID=$_session_id"

  # An unresolvable sandbox degrades the hint pair to resume-only instead of
  # aborting the caller's teardown with a raw library error.
  [[ -n "$_sandbox_dir" ]] || return 0
  dirs_resolve "$_sandbox_dir" || return 0

  local _session_base="$CHANGES_DIR/session"

  # Newest export for the session: EXPORT_TIME sorts chronologically, so the
  # name-sort tail is the most recent (same ordering rule as resolve_latest_dir).
  # `|| true` absorbs a failed pipeline so a missing base cannot abort the
  # caller under `set -o pipefail`.
  local _export_dir
  _export_dir=$(find "$_session_base" -mindepth 1 -maxdepth 1 -type d \
    -name "*-${_session_id}" 2>/dev/null | sort | tail -n 1) || true

  # Draftability gate: an export dir can exist but hold nothing draftable
  # (failed export with no autosave fallback). A hint naming such a bundle
  # would make `make draft` fail; suppress instead.
  if [[ -d "$_export_dir/patches" ]] || [[ -f "$_export_dir/uncommitted.diff" ]]; then
    echo "Draft this session's changes: make draft BUNDLE=$(basename "$_export_dir")"
  fi
}