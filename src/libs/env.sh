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
#     - Strips one layer of matching surrounding quotes (double or single)
#       from the value, so K="a b" and K=a b load identically. The pair must
#       enclose the whole value with no occurrence of the same quote inside;
#       a value that merely begins and ends with a quote (K="a" and "b")
#       stays literal. Padding inside the quotes is preserved.
#     - Skips a line with no `=` and a line whose key is not a valid shell
#       identifier, with a warning.
#     - Skips a key that would shadow the loader's own scratch names (the
#       `_env_` prefix), with a warning, so a file cannot silently drop a
#       variable by naming it after the parser.
#     - Keeps any text after the value as-is (there is no inline-comment rule).
env_load() {
  local FILE="${1:?env_load requires a file path}"

  [[ -f "$FILE" ]] || return 0

  # Scratch names are prefixed because `export "$KEY=$VALUE"` targets this
  # function's scope: a local named like a .env key would swallow the key.
  local _env_line _env_key _env_val _env_q
  while IFS= read -r _env_line || [[ -n "$_env_line" ]]; do
    _env_line="${_env_line%$'\r'}"
    [[ "$_env_line" =~ ^[[:space:]]*$ ]] && continue
    [[ "$_env_line" =~ ^[[:space:]]*# ]] && continue
    if [[ "$_env_line" =~ ^[[:space:]]*export[[:space:]]+(.*)$ ]]; then
      _env_line="${BASH_REMATCH[1]}"
    fi
    if [[ "$_env_line" != *=* ]]; then
      echo "Warning: skipping .env line without '=' in $FILE" >&2
      continue
    fi
    _env_key="${_env_line%%=*}"
    _env_val="${_env_line#*=}"
    _env_key="${_env_key//[$'\r\n\t ']/}"
    [[ -z "$_env_key" ]] && continue
    _env_val="${_env_val//[$'\r\n']/}"
    _env_val="${_env_val#"${_env_val%%[! ]*}"}"
    _env_val="${_env_val%"${_env_val##*[! ]}"}"
    # A matching pair of surrounding quotes is a quoting convention, not data:
    # strip one layer so a quoted value loads as its contents. The pair must
    # enclose the whole value with no occurrence of the same quote inside, so
    # K="a" and "b" stays literal rather than losing its end quotes. Padding
    # inside the quotes survives, which is what quoting is for.
    _env_q="${_env_val:0:1}"
    if [[ ${#_env_val} -ge 2 && "$_env_q" == "${_env_val: -1}" ]] \
      && [[ "$_env_q" == '"' || "$_env_q" == "'" ]] \
      && [[ "${_env_val:1:${#_env_val}-2}" != *"$_env_q"* ]]; then
      _env_val="${_env_val:1:${#_env_val}-2}"
    fi
    if [[ ! "$_env_key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
      echo "Warning: skipping .env line with invalid variable name '$_env_key' in $FILE" >&2
      continue
    fi
    if [[ "$_env_key" == _env_* ]]; then
      echo "Warning: skipping .env key that shadows the loader's scratch names: '$_env_key' in $FILE" >&2
      continue
    fi
    export "$_env_key=$_env_val"
  done < "$FILE"
}