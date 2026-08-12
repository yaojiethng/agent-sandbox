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
# Returns empty string (and exit 0) if no step found yet — early in a build
# the log is still empty, and the poll loop must not treat that as a failure.
# The `|| true` makes the pipeline exit 0 when grep finds nothing, so a
# legitimate "no step header written yet" does not trip `set -e`/`pipefail`
# in the sourced context.
_buildkit_current_step() {
  local log="$1"
  local step
  step="$(grep -E '^#[0-9]+ \[' "$log" 2>/dev/null | tail -1 | sed 's/^#[0-9]* \[[^]]*\] //')" || true
  printf '%s\n' "$step"
}

# _buildkit_run <label> <cmd...>
# Runs cmd in the background, showing a single self-updating progress line
# that displays the current BuildKit step (extracted from --progress=plain
# output).  stdout and stderr are captured to a temp file.
#
# While running, shows:   <label>  <current step>  Ns
# On success, shows:        <label> complete (Ns)
# On failure, dumps the captured output and returns the command's exit code so
# the caller owns the conclusive failure report (a single line + exit 1).
#
# Callers must treat the returned status as an expected non-zero value and
# capture it (a bare call under `set -e` would abort before `$?` is read):
#
#   _buildkit_run "Building image: myimage" \
#     docker build --progress=plain -t myimage . \
#     || _build_rc=$?
#   if [[ $_build_rc -ne 0 ]]; then
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

  # `wait` on a failed background build returns its (non-zero) status. Under
  # `set -e` a bare `wait` would abort here before the failure handling below
  # runs. The `wait ... || _rc=$?` form captures the child's exact status while
  # keeping the non-zero return a safely-expected one.
  local _rc=0
  wait "$_prog_pid" || _rc=$?
  local _total=$((SECONDS - _start))

  if [[ $_rc -eq 0 ]]; then
    printf "\r  %s complete (%ds)\n" "$label" "$_total"
    rm -f "$_prog_log"
  else
    # No terminal FAILED line here — on failure the caller issues the single
    # conclusive failure report. Dump the captured build output for diagnosis.
    echo "--- output ---"
    cat "$_prog_log"
    echo "--- end output ---"
    rm -f "$_prog_log"
  fi

  return $_rc
}
