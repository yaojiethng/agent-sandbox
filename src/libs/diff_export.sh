#!/usr/bin/env bash
# src/libs/diff_export.sh
# diff_export orchestrator — packages session artefacts into an output directory.
# Cross-context — deployed to capability container (sandbox-entrypoint).
# Uses self-resolution for sibling sourcing (_self_dir).
#
# Provides:
#   diff_export  — package session artefacts via package-branch + export time

# diff_export SANDBOX_DIR OUTPUT_DIR
#   Packages session artefacts into OUTPUT_DIR via package_branch,
#   then writes EXPORT-TIME.txt for audit trail.
diff_export() {
  local SANDBOX_DIR="$1"
  local OUTPUT_DIR="$2"

  if [[ -z "$SANDBOX_DIR" || -z "$OUTPUT_DIR" ]]; then
    echo "diff_export: SANDBOX_DIR and OUTPUT_DIR are required" >&2
    return 1
  fi

  echo "diff_export: packaging artefacts..." >&2

  # Source sibling package-branch
  _self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  source "$_self_dir/package_branch.sh"

  if ! package_branch "$SANDBOX_DIR" "$OUTPUT_DIR"; then
    echo "diff_export: package_branch failed — export incomplete" >&2
    return 1
  fi

  # Record export time for audit trail (written after package_branch
  # since it removes and recreates OUTPUT_DIR internally)
  local EXPORT_TIME
  EXPORT_TIME=$(date -u +%Y%m%d-%H%M%S)
  echo "$EXPORT_TIME" > "$OUTPUT_DIR/EXPORT-TIME.txt"
}
