#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=src/capability/git-hooks/pre-commit.sh
bite() {
  local label="$1" old="$2" new="$3" occ="${4:-1}"
  awk -v old="$old" -v new="$new" -v want="$occ" '
    { p=index($0,old); if(p>0){ n++; if(n==want){ c++; $0=substr($0,1,p-1) new substr($0,p+length(old)) } } print }
    END{ if(c==0) print "  NOMATCH" > "/dev/stderr" }
  ' /tmp/hook.orig > "$SRC"
  if ! diff -q /tmp/hook.orig "$SRC" >/dev/null; then :; else printf '%-4s NO-OP\n' "$label"; cp /tmp/hook.orig "$SRC"; return; fi
  local out; out=$(timeout 300 bash scripts/run_tests.sh 2>&1 | tail -1)
  local verdict="SURVIVED"; [[ "$out" == *"0 failed"* ]] || verdict="PROVEN"
  printf '%-4s %-9s %s\n' "$label" "$verdict" "$out"
  cp /tmp/hook.orig "$SRC"
}
bite H1  "--diff-filter=ACMR -z -- '*.md'" "--diff-filter=ACMRD -z -- '*.md'"
bite H2  '    HAD_FINDINGS=1' '    HAD_FINDINGS=0' 1
bite H3  '      HAD_FINDINGS=1' '      HAD_FINDINGS=0'
bite H4  '  exit 1' '  exit 0'
bite H5  '< <(git diff --cached --name-only --diff-filter=ACMR -z -- '\''*.md'\'')' '< <(git diff --name-only --diff-filter=ACMR -z -- '\''*.md'\'')'
bite H6  '! "$MDL" --no-globs "${STAGED_MD[@]}"' '! "$MDL" --no-globs'
bite H7  'shellcheck -S warning "${STAGED_SH[@]}"' 'shellcheck "${STAGED_SH[@]}"'
bite H8  '"$MDL" --no-globs "${STAGED_MD[@]}"' '"$MDL" "${STAGED_MD[@]}"'
bite H9  "grep -q \"Couldn't parse this shellcheck directive\"" 'grep -q "zzz-never-matches-this"'
bite H10 '    MDL=""' '    HAD_FINDINGS=1; MDL=""'
bite H11 '  echo "pre-commit: fix the findings, or commit with: git commit --no-verify" >&2' '  echo "pre-commit: fix the findings." >&2'
cp /tmp/hook.orig "$SRC"; cmp -s /tmp/hook.orig "$SRC" && echo "restored"
