#!/usr/bin/env bash
# tests/stubs/libs/session_state.sh
# Minimal controllable fake for src/libs/session_state.sh.
# Reads keys from <SANDBOX_DIR>/.git/SESSION_STATE exactly like the real lib, so
# tests drive outcomes purely by what they write into the SESSION_STATE file.

session_state_read() {
  local dir="$1" key="$2"
  local file="$dir/.git/SESSION_STATE"
  [[ -f "$file" ]] || return 0
  local k v
  while IFS='=' read -r k v; do
    if [[ "$k" == "$key" ]]; then
      echo "$v"
      return 0
    fi
  done < "$file"
  return 0
}

session_state_write() {
  local dir="$1" key="$2" value="$3"
  local file="$dir/.git/SESSION_STATE"
  local d
  d="$(dirname "$file")"
  [[ -d "$d" ]] || return 1
  echo "${key}=${value}" >> "$file"
}

# Mirrors src/libs/session_state.sh (used by the capability probe gate and the
# knowledge diagnostics).
init_sha_is_valid() {
  local dir="$1"
  local sha
  sha=$(session_state_read "$dir" "init_sha" 2>/dev/null) || return 1
  [[ -z "$sha" ]] && return 1
  git -C "$dir" cat-file -e "$sha^{commit}" >/dev/null 2>&1
}