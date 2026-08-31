#!/usr/bin/env bash
# test/stubs/libs/diff_export.sh
# Controllable fake for src/libs/diff_export.sh.
# Success iff SANDBOX_DIR is a git repo: writes a .diff artefact + a
# SUCCESS .export-status (mirrors the real pipeline's observable output, so the
# probe's session_data checks exercise both branches without package_branch).
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