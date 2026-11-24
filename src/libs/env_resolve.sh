#!/usr/bin/env bash
# libs/env_resolve.sh  --  centralized precedence resolver for the sandbox
# identity triple (PROJECT_NAME, PROJECT_DIR, SANDBOX_DIR), mirroring pi's
# thin-interface / deep-resolution model.
#
# Precedence per identifier (highest wins):
#   1. explicit value (the CLI flag on the current invocation)
#   2. the per-sandbox .env file
#   3. no runtime default  --  a missing value at every level is a hard error
#      pointing at `agent-sandbox onboard`.
#
# A record key has no environment level. The record is read, never exported, so
# the invoking shell cannot stand in for it: AGENT_SANDBOX_<KEY> is not a level
# for any key the record holds.
#
# The .env is located by default_env_file: an absolute ENV_REF (--env) as-is, a
# relative ENV_REF a name under the sandbox dir, and an empty ENV_REF
# <sandbox>/.env, else the invocation CWD's .env. Every branch returns an
# absolute path, so a caller and the process it hands the path to name the same
# file.

_self_env_resolve_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$_self_env_resolve_dir/libs/env.sh"

# _record_field KEY ENV_FILE [REMEDY]
#   Sets REPLY to the value of KEY from ENV_FILE, or prints the one missing-value
#   error and returns a failure status. The primitive owns the cache, so a
#   sequence of fields costs one parse.
_record_field() {
  local key="$1" env_file="$2" remedy="${3:-}"
  record_get "$env_file" "$key"
  if [[ -n "$REPLY" ]]; then return 0; fi
  _env_missing "$key" "$env_file" "$remedy"
  return 1
}

# _env_missing KEY ENV_FILE [REMEDY]
#   Prints the one missing-value error. REMEDY defaults to the generic
#   set-this-key advice, because the primitive cannot know which command owns a
#   setting; the caller that owns the setting names its remedy.
_env_missing() {
  local key="$1" env_file="$2" remedy="${3:-}"
  echo "Error: $key is not set (no explicit flag, no $key in ${env_file:-.env})." >&2
  if [[ -n "$remedy" ]]; then
    echo "  $remedy" >&2
  else
    echo "  Set $key in ${env_file:-.env}." >&2
  fi
}

# _env_abs_path PATH
#   Prints PATH as an absolute path. Canonicalizes through readlink -f when the
#   path resolves; a path whose parent does not exist is anchored at the
#   invocation CWD instead. The file need not exist, because a specified path's
#   absence is reported by its reader, not by path construction.
_env_abs_path() {
  local path="$1" resolved
  if resolved="$(readlink -f -- "$path" 2>/dev/null)"; then
    printf '%s' "$resolved"
    return 0
  fi
  if [[ "$path" == /* ]]; then
    printf '%s' "$path"
  else
    printf '%s/%s' "$PWD" "$path"
  fi
}

# default_env_file RAW_ENV_REF SANDBOX_DIR
#   Prints the absolute .env path for the raw --env value under the single
#   .env-path contract: an absolute RAW_ENV_REF is used as-is; a relative
#   RAW_ENV_REF is a name under SANDBOX_DIR; an empty RAW_ENV_REF falls back to
#   <sandbox>/.env, else the invocation CWD's .env.
default_env_file() {
  local raw="${1:-}" sandbox_dir="$2" path
  if [[ -n "$raw" && "$raw" == /* ]]; then
    path="$raw"
  elif [[ -n "$sandbox_dir" ]]; then
    path="$sandbox_dir/${raw:-.env}"
  else
    path="${PWD}/${raw:-.env}"
  fi
  _env_abs_path "$path"
}

# env_resolve_one KEY ENV_FILE [REMEDY]
#   Resolves one identifier: the KEY value from ENV_FILE, else a hard error.
#   Prints the value. The explicit-flag level is the caller's, which owns the
#   input; this primitive owns the record. The identity triple is a sequence of
#   the same rule.
#
#   REMEDY is the line printed under the error, naming what the operator runs.
#   It defaults to the generic set-this-key advice, because the primitive cannot
#   know which command owns a setting; the caller that owns the setting names
#   its remedy. An argument rather than a per-key table keeps a new setting a
#   call-site edit, and keeps the text beside the command that writes the value.
env_resolve_one() {
  local key="$1" env_file="$2" remedy="${3:-}"
  _record_field "$key" "$env_file" "$remedy" || return 1
  printf '%s' "$REPLY"
}

# env_resolve_identity EXPLICIT_NAME EXPLICIT_DIR EXPLICIT_SANDBOX [ENV_REF [FIELDS...]]
#   Resolves the requested identity fields (default: name dir sandbox). An
#   empty explicit value means "not given". ENV_REF is the raw --env value
#   (absolute, sandbox-relative, or empty) normalized via default_env_file.
#   An explicit fourth argument is authoritative even when it is empty; only an
#   omitted fourth argument falls back to the caller's ENV_REL.
#   SANDBOX is anchored first (a relative ENV_REF needs a sandbox that may live
#   in the .env). Exports PROJECT_NAME/PROJECT_DIR/SANDBOX_DIR for the
#   requested fields and the normalized ENV_FILE into the caller's scope.
#
#   Every key here is written by `onboard`, so the onboard command is what this
#   sequence passes as each setting's remedy.
_ENV_ONBOARD_REMEDY="Run: agent-sandbox onboard --name=<name> --project=<path> --sandbox=<path>"

env_resolve_identity() {
  local expl_name="${1:-}" expl_dir="${2:-}" expl_sandbox="${3:-}" env_ref
  if [[ $# -ge 4 ]]; then
    env_ref="$4"
  else
    env_ref="${ENV_REL:-}"
  fi
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
    _record_field SANDBOX_DIR "$ep" "$_ENV_ONBOARD_REMEDY" || return 1
    SANDBOX_DIR="$REPLY"
  else
    SANDBOX_DIR="$expl_sandbox"
  fi
  ep="$(default_env_file "$env_ref" "$SANDBOX_DIR")"
  export ENV_FILE="$ep"

  # A specified .env path that does not exist fails here, naming the path,
  # instead of surfacing later as a generic missing-key error that names the
  # wrong level. An empty ENV_REF is the fallback, which the caller resolves:
  # <sandbox>/.env, else the invocation CWD's .env.
  if [[ -n "$env_ref" && ! -f "$ep" ]]; then
    echo "Error: .env not found: $ep" >&2
    echo "  A specified --env path must exist. Omit --env to use <sandbox>/.env, else the CWD's .env." >&2
    return 1
  fi

  # The primitive holds one file. A bootstrap above may have read a different
  # file, in which case the next read replaces the cache rather than merging.

  if $need_name && [[ -z "$expl_name" ]]; then
    _record_field PROJECT_NAME "$ep" "$_ENV_ONBOARD_REMEDY" || return 1
    PROJECT_NAME="$REPLY"
    export PROJECT_NAME
  elif $need_name; then
    export PROJECT_NAME="$expl_name"
  fi
  if $need_dir && [[ -z "$expl_dir" ]]; then
    _record_field PROJECT_DIR "$ep" "$_ENV_ONBOARD_REMEDY" || return 1
    PROJECT_DIR="$REPLY"
    export PROJECT_DIR
  elif $need_dir; then
    export PROJECT_DIR="$expl_dir"
  fi
  export PROJECT_NAME PROJECT_DIR SANDBOX_DIR
  return 0
}
