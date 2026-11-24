#!/usr/bin/env bash
# tests/libs/env_parse_counter.sh
# One counting wrapper for the parser. Call it from the shell under test after
# env_parse is defined; each call appends x to the counter file.

env_parse_counter_install() {
  _ENV_PARSE_COUNTER="$1"
  eval "$(declare -f env_parse | sed '1s/env_parse/env_parse_orig/')"
  env_parse() { printf x >> "$_ENV_PARSE_COUNTER"; env_parse_orig "$@"; }
}
