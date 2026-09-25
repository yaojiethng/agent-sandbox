#!/usr/bin/env bash
# Bite checks for src/libs/package_branch.sh
cd /home/agentuser/sandbox || exit 1
SRC=src/libs/package_branch.sh
BAK=/tmp/pb.orig
cp "$SRC" "$BAK"
SUITES=(tests/test_package_branch.sh tests/test_diff_rename.sh tests/test_diff_export.sh)

mut() {
  awk -v ln="$1" -v repl="$2" 'NR==ln{print repl; next} {print}' "$BAK" > "$SRC"
  cmp -s "$SRC" "$BAK" && echo "  !! line $1 unchanged"
}

verdicts() {
  awk '/^\[ .* \]$/{n=$0; sub(/^\[ /,"",n); sub(/ \]$/,"",n)}
       /^  (PASS|FAIL): /{if(!(n in seen)){seen[n]=1; print n": "substr($0,3,4)}}'
}

run_one() {
  local label="$1" desc="$2" out fails
  out="$( { for s in "${SUITES[@]}"; do bash "$s"; done; } 2>&1 )"
  fails="$(printf '%s\n' "$out" | verdicts | grep ': FAIL' | sed 's/: FAIL//' | tr '\n' ' ')"
  printf '%-4s %-46s FAIL: %s\n' "$label" "$desc" "${fails:-<none>}"
}

cp "$BAK" "$SRC"
t0=$(date +%s)
base="$( { for s in "${SUITES[@]}"; do bash "$s"; done; } 2>&1 | grep -E '^UNIT:')"
echo "baseline ($(($(date +%s)-t0))s): $(tr '\n' ' ' <<< "$base")"
echo

mut 299 '  MERGE_BASE="$INIT_SHA"'                                  ; run_one B1  'drop merge-base (baseline = init_sha)'
mut 283 '    if false; then'                                        ; run_one B2  'drop the explicit-baseline validation'
mut 328 '  if false; then'                                          ; run_one B3  'drop the refuse-state guard'
mut 201 '  if false; then'                                          ; run_one B4  'drop the preflight bypass'
mut 233 '      if false; then'                                      ; run_one B5  'drop the cancelled-out advisory'
mut 215 '    if false; then'                                        ; run_one B6  'drop the deleted-file skip'
mut 337 '  :'                                                       ; run_one B7  'drop the dispatcher rm -rf'
mut 141 '    local GIT_DIFF_OPTS=()'                                ; run_one B8  'drop --binary from the per-commit diff'
mut 146 '      | cat \'                                             ; run_one B9  'bypass strip_index_lines'
mut 147 "      | awk '{print}' \\"                                  ; run_one B10 'drop the trailing-newline append'
mut 357 '  :'                                                       ; run_one B11 'drop the .export-status write'
mut 356 '  _export_ts=$(date +%Y%m%d-%H%M%S)'                       ; run_one B12 'timestamp no longer UTC'
mut 364 "  echo \"  make draft FROM=bundles BUNDLE=\${bundle_name} BRANCH_SUMMARY=\${BUNDLE_SUMMARY:-\$bundle_name}\" >&2" ; run_one B13 'drop BRANCH_FROM from the hint'
mut 334 '  :'                                                       ; run_one B14 'drop the preflight call'
mut 134 '    COMMIT_SUBJECT=$(git -C "$SANDBOX_DIR" log --format="%s" -1 "$COMMIT_SHA" 2>/dev/null | head -c 60) || COMMIT_SUBJECT=""' ; run_one B15 'drop the subject sanitisation'
mut 152 '    :'                                                     ; run_one B16 'drop the .msg write'
mut 347 '  write_all_changes_diff "$SANDBOX_DIR" "${OUTPUT_DIR}/all-changes.diff" ""' ; run_one B17 'all-changes writer without a baseline'
mut 111 '  :'                                                       ; run_one B18 'drop the package_commits rm'

cp "$BAK" "$SRC"
echo
echo "restored: $(cmp -s "$SRC" "$BAK" && echo yes || echo NO)"
