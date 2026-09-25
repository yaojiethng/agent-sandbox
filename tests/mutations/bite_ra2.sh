#!/usr/bin/env bash
# Corrected / completed bites for run_agent.sh: R3 done right, R2, R12, R24.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/run_agent.sh
ORIG=/tmp/ra.orig

bite() { # bite <label> <literal-old> <literal-new>
  local label="$1"
  cp "$ORIG" "$SRC"
  OLD="$2" NEW="$3" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  if cmp -s "$ORIG" "$SRC"; then printf '%-4s NO-OP\n' "$label"; return 0; fi
  echo "  [$label] applied: $(diff <(grep -c . "$ORIG") <(grep -c . "$SRC") >/dev/null; diff "$ORIG" "$SRC" | head -6 | tr '\n' '|')"
  timeout 900 bash scripts/run_tests.sh > "/tmp/bite_ra_$label.log" 2>&1
  cp "$ORIG" "$SRC"
  if grep -q '^FAIL ' "/tmp/bite_ra_$label.log"; then
    printf '%-4s PROVEN    %s\n' "$label" "$(grep '^FAIL ' "/tmp/bite_ra_$label.log" | sed 's/^FAIL //' | tr '\n' ' ')"
  else
    printf '%-4s SURVIVED  %s\n' "$label" "$(tail -1 "/tmp/bite_ra_$label.log")"
  fi
}

# R3 corrected: disable the required-delivery guard entirely
bite R3b 'if [[ -z "$DELIVERY" ]]; then
    echo "Error: --delivery is required' 'if false; then
    echo "Error: --delivery is required'
# R2 corrected: the case's empty-string arm
bite R2b 'copy|mount|"")' 'copy|mount)'
# R12 completed: arm teardown before the session runs (the pre-run assignment)
bite R12 'agent_rc=0
TEARDOWN_NEEDED=1' 'agent_rc=0
TEARDOWN_NEEDED=0'
# R24 completed: the serve-only SERVE_PORT warning
bite R24 'if [[ "$MODE" == "serve" ]]; then
    echo "Warning: SERVE_PORT is not set' 'if [[ "$MODE" == "standard" ]]; then
    echo "Warning: SERVE_PORT is not set'

echo "--- integrity ---"; cp "$ORIG" "$SRC"; cmp -s "$ORIG" "$SRC" && echo "restored byte-identical"
