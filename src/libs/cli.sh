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
# Boolean vars default to "false" in the caller's scope before parsing,
# value vars to "".

# parse_args USAGE_FN spec... -- args...
declare -A _cli_specs=()
parse_args() {
  local usage_fn="$1"
  shift
  local -a SPECS=()
  local -a CALL_ARGS=()
  local seen_sep=false
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

  # --help/-h anywhere wins (matches the pre-existing behavior of scanning
  # the raw arg list before parsing).
  local a
  for a in "${CALL_ARGS[@]:-}"; do
    [[ "$a" == "--help" || "$a" == "-h" ]] && { "$usage_fn"; return 2; }
  done

  # Map each spec to a (flag, var, kind) triple.
  local flag var kind
  for spec in "${SPECS[@]:-}"; do
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
    _cli_specs["$flag"]="$kind|$var"
    # Default the target var so callers can reference it under set -u even
    # when the flag is absent. Only when unset: a caller-predeclared default
    # (e.g. DELIVERY="copy") must survive a spec whose flag never fires.
    case "$kind" in
      value)
        [[ -n "$(declare -p "$var" 2>/dev/null)" ]] || declare -g "$var="
        ;;
      boolean)
        [[ -n "$(declare -p "$var" 2>/dev/null)" ]] || declare -g "$var=false"
        ;;
    esac
  done

  for a in "${CALL_ARGS[@]:-}"; do
    [[ -n "$a" ]] || continue
    local entry="${_cli_specs[${a%%=*}]:-}"
    if [[ -z "$entry" ]]; then
      # Tolerant mode ignores unknown flags (the old prune loop accepted
      # anything not matched); strict mode (default) errors with usage.
      [[ "${_CLI_TOLERANT:-}" == "1" ]] && continue
      # The unknown-word is overridable: leaf scripts that historically printed
      # a different opening word ("Unknown flag") keep their exact output.
      echo "${_CLI_UNKNOWN_WORD:-Unknown argument}: $a" >&2
      "$usage_fn" >&2
      return 1
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