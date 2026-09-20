#!/usr/bin/env bash
# tests/stubs/libs/diff_export.sh
# Test stand-in for src/libs/diff_export.sh that replaces only the docker-facing
# producer (diff_export). The save decision (session_save_needed,
# _save_baseline) comes from the real src/libs/session_save_policy.sh, so the
# skip/run rule under test is the shipped one and cannot drift from it.
#
# diff_export succeeds iff SANDBOX_DIR is a git repo: it writes a .diff artefact
# and a SUCCESS .export-status, mirroring the real pipeline's observable output
# without invoking package_branch.

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/session_save_policy.sh"

# diff_export SANDBOX_DIR OUTPUT_DIR  --  stub producer (docker/package_branch
# replaced by a direct .diff write).
diff_export() {
  local sandbox_dir="$1" out_dir="$2"
  local ts
  ts=$(date -u +%Y%m%d-%H%M%S)

  # Explicit failure lever, independent of repo state, so the session_data
  # FAIL branch is testable in isolation while SESSION_STATE stays valid.
  if [[ -n "${STUB_DIFF_EXPORT_FAIL:-}" ]]; then
    printf 'STATUS=FAIL\n' > "$out_dir/.export-status" 2>/dev/null
    return 1
  fi

  if [[ -d "$sandbox_dir/.git" && -f "$sandbox_dir/.git/HEAD" ]]; then
    echo "stub-diff" > "$out_dir/${ts}.diff" 2>/dev/null
    printf 'STATUS=SUCCESS\n' > "$out_dir/.export-status" 2>/dev/null
    return 0
  fi
  printf 'STATUS=FAIL\n' > "$out_dir/.export-status" 2>/dev/null
  return 1
}

# Return 0 once the git index lockfile is gone (no sleep needed for stubs).
wait_git_lockfile() {
  local sandbox_dir="$1"
  [[ -f "$sandbox_dir/.git/index.lock" ]] && return 1 || return 0
}
