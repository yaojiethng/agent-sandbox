#!/usr/bin/env bash
# layout.sh -- read an eval's layout declaration.
#
# The layout is declared once, in assets/layout.json beside this script's parent.
# A consumer reads a value rather than carrying it, so two statements of where a
# case, a fixture or a run's artefacts live cannot disagree. The declaration is
# the store; this file is its only reader.

EVAL_LAYOUT_DEFAULT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/assets/layout.json"

layout_get() { # <key> [<file>] -> the declared value
  local key="$1" file="${2:-$EVAL_LAYOUT_DEFAULT}"
  [[ -f "$file" ]] || { printf 'eval layout not found: %s\n' "$file" >&2; return 2; }
  jq -er --arg k "$key" '.[$k] | strings' "$file" 2>/dev/null \
    || { printf 'eval layout carries no string for %s: %s\n' "$key" "$file" >&2; return 2; }
}

# A declaration names an artifact home the way the documents do, with a literal
# $HOME, because JSON does no expansion. Only a leading $HOME or ${HOME} expands.
expand_home() { # <path>
  case "$1" in
  '$HOME/'*) printf '%s/%s\n' "$HOME" "${1#'$HOME/'}" ;;
  '${HOME}/'*) printf '%s/%s\n' "$HOME" "${1#'${HOME}/'}" ;;
  *) printf '%s\n' "$1" ;;
  esac
}
