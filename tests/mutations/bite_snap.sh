#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=src/capability/snapshot.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "NOMATCH" > "/dev/stderr" }
  ' /tmp/snap.orig > "$SRC"
  local out; out=$(timeout 400 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/snap.orig "$SRC"
}
bite P1  'if [[ -e "$SOURCE_DIR/$f" || -L "$SOURCE_DIR/$f" ]]; then printf' 'printf'
bite P2  '--cached --others --exclude-standard' '--cached --others'
bite P3  'cp -a "$SOURCE_DIR/.git" "$DEST_DIR/.git"' 'cp -r "$SOURCE_DIR/.git" "$DEST_DIR/.git"'
bite P4  'if filesystem_tracks_exec_bits; then' 'if false; then'
bite P5  '[[ -n "$mode" && $(( 0${mode:0:1} & 1 )) -eq 1 ]]' 'return 1'
bite P6  "if git -C \"\$SOURCE_DIR\" ls-files --stage | grep -q '^160000'; then" 'if false; then'
bite P8  'snapshot_baseline_init "$DEST_DIR" || return 1' 'true # baseline init removed'
bite P10 'mkdir -p "$DEST_DIR"' 'true # mkdir removed' 2
bite P11 'mkdir -p "$DEST_DIR"' 'true # mkdir removed' 1
bite P12 'local FLATTEN="${3:-false}"' 'local FLATTEN="${3:-true}"'
cp /tmp/snap.orig "$SRC"; cmp -s /tmp/snap.orig "$SRC" && echo restored
