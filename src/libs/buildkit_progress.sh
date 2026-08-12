#!/usr/bin/env bash
# src/libs/buildkit_progress.sh
# BuildKit progress rendering — parses --progress=plain output to show
# a single self-updating progress line with the current build step.
# Sourced by host-side build scripts.
#
# Provides:
#   _buildkit_run            — run docker build with a single self-updating
#                              progress line showing the current BuildKit step
#   _buildkit_current_step   — extract the most recent step header from a
#                              BuildKit plain-format log

# _buildkit_current_step <log>
# Extracts the most recent BuildKit step header from the build log.
# Returns empty string if no step found.
_buildkit_current_step() {
  local log="$1"
  grep -E '^#[0-9]+ \[' "$log" 2>/dev/null | tail -1 | sed 's/^#[0-9]* \[[^]]*\] //'
}

# _buildkit_run <label> <cmd...>
# Runs cmd in the background, showing a single self-updating progress line
# that displays the current BuildKit step (extracted from --progress=plain
# output).  stdout and stderr are captured to a temp file.
#
# While running, shows:   <label>  <current step>  Ns
# On success, shows:        <label> complete (Ns)
# On failure, dumps the captured output and returns the command's exit code.
#
# Example:
#   _buildkit_run "Building image: myimage" \
#     docker build --progress=plain -t myimage .
#   if [[ $? -ne 0 ]]; then
#     exit 1
#   fi
_buildkit_run() {
  local label="$1"
  shift

  local _prog_log
  _prog_log="$(mktemp)"

  "$@" >"$_prog_log" 2>&1 &
  local _prog_pid=$!
  local _start=$SECONDS

  while kill -0 "$_prog_pid" 2>/dev/null; do
    local _step
    _step="$(_buildkit_current_step "$_prog_log")"
    local _elapsed=$((SECONDS - _start))
    if [[ -n "$_step" ]]; then
      # Truncate step description to keep the line from wrapping
      if [[ ${#_step} -gt 70 ]]; then
        _step="${_step:0:67}..."
      fi
      printf "\r%s  %s  %ds " "$label" "$_step" "$_elapsed"
    else
      printf "\r%s  ...  %ds " "$label" "$_elapsed"
    fi
    sleep 0.25
  done

  wait "$_prog_pid"
  local _rc=$?
  local _total=$((SECONDS - _start))

  if [[ $_rc -eq 0 ]]; then
    printf "\r  %s complete (%ds)\n" "$label" "$_total"
    rm -f "$_prog_log"
  else
    printf "\r  %s FAILED (%ds)\n" "$label" "$_total"
    echo "--- output ---"
    cat "$_prog_log"
    echo "--- end output ---"
    rm -f "$_prog_log"
  fi

  return $_rc
}
