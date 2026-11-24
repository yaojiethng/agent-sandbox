#!/usr/bin/env bash
# libs/env.sh  --  the one parser for simple KEY=VALUE env files (the
# per-sandbox .env). Single home for reading .env.
#
# env_parse prints; nothing here exports. A record value reaches its reader
# through `record_get`'s REPLY, and no key of the record becomes a child
# process's environment. That boundary is what keeps a per-sandbox record from
# standing in for the ambient environment of the toolchain.
#
#   record_get FILE KEY     set REPLY to KEY's value from FILE, parsing once
#   env_parse FILE           print the entries as canonical KEY=VALUE lines
#
# A process reads a record through record_get. The first read of a file parses
# it into a private cache; later reads of the same file reuse it. env_parse is
# the parser, and the cache is an implementation detail: it is never exported,
# and no caller reads it directly. The cache holds one file, so reading a
# different file replaces it rather than merging two records.
#
# The parse is lazy: a record no reader asks for is not parsed, and a malformed
# line warns on the first read of its file, not again.
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

# The record cache is process-local. `record_get` reads it by indirect
# expansion, and bash resolves a subscript arithmetically unless the array is
# already associative: an indexed array answers element 0 for every key, and
# an undeclared one dies under `set -u` naming the key. Declaring it here means
# the primitive is always reading the shape it documents. The leading
# underscore marks the cache as a library implementation detail; it is not
# exported, and only `record_get` writes it.
# shellcheck disable=SC2034  # the cache is read by name through record_get
declare -gA _ENV_RECORD_CACHE=()
_ENV_RECORD_FILE=""
_ENV_RECORD_LOADED=0

# _record_open FILE
#   Fills the private cache from FILE. An empty or missing FILE leaves the cache
#   empty, so an optional record costs no branch at every reader. A second
#   occurrence of a key overwrites the first, because env_parse emits every entry
#   and the reader takes the last one.
_record_open() {
  local FILE="${1:-}"
  local _env_line _env_key _env_val
  _ENV_RECORD_CACHE=()
  [[ -n "$FILE" && -f "$FILE" ]] || return 0
  while IFS= read -r _env_line; do
    _env_key="${_env_line%%=*}"
    _env_val="${_env_line#*=}"
    _ENV_RECORD_CACHE["$_env_key"]="$_env_val"
  done < <(env_parse "$FILE")
}

# record_get FILE KEY
#   Sets REPLY to the value of KEY from FILE and returns 0. The first read of a
#   file parses it into the private cache; later reads of the same file reuse the
#   cache. A different file replaces it. A missing file or key sets REPLY empty.
#   The caller decides whether an absent key is an error.
#
#   The value returns through REPLY rather than stdout because a command
#   substitution runs in a subshell, and a cache written there would not survive
#   to the caller's next read.
record_get() {
  local FILE="${1:-}"
  local KEY="${2:?record_get requires a key}"
  if [[ "$_ENV_RECORD_LOADED" -eq 0 || "$_ENV_RECORD_FILE" != "$FILE" ]]; then
    _record_open "$FILE"
    _ENV_RECORD_FILE="$FILE"
    _ENV_RECORD_LOADED=1
  fi
  local _ref="_ENV_RECORD_CACHE[${KEY}]"
  REPLY="${!_ref:-}"
  return 0
}
