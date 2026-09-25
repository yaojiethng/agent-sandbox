#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=src/capability/seed_volume.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "NOMATCH" > "/dev/stderr" }
  ' /tmp/sv.orig > "$SRC"
  local out; out=$(timeout 400 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/sv.orig "$SRC"
}
bite S1  'die "$SRC is a linked git worktree' 'true # die "$SRC is a linked git worktree'
bite S2  'die "repository at $SRC has no commits.' 'true # die "repository at $SRC has no commits.'
bite S3  'die "submodules detected in $SRC.' 'true # die "submodules detected in $SRC.'
bite S4  'ls-files -- .agent-sandbox-seed 2>/dev/null' 'ls-files -- .no-such-sentinel-path 2>/dev/null'
bite S5  'git -C "$DEST" stash clear || die "clearing the host stash stack in the volume failed"' 'true # stash clear removed'
bite S6  'if [[ -n "$unreachable" ]]; then' 'if false; then' 1
bite S7  'die "the volume still carries unreachable objects after the prune"' 'true # prune tripwire removed'
bite S8  'verify_parity "$SRC" "$DEST" || die "the volume was not seeded correctly' 'true # verify_parity call removed'
bite S9  'verify_baseline "$SRC" "$DEST" || die "the volume was not seeded correctly' 'true # verify_baseline call removed'
bite S10 'snapshot_check_case_mismatch "$SRC"' 'true # case check removed'
bite S11 'if [[ "$FLATTEN" == "true" ]]; then' 'if [[ "$FLATTEN" != "true" ]]; then'
bite S12 'session_state_write_set "$DEST" "$(git -C "$SRC" rev-parse HEAD)"' 'session_state_write_set "$DEST" "$(git -C "$SRC" rev-list --max-parents=0 HEAD)"'
bite S13 '[[ -d "$SRC/.git" ]] || die "no git repository at $SRC' 'true # no-repo guard removed'
bite S14 'if [[ -n "$(git -C "$dest" status --porcelain)" ]]; then' 'if false; then'
bite S15 'if [[ -n "$stash_list" ]]; then' 'if false; then'
cp /tmp/sv.orig "$SRC"; cmp -s /tmp/sv.orig "$SRC" && echo restored
