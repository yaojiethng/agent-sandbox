#!/usr/bin/env bash
set -u
cd /home/agentuser/sandbox || exit 1
src=src/libs/cli.sh; orig=/tmp/cli.orig; cp "$src" "$orig"
run() { local label="$1"; shift
  if cmp -s "$src" "$orig"; then printf '%-50s NO-OP\n' "$label"; cp "$orig" "$src"; return; fi
  local out f=""
  for t in "$@"; do out=$(bash "$t" 2>&1); local x; x=$(printf '%s\n' "$out" | grep -E '^  FAIL' | sed 's/^  FAIL: //' | paste -sd';' -); [[ -n "$x" ]] && f+="${t}[$x] "; done
  printf '%-50s %s\n' "$label" "${f:-SURVIVED (no unit failed)}"
  cp "$orig" "$src"
}
m() { awk -v n="$1" -v new="$2" 'NR==n{ if (new!="") print new; next } {print}' "$orig" > "$src"; }

m 116 '        :'; run "C1 unset-only default guard removed" tests/test_cli_lib.sh tests/test_start_agent.sh
m 79 '      [[ "$a" == "-h" ]] && { "$usage_fn"; return 2; }'; run "C2 --help detection narrowed to -h" tests/test_cli_lib.sh
m 79 '      [[ "$a" == "--help" || "$a" == "-h" ]] && { "$usage_fn"; return 1; }'; run "C3 help return code 2 -> 1" tests/test_cli_lib.sh
m 76 '  if true; then'; run "C4 collect help-exemption removed" tests/test_cli_lib.sh
m 137 '          echo "Unknown flag: $a" >&2'; run "C5 unknown-word override dropped" tests/test_cli_lib.sh tests/test_start_agent.sh tests/test_resume.sh
m 148 '      value) declare -g "$var=${a##*=}" ;;'; run "C6 value keeps only last = segment" tests/test_cli_lib.sh
m 61 '  local seen_sep=true spec'; run "C7 every spec treated as args" tests/test_cli_lib.sh
m 113 '    REG["$flag"]="$kind>$var"'; run "C8 registry separator changed" tests/test_cli_lib.sh
echo "--- restored: $(cmp -s "$src" "$orig" && echo identical || echo MISMATCH) ---"

echo
echo "== probes (original code) =="
# shellcheck disable=SC1090  # subject path is runtime-resolved
source "$orig"
_test_usage() { echo "usage: test" >&2; }
( PROJECT_NAME=""; parse_args _test_usage --name=PROJECT_NAME -- --name >/dev/null 2>&1; rc=$?
  printf 'P1 bare value flag last, strict : rc=%s PROJECT_NAME=<%s>\n' "$rc" "$PROJECT_NAME" )
( SINK=(); ENV_REL=""; parse_args_collect SINK --env=ENV_REL -- --env >/dev/null 2>&1
  printf 'P2 bare value flag, collect    : ENV_REL=<%s> sink=<%s>\n' "$ENV_REL" "${SINK[*]:-}" )
( SINK=(); PERMISSIVE=""; parse_args_collect SINK --permissive -- p1 >/dev/null 2>&1
  printf 'P3 spec --permissive            : PERMISSIVE=<%s> sink=<%s>\n' "${PERMISSIVE:-<unset>}" "${SINK[*]}" )
( PROJECT_NAME=""; parse_args _test_usage --name=PROJECT_NAME -- '--name=x[0]' >/dev/null 2>&1
  printf 'P4 bracketed value              : PROJECT_NAME=<%s>\n' "$PROJECT_NAME" )
( PROJECT_NAME=""; parse_args _test_usage --name=PROJECT_NAME -- '--name=a=b=c' >/dev/null 2>&1
  printf 'P5 value containing =           : PROJECT_NAME=<%s>\n' "$PROJECT_NAME" )
( DELIVERY="copy"; parse_args _test_usage --delivery=DELIVERY -- >/dev/null 2>&1
  printf 'P6 predeclared default survives : DELIVERY=<%s>\n' "$DELIVERY" )
