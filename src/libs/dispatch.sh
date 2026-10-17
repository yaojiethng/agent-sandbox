#!/usr/bin/env bash
# libs/dispatch.sh
#
# The runner seam: one command builder with two backends, so a brief names a
# role and not a runtime.
#
# A role is a line in $AGENT_HOME/model-recommendations.md:
#
#   _IMPLEMENTER: opencode-go/cat-jam-free at high
#
# The seam resolves the role to a `provider/model` pair and a thinking level,
# then chooses the backend that can reach that pair:
#
#   pi        a provider pi's registry serves, invoked `pi -p`
#   opencode  a provider only the OpenCode CLI reaches, invoked `opencode run`
#
# The measured boundary: pi answers `403 FreeTierError` for the OpenCode free
# tier, because that tier is served only from inside the OpenCode app. The
# sanctioned route is the real CLI, so this seam never spoofs a client.
#
# The builder prints a shell command string. A launch site substitutes it for
# its own inline `pi --provider ... -p` line, so the runtime is chosen in one
# place. Providers the OpenCode CLI alone serves are declared in
# DISPATCH_OPENCODE_PROVIDERS; a new one is a data edit.
#
# No set -euo pipefail here  --  this file is always sourced, never executed
# directly. Safety settings are inherited from the parent script.

# The role table, beside the agent config home.
dispatch_rec_file() {
  printf '%s/model-recommendations.md' "${AGENT_HOME:-$HOME/.pi}"
}

# The OpenCode CLI. The pi image installs `opencode-ai` globally, so it
# resolves on PATH; the agent-home path is the fallback for a session whose
# image predates that install. The override exists so a test never depends on
# an install.
dispatch_opencode_bin() {
  if [[ -n "${DISPATCH_OPENCODE_BIN:-}" ]]; then
    printf '%s' "$DISPATCH_OPENCODE_BIN"
    return 0
  fi
  if command -v opencode >/dev/null 2>&1; then
    command -v opencode
    return 0
  fi
  printf '%s' "${AGENT_HOME:-$HOME/.pi}/opencode/node_modules/.bin/opencode"
}

# Providers only the OpenCode CLI serves. pi's own provider registry is the
# complement, so a provider absent here is a pi backend.
DISPATCH_OPENCODE_PROVIDERS="${DISPATCH_OPENCODE_PROVIDERS:-opencode}"

# dispatch_role_model ROLE [REC_FILE]
#
# Resolves a role to "<provider>/<model> <thinking>". The thinking level is
# absent from the output when the line omits it.
#
# Returns 1 with a message on stderr when the role has no line, so a caller
# cannot silently dispatch the wrong model.
dispatch_role_model() {
  local role="$1"
  local file="${2:-$(dispatch_rec_file)}"
  if [[ ! -f "$file" ]]; then
    echo "dispatch: role table not found: $file" >&2
    return 1
  fi
  local line
  line="$(grep -E "^${role}:" "$file" | head -n 1)"
  if [[ -z "$line" ]]; then
    echo "dispatch: no recommendation for role '${role}' in ${file}" >&2
    return 1
  fi
  local value
  value="$(printf '%s' "${line#*:}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  value="${value%%;*}"
  value="$(printf '%s' "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [[ -z "$value" ]]; then
    echo "dispatch: role '${role}' names no model" >&2
    return 1
  fi
  local model thinking
  if [[ "$value" == *" at "* ]]; then
    model="${value%% at *}"
    thinking="${value##* at }"
    printf '%s %s' "$model" "$thinking"
  else
    printf '%s' "$value"
  fi
}

# dispatch_backend PROVIDER
#
# The backend that reaches a provider: `opencode` or `pi`.
dispatch_backend() {
  local provider="$1"
  local known
  for known in $DISPATCH_OPENCODE_PROVIDERS; do
    if [[ "$provider" == "$known" ]]; then
      printf 'opencode'
      return 0
    fi
  done
  printf 'pi'
}

# dispatch_roles [REC_FILE]
#
# Prints one line per role in the table, in file order:
#
#   <role> <provider>/<model> <backend>
#
# A blank line and any line that is not a `role:` entry are skipped, so a
# heading or prose never becomes a role. An empty table is not an error.
dispatch_roles() {
  local file="${1:-$(dispatch_rec_file)}"
  if [[ ! -f "$file" ]]; then
    echo "dispatch: role table not found: $file" >&2
    return 1
  fi
  local line role resolved pair provider backend
  while IFS= read -r line; do
    # The tag before the first colon is the role; anything else is not an entry.
    [[ "$line" =~ ^[A-Za-z0-9_]+: ]] || continue
    role="${line%%:*}"
    resolved="$(dispatch_role_model "$role" "$file")" || continue
    pair="${resolved%% *}"
    provider="${pair%%/*}"
    backend="$(dispatch_backend "$provider")"
    printf '%s %s %s\n' "$role" "$pair" "$backend"
  done < "$file"
  return 0
}

# dispatch_check ROLE [REC_FILE]
#
# Reports whether ROLE's backend can run in this session. Silent and 0 when it
# can; one message on stderr and 1 when it cannot.
dispatch_check() {
  local role="$1"
  local file="${2:-$(dispatch_rec_file)}"
  local resolved
  resolved="$(dispatch_role_model "$role" "$file")" || return 1
  local pair provider backend bin
  pair="${resolved%% *}"
  provider="${pair%%/*}"
  backend="$(dispatch_backend "$provider")"
  if [[ "$backend" == "opencode" ]]; then
    bin="$(dispatch_opencode_bin)"
    if command -v "$bin" >/dev/null 2>&1; then
      return 0
    fi
    echo "dispatch: role '${role}' needs the opencode CLI, not runnable: ${bin}" >&2
    return 1
  fi
  if command -v pi >/dev/null 2>&1; then
    return 0
  fi
  echo "dispatch: role '${role}' needs the pi CLI, not on PATH" >&2
  return 1
}

# dispatch_command ROLE BRIEF DIR [MODEL] [THINKING] [SESSION]
#
# Prints the shell command that runs one subagent for a role. MODEL overrides
# the role's pair; THINKING overrides its level; SESSION resumes a prior run.
#
# The brief is read at run time with `$(cat <brief>)`, so the printed command
# carries a path and never the brief text.
dispatch_command() {
  local role="$1" brief="$2" dir="$3"
  local model="${4:-}" thinking="${5:-}" session="${6:-}"
  if [[ -z "$role" || -z "$brief" || -z "$dir" ]]; then
    echo "dispatch: ROLE, BRIEF and DIR are required" >&2
    return 1
  fi
  local resolved
  resolved="$(dispatch_role_model "$role")" || return 1
  local pair level
  if [[ -n "$model" ]]; then
    pair="$model"
  else
    pair="${resolved%% *}"
  fi
  if [[ -n "$thinking" ]]; then
    level="$thinking"
  elif [[ "$resolved" == *" "* ]]; then
    level="${resolved#* }"
  else
    level=""
  fi
  local provider="${pair%%/*}"
  local name="${pair#*/}"
  if [[ "$provider" == "$pair" || -z "$name" ]]; then
    echo "dispatch: the role's model '${pair}' is not provider/model" >&2
    return 1
  fi
  local backend
  backend="$(dispatch_backend "$provider")"
  local brief_ref
  brief_ref="$(printf '%q' "$brief")"

  if [[ "$backend" == "opencode" ]]; then
    local bin
    bin="$(dispatch_opencode_bin)"
    local argv
    # The CLI's error channel is stderr at ERROR level. Without these flags a
    # refused request prints only its banner, and the process stays alive on an
    # event subscription it never closes, so a caller cannot tell a refusal from
    # a slow run.
    argv="${bin} run --auto --print-logs --log-level ERROR --title $(printf '%q' "$(basename "$brief")") --dir $(printf '%q' "$dir") -m $(printf '%q' "$pair")"
    if [[ -n "$level" ]]; then
      argv="${argv} --variant $(printf '%q' "$level")"
    fi
    if [[ -n "$session" ]]; then
      argv="${argv} --session $(printf '%q' "$session")"
    fi
    printf '%s "$(cat %s)"' "$argv" "$brief_ref"
    return 0
  fi

  local argv
  argv="pi --provider $(printf '%q' "$provider") --model $(printf '%q' "$name")"
  if [[ -n "$level" ]]; then
    argv="${argv} --thinking $(printf '%q' "$level")"
  fi
  if [[ -n "$session" ]]; then
    argv="${argv} --session $(printf '%q' "$session")"
  fi
  printf '%s -p "$(cat %s)"' "$argv" "$brief_ref"
}
