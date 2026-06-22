#!/usr/bin/env bash
# src/libs/diff_export.sh
# diff_export orchestrator — packages session artefacts into an output directory.
# Cross-context — deployed to capability container (sandbox-entrypoint).
# Uses self-resolution for sibling sourcing (_self_dir).
#
# Provides:
#   diff_export          — package session artefacts via package-branch + export time
#   _write_export_status — write .export-status atomically
#   _write_export_error_log — write timestamped error log
#   wait_git_lockfile    — poll for git index.lock to disappear
#
# Reliability features:
#   - Writes .export-status (SUCCESS/FAIL + timestamp) after every run
#   - On failure, writes a timestamped error log for diagnosis
#   - Supports optional RUN_ID parameter for tracing failures to a container
#   - wait_git_lockfile polls for git index.lock before proceeding
#     (prevents races with concurrent git operations)

# diff_export SANDBOX_DIR OUTPUT_DIR [RUN_ID]
#   Packages session artefacts into OUTPUT_DIR via package_branch,
#   then writes EXPORT-TIME.txt and .export-status for audit trail.
#   Optional RUN_ID is embedded in error log filenames for traceability.
diff_export() {
  local SANDBOX_DIR="$1"
  local OUTPUT_DIR="$2"
  local RUN_ID="${3:-}"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "diff_export: SANDBOX_DIR and OUTPUT_DIR are required" >&2
    return 1
  fi

  local _export_ts
  _export_ts=$(date -u +%Y%m%d-%H%M%S)

  echo "diff_export: packaging artefacts..." >&2

  # Source sibling package-branch
  _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$_self_dir/package_branch.sh"

  # Capture package_branch stderr so it can be included in the error log
  # on failure. stderr is also echoed live for immediate visibility.
  # Uses a shared cleanup helper to avoid duplicating the read+remove logic
  # on both the success and failure paths.
  local _pb_stderr
  _pb_stderr=$(mktemp "${OUTPUT_DIR}/.package_branch.stderr.XXXXXXXXXX" 2>/dev/null) || _pb_stderr=""

  _read_and_remove_pb_stderr() {
    local _dump=""
    [[ -n "$_pb_stderr" && -f "$_pb_stderr" ]] && _dump=$(cat "$_pb_stderr" 2>/dev/null) && rm -f "$_pb_stderr"
    echo "$_dump"
  }

  package_branch "$SANDBOX_DIR" "$OUTPUT_DIR" 2> >(tee "$_pb_stderr" >&2) || {
    local _exit_code=$?
    echo "diff_export: package_branch failed (exit $_exit_code) — export incomplete" >&2

    local _stderr_dump
    _stderr_dump=$(_read_and_remove_pb_stderr)

    # Write .export-status with failure
    _write_export_status "$OUTPUT_DIR" "FAIL" "$_export_ts" "$_exit_code"

    # Write error log with stderr capture
    _write_export_error_log "$OUTPUT_DIR" "$_export_ts" "$RUN_ID" "$_exit_code" "$_stderr_dump" "package_branch returned exit $_exit_code"
    return $_exit_code
  }
  _read_and_remove_pb_stderr > /dev/null  # cleanup on success

  # Record export time for audit trail (written after package_branch
  # since it removes and recreates OUTPUT_DIR internally)
  echo "$_export_ts" > "$OUTPUT_DIR/EXPORT-TIME.txt"

  # Write .export-status with success
  _write_export_status "$OUTPUT_DIR" "SUCCESS" "$_export_ts" "0"
}

# _write_export_status OUTPUT_DIR STATUS TIMESTAMP [EXIT_CODE]
#   Writes a .export-status file in OUTPUT_DIR containing STATUS and TIMESTAMP.
#   On failure, includes EXIT_CODE. The file is written atomically (write to
#   temp, rename) so concurrent readers see either the old state or the new one.
_write_export_status() {
  local _dir="$1"
  local _status="$2"
  local _ts="$3"
  local _exit_code="${4:-}"

  local _content="STATUS=${_status}"
  _content="${_content}"$'\n'"TIMESTAMP=${_ts}"
  if [[ -n "$_exit_code" && "$_exit_code" != "0" ]]; then
    _content="${_content}"$'\n'"EXIT_CODE=${_exit_code}"
  fi

  # Atomic write: temp file + rename
  # If mktemp fails, fall back to a deterministic temp name so the
  # function degrades gracefully rather than silently discarding content.
  local _tmp
  _tmp=$(mktemp "${_dir}/.export-status.XXXXXXXXXX" 2>/dev/null) || _tmp="${_dir}/.export-status.$$"
  printf '%s\n' "$_content" > "$_tmp"
  mv -f "$_tmp" "${_dir}/.export-status" 2>/dev/null || true
}

# _write_export_error_log OUTPUT_DIR TIMESTAMP [RUN_ID] [EXIT_CODE] [STDERR_DUMP] [SUMMARY]
#   Writes a timestamped error log file in OUTPUT_DIR for diagnosis.
#   Filename format: {TIMESTAMP}[-{RUN_ID}]-EXPORT-ERROR.log
_write_export_error_log() {
  local _dir="$1"
  local _ts="$2"
  local _run_id="${3:-}"
  local _exit_code="${4:-}"
  local _stderr_dump="${5:-}"
  local _summary="${6:-}"

  local _filename="${_ts}"
  if [[ -n "$_run_id" ]]; then
    _filename="${_filename}-${_run_id}"
  fi
  _filename="${_filename}-EXPORT-ERROR.log"

  {
    echo "=== Export Error ==="
    echo "TIMESTAMP=${_ts}"
    [[ -n "$_run_id" ]] && echo "RUN_ID=${_run_id}"
    [[ -n "$_exit_code" ]] && echo "EXIT_CODE=${_exit_code}"
    [[ -n "$_summary" ]] && echo "SUMMARY=${_summary}"
    echo "---"
    if [[ -n "$_stderr_dump" ]]; then
      echo "STDERR:"
      echo "$_stderr_dump"
    fi
  } > "${_dir}/${_filename}"
  echo "diff_export: error log written to ${_dir}/${_filename}" >&2
}

# =============================================================================
# Lockfile wait helper (shared by entrypoint and callers)
# =============================================================================

# wait_git_lockfile SANDBOX_DIR [TIMEOUT_SECS]
#   Polls for a git index.lock file to disappear. Returns 0 once the lockfile
#   is gone, or 1 if the lockfile persists beyond TIMEOUT_SECS.
#   Default timeout: 3 seconds, poll interval: 200ms.
wait_git_lockfile() {
  local _sandbox_dir="$1"
  local _timeout="${2:-3}"
  local _lockfile="${_sandbox_dir}/.git/index.lock"

  if [[ ! -f "$_lockfile" ]]; then
    return 0
  fi

  local _max_polls=$(( _timeout * 5 ))   # 5 polls/s (200ms each)
  local _poll=0

  while [[ -f "$_lockfile" ]] && [[ $_poll -lt $_max_polls ]]; do
    sleep 0.2
    _poll=$(( _poll + 1 ))
  done

  if [[ -f "$_lockfile" ]]; then
    echo "wait_git_lockfile: lockfile persisted after ${_timeout}s — proceeding anyway" >&2
    return 1
  fi
  return 0
}
