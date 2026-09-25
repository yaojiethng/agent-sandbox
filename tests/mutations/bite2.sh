#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/session_inventory.sh
orig=/tmp/session_inventory.orig
cp "$src" "$orig"

repl_ln() { # $1 line-number  $2 replacement-text ('' = delete)
  local n="$1" new="$2" t=/tmp/ln.$$
  awk -v n="$n" -v new="$new" 'NR==n{ if (new != "") print new; next } {print}' "$orig" > "$t" && cp "$t" "$src"
  rm -f "$t"
}

run_mut() { # $1 label $2 result-expected  -- caller must have applied mutation
  local label="$1"
  if cmp -s "$src" "$orig"; then printf '%-52s NO-OP (mutation did not apply)\n' "$label"; return; fi
  shift
  local out; out=$(bash "$@" 2>&1) || true
  local pf; pf=$(printf '%s\n' "$out" | grep -oE 'pass=[0-9]+ fail=[0-9]+ skip=[0-9]+' | tail -1)
  local fails; fails=$(printf '%s' "$pf" | grep -oE 'fail=[0-9]+' | cut -d= -f2)
  printf '%-52s %s  [%s]\n' "$label" "$([[ "${fails:-0}" -gt 0 ]] && echo PROVEN || echo SURVIVED)" "${pf:-no-summary}"
  cp "$orig" "$src"
}

repl_ln 34 ''
run_mut "M1 record_image: drop service-boundary reset" tests/test_session_inventory.sh

repl_ln 61 "    | sed -E 's/.*'\$label':[[:space:]]*//'"
run_mut "M3 record_label: drop pipefail || true" tests/test_session_inventory.sh

repl_ln 185 '  grep -E "^${key}=" "$f" | sed -E "s/^${key}=//" || true'
run_mut "M10 session_log_read: drop -m1" tests/test_session_log.sh

repl_ln 223 '  diff=$(( now - ep ))'
cp "$src" /tmp/t223 && repl_ln 243 '  diff=$(( now - ep ))' >/dev/null 2>&1 || true
# apply both: 243 handles via second pass on the already-223-mutated file
t=/tmp/ln2.$$; awk -v n=243 'NR==n{next}{print}' "$src" > "$t" && cp "$t" "$src"; rm -f "$t"
run_mut "M11 relative_time(+compact): drop negative clamp" tests/test_session_log.sh

repl_ln 212 '  [[ "$ts" =~ ^.*$ ]] || { echo ""; return 0; }'
run_mut "M12 ts_to_epoch: accept any string" tests/test_session_log.sh

echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"

# Direct probes (no suite): leak + over-long timestamp
# shellcheck disable=SC1090  # subject path is runtime-resolved
source "$src"
p=/tmp/probe_rec.yml
printf 'services:\n  sandbox:\n    image: sbx\n  agent:\n    extra: x\n  other:\n    image: LEAK\n' > "$p"
echo "P1 agent-block-without-image, later service has image -> record_image agent = '$(record_image "$p" agent)' (expected empty)"
echo "P2 ts_to_epoch '20260828-120000junk' -> '$(ts_to_epoch '20260828-120000junk')' (expected empty)"
echo "P3 ts_to_epoch '20260828-120000' -> '$(ts_to_epoch '20260828-120000')'"
rm -f "$p"
