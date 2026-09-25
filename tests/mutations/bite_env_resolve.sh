#!/usr/bin/env bash
# libs/env_resolve.sh  --  centralized precedence resolver for the sandbox
# identity triple (PROJECT_NAME, PROJECT_DIR, SANDBOX_DIR), mirroring pi's
# thin-interface / deep-resolution model.
#
# Precedence per identifier (highest wins):
#   1. explicit value (the CLI flag on the current invocation)
#   2. host environment variable AGENT_SANDBOX_<KEY>
#   3. the per-sandbox .env file
#   4. no runtime default  --  a missing value at every level is a hard error
#      pointing at `agent-sandbox onboard`.
#
# The .env is located by default_env_file: an absolute ENV_REF (--env) as-is, a
# relative ENV_REF a name under the sandbox dir, and an empty ENV_REF
# <sandbox>/.env, else the invocation CWD's .env. The TWO-level guard reads only
# the AGENT_SANDBOX_* keys as the environment level so a plain exported
# PROJECT_DIR/SANDBOX_DIR/PROJECT_NAME (leaked by a sourced script) does not
# bypass .env precedence.

_self_env_resolve_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_self_env_resolve_dir/libs/env.sh"

# _env_value FILE KEY
#   Prints the value of KEY read from FILE using env_load, or empty if KEY is
#   absent. Runs env_load in a subshell so FILE content does not leak into the
#   caller's environment.
_env_value() {
  local file="$1" key="$2"
  ( unset "$key"; env_load "$file" >/dev/null 2>&1 || true; printf '%s' "${!key:-}" )
}

# default_env_file RAW_ENV_REF SANDBOX_DIR
#   Prints the .env path for the raw --env value under the single .env-path
#   contract: an absolute RAW_ENV_REF is used as-is; a relative RAW_ENV_REF is a
#   name under SANDBOX_DIR; an empty RAW_ENV_REF falls back to <sandbox>/.env,
#   else the invocation CWD's .env.
default_env_file() {
  local raw="${1:-}" sandbox_dir="$2"
  if [[ -n "$raw" && "$raw" == /* ]]; then
    printf '%s' "$raw"
  elif [[ -n "$sandbox_dir" ]]; then
    printf '%s' "$sandbox_dir/${raw:-.env}"
  else
    printf '%s' "${PWD}/${raw:-.env}"
  fi
}

# env_resolve_one EXPLICIT ENVVAR KEY ENV_FILE
#   Resolves one identifier by precedence: explicit, then the named env var,
#   then the KEY value from ENV_FILE, else a hard error. Prints the value.
#   This is the single resolution primitive; the identity triple is a sequence
#   of the same rule.
env_resolve_one() {
  local explicit="$1" envvar="$2" key="$3" env_file="$4" value
  if [[ -n "$explicit" ]]; then printf '%s' "$explicit"; return 0; fi
  if [[ -n "${!envvar:-}" ]]; then printf '%s' "${!envvar}"; return 0; fi
  if [[ -n "$env_file" && -f "$env_file" ]]; then
    value="$(_env_value "$env_file" "$key")"
    if [[ -n "$value" ]]; then printf '%s' "$value"; return 0; fi
  fi
  echo "Error: $key is not set (no explicit flag, no $envvar env var, no $key in ${env_file:-.env})." >&2
  echo "  Run: agent-sandbox onboard --name=<name> --project=<path> --sandbox=<path>" >&2
  return 1
}

# env_resolve_identity EXPLICIT_NAME EXPLICIT_DIR EXPLICIT_SANDBOX [ENV_REF [FIELDS...]]
#   Resolves the requested identity fields (default: name dir sandbox). An
#   empty explicit value means "not given". ENV_REF is the raw --env value
#   (absolute, sandbox-relative, or empty) normalized via default_env_file.
#   SANDBOX is anchored first (a relative ENV_REF needs a sandbox that may live
#   in the .env). Exports PROJECT_NAME/PROJECT_DIR/SANDBOX_DIR for the
#   requested fields and the normalized ENV_FILE into the caller's scope.
env_resolve_identity() {
  local expl_name="${1:-}" expl_dir="${2:-}" expl_sandbox="${3:-}" env_ref="${4:-}"
  local fields=()
  if [[ $# -gt 4 ]]; then
    shift 4
    fields=("$@")
  fi
  if [[ ${#fields[@]} -eq 0 ]]; then fields=(name dir sandbox); fi

  local need_name=false need_dir=false need_sandbox=false
  local f
  for f in "${fields[@]}"; do
    case "$f" in
      name)    need_name=true ;;
      dir)     need_dir=true ;;
      sandbox) need_sandbox=true ;;
    esac
  done

  local ep
  if $need_sandbox && [[ -z "$expl_sandbox" ]]; then
    # Chicken-and-egg: a relative ENV_REF needs a sandbox that may itself live
    # in the .env, so bootstrap SANDBOX from the CWD fallback first.
    ep="$(default_env_file "$env_ref" "")"
    SANDBOX_DIR="$(env_resolve_one "" AGENT_SANDBOX_SANDBOX_DIR SANDBOX_DIR "$ep")" || return 1
  else
    SANDBOX_DIR="$expl_sandbox"
  fi
  ep="$(default_env_file "$env_ref" "$SANDBOX_DIR")"
  export ENV_FILE="$ep"

  if $need_name; then
    if [[ -n "$expl_name" ]]; then
      export PROJECT_NAME="$expl_name"
    else
      PROJECT_NAME="$(env_resolve_one "" AGENT_SANDBOX_PROJECT_NAME PROJECT_NAME "$ep")" || return 1
    fi
  fi
  if $need_dir; then
    if [[ -n "$expl_dir" ]]; then
      export PROJECT_DIR="$expl_dir"
    else
      PROJECT_DIR="$(env_resolve_one "" AGENT_SANDBOX_PROJECT_DIR PROJECT_DIR "$ep")" || return 1
    fi
  fi
  export PROJECT_NAME PROJECT_DIR SANDBOX_DIR
  return 0
}