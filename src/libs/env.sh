#!/usr/bin/env bash
# libs/env.sh  --  the one parser for simple KEY=VALUE env files (the
# per-sandbox .env). Single home for reading .env.
#
# It prints; it never exports. A record value reaches its reader as a return
# value, and no key of the record becomes a child process's environment. That
# boundary is what keeps a per-sandbox record from standing in for the ambient
# environment of the toolchain.
#
#   record_open FILE ARRAY   parse FILE once, filling the caller's array
#   record_get ARRAY KEY     print the value of KEY from an opened record
#   env_parse FILE           print the entries as canonical KEY=VALUE lines
#
# A process opens a record once, at its entry, and reads every value it needs
# from that view. env_parse is the parser; record_open is its only caller, so
# one parse per file per process is a property of the library rather than a
# discipline each reader has to remember.
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

# record_open FILE ARRAY
#   Parses FILE once and fills ARRAY (an associative array the caller declared)
#   with one entry per key. An empty or missing FILE leaves the array empty, so
#   an optional record costs no branch at every reader. A second occurrence of a
#   key overwrites the first in the view; env_parse emits every entry and the
#   caller decides, which keeps the parser single-purpose.
record_open() {
  local FILE="${1:-}"
  local NAME="${2:?record_open requires an array name}"
  local _env_line _env_key _env_val
  [[ -n "$FILE" && -f "$FILE" ]] || return 0
  while IFS= read -r _env_line; do
    _env_key="${_env_line%%=*}"
    _env_val="${_env_line#*=}"
    printf -v "${NAME}[${_env_key}]" '%s' "$_env_val"
  done < <(env_parse "$FILE")
}

# record_get ARRAY KEY
#   Prints the value of KEY from an opened record, or nothing. The caller decides
#   whether an absent key is an error.
record_get() {
  local NAME="${1:?record_get requires an array name}"
  local KEY="${2:?record_get requires a key}"
  local _ref="${NAME}[${KEY}]"
  printf '%s' "${!_ref:-}"
}

# env_record_view FILE
#   Opens FILE into the process view, or reuses the view already open for it, so
#   a process that resolves identity and then initialises parses one file once.
#   Every reader in the process asks ENV_RECORD through record_get; a reader that
#   needs the value only once may call record_open on a view of its own.
#
#   Opening a different file replaces the view: the view holds one record, and a
#   process that reads two records reads each once.
env_record_view() {
  local FILE="${1:-}"
  if [[ -n "${_ENV_VIEW_FILE:-}" && "$_ENV_VIEW_FILE" == "$FILE" ]]; then
    return 0
  fi
  # shellcheck disable=SC2034  # the view is read by name through record_get
  declare -gA ENV_RECORD=()
  record_open "$FILE" ENV_RECORD
  _ENV_VIEW_FILE="$FILE"
  return 0
}
