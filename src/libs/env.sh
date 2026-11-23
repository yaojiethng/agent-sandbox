#!/usr/bin/env bash
# libs/env.sh  --  the one parser for simple KEY=VALUE env files (the
# per-sandbox .env). Single home for reading .env.
#
# It prints; it never exports. A record value reaches its reader as a return
# value, and no key of the record becomes a child process's environment. That
# boundary is what keeps a per-sandbox record from standing in for the ambient
# environment of the toolchain.
#
#   env_parse FILE      print the file's entries as canonical KEY=VALUE lines
#   env_get FILE KEY    print the value of the first KEY entry; empty if absent
#
#   Parsing rules (hardened):
#     - Skips blank lines and comment lines (# ...).
#     - Strips an optional leading `export` keyword.
#     - Trims CR/LF/TAB/space from the key and surrounding whitespace from the
#       value.
#     - Strips one layer of matching surrounding quotes (double or single)
#       from the value, so K="a b" and K=a b parse identically. The pair must
#       enclose the whole value with no occurrence of the same quote inside;
#       a value that merely begins and ends with a quote (K="a" and "b")
#       stays literal. Padding inside the quotes is preserved.
#     - Skips a line with no `=` and a line whose key is not a valid shell
#       identifier, with a warning.
#     - Skips a key that would shadow the parser's own scratch names (the
#       `_env_` prefix), with a warning, so a key cannot silently take the
#       place of a scratch variable.
#     - Keeps any text after the value as-is (there is no inline-comment rule).
env_parse() {
  local FILE="${1:?env_parse requires a file path}"

  [[ -f "$FILE" ]] || return 0

  # Scratch names are prefixed so a record key cannot take their place.
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
    # strip one layer so a quoted value parses as its contents. The pair must
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
      echo "Warning: skipping .env key that shadows the parser's scratch names: '$_env_key' in $FILE" >&2
      continue
    fi
    printf '%s=%s\n' "$_env_key" "$_env_val"
  done < "$FILE"
}

# env_get FILE KEY
#   Prints the value of the first KEY entry, or nothing. The caller decides
#   whether an absent key is an error; a second occurrence of the same key is
#   ignored, so a record has one value per key.
env_get() {
  local FILE="${1:-}"
  local WANT="${2:?env_get requires a key}"
  local _env_line
  [[ -n "$FILE" && -f "$FILE" ]] || return 0
  while IFS= read -r _env_line; do
    if [[ "$_env_line" == "$WANT="* ]]; then
      printf '%s' "${_env_line#*=}"
      return 0
    fi
  done < <(env_parse "$FILE")
}
