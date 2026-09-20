#!/usr/bin/env bash
# src/libs/export_status.sh
# Shared library: writes .export-status key=value file atomically.
# Sourced by diff_export.sh and package_branch.sh.
#
# Safe to source multiple times  --  defines only a function, no variables.
#
# Provides:
#   _write_export_status  --  write .export-status atomically
#   export_status_read    --  read one field from .export-status
#   export_status_is_success --  test whether the last export succeeded

# _write_export_status OUTPUT_DIR STATUS TIMESTAMP [EXIT_CODE] [INIT_SHA] [HEAD]
#   Writes a .export-status file in OUTPUT_DIR containing STATUS, TIMESTAMP,
#   and optionally EXIT_CODE (on failure), INIT_SHA, and HEAD (the source
#   commit the export captured, which is the next save's comparison point).
#   Written atomically (write to temp, rename) so concurrent readers see
#   either the old state or the new one.
_write_export_status() {
  local _dir="$1"
  local _status="$2"
  local _ts="$3"
  local _exit_code="${4:-}"
  local _init_sha="${5:-}"
  local _head="${6:-}"

  local _content="STATUS=${_status}"
  _content="${_content}"$'\n'"TIMESTAMP=${_ts}"
  if [[ -n "$_exit_code" && "$_exit_code" != "0" ]]; then
    _content="${_content}"$'\n'"EXIT_CODE=${_exit_code}"
  fi
  if [[ -n "$_init_sha" ]]; then
    _content="${_content}"$'\n'"INIT_SHA=${_init_sha}"
  fi
  if [[ -n "$_head" ]]; then
    _content="${_content}"$'\n'"HEAD=${_head}"
  fi

  # Atomic write: temp file + rename
  # If mktemp fails, fall back to a deterministic temp name so the
  # function degrades gracefully rather than silently discarding content.
  local _tmp
  _tmp=$(mktemp "${_dir}/.export-status.XXXXXXXXXX" 2>/dev/null) || _tmp="${_dir}/.export-status.$$"
  printf '%s\n' "$_content" > "$_tmp"
  mv -f "$_tmp" "${_dir}/.export-status" 2>/dev/null || true
}

# export_status_read EXPORT_DIR KEY
#   Reads one field from EXPORT_DIR/.export-status. Prints the value, or the
#   empty string when the file or the key is absent. The value is everything
#   after the first '=', so a value may contain '='.
#   This is the single reader for the format _write_export_status writes.
export_status_read() {
  local _dir="$1"
  local _key="$2"
  local _file="$_dir/.export-status"
  [[ -f "$_file" ]] || return 0
  while IFS='=' read -r _k _v; do
    if [[ "$_k" == "$_key" ]]; then
      echo "$_v"
      return 0
    fi
  done < "$_file"
}

# export_status_is_success EXPORT_DIR
#   Returns 0 when the last export recorded STATUS=SUCCESS, 1 otherwise
#   (missing file, missing STATUS line, or any other status).
export_status_is_success() {
  local _dir="$1"
  [[ "$(export_status_read "$_dir" STATUS)" == "SUCCESS" ]]
}
