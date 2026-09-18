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
# The .env is located in the provided sandbox dir (explicit or AGENT_SANDBOX_
# value) when one is known, else in the directory the command is invoked from.
# The TWO-level guard reads only the AGENT_SANDBOX_* keys as the env level so a
# plain exported PROJECT_DIR/SANDBOX_DIR/PROJECT_NAME (leaked by a sourced
# script) does not bypass .env precedence.

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

# _resolve_one EXPLICIT ENVVAR KEY ENV_FILE
#   Resolves one identifier by precedence: explicit, then the named env var,
#   then the KEY value from ENV_FILE, else a hard error. Prints the value.
_resolve_one() {
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

# default_env_file SANDBOX_DIR
#   Prints the .env path: an absolute ENV_REL (--env) is used as-is, a relative
#   ENV_REL is a name under SANDBOX_DIR, and an empty ENV_REL falls back to
#   <sandbox>/.env, else the invocation CWD's .env. This is the single --env
#   contract, shared with the run's env load.
default_env_file() {
  local sandbox_dir="$1"
  if [[ -n "${ENV_REL:-}" && "$ENV_REL" == /* ]]; then
    printf '%s' "$ENV_REL"
  elif [[ -n "$sandbox_dir" ]]; then
    printf '%s' "$sandbox_dir/${ENV_REL:-.env}"
  else
    printf '%s' "${PWD}/${ENV_REL:-.env}"
  fi
}

# env_resolve_value EXPLICIT ENVVAR KEY ENV_PATH
#   Resolves one identifier's value: explicit > ENVVAR > .env > error. ENV_PATH,
#   when given, is the .env file to read; else the invocation CWD's .env is
#   used. Prints the value; returns non-zero with an onboard hint on failure.
env_resolve_value() {
  local explicit="$1" envvar="$2" key="$3" env_path="${4:-}"
  if [[ -z "$env_path" ]]; then
    env_path="$(default_env_file "")"
  fi
  _resolve_one "$explicit" "$envvar" "$key" "$env_path"
}

# env_resolve_identity EXPLICIT_NAME EXPLICIT_DIR EXPLICIT_SANDBOX [ENV_FILE]
#   Resolves the identity triple. An empty explicit value means "not given".
#   When ENV_FILE is omitted it is derived from the sandbox dir known so far
#   (explicit or AGENT_SANDBOX_SANDBOX_DIR), else from the CWD. Exports the
#   resolved PROJECT_NAME, PROJECT_DIR, SANDBOX_DIR into the caller's scope.
env_resolve_identity() {
  local expl_name="${1:-}" expl_dir="${2:-}" expl_sandbox="${3:-}" env_file="${4:-}"
  local known_sbx pn pd sd

  if [[ -z "$env_file" ]]; then
    known_sbx=""
    [[ -n "$expl_sandbox" ]] && known_sbx="$expl_sandbox"
    [[ -z "$known_sbx" && -n "${AGENT_SANDBOX_SANDBOX_DIR:-}" ]] && known_sbx="$AGENT_SANDBOX_SANDBOX_DIR"
    env_file="$(default_env_file "$known_sbx")"
  fi

  pn="$(_resolve_one "$expl_name"    AGENT_SANDBOX_PROJECT_NAME  PROJECT_NAME  "$env_file")" || return 1
  pd="$(_resolve_one "$expl_dir"     AGENT_SANDBOX_PROJECT_DIR   PROJECT_DIR   "$env_file")" || return 1
  sd="$(_resolve_one "$expl_sandbox" AGENT_SANDBOX_SANDBOX_DIR   SANDBOX_DIR   "$env_file")" || return 1

  export PROJECT_NAME="$pn" PROJECT_DIR="$pd" SANDBOX_DIR="$sd"
}