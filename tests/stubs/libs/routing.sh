#!/usr/bin/env bash
# test/stubs/libs/routing.sh
# Minimal fake for src/libs/routing.sh -- only the subset consumed by the
# dry-run probes is provided (export_path). Mirrors the real contract: requires
# PARENT_DIR, SUBDIR and SESSION_ID; prints a non-empty path on success.
export_path() {
  local parent="$1" sub="$2" sid="$3"
  if [[ -z "$parent" || -z "$sub" || -z "$sid" ]]; then
    return 1
  fi
  if [[ "$sub" == "autosave" ]]; then
    echo "${parent}/autosave/${sid}"
    return 0
  fi
  echo "${parent}/${sub}/stub-${sid}"
}