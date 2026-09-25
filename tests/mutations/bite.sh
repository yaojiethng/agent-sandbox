#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_inventory.sh
cp "$src" /tmp/session_inventory.orig
tmp=/tmp/mut.$$

apply() {
  local o="$1" n="$2"
  : > "$tmp"
  while IFS= read -r line; do
    if [[ "$line" == "$o" ]]; then
      [[ -n "$n" ]] && printf '%s\n' "$n" >> "$tmp"
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < /tmp/session_inventory.orig
  cp "$tmp" "$src"
}

run_mut() { # $1 label $2 old $3 new $4.. test files
  local label="$1" old="$2" new="$3"; shift 3
  apply "$old" "$new"
  local out
  out=$(bash "$@" 2>&1) || true
  local pf; pf=$(printf '%s\n' "$out" | grep -oE 'pass=[0-9]+ fail=[0-9]+ skip=[0-9]+' | tail -1)
  local fails; fails=$(printf '%s' "$pf" | grep -oE 'fail=[0-9]+' | cut -d= -f2)
  printf '%-52s %s  [%s]\n' "$label" "$([[ "${fails:-0}" -gt 0 ]] && echo PROVEN || echo SURVIVED)" "${pf:-no-summary}"
  cp /tmp/session_inventory.orig "$src"
}

run_mut "M1 record_image: drop service-boundary reset" \
  '    in_svc && /^  [A-Za-z0-9_-]+:/ { in_svc=0 }' '' tests/test_session_inventory.sh
run_mut "M2 record_provider: drop -agent- gate" \
  '  [[ "$agent_img" == *"-agent-"* ]] || return 0' '  :' tests/test_session_inventory.sh
run_mut "M3 record_label: drop pipefail || true" \
  "    | sed -E 's/.*'\$label':[[:space:]]*//' || true" \
  "    | sed -E 's/.*'\$label':[[:space:]]*//'" tests/test_session_inventory.sh
run_mut "M4 env_field: drop head -1" \
  '    | sed -E "s/.*[[:space:]]-*[[:space:]]*${var}=([^[:space:]]+).*/\1/" | head -1 || true' \
  '    | sed -E "s/.*[[:space:]]-*[[:space:]]*${var}=([^[:space:]]+).*/\1/" || true' tests/test_prune.sh
run_mut "M5 project_current_sha: echo HEAD" \
  '  git -C "$dir" rev-parse HEAD 2>/dev/null || true' '  echo HEAD' tests/test_session_inventory.sh
run_mut "M6 session_stale: swap fresh/stale" \
  '    if [[ "$rec_sha" == "$current_sha" ]]; then echo "fresh"; else echo "stale"; fi' \
  '    if [[ "$rec_sha" == "$current_sha" ]]; then echo "stale"; else echo "fresh"; fi' tests/test_session_inventory.sh
run_mut "M7 session_stale: drop derived current_sha" \
  '    current_sha="$(project_current_sha)"' '    current_sha=""' tests/test_session_inventory.sh
run_mut "M8 enumerate: disable PROVIDER_FILTER" \
  '    if [[ -n "${PROVIDER_FILTER:-}" && "$provider" != "$PROVIDER_FILTER" ]]; then' '    if false; then' tests/test_session_inventory.sh
run_mut "M9 enumerate: keep unrecoverable-provider records" \
  '    [[ -n "$provider" ]] || continue' '    :' tests/test_session_inventory.sh
run_mut "M10 session_log_read: drop -m1 (last-match wins)" \
  '  grep -m1 -E "^${key}=" "$f" | sed -E "s/^${key}=//" || true' \
  '  grep -E "^${key}=" "$f" | sed -E "s/^${key}=//" || true' tests/test_session_log.sh
run_mut "M11 relative_time(+compact): drop negative-diff clamp" \
  '  diff=$(( now - ep )); [[ $diff -lt 0 ]] && diff=0' '  diff=$(( now - ep ))' tests/test_session_log.sh
run_mut "M12 ts_to_epoch: accept any string" \
  '  [[ "$ts" =~ ^[0-9]{8}-[0-9]{6}$ ]] || { echo ""; return 0; }' \
  '  [[ "$ts" =~ ^.*$ ]] || { echo ""; return 0; }' tests/test_session_log.sh
rm -f "$tmp"
echo "--- restored: $(cmp -s "$src" /tmp/session_inventory.orig && echo identical || echo MISMATCH) ---"
