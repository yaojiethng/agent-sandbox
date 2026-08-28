#!/usr/bin/env bash
# src/libs/export_status.sh
# Shared library: writes .export-status key=value file atomically.
# Sourced by diff_export.sh and package_branch.sh.
#
# Safe to source multiple times  --  defines only a function, no variables.
#
# Provides:
#   _write_export_status  --  write .export-status atomically

# _write_export_status OUTPUT_DIR STATUS TIMESTAMP [EXIT_CODE] [INIT_SHA]
#   Writes a .export-status file in OUTPUT_DIR containing STATUS, TIMESTAMP,
#   and optionally EXIT_CODE (on failure) and INIT_SHA (when available).
#   Written atomically (write to temp, rename) so concurrent readers see
#   either the old state or the new one.
_write_export_status() {
  local _dir="$1"
  local _status="$2"
  local _ts="$3"
  local _exit_code="${4:-}"
  local _init_sha="${5:-}"

  local _content="STATUS=${_status}"
  _content="${_content}"$'\n'"TIMESTAMP=${_ts}"
  if [[ -n "$_exit_code" && "$_exit_code" != "0" ]]; then
    _content="${_content}"$'\n'"EXIT_CODE=${_exit_code}"
  fi
  if [[ -n "$_init_sha" ]]; then
    _content="${_content}"$'\n'"INIT_SHA=${_init_sha}"
  fi

  # Atomic write: temp file + rename
  # If mktemp fails, fall back to a deterministic temp name so the
  # function degrades gracefully rather than silently discarding content.
  local _tmp
  _tmp=$(mktemp "${_dir}/.export-status.XXXXXXXXXX" 2>/dev/null) || _tmp="${_dir}/.export-status.$$"
  printf '%s\n' "$_content" > "$_tmp"
  mv -f "$_tmp" "${_dir}/.export-status" 2>/dev/null || true
}
