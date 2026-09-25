#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/diff.sh; orig=/tmp/diff.orig; cp "$src" "$orig"
FILES="test_diff_helpers test_diff_workflow test_binary_roundtrip test_apply_count test_package_branch test_diff_rename"
run() { local label="$1"
  if cmp -s "$src" "$orig"; then printf '%-52s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out f=""
  for t in $FILES; do
    out=$(bash "tests/$t.sh" 2>&1); local x; x=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
    [[ -n "$x" ]] && f+="${t}[$x] "
  done
  printf '%-52s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ print new; next } {print}' "$orig" > "$src"; }
m 54 '  untracked=$(git -C "$dir" ls-files --others 2>/dev/null || true)'; run "D1 stage: --exclude-standard dropped"
m 57 '    git -C "$dir" add -- "$f" 2>/dev/null && _DIFF_STAGED_UNTRACKED+=("$f")'; run "D2 stage: add -N -> add (content staged)"
m 65 '  if true; then'; run "D3 restore: empty-array guard off"
m 66 '    git -C "$dir" restore -- "${_DIFF_STAGED_UNTRACKED[@]}" 2>/dev/null || true'; run "D4 restore: --staged dropped (worktree reset)"
m 77 '  if false; then'; run "D5 write_git_diff: empty fast-path off"
m 82 "      | cat \\\\"; run "D6 write_git_diff: trailing-newline append off"
m 88 "  awk '/^index / { getline; next } 1'"; run "D7 strip: binary index preservation off"
m 118 '    return 1'; run "D8 apply: force mode returns 1"
m 123 '  if ! git -C "$PROJECT_DIR" apply < <(strip_index_lines < "$DIFF_FILE"); then'; run "D9 apply: --ignore-whitespace dropped"
m 124 '    if false; then'; run "D10 apply: recount retry off"
m 152 '  ! grep -q "diff --git" "$DIFF_FILE"'; run "D11 is_empty: header anchor off"
m 174 '  if [[ -z "$PROJECT_DIR" || -z "$DIFF_FILE" || -z "$COMMIT_MSG" ]]; then'; run "D12 apply_and_commit: AUTHOR requirement off"
m 190 '    git -C "$PROJECT_DIR" commit --allow-empty -m "$COMMIT_MSG"'; run "D13 apply_and_commit: empty-commit author dropped"
m 196 '  git -C "$PROJECT_DIR" add -u'; run "D14 apply_and_commit: add -A -> add -u"
m 256 '    SINCE_SHA=$(session_state_read "$SANDBOX_DIR" "host_head_sha")'; run "D15 all_changes: init_sha -> host_head_sha"
m 304 '    :'; run "D16 changed_files: deleted-file skip off"
m 312 '    printf "%s\n" "$FILE_LIST" | while IFS= read -r _c; do [[ -f "$SANDBOX_DIR/$_c" ]] && echo "$_c"; done > "$CHANGED_FILES_DIR/MANIFEST.txt"'; run "D17 changed_files: manifest from copied only"
m 315 '    :'; run "D18 changed_files: empty-dir cleanup off"
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
