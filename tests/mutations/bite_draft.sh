#!/usr/bin/env bash
# Bite sweep for scripts/workflows/draft.sh. Each mutation runs the full suite.
# Literals pass through the environment so perl cannot interpolate them.
set -uo pipefail
REPO=/home/agentuser/sandbox
F="$REPO/scripts/workflows/draft.sh"
ORIG=/tmp/draft.orig
cp "$F" "$ORIG"

bite() {
  local name="$1" old="$2" new="$3"
  cp "$ORIG" "$F"
  OLD="$old" NEW="$new" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$F"
  if cmp -s "$F" "$ORIG"; then
    echo "NO-OP    $name   (mutation left the file unchanged)"
    return
  fi
  local out rc=0
  out=$(cd "$REPO" && timeout 900 bash scripts/run_tests.sh 2>&1) || rc=$?
  if [[ $rc -ne 0 ]]; then
    echo "PROVEN   $name"
    printf '%s\n' "$out" | grep -E "^  FAIL: " | head -3 | sed 's/^/           /'
  else
    echo "SURVIVED $name"
  fi
  cp "$ORIG" "$F"
}

# ---- draft_collect_patches ----
bite D1-range-upper-bound 'if [[ "$NUM_INT" -ge "$START_NUM" && "$NUM_INT" -le "$END_NUM" ]]; then' 'if [[ "$NUM_INT" -ge "$START_NUM" ]]; then'
bite D2-range-lower-bound 'if [[ "$NUM_INT" -ge "$START_NUM" && "$NUM_INT" -le "$END_NUM" ]]; then' 'if [[ "$NUM_INT" -le "$END_NUM" ]]; then'
bite D3-invalid-range-error 'if [[ -z "$START_NUM" || -z "$END_NUM" ]]; then' 'if false; then'
bite D4-empty-filter-error 'if [[ "${#FILTERED[@]}" -eq 0 ]]; then' 'if false; then'
bite D5-collection-order 'sort -z)' ')'
bite D6-patches-dir-check 'if [[ ! -d "$PATCHES_DIR" ]]; then
    return 1
  fi' 'if false; then
    return 1
  fi'
# ---- draft_create_and_init_branch ----
bite D7-on-draft-branch-guard 'if [[ "$CURRENT_BRANCH" == draft/* ]]; then' 'if false; then'
bite D8-collision-guard 'draft_guard_no_collision "$PROJECT_DIR" "$WORKING_BRANCH" || return 1' ': # collision guard removed'
bite D9-checkout-base 'git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH" "$BASE_COMMIT"' 'git -C "$PROJECT_DIR" checkout -b "$WORKING_BRANCH"'
bite D10-state-commit-author 'git -C "$PROJECT_DIR" commit -m ".draft-state" --author="$AUTHOR"' 'git -C "$PROJECT_DIR" commit -m ".draft-state" --author="nobody <nobody@example.com>"'
# ---- draft_apply_patches ----
bite D11-apply-force 'apply_and_commit "$PROJECT_DIR" "$diff_file" "$COMMIT_MSG" "$AUTHOR" "$FORCE" || {' 'apply_and_commit "$PROJECT_DIR" "$diff_file" "$COMMIT_MSG" "$AUTHOR" || {'
bite D12-apply-failure-verdict '      git -C "$PROJECT_DIR" diff --stat HEAD >&2 || true
      return 1' '      git -C "$PROJECT_DIR" diff --stat HEAD >&2 || true
      return 0'
bite D13-commit-message 'COMMIT_MSG=$(draft_resolve_commit_message "$diff_file")' 'COMMIT_MSG="msg"'
bite D14-blank-line-skip '[[ -z "$diff_file" ]] && continue' ': # blank lines not skipped'
# ---- draft_apply_uncommitted ----
bite D15-uncommitted-empty-guard 'if diff_is_empty "$UNCOMMITTED_DIFF"; then' 'if false; then'
bite D16-uncommitted-file-guard '[[ -f "$UNCOMMITTED_DIFF" ]] || return 0' ': # presence check removed'
# ---- _ingest_export_metadata ----
bite D17-missing-status-error 'elif [[ -z "$_explicit_from" ]]; then' 'elif false; then'
bite D18-missing-timestamp-error 'if [[ -z "$_time" && -z "$_explicit_from" ]]; then' 'if false; then'
bite D19-base-resolves-check 'if ! git -C "$_project_dir" rev-parse --verify "$_base" >/dev/null 2>&1; then' 'if false; then'
bite D20-divergence-warning 'if [[ "$_resolved" != "$_init" ]]; then' 'if false; then'
bite D21-head-default '[[ -n "$_base" ]] || _base="HEAD"' '[[ -n "$_base" ]] || _base=""'
# ---- draft_run ----
bite D22-unreadable-tree-arm 'if [[ "$_tree_rc" -eq 2 ]]; then' 'if false; then'
bite D23-dirty-tree-arm 'if [[ "$_tree_rc" -eq 1 ]]; then' 'if false; then'
bite D24-source-dir-check '[[ -d "$SOURCE_DIR" ]] || { echo "Error: source not found: $SOURCE_DIR" >&2; return 1; }' ': # source check removed'
bite D25-patches-dir-or-count-check '[[ -d "$PATCHES_DIR" ]] || [[ "$DIFF_COUNT" -eq 0 ]] || { echo "Error: no patches/ in $SOURCE_DIR" >&2; return 1; }' ': # patches check removed'
bite D26-diff-count-required ': "${DIFF_COUNT:?}"' ': # required-parameter check removed'
bite D27-branch-suffix-length 'local WORKING_BRANCH="draft/${IDENTITY}-${BRANCH_SLUG}-${FROM_HASH:0:6}"' 'local WORKING_BRANCH="draft/${IDENTITY}-${BRANCH_SLUG}-${FROM_HASH:0:8}"'
# ---- _draft_rollback ----
bite D28-rollback-to-source-branch 'if git -C "$PROJECT_DIR" rev-parse --verify --quiet "refs/heads/$SOURCE_BRANCH" >/dev/null; then' 'if false; then'
bite D29-rollback-branch-delete-guard 'if [[ -n "$DRAFT_BRANCH" && "$DRAFT_BRANCH" == draft/* ]] \' 'if [[ -n "$DRAFT_BRANCH" ]] \'
bite D30-rollback-tag-delete '  git -C "$PROJECT_DIR" tag -d draft-savepoint
}' ': # savepoint tag left behind
}'
# ---- _run_draft_workflow ----
bite D31-patch-list-position 'local PATCH_LIST="${9:-}"' 'local PATCH_LIST="${8:-}"'
bite D32-zero-count-uncommitted-fallback 'if [[ -f "$SOURCE_DIR/uncommitted.diff" && -s "$SOURCE_DIR/uncommitted.diff" ]]; then
      DIFF_COUNT=0' 'if false; then
      DIFF_COUNT=0'
bite D33-savepoint-create 'git -C "$PROJECT_DIR" tag draft-savepoint "$_validated_base"' ': # no savepoint created'
bite D34-savepoint-predelete 'git -C "$PROJECT_DIR" tag -d draft-savepoint 2>/dev/null || true' ': # stale savepoint not removed'
bite D35-rollback-on-apply-failure '  printf '"'"'%s\n'"'"' "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" "$FORCE" || {
    _draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH" "$DRAFT_WORKING_BRANCH"
    return 1
  }' '  printf '"'"'%s\n'"'"' "$PATCH_LIST" | draft_apply_patches "$PROJECT_DIR" "$AUTHOR" "$FORCE" || {
    return 1
  }'
bite D36-rollback-on-uncommitted-failure '  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" "$FORCE" || {
    _draft_rollback "$PROJECT_DIR" "$SOURCE_BRANCH" "$DRAFT_WORKING_BRANCH"
    return 1
  }' '  draft_apply_uncommitted "$PROJECT_DIR" "$SOURCE_DIR" "$AUTHOR" "$FORCE" || {
    return 1
  }'
# ---- main ----
bite D37-base-args-guard 'if [[ -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then' 'if false; then'
bite D38-channel-default 'local CHANNEL="${CHANNEL_ARG:-session}"' 'local CHANNEL="${CHANNEL_ARG}"'
bite D39-interactive-branch 'if [[ "$INTERACTIVE" == true ]]; then' 'if false; then'
bite D40-confirm-hint-var 'echo "  make confirm TARGET_BRANCH=${SOURCE_BRANCH}"' 'echo "  make confirm TARGET=${SOURCE_BRANCH}"'

cp "$ORIG" "$F"
cmp -s "$F" "$ORIG" && echo && echo "restored byte-identical to $ORIG"
