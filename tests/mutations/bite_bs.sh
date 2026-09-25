#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=scripts/build.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "NOMATCH" > "/dev/stderr" }
  ' /tmp/bs.orig > "$SRC"
  local out; out=$(timeout 400 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/bs.orig "$SRC"
}
bite B1  '[[ "$REBUILD" == true ]] && REBUILD_FLAG="--no-cache"' 'true'
bite B2  '"$(interface_contract_version)" "" \' '"$(interface_contract_version)" "$cache_flag" \'
bite B4  '    exit 1' '    return 1' 1
bite B5  '    if ! docker image inspect "$image" >/dev/null 2>&1 || [[ -n "$no_cache" ]]; then' '    if ! docker image inspect "$image" >/dev/null 2>&1; then'
bite B6  '  set -euo pipefail' '  true'
bite B7  '    if [[ "$build_missing" == "true" ]]; then' '    if true; then'
bite B8  '  if [[ -z "$PROJECT_NAME" || -z "$PROJECT_DIR" || -z "$SANDBOX_DIR" ]]; then' '  if false; then'
bite B9  '"$REPO_ROOT/src/reasoning/providers/"*/base.dockerfile' '"$REPO_ROOT/src/reasoning/providers/"*/no-such.dockerfile'
bite B10 '  if [[ "$baked" != "$current" ]]; then' '  if false; then'
bite B12 '  if [[ ! -f "$provider_dockerfile" ]]; then' '  if false; then'
bite B13 '      if [[ "$WANT_SANDBOX" == true ]]; then' '      if false; then'
cp /tmp/bs.orig "$SRC"; cmp -s /tmp/bs.orig "$SRC" && echo restored
