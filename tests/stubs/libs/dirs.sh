#!/usr/bin/env bash
# test/stubs/libs/dirs.sh
# Faithful minimal copy of src/libs/dirs.sh dirs_resolve(): derive the four
# workspace dirs from a base. Used only by the probes' fallback path when a
# dir env var is unset.
dirs_resolve() {
  local base="$1"
  [[ -n "$base" ]] || return 1
  local ws="${WORKSPACE_DIR_NAME:-.workspace}"
  export SNAPSHOT_DIR="${base}/${SNAPSHOT_DIR_NAME:-.snapshot}"
  export CHANGES_DIR="${base}/${ws}/${CHANGES_DIR_NAME:-session-diffs}"
  export INPUT_DIR="${base}/${ws}/${INPUT_DIR_NAME:-input}"
  export OUTPUT_DIR="${base}/${ws}/${OUTPUT_DIR_NAME:-output}"
}