#!/usr/bin/env bash
# Mutation bites for scripts/agent-sandbox.sh, each against the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
SRC=scripts/agent-sandbox.sh
ORIG=/tmp/dispatch.orig
cp "$SRC" "$ORIG"

bite() { # bite <label> <literal-old> <literal-new>
  local label="$1"
  cp "$ORIG" "$SRC"
  local n
  n=$(grep -cF -e "$2" "$SRC" || true)
  if [[ "$n" != "1" ]]; then printf '%-4s SKIP  (literal matches=%s)\n' "$label" "$n"; return 0; fi
  OLD="$2" NEW="$3" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$SRC"
  cmp -s "$ORIG" "$SRC" && { printf '%-4s NO-OP\n' "$label"; return 0; }
  timeout 900 bash scripts/run_tests.sh > "/tmp/bite_dp_$label.log" 2>&1
  cp "$ORIG" "$SRC"
  if grep -q '^FAIL ' "/tmp/bite_dp_$label.log"; then
    printf '%-4s PROVEN    %s\n' "$label" "$(grep '^FAIL ' "/tmp/bite_dp_$label.log" | sed 's/^FAIL //' | tr '\n' ' ')"
  else
    printf '%-4s SURVIVED  %s\n' "$label" "$(tail -1 "/tmp/bite_dp_$label.log")"
  fi
}

# B1  the resume arm of route_help points at the wrong file
bite B1 'exec bash "$SCRIPTS/resume_agent.sh" --help ;;' 'exec bash "$SCRIPTS/resume.sh" --help ;;'
# B2  the help scan reads only the first argument
bite B2 '  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) route_help "$SUBCOMMAND" ;;
    esac
  done' '  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then route_help "$SUBCOMMAND"; fi'
# B3  the empty-subcommand guard exits 0
bite B3 '    echo "Usage: agent-sandbox <onboard|build|start|dry-run|resume|stop|prune|apply|draft|confirm|reject> <flags>"
    exit 1' '    echo "Usage: agent-sandbox <onboard|build|start|dry-run|resume|stop|prune|apply|draft|confirm|reject> <flags>"
    exit 0'
# B4  the unknown-subcommand arm exits 0
bite B4 '      echo "Unknown subcommand: $SUBCOMMAND"
      print_subcommand_list
      exit 1' '      echo "Unknown subcommand: $SUBCOMMAND"
      print_subcommand_list
      exit 0'
# B5  the unknown-subcommand message moves to stderr
bite B5 '      echo "Unknown subcommand: $SUBCOMMAND"' '      echo "Unknown subcommand: $SUBCOMMAND" >&2'
# B6  the subcommand list drops package-branch
bite B6 'onboard, build, start, dry-run, resume, stop, prune, apply, draft, confirm, reject, package-branch' 'onboard, build, start, dry-run, resume, stop, prune, apply, draft, confirm, reject'
# B7  start stops forwarding --env
bite B7 '      exec bash "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_REL" \' '      exec bash "$SCRIPTS/start_agent.sh" standard \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \'
# B8  dry-run stops forwarding --env
bite B8 '      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \
        --env="$ENV_REL" \' '      exec bash "$SCRIPTS/start_agent.sh" dry-run \
        --name="$PROJECT_NAME" \
        --project="$PROJECT_DIR" \
        --sandbox="$SANDBOX_DIR" \'
# B9  resume demands the full identity instead of sandbox alone
bite B9 '    resume)
      resolve_identity sandbox' '    resume)
      resolve_identity name dir sandbox'
# B10 apply demands sandbox alone instead of dir+sandbox
bite B10 '    apply)
      resolve_identity dir sandbox' '    apply)
      resolve_identity sandbox'
# B11 the help routing loses dry-run
bite B11 '    start|dry-run)
      exec bash "$SCRIPTS/start_agent.sh" --help ;;' '    start)
      exec bash "$SCRIPTS/start_agent.sh" --help ;;'
# B12 onboard no longer requires base args
bite B12 '    onboard)
      require_base_args' '    onboard)
      resolve_identity name dir sandbox'
# B13 stop stops forwarding the project dir
bite B13 'exec bash "$SCRIPTS/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" --project="$PROJECT_DIR" "${PASSTHROUGH[@]}"' 'exec bash "$SCRIPTS/stop.sh" --name="$PROJECT_NAME" --sandbox="$SANDBOX_DIR" "${PASSTHROUGH[@]}"'
# B14 the source guard is removed
bite B14 'if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi' 'main "$@"'
# B15 help ignores its argument
bite B15 '      route_help "${1:-help}"' '      route_help help'
# B16 the dispatcher stops parsing --env
bite B16 '  parse_args_collect PASSTHROUGH --env=ENV_REL \
' '  parse_args_collect PASSTHROUGH \
'
# B17 the onboard arm of route_help is dropped
bite B17 '    onboard|build|stop|prune)
      exec bash "$SCRIPTS/$sub.sh" --help ;;' '    build|stop|prune)
      exec bash "$SCRIPTS/$sub.sh" --help ;;'
# B18 the self-location loses GNU readlink
bite B18 '_SELF="$(readlink -f "${BASH_SOURCE[0]}")"' '_SELF="$(readlink "${BASH_SOURCE[0]}")"'
# B19 the -h alias is dropped
bite B19 '      --help|-h) route_help "$SUBCOMMAND" ;;' '      --help) route_help "$SUBCOMMAND" ;;'
# B20 start switches mode
bite B20 '      exec bash "$SCRIPTS/start_agent.sh" standard \' '      exec bash "$SCRIPTS/start_agent.sh" serve \'

echo "--- integrity ---"; cp "$ORIG" "$SRC"; cmp -s "$ORIG" "$SRC" && echo "restored byte-identical"
