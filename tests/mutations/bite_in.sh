#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=scripts/install.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "NOMATCH" > "/dev/stderr" }
  ' /tmp/in.orig > "$SRC"
  local out; out=$(timeout 400 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/in.orig "$SRC"
}
bite J1  'if (( BASH_VERSINFO[0] < 4 )); then' 'if (( BASH_VERSINFO[0] < 3 )); then'
bite J2  'echo "${INSTALL_OS:-$(uname -s)}"' 'echo "$(uname -s)"'
bite J3  'ln -sfn "$REPO_ROOT/scripts/agent-sandbox.sh" "$dir/agent-sandbox"' 'ln -sn "$REPO_ROOT/scripts/agent-sandbox.sh" "$dir/agent-sandbox"'
bite J4  'rm -f "$dir/agent-sandbox"' 'rm -f "$dir/not-our-bin"'
bite J5  'if (( failures > 0 )); then' 'if (( failures > 99 )); then'
bite J6  'if ! command -v git >/dev/null 2>&1; then' 'if false; then'
bite J7  "if ! sed --version 2>/dev/null | grep -q 'GNU sed'; then" 'if false; then'
bite J8  'local dir="${INSTALL_DIR:-}"' 'local dir=""'
bite J9  'dir="${dir/#\~/$HOME}"' 'true'
bite J10 'grep '\''^INSTALL_DIR='\'' "$REPO_ROOT/.env"' 'grep '\''^SOME_OTHER_KEY='\'' "$REPO_ROOT/.env"'
bite J11 'if [[ "$(install_os)" == "Darwin" ]]; then' 'if [[ "$(install_os)" == "darwin" ]]; then'
bite J12 'if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then' 'if false; then'
cp /tmp/in.orig "$SRC"; cmp -s /tmp/in.orig "$SRC" && echo restored
