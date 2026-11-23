#!/usr/bin/env bash
# libs/common.sh
# Shared flag parsing and validation for agent-sandbox scripts.
# Sourced by scripts that need --name and --sandbox (stop.sh, prune.sh, etc.).
#
# Pure flag-parsing library: it parses flags and does NOT set caller-owned
# path variables (REPO_ROOT, etc.). Callers derive their own
# paths self-referentially from BASH_SOURCE[0] and define their own usage().
#
# Sets in caller's scope:
#   PROJECT_NAME  --  parsed from --name flag
#   PROJECT_DIR   --  parsed from --project flag
#   SANDBOX_DIR   --  parsed from --sandbox flag
#
# Provides:
#   check_base_flags()    --  validate PROJECT_NAME and SANDBOX_DIR are set
#   parse_help_flag()     --  check for --help/-h, print usage and return 0
#                           when help was requested; the caller turns the
#                           status into its exit
#   json_string()         --  print a value as a JSON string literal
#
# Scripts should define their own usage() before sourcing this file.

# Max entries per page for numbered pickers (draft bundle select, resume
# session select) and for the resume --list cap. Single canonical value; both
# scripts/workflows/interactive.sh and scripts/resume_agent.sh read it from
# here. Overridable via environment; not consumed inside this library.
# shellcheck disable=SC2034
: "${INTERACTIVE_MAX_ENTRIES:=10}"

# canonical_sandbox_dir SANDBOX_DIR
#   Resolves SANDBOX_DIR to its canonical absolute form so any path spelling
#   (absolute, ~-form, relative, symlink, trailing-slash, ./) of the same folder
#   converges. The canonical value is what is baked into the
#   `agent-sandbox.sandbox-dir` label at create time and what all discovery
#   filters (stop, prune, diagnostic) match, so label<spelling> and
#   filter<spelling> always agree. Fails loudly when the path cannot be parsed
#   or resolved. Single canonical home -- sourced by all four host entrypoints
#   (start_agent, resume_agent, stop, prune) via common.sh.
sandbox_dir_canon() {
  local dir="$1"
  [[ -n "$dir" ]] || { echo "sandbox_dir_canon: SANDBOX_DIR is empty" >&2; return 1; }
  local expanded
  expanded="${dir/#\~/$HOME}"   # expand a leading ~ before realpath
  local canon
  if ! canon="$(readlink -f "$expanded" 2>/dev/null)"; then
    echo "Error: cannot canonicalize SANDBOX_DIR: $dir" >&2
    return 1
  fi
  echo "$canon"
}

parse_help_flag() {
  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) usage; return 0 ;;
    esac
  done
  return 1
}

check_base_flags() {
  if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --name and --sandbox are required" >&2
    usage >&2
    return 1
  fi
  # SANDBOX_DIR is already guaranteed non-empty above; only reject root.
  if [[ "$SANDBOX_DIR" == "/" ]]; then
    echo "Error: invalid SANDBOX_DIR: $SANDBOX_DIR" >&2
    return 1
  fi
}

# json_string VALUE  --  print VALUE as a JSON string: the two escapes JSON
# requires, plus the whitespace ones a JSON parser would reject if raw. The
# three probe scripts and the dispatcher's `help --json` render JSON this way;
# one definition keeps the escaping identical, including the carriage return
# `stop_signal_matrix.sh` used to miss.
json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# sed_replacement VALUE  --  VALUE with the characters that change meaning in a
# sed replacement escaped, so a host path reaches the template intact. A sed
# replacement treats `&` as the matched text and `\` as itself, and the `|`
# delimiter here ends the expression.
#
# A value lands in YAML as well: the template quotes the placeholders whose
# lookup is exact (a label, a bind source), and `yaml_quote` makes the value
# safe for that quoting.
sed_replacement() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//&/\\&}"
  s="${s//|/\\|}"
  printf '%s' "$s"
}

# yaml_quote VALUE  --  VALUE escaped for a single-quoted YAML scalar: a
# single quote is written twice, and nothing else needs escaping. A value
# without a quote passes through unchanged.
yaml_quote() {
  printf '%s' "${1//\'/\'\'}"
}

# yaml_unquote VALUE  --  VALUE with one surrounding pair of single quotes
# removed, and a doubled quote restored to one. A generated compose value is
# quoted so it can carry a space or a `#`; a hand-written fixture need not be,
# so a reader accepts both forms.
yaml_unquote() {
  local s="$1"
  s="${s#\'}"
  s="${s%\'}"
  printf '%s' "${s//\'\'/\'}"
}
