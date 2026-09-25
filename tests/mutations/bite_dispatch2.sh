#!/usr/bin/env bash
# Multi-line bites for agent-sandbox.sh, applied with perl and verified by diff.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/agent-sandbox.sh
ORIG=/tmp/dispatch.orig

bite() { # bite <label> <literal-old> <literal-new>
  local label="$1"
  cp "$ORIG" "$SRC"
  OLD="$2" NEW="$3" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  if cmp -s "$ORIG" "$SRC"; then printf '%-4s NO-OP (literal not found)\n' "$label"; return 0; fi
  timeout 900 bash scripts/run_tests.sh > "/tmp/bite_dp_$label.log" 2>&1
  cp "$ORIG" "$SRC"
  if grep -q '^FAIL ' "/tmp/bite_dp_$label.log"; then
    printf '%-4s PROVEN    %s\n' "$label" "$(grep '^FAIL ' "/tmp/bite_dp_$label.log" | sed 's/^FAIL //' | tr '\n' ' ')"
  else
    printf '%-4s SURVIVED  %s\n' "$label" "$(tail -1 "/tmp/bite_dp_$label.log")"
  fi
}

bite B2 '  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) route_help "$SUBCOMMAND" ;;
    esac
  done' '  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then route_help "$SUBCOMMAND"; fi'

bite B3 '    echo "Usage: agent-sandbox <onboard|build|start|dry-run|resume|stop|prune|apply|draft|confirm|reject> <flags>"
    exit 1' '    echo "Usage: agent-sandbox <onboard|build|start|dry-run|resume|stop|prune|apply|draft|confirm|reject> <flags>"
    exit 0'

bite B4 '      echo "Unknown subcommand: $SUBCOMMAND"
      print_subcommand_list
      exit 1' '      echo "Unknown subcommand: $SUBCOMMAND"
      print_subcommand_list
      exit 0'

bite B7 '      exec bash "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_REL" \' '      exec bash "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \'

bite B8 '      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_REL" \' '      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \'

bite B9 '    resume)
      resolve_identity sandbox' '    resume)
      resolve_identity name dir sandbox'

bite B10 '    apply)
      resolve_identity dir sandbox' '    apply)
      resolve_identity sandbox'

bite B11 '    start|dry-run)
      exec bash "$SCRIPTS/start_agent.sh" --help ;;' '    start)
      exec bash "$SCRIPTS/start_agent.sh" --help ;;'

bite B12 '    onboard)
      require_base_args' '    onboard)
      resolve_identity name dir sandbox'

bite B14 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi' 'main "$@"'

bite B16 '  parse_args_collect PASSTHROUGH --env=ENV_REL \' '  parse_args_collect PASSTHROUGH \'

bite B17 '    onboard|build|stop|prune)
      exec bash "$SCRIPTS/$sub.sh" --help ;;' '    build|stop|prune)
      exec bash "$SCRIPTS/$sub.sh" --help ;;'

echo "--- integrity ---"; cp "$ORIG" "$SRC"; cmp -s "$ORIG" "$SRC" && echo "restored byte-identical"
