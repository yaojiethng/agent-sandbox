#!/usr/bin/env bash
# libs/image.sh — Image digest computation for staleness detection.
#
# Provides image_compute_digest, which hashes all files in libs/ plus
# any files listed in a given image-files.txt.
#
# libs/ is always included — changes to shared harness functions invalidate
# both the reasoning layer image and the capability layer image.
#
# Usage:
#   source libs/image.sh
#   digest=$(image_compute_digest "$REPO_ROOT" "$IMAGE_FILES_TXT")
#
# Arguments:
#   $1  AGENT_SANDBOX_REPO — absolute path to the agent-sandbox repository root
#   $2  IMAGE_FILES_TXT    — absolute path to an image-files.txt
#
# File resolution in image-files.txt:
#   Paths are resolved relative to the directory containing image-files.txt.
#   Reasoning layer: $REPO_ROOT/providers/opencode/image-files.txt
#                    -> paths relative to $REPO_ROOT/providers/opencode/
#   Capability layer: $SANDBOX_DIR/image-files.txt
#                    -> paths relative to $SANDBOX_DIR/
#
# Conventions:
#   Reasoning layer: $REPO_ROOT/providers/opencode/image-files.txt
#   Capability layer: $SANDBOX_DIR/image-files.txt  (generated at onboarding)
#
# Output:
#   Prints a 64-character hex SHA-256 digest to stdout.
#   Exits non-zero if libs/ is empty, image-files.txt is missing, any listed
#   file does not exist, or sha256sum fails.

set -euo pipefail

image_compute_digest() {
    local repo="${1:?image_compute_digest: AGENT_SANDBOX_REPO is required}"
    local image_files_txt="${2:?image_compute_digest: IMAGE_FILES_TXT is required}"

    local lib_dir="$repo/libs"
    local base_dir
    base_dir="$(dirname "$image_files_txt")"

    # Collect libs/ files — sorted for determinism
    local lib_files=()
    while IFS= read -r -d '' f; do
        lib_files+=("$f")
    done < <(find "$lib_dir" -maxdepth 1 -type f -print0 | sort -z)

    if [[ ${#lib_files[@]} -eq 0 ]]; then
        echo "image_compute_digest: no files found in $lib_dir" >&2
        return 1
    fi

    # Collect image-specific files — paths resolved relative to image-files.txt location
    if [[ ! -f "$image_files_txt" ]]; then
        echo "image_compute_digest: missing $image_files_txt" >&2
        return 1
    fi

    local image_files=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue
        local abs="$base_dir/$line"
        if [[ ! -f "$abs" ]]; then
            echo "image_compute_digest: listed file does not exist: $abs" >&2
            return 1
        fi
        image_files+=("$abs")
    done < "$image_files_txt"

    # Concatenate all files in deterministic order and hash
    cat "${lib_files[@]}" "${image_files[@]}" | sha256sum | cut -d' ' -f1
}
