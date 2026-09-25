#!/usr/bin/env bash
# src/libs/cli.sh
# Shared CLI flag parsing for the agent-sandbox scripts. Every leaf script
# parses --help, required identity flags, and a small set of value/boolean
# flags. One declarative parse replaces the per-script `for ARG` loops so
# the routing is identical everywhere (and lives once).
#
# Usage:
#   source "$AGENT_SANDBOX_REPO/src/libs/cli.sh"
#   parse_args USAGE_FN \
#     --project=PROJECT_DIR \
#     --sandbox=SANDBOX_DIR \
#     --bundle=BUNDLE_ARG \
#     --force \
#     -- <args...>
#   parse_args_collect SINK_VAR \
#     --name=PROJECT_NAME \
#     --env=ENV_REL \
#     -- <args...>
#
# Both entry points are policy wrappers over the single implementation
# `_cli_parse`. All parse state is local to the call: the spec registry is
# a local associative array that dies with the function, so one parse can
# never observe another parse's registry.
#
# Spec entries (order-insensitive, before the `--` separator):
#   --flag=VAR      value flag: sets VAR to the flag's value
#   --flag          boolean flag: sets <UPPER_SNAKE(flag)> to "true"
#   --flag=         value flag writing into a caller-predeclared VAR named
#                   <UPPER_SNAKE(flag)> (--branch-from writes BRANCH_FROM)
#   --flag:VAR      boolean flag writing to a specific VAR (--yes:YES_FLAG)
#   <literal>       accepted and ignored (compat toggles such as --permissive)
#
# parse_args returns 0 on success, 1 on unknown argument (usage printed),
# and 2 when --help/-h was given (usage printed, caller decides to exit).
# A value flag with no `=value` and a boolean flag with a value do not match
# their spec shape; the mode's unknown-argument policy decides their fate.
# Boolean vars default to "false" in the caller's scope before parsing,
# value vars to "".

# _cli_parse MODE USAGE_FN SINK_VAR spec... -- args...
#   The single flag-ingestion implementation. Compiles the spec into a local
#   registry, walks the args once, and classifies each arg: a matched spec
#   assigns its target var; an unmatched arg is handled per MODE.
#
#   MODE:
#     error     unmatched args print usage and return 1 (strict, default)
#     drop      unmatched args warn on stderr and are ignored (_CLI_TOLERANT=1)
#     collect   unmatched args append, in order, to the array named SINK_VAR;
#               never errors. In collect mode --help/-h is not special: the
#               caller owns help routing (the dispatcher scans its args).
#
#   --help/-h (MODE error|drop): prints usage via USAGE_FN and returns 2.
#   The help scan stops at a `--` in the args so a positional `--help` can be
#   passed through.
#
#   The only escaping state is intentional: matched value/boolean vars are
#   written with declare -g so the caller reads them after the call.
_cli_parse() {
  local mode="$1" usage_fn="$2" sink_var="$3"
  shift 3

  local -a SPECS=()
  local -a CALL_ARGS=()
  local seen_sep=false spec
  for spec in "$@"; do
    if [[ "$seen_sep" == false && "$spec" == "--" ]]; then
      seen_sep=true
      continue
    fi
    if [[ "$seen_sep" == false ]]; then
      SPECS+=("$spec")
    else
      CALL_ARGS+=("$spec")
    fi
  done

  # --help/-h anywhere wins (the pre-existing raw-scan behavior). Collect
  # mode leaves help routing to the caller.
  if [[ "$mode" != "collect" ]]; then
    local a scan_done=false
    for a in "${CALL_ARGS[@]-}"; do
      [[ "$scan_done" == true ]] && break
      if [[ "$a" == "--" ]]; then
        scan_done=true
        continue
      fi
      [[ "$a" == "--help" || "$a" == "-h" ]] && { "$usage_fn"; return 2; }
    done
  fi

  # Compile the spec into a per-call registry and default the target vars.
  # Unset-only rule: a caller-predeclared default (e.g. DELIVERY="copy")
  # survives a spec whose flag never fires.
  local -A REG=()
  local flag var kind a entry
  for spec in "${SPECS[@]-}"; do
    [[ -n "$spec" ]] || continue
    case "$spec" in
      --*=*)
        flag="${spec%%=*}"
        var="${spec#*=}"
        [[ -n "$var" ]] || var="$(printf '%s' "${flag#--}" | tr 'a-z-' 'A-Z_')"
        kind="value"
        ;;
      --*:*)
        flag="${spec%%:*}"
        var="${spec#*:}"
        kind="boolean"
        ;;
      --*)
        flag="$spec"
        var="$(printf '%s' "${spec#--}" | tr 'a-z-' 'A-Z_')"
        kind="boolean"
        ;;
      *)
        flag="$spec"
        var=""
        kind="literal"
        ;;
    esac
    REG["$flag"]="$kind|$var"
    case "$kind" in
      value)
        [[ -n "$(declare -p "$var" 2>/dev/null)" ]] || declare -g "$var="
        ;;
      boolean)
        [[ -n "$(declare -p "$var" 2>/dev/null)" ]] || declare -g "$var=false"
        ;;
    esac
  done

  # collect mode appends through a local nameref to the caller's sink array.
  if [[ "$mode" == "collect" ]]; then
    local -n SINK="$sink_var"
  fi

  for a in "${CALL_ARGS[@]-}"; do
    [[ -n "$a" ]] || continue
    entry="${REG[${a%%=*}]:-}"
    if [[ -n "$entry" ]]; then
      kind="${entry%%|*}"
      # A value flag requires `=value`; a boolean flag takes no value. A
      # mismatched shape is not a usable match, so the mode's unknown-argument
      # policy decides its fate (reject, warn and drop, or forward).
      if [[ "$kind" == "value" && "$a" != *=* ]]; then entry=""; fi
      if [[ "$kind" == "boolean" && "$a" == *=* ]]; then entry=""; fi
    fi
    if [[ -z "$entry" ]]; then
      case "$mode" in
        error)
          # The unknown-word is overridable: leaf scripts that historically
          # printed a different opening word ("Unknown flag") keep it.
          echo "${_CLI_UNKNOWN_WORD:-Unknown argument}: $a" >&2
          "$usage_fn" >&2
          return 1
          ;;
        drop)
          echo "Warning: ignoring unrecognised argument: $a" >&2
          continue
          ;;
        collect) SINK+=( "$a" ); continue ;;
      esac
    fi
    kind="${entry%%|*}"
    var="${entry#*|}"
    case "$kind" in
      value) declare -g "$var=${a#*=}" ;;
      boolean) declare -g "$var=true" ;;
      literal) : ;;
    esac
  done
  return 0
}

# parse_args USAGE_FN spec... -- args...
#   Strict or tolerant leaf parse (MODE error/drop per _CLI_TOLERANT).
parse_args() {
  local usage_fn="$1"
  shift
  local mode=error
  [[ "${_CLI_TOLERANT:-}" == "1" ]] && mode=drop
  _cli_parse "$mode" "$usage_fn" "" "$@"
}

# parse_args_collect SINK_VAR spec... -- args...
#   Collect parse for forwarding entry points (the agent-sandbox dispatcher).
#   SINK_VAR must exist at call time and may be empty.
parse_args_collect() {
  local sink_var="$1"
  shift
  _cli_parse collect "" "$sink_var" "$@"
}