#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
F=scripts/workflows/interactive.sh
run_case() {   # name OLD NEW
  local name="$1" OLD="$2" NEW="$3"
  cp /tmp/int.orig "$F"
  OLD="$OLD" NEW="$NEW" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$F"
  if cmp -s /tmp/int.orig "$F"; then echo "$name  NO-OP-MUTANT"; cp /tmp/int.orig "$F"; return; fi
  local out rc
  out=$(bash scripts/run_tests.sh 2>&1); rc=$?
  if [[ $rc -eq 0 ]]; then echo "$name  SURVIVED"; else
    echo "$name  PROVEN  ($(echo "$out" | tail -1 | cut -c1-70))"
  fi
  cp /tmp/int.orig "$F"
}

run_case I1  'read -r -p "$PROMPT" REPLY || true'            'read -r -p "$PROMPT" REPLY'
run_case I2  '      echo "Invalid selection. Try again." >&2
      continue
    fi' '      echo "Invalid selection. Try again." >&2
      return 1
    fi'
run_case I3  'CHANNELS=("session" "autosave" "bundles")'      'CHANNELS=("session" "bundles" "autosave")'
run_case I4  'HAS_UNCOMMITTED="[x]"'                          'HAS_UNCOMMITTED="[X]"'
run_case I5  '[BUNDLE]=34 [STATE]=16'                         '[BUNDLE]=50 [STATE]=16'
run_case I6  'age="exported $age"'                            'age="$age"'
run_case I7  'if ! test -t 0; then
    echo "Warning: stdin is not a terminal; interactive prompts may not display correctly." >&2
  fi
' ''
run_case I8  '      echo "Error: unknown subcommand: $SUBCOMMAND" >&2
      return 1' '      echo "Error: unknown subcommand: $SUBCOMMAND" >&2
      return 0'
run_case I9  'PAGE_OFFSET=$((PAGE_OFFSET + 1))'               'PAGE_OFFSET=$((PAGE_OFFSET + 2))'
run_case I10 'PATCH_COUNT=$(find "$ENTRY_DIR/patches" -maxdepth 1 -name "*.diff" 2>/dev/null | wc -l | tr -d " ")' 'PATCH_COUNT=0'
run_case I11 'state="$(project_branch_age "$init_sha")"'      'state="fixed"'
run_case I12 '    if [[ -n "$HEADER" ]]; then
      printf "%*s%s\n" "$((2 + INDEX_W + 2))" "" "$HEADER" >&2
    fi
' ''
run_case I13 'sort -rn | cut -d" " -f2-'                       'sort -n | cut -d" " -f2-'
run_case I14 'NEWEST=$(relative_time "$(date -u -d "@${newest_ep}" '"'"'+%Y%m%d-%H%M%S'"'"')" 2>/dev/null)' 'NEWEST="just now"'
echo "--- restore check ---"; cmp -s /tmp/int.orig "$F" && echo "interactive.sh byte-identical to backup" || echo "MISMATCH"
