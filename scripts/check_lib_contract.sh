#!/usr/bin/env bash
# scripts/check_lib_contract.sh
# Sourced-library contract gate over src/libs/ and src/build/.
#
# Enforces two conventions from docs/development/bash-coding-conventions.md:
#   rule 3.1  --  functions in sourced libraries use `return`, never `exit`.
#                Top-level main flow behind a BASH_SOURCE[0] == "$0" exec guard
#                may exit legitimately, so only function-body exits are flagged.
#   rule 4.4  --  a `while read ...; done < "$VAR"` in a sourced-lib function
#                must not redirect from an unguarded path. A finding unless the
#                function guards the same variable with a `[[ -f "$VAR" ]]` or
#                `[[ ! -f "$VAR" ]]` test before the read.
#
# Heuristic scope: function boundaries are tracked by brace depth outside
# quotes and comments. Here-string (`<<<`) and process-substitution reads are
# in-memory and never flagged; `rm -f "$x"` can masquerade as a guard only in
# the same function. The gate is a backpressure catcher, not a parser.
#
# Exit codes: 0 = no findings, 1 = findings OR the gate could not run. The
# finding count is printed, never encoded in the exit code (see
# bash-coding-conventions.md 3.2).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCAN_DIRS=("$REPO_ROOT/src/libs" "$REPO_ROOT/src/build")
# Test seam: a fixture root exercises the guard and rule branches without
# touching the real tree. The fixture mirrors the real layout under the root:
#   LIB_CONTRACT_SCAN_ROOT/<...>/src/libs, LIB_CONTRACT_SCAN_ROOT/<...>/src/build
if [[ -n "${LIB_CONTRACT_SCAN_ROOT:-}" ]]; then
  SCAN_DIRS=("$LIB_CONTRACT_SCAN_ROOT/src/libs" "$LIB_CONTRACT_SCAN_ROOT/src/build")
fi

FILES=()
for d in "${SCAN_DIRS[@]}"; do
  if [[ ! -d "$d" ]]; then
    echo "Lib-contract gate: $d is missing; cannot determine the file set." >&2
    exit 1
  fi
done
while IFS= read -r F; do
  FILES+=("$F")
done < <(find "${SCAN_DIRS[@]}" -name '*.sh' | sort)

if (( ${#FILES[@]} == 0 )); then
  echo "Lib-contract gate: no shell files found under ${SCAN_DIRS[*]}; cannot run the gate." >&2
  exit 1
fi

# check_file FILE -- print one line per finding, file:line prefixed.
check_file() {
  local file="$1"
  awk -v fname="$file" '
    # brace_delta S -- net { } depth of S outside quotes and comments. Nested
    # ${...} expansions and quoted content (awk programs, echo strings) never
    # move the depth. Quote state carries across records (b_dq, b_sq) so a
    # multi-line quoted span, like an embedded awk program, stays inert.
    function brace_delta(s,    i, c, n) {
      n = 0
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (b_dq) { if (c == "\"") b_dq = 0; continue }
        if (b_sq) { if (c == "'"'"'") b_sq = 0; continue }
        if (c == "\"") { b_dq = 1; continue }
        if (c == "'"'"'") { b_sq = 1; continue }
        if (c == "#") break
        if (c == "{") n++
        else if (c == "}") n--
      }
      return n
    }
    # strip_quotes S -- S with double- and single-quoted spans replaced by
    # spaces, so command tokens (exit) inside strings do not match. Quote
    # state carries across records (s_dq, s_sq).
    function strip_quotes(s,    t, i, c) {
      t = ""
      for (i = 1; i <= length(s); i++) {
        c = substr(s, i, 1)
        if (s_dq) { if (c == "\"") s_dq = 0; t = t " "; continue }
        if (s_sq) { if (c == "'"'"'") s_sq = 0; t = t " "; continue }
        if (c == "\"") { s_dq = 1; t = t " "; continue }
        if (c == "'"'"'") { s_sq = 1; t = t " "; continue }
        if (c == "#") break
        t = t c
      }
      return t
    }
    function var_in(t,    x) {
      # t is a matched span containing "${NAME}" or "$NAME"; return NAME.
      x = t
      sub(/^.*\$/, "", x)
      gsub(/[{}\"]/, "", x)
      return x
    }
    {
      raw = $0
      plain = strip_quotes(raw)

      if (!in_func && (raw ~ /^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/ ||
                       raw ~ /^function[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
        in_func = 1
        depth = brace_delta(raw)
        delete guards
        next
      }

      if (in_func) {
        depth += brace_delta(raw)
        if (depth <= 0) {
          in_func = 0
          next
        }

        # rule 4.4 guard -- a -f / ! -f test records the protected variable
        if (match(raw, /(^|[^A-Za-z0-9_])-f[[:space:]]+["]?\$\{?[A-Za-z_][A-Za-z0-9_]*\}?["]?/)) {
          guards[var_in(substr(raw, RSTART, RLENGTH))] = 1
        }

        # rule 3.1 -- exit inside a function body
        if (plain ~ /(^|[;&|( ])exit([;&|) ]|$)/) {
          printf "%s:%d: exit in a sourced-library function (convention 3.1; use return)\n", fname, NR
          findings++
        }

        # rule 4.4 -- while-read redirect from a variable without a guard
        if (match(raw, /done[[:space:]]*<[[:space:]]*["]?\$\{?[A-Za-z_][A-Za-z0-9_]*\}?["]?/)) {
          v = var_in(substr(raw, RSTART, RLENGTH))
          if (!guards[v]) {
            printf "%s:%d: while-read redirects from unguarded path $%s (convention 4.4; guard with [[ -f ]] || return 0)\n", fname, NR, v
            findings++
          }
        }
      }
    }
    END { if (findings) exit 1 }
  ' "$file"
}

RC=0
TOTAL=0
for f in "${FILES[@]}"; do
  OUT=$(check_file "$f") || RC=1
  if [[ -n "$OUT" ]]; then
    printf '%s\n' "$OUT"
    TOTAL=$(( TOTAL + $(printf '%s\n' "$OUT" | grep -c .) ))
  fi
done

echo "Lib-contract gate: $TOTAL finding(s) across ${#FILES[@]} files"
if (( RC != 0 )); then
  echo "Blocking gate: fix the findings above (see docs/development/bash-coding-conventions.md 3.1 and 4.4)." >&2
  exit 1
fi

echo "Clean (${SECONDS}s)"
exit 0