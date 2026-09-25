#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=src/capability/entrypoint.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "NOMATCH" > "/dev/stderr" }
  ' /tmp/ep.orig > "$SRC"
  local out; out=$(timeout 400 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/ep.orig "$SRC"
}
bite E1  'if [[ ! -d "$SANDBOX_DIR/.git" ]]; then' 'if false; then'
bite E2  'if [[ ! -f "$SANDBOX_DIR/.git/SESSION_STATE" ]]; then' 'if false; then'
bite E3  '_init_sha=$(git -C "$SANDBOX_DIR" rev-list --max-parents=0 HEAD || true)' '_init_sha=$(git -C "$SANDBOX_DIR" rev-parse HEAD || true)'
bite E4  'if [[ -z "$_init_sha" ]]; then' 'if false; then'
bite E5  'if [[ -n "$_sr" && "$_sr" != "${SESSION_ID:-}" ]]; then' 'if true; then'
bite E6  'session_state_write "$SANDBOX_DIR" "changes_dir"  "$CHANGES_DIR"' 'true # changes_dir write removed'
bite E7  'install -m 0755 "$GIT_HOOKS_DIR/pre-commit.sh"' 'install -m 0644 "$GIT_HOOKS_DIR/pre-commit.sh"'
bite E8  'if [[ "$SANDBOX_TYPE" == "copy" && -f "$GIT_HOOKS_DIR/pre-commit.sh" ]]; then' 'if [[ -f "$GIT_HOOKS_DIR/pre-commit.sh" ]]; then'
bite E9  'elif [[ ! -d "$SANDBOX_DIR/.git" ]]; then' 'elif false; then'
bite E10 '/home/agentuser/sandbox/.git/SESSION_STATE' '/nonexistent-dir/SESSION_STATE'
bite E11 'if [[ "$PREFLIGHT_FAILS" -gt 0 ]]; then' 'if [[ "$PREFLIGHT_FAILS" -gt 99 ]]; then'
bite E12 'test -f "${AGENT_HOME:-~/.pi}/AGENTS.md"' 'test -f "${AGENT_HOME:-$HOME/.pi}/AGENTS.md"'
bite E13 'session_export_needed "$_sandbox_dir" || return 0' 'true'
bite E14 'if (( $# > 0 )); then' 'if false; then'
cp /tmp/ep.orig "$SRC"; cmp -s /tmp/ep.orig "$SRC" && echo restored
