#!/usr/bin/env bash
# tests/stubs/libs/diff_export.sh
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

# Mirror of the real session_save_needed guard so the session-export path in
# the mount test exercises the same skip/run decision. The worktree fixture is
# clean at HEAD == init_sha, so this returns "skip" and _session_export returns
# 0 without writing an empty bundle  --  matching the real no-op rule.
session_save_needed() {
  local sandbox_dir="$1" baseline="$2"
  local head
  [[ -n "$(git -C "$sandbox_dir" status --porcelain 2>/dev/null)" ]] && return 0
  head=$(git -C "$sandbox_dir" rev-parse HEAD 2>/dev/null) || return 0
  [[ -n "$head" && "$head" != "$baseline" ]]
}

_save_baseline() {
  local sandbox_dir="$1" export_dir="$2"
  local head=""
  if [[ -f "$export_dir/.export-status" ]] \
     && grep -q '^STATUS=SUCCESS' "$export_dir/.export-status" 2>/dev/null; then
    head=$(grep '^HEAD=' "$export_dir/.export-status" 2>/dev/null | head -1 | cut -d= -f2-)
  fi
  if [[ -n "$head" ]]; then echo "$head"; return 0; fi
  session_state_read "$sandbox_dir" "init_sha" 2>/dev/null || true
}