#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=src/build/compose.sh
bite() {  # label old new [occ]
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
  ' /tmp/compose.orig > "$SRC"
  if cmp -s /tmp/compose.orig "$SRC"; then printf '%-4s NO-OP\n' "$label"; cp /tmp/compose.orig "$SRC"; return; fi
  local out; out=$(timeout 300 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/compose.orig "$SRC"
}
bite C1  'if [[ ${#input_files[@]} -eq 0 ]]; then' 'if [[ ${#input_files[@]} -eq 99 ]]; then'
bite C2  'if ! command -v docker >/dev/null 2>&1; then' 'if false; then'
bite C3  'if [[ -z "$agent_image_digest" || -z "$sandbox_image_digest" ]]; then' 'if false; then'
bite C4  "    | grep -v '^[[:space:]]*name:' \\" '    | cat \'
bite C5  '-e "s|{{FLATTEN}}|${FLATTEN:-false}|g" \' '-e "s|{{FLATTEN}}|zzz|g" \'
bite C6  '-e "s|{{AGENT_IMAGE_DIGEST}}|${agent_image_digest:-}|g" \' '-e "s|{{AGENT_IMAGE_DIGEST}}|zzz|g" \'
bite C7  'config --no-interpolate \' 'config \'
bite C8  '  rm -rf "$staging_dir"' '  true' 2
bite C9  '    if [[ ! -f "$src" ]]; then' '    if false; then'
bite C10 '  return "$merge_rc"' '  return 0'
bite C11 '$(printf '\''%02d'\'' "$i")-$(basename "$src")' '$(basename "$src")'
bite C12 'for (( i=n-1; i>=0; i-- )); do' 'for (( i=0; i<n; i++ )); do'
bite C13 '[[ $(( i + 1 )) -lt ${#COMPOSE_ARGS[@]} ]] && { echo' '{ echo'
bite C14 'normalised="$(echo "$project_name" | tr '\''[:upper:]'\'' '\''[:lower:]'\'')"' 'normalised="$project_name"'
bite C15 'normalised="${normalised//[^a-z0-9-]/-}"' 'true'
bite C16 'normalised="${normalised}-${session_id}"' 'true'
bite C17 'sandbox_hash="$(echo "$sandbox_dir" | sha256sum | cut -c1-6)"' 'sandbox_hash="000000"'
bite C18 'down 2>/dev/null || true' 'down -v 2>/dev/null || true'
bite C19 'down -v 2>/dev/null || true' 'down 2>/dev/null || true' 2
bite C20 'if [[ "$state" == "exited" || "$state" == "dead" || -z "$state" ]]; then' 'if false; then'
bite C21 'if [[ "$elapsed" -ge "$timeout" ]]; then' 'if [[ "$elapsed" -gt "$timeout" ]]; then'
bite C22 'container="$SANDBOX_CONTAINER_NAME"' 'container="nonexistent"'
cp /tmp/compose.orig "$SRC"; cmp -s /tmp/compose.orig "$SRC" && echo "restored: identical"
