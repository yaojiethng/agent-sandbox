#!/usr/bin/env bash
# libs/env.sh  --  shared loader for simple KEY=VALUE env files (the per-sandbox
# .env). Single home for reading .env so the Makefile -include (make vars) and
# the runtime export are the only two consumers, each behind one loader.

# env_load FILE
#   Sources KEY=VALUE lines from FILE into the environment. The caller checks
#   FILE exists before calling. Overwrites any variable of the same name with
#   the FILE value.
#
#   Parsing rules (hardened):
#     - Skips blank lines and comment lines (# ...).
#     - Strips an optional leading `export` keyword.
#     - Trims CR/LF/TAB/space from the key and surrounding whitespace from the
#       value.
#     - Skips a line with no `=` and a line whose key is not a valid shell
#       identifier, with a warning.
#     - Keeps any text after the value as-is (there is no inline-comment rule).
env_load() {
  local FILE="${1:?env_load requires a file path}"

  [[ -f "$FILE" ]] || return 0

  local LINE KEY VALUE
  while IFS= read -r LINE || [[ -n "$LINE" ]]; do
    LINE="${LINE%$'\r'}"
    [[ "$LINE" =~ ^[[:space:]]*$ ]] && continue
    [[ "$LINE" =~ ^[[:space:]]*# ]] && continue
    if [[ "$LINE" =~ ^[[:space:]]*export[[:space:]]+(.*)$ ]]; then
      LINE="${BASH_REMATCH[1]}"
    fi
    if [[ "$LINE" != *=* ]]; then
      echo "Warning: skipping .env line without '=' in $FILE" >&2
      continue
    fi
    KEY="${LINE%%=*}"
    VALUE="${LINE#*=}"
    KEY="${KEY//[$'\r\n\t ']/}"
    [[ -z "$KEY" ]] && continue
    VALUE="${VALUE//[$'\r\n']/}"
    VALUE="${VALUE#"${VALUE%%[! ]*}"}"
    VALUE="${VALUE%"${VALUE##*[! ]}"}"
    if [[ ! "$KEY" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      echo "Warning: skipping .env line with invalid variable name '$KEY' in $FILE" >&2
      continue
    fi
    export "$KEY=$VALUE"
  done < "$FILE"
}