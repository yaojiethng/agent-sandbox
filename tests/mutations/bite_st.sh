#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=scripts/stop.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "NOMATCH" > "/dev/stderr" }
  ' /tmp/st.orig > "$SRC"
  local out; out=$(timeout 400 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/st.orig "$SRC"
}
bite S1  '[ $? -eq 2 ] && exit 0' 'true'
bite S2  'docker rm "${CONTAINER_IDS[@]}" || true' 'docker rm "${CONTAINER_IDS[@]}"'
bite S3  'docker stop "${CONTAINER_IDS[@]}"' 'docker stop "${CONTAINER_IDS[@]}" || true'
bite S4  '  CONTAINER_IDS=()' '  true' 1
bite S5  'docker network rm "${NETWORK_IDS[@]}" 2>/dev/null || true' 'docker network rm "${NETWORK_IDS[@]}" 2>/dev/null'
bite S6  'session_end_hints "$SANDBOX_DIR" "$SESSION_ID"' 'true'
bite S7  'echo "Error: --prune requires --project (for registry staleness)." >&2' 'true'
bite S8  'if ! canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")"; then exit 1; fi' 'canon_dir="$(sandbox_dir_canon "$SANDBOX_DIR")" || true'
bite S9  '--filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}"' '--filter "label=agent-sandbox.sandbox-dir=WRONG"'
bite S10 '"$REPO_ROOT/scripts/prune.sh"' '"$REPO_ROOT/scripts/no-such-prune.sh"'
bite S11 'LABEL_FILTERS+=(--filter "label=agent-sandbox.session-id=${SESSION_ID}")' 'LABEL_FILTERS+=(--filter "label=agent-sandbox.session-id=always")'
cp /tmp/st.orig "$SRC"; cmp -s /tmp/st.orig "$SRC" && echo restored
