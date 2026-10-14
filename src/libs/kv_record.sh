#!/usr/bin/env bash
# libs/kv_record.sh  --  the one reader/writer pair for every key=value record
# the harness persists: SESSION_STATE, .export-status, the dry-run diagnostics
# records, and the .draft-state string once its reader lands on it.
#
# Record format (one record, one shape):
#   - one KEY=VALUE pair per line, KEY a shell identifier
#   - the value is everything after the FIRST '=', so a value may contain '='
#   - the first line carrying a key wins on read; a later line never shadows it
#   - a missing file, a missing key, or an empty value reads as empty with rc 0
#
# Provides:
#   kv_read  FILE KEY        --  print the value for KEY (first match, full tail)
#   kv_write FILE KEY VALUE  --  append the pair; creates the file, rc 1 when
#                                the parent directory does not exist
#   kv_load  FILE [KEY...]   --  print key=value lines, one per line, in record
#                                order for the whole record or in argument
#                                order for the named keys, in one pass over
#                                the file
#
# Every parser for these records lives here. A consumer that parses a record by
# any other path is a defect the tree-scan in tests/test_kv_record.sh fails.

# kv_read FILE KEY
#   Prints the value stored under KEY, or nothing. The value is everything
#   after the first '=' on the first line whose key matches, so a value with
#   '=' inside reads whole. A missing file or key is not an error.
kv_read() {
  local file="$1" key="$2"
  [[ -f "$file" ]] || return 0
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    # The whole pattern is quoted, so a metacharacter in the key cannot widen
    # it, and the '=' inside the pattern pins the key boundary: a key that is
    # a prefix of another key cannot collide.
    [[ "$line" == "$key="* ]] || continue
    printf '%s\n' "${line#*=}"
    return 0
  done < "$file"
  return 0
}

# kv_write FILE KEY VALUE
#   Appends KEY=VALUE to FILE, creating FILE when it is absent. The parent
#   directory must exist: a record whose directory is missing is a caller
#   error, and silently creating it would hide an uninitialised sandbox.
kv_write() {
  local file="$1" key="$2" value="$3"
  local dir
  dir="$(dirname "$file")"
  [[ -d "$dir" ]] || return 1
  printf '%s=%s\n' "$key" "$value" >> "$file"
}

# kv_load FILE [KEY...]
#   Prints the record's key=value lines. With no KEY, every pair of the record
#   prints in file order. With one or more KEYs, one line prints per KEY in
#   argument order, the empty value standing for a missing key. Both forms run
#   the same line rules as kv_read -- a trailing CR is stripped and a line with
#   no '=' is not a pair -- and both make ONE pass over the file, so a multi-key
#   read costs one traversal, not one per key.
#   A missing file reads as an empty record: no line for the whole-record
#   form, an empty value per key for the keyed form.
kv_load() {
  local file="$1"
  shift
  local line i
  if [[ $# -eq 0 ]]; then
    [[ -f "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ "$line" == *=* ]] || continue
      printf '%s\n' "$line"
    done < "$file"
    return 0
  fi
  local wants=("$@") vals=() seen=()
  local i remaining=$#
  for i in "${!wants[@]}"; do vals[$i]=""; seen[$i]=""; done
  if [[ -f "$file" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      line="${line%$'\r'}"
      [[ "$line" == *=* ]] || continue
      for i in "${!wants[@]}"; do
        [[ -z "${seen[$i]}" ]] || continue
        [[ "$line" == "${wants[$i]}="* ]] || continue
        seen[$i]=1
        vals[$i]="${line#*=}"
        remaining=$(( remaining - 1 ))
      done
      # Every named key resolved: stop rather than walk the rest of the file.
      [[ $remaining -eq 0 ]] && break
    done < "$file"
  fi
  for i in "${!wants[@]}"; do
    printf '%s=%s\n' "${wants[$i]}" "${vals[$i]}"
  done
  return 0
}
