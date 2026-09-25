#!/usr/bin/env bash
# Bite checks for src/libs/session_env.sh
cd /home/agentuser/sandbox || exit 1
SRC=src/libs/session_env.sh
BAK=/tmp/se.orig
cp "$SRC" "$BAK"

mut() {
  awk -v ln="$1" -v repl="$2" 'NR==ln{print repl; next} {print}' "$BAK" > "$SRC"
  cmp -s "$SRC" "$BAK" && { echo "  !! mutation on line $1 did not change the file"; return 1; }
}

verdicts() {
  awk '/^\[ .* \]$/{n=$0; sub(/^\[ /,"",n); sub(/ \]$/,"",n)}
       /^  (PASS|FAIL): /{if(!(n in seen)){seen[n]=1; print n": "substr($0,3,4)}}'
}

run_one() {
  local label="$1" desc="$2" out fails
  out="$( { bash tests/test_session_env.sh; bash tests/test_checkpoint.sh; } 2>&1 )"
  fails="$(printf '%s\n' "$out" | verdicts | grep ': FAIL' | sed 's/: FAIL//' | tr '\n' ' ')"
  printf '%-4s %-58s FAIL: %s\n' "$label" "$desc" "${fails:-<none>}"
}

cp "$BAK" "$SRC"
echo "baseline: $( { bash tests/test_session_env.sh; bash tests/test_checkpoint.sh; } 2>&1 | grep -E '^UNIT:')"
echo

mut 55  '  :'                                                          ; run_one V1  'drop PROJECT_NAME re-assert'
mut 56  '  :'                                                          ; run_one V2  'drop PROJECT_DIR re-assert'
mut 57  '  :'                                                          ; run_one V3  'drop SANDBOX_DIR re-assert'
mut 60  '  if false; then'                                             ; run_one V4  'drop the .git-is-a-directory guard'
mut 64  '  if false; then'                                             ; run_one V5  'drop the has-commits guard'
mut 96  '    branch="$(git -C "$PROJECT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"' ; run_one V6 'detached fallback uses abbrev-ref'
mut 99  '  sanitized_branch="$(echo "$branch" | sed '"'"'s/[^a-zA-Z0-9._-]/_/g'"'"')"'      ; run_one V7 'sanitise to underscore'
mut 109 '  export SANDBOX_CONTAINER_NAME="sandbox-${session_id}"'      ; run_one V8  'container name drops project'
mut 115 '  export WORKTREE_DIR="$sandbox_dir/.worktree"'               ; run_one V9  'worktree override ignored'
mut 128 '  dir="$1"; canon="$dir"'                                     ; run_one V10 'session_id: no canonicalisation'
mut 129 '  echo "${canon}:${2}:${3}" | sha256sum | cut -c1-5'          ; run_one V11 'session_id: 5 chars'
mut 129 '  echo "${canon}:${2}" | sha256sum | cut -c1-6'               ; run_one V12 'session_id: timestamp dropped'
mut 73  '  dirs_resolve "$project_dir"'                                ; run_one V13 'dirs_resolve on the wrong dir'
mut 46  '  :'                                                          ; run_one V14 'drop the onboard hint line'
mut 75  '  HOST_UID=0'                                                 ; run_one V15 'HOST_UID hardcoded'
mut 89  '  export PROVIDER_NAME="nope"'                                ; run_one V16 'PROVIDER_NAME export wrong'
mut 84  '  local project_name="$1"'                                    ; run_one V17 'drop the project_name arg guard'
mut 104 '  sandbox_image="$(sandbox_image_name "WRONG")"'              ; run_one V18 'sandbox image name wrong project'
mut 51  '  env_load /dev/null'                                         ; run_one V19 'env_load skips the .env'
mut 90  '  export SESSION_ID="nope"'                                   ; run_one V20 'SESSION_ID export wrong'

cp "$BAK" "$SRC"
echo
echo "restored: $(cmp -s "$SRC" "$BAK" && echo yes || echo NO)"
