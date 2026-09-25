#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_inventory.sh; orig=/tmp/session_inventory.orig; cp "$src" "$orig"
L() { grep -nF "$1" "$orig" | cut -d: -f1 | head -1; }
run() { local label="$1" file="$2"; if cmp -s "$src" "$orig"; then echo "$label: NO-OP"; else
  local out; out=$(bash "$file" 2>&1)
  printf '%-46s %s\n' "$label" "$(printf '%s\n' "$out" | grep -cE '^  FAIL') failed"; printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^/      /'
  fi; cp "$orig" "$src"; }

awk -v n="$(L '    $0 ~ "^  " svc ":" { in_svc=1; next }')" 'NR==n{print "    { in_svc=1; next }"; next}{print}' "$orig" > "$src"
run "M16 record_image: service match always true" tests/test_session_inventory.sh

awk -v n="$(L '  echo "${SANDBOX_DIR:-}/.compose/${1}.log"')" 'NR==n{print "  echo \"${SANDBOX_DIR:-}/.compose/${1}.txt\""; next}{print}' "$orig" > "$src"
run "M17 session_log_path: .log -> .txt" tests/test_session_log.sh

awk -v n="$(L "    | sed -E 's/.*'\$label':[[:space:]]*//' || true")" 'NR==n{print "    | cat"; next}{print}' "$orig" > "$src"
run "M22 record_label: drop the value strip" tests/test_session_inventory.sh

awk 'NR==203{print "  elif (( diff < 3600 )); then"; next}{print}' "$orig" > /dev/null 2>&1
awk -v n="$(L '    val=$(( diff / 60 )); printf '"'"'%d minute%s ago'"'"' "$val" "$([[ $val -eq 1 ]] && echo '"'"''"'"' || echo '"'"'s'"'"')"')" 'NR==n{print "    val=$(( diff / 120 )); printf '"'"'%d minute%s ago'"'"' \"$val\" \"$([[ $val -eq 1 ]] && echo '"'"''"'"' || echo '"'"'s'"'"')\""; next}{print}' "$orig" > "$src"
run "M18 relative_time: minutes divisor 60 -> 120" tests/test_session_log.sh

awk -v n="$(L '    echo "${key}=${value}" >> "$f"')" 'NR==n{print "    :"; next}{print}' "$orig" > "$src"
run "M20 session_log_set: drop the append branch" tests/test_session_log.sh

awk -v n="$(L '  if grep -q "^${key}=" "$f"; then')" 'NR==n{print "  if false; then"; next}{print}' "$orig" > "$src"
run "M21 session_log_set: upsert -> always append" tests/test_session_log.sh

awk -v n="$(L '    printf '"'"'%dm ago'"'"' $(( diff / 60 ))')" 'NR==n{print "    printf '"'"'%dm ago'"'"' $(( diff / 120 ))"; next}{print}' "$orig" > "$src"
run "M23 relative_time_compact: minutes divisor 60 -> 120" tests/test_session_log.sh
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"
