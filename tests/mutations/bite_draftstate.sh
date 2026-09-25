#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/draft_state.sh; orig=/tmp/draft_state.orig; cp "$src" "$orig"
run() { local label="$1" file="$2"
  if cmp -s "$src" "$orig"; then printf '%-52s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out; out=$(bash "$file" 2>&1)
  local f; f=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -)
  printf '%-52s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ if (new!="") print new; next } {print}' "$orig" > "$src"; }

m 25 '  SESSION_TS="${BASENAME:0:14}"'; run "M1 parse: timestamp slice 0:15 -> 0:14" tests/test_draft_state.sh
m 26 '  SANITIZED_HOST_BRANCH="${BASENAME:15}"'; run "M2 parse: branch slice 16 -> 15" tests/test_draft_state.sh
m 30 '  if [[ "$SANITIZED_HOST_BRANCH" =~ -([a-f0-9]{5,6})$ ]]; then'; run "M3 parse: hex suffix 6 -> 5,6" tests/test_draft_state.sh
m 32 '    :'; run "M4 parse: session-id strip removed" tests/test_draft_state.sh
m 44 '  if false; then'; run "M5 guard: collision check disabled" tests/test_draft_state.sh
m 74 'exported-at: ${EXPORTED_AT}'; run "M6 write: unchanged (control)" tests/test_draft_state.sh
m 74 ''; run "M7 write: exported-at line dropped" tests/test_draft_state.sh
m 77 ''; run "M8 write: session_id line dropped" tests/test_draft_state.sh
m 103 '    KEY=$(echo "$KEY" | tr -d '"'"' '"'"')'; run "M9 read: hyphen->underscore normalisation off" tests/test_draft_state.sh
m 90 '  if false; then'; run "M10 read: branch-exists guard disabled" tests/test_draft_state.sh
m 153 '  if false; then'; run "M11 validate: from_hash check disabled" tests/test_draft_state.sh
m 141 ''; run "M12 validate: pre-clear locals removed" tests/test_draft_state.sh
m 162 '  DRAFT_STATE_COMMIT=$(git -C "$PROJECT_DIR" log "${from_hash}..${CURRENT_BRANCH}" --reverse --format="%H" --grep="^\.draft-state$" 2>/dev/null | tail -1)'; run "M13 validate: head -1 -> tail -1" tests/test_draft_state.sh
m 125 '  if [[ "$CURRENT_BRANCH" == draft/* ]]; then'; run "M14 validate: draft-prefix check inverted" tests/test_draft_state.sh
m 197 '  if [[ -f "$MSG_FILE" ]]; then'; run "M15 commit-msg: empty .msg accepted" tests/test_draft_workflow.sh
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"

echo
echo "== direct probes (original code) =="
# shellcheck disable=SC1090  # subject path is runtime-resolved
source "$orig"
for n in "20260420-120000-feature-fix-deadbeef" "20260420-120000-branch-abcdef" "20260420-120000-main-cafe01"; do
  draft_parse_folder_name "$n"
  printf '  %-42s -> ts=%s branch=%s sid=%s\n' "$n" "$SESSION_TS" "$SANITIZED_HOST_BRANCH" "${SESSION_ID:-<none>}"
done
echo "  colon-in-value round trip:"
  SESSION_TS=X; SANITIZED_HOST_BRANCH=Y
  while IFS=':' read -r K V; do [[ -n "$K" ]] && printf '    key=<%s> value=<%s>\n' "$K" "$V"; done <<< "author: A: B <x@y.z>"
