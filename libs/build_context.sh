#!/usr/bin/env bash
# libs/build_context.sh — build context preparation
#
# Defines build_context: creates a temp directory, populates it with the
# files required to build a given image, and prints the temp dir path to
# stdout. The caller passes this path as the Docker build context and is
# responsible for cleaning it up.
#
# A missing source file is a hard error — build_context exits non-zero
# and prints the missing path to stderr. The temp dir is removed before
# returning so no partial context is left behind on failure.
#
# Usage:
#   source libs/build_context.sh
#   context_dir=$(build_context <image_type> <repo_root>)
#   docker build -t <image> -f <dockerfile> "$context_dir"
#   rm -rf "$context_dir"
#
# image_type: "sandbox" (capability layer) or "agent" (reasoning layer)
# repo_root:  absolute path to the agent-sandbox repo root

set -euo pipefail

build_context() {
    local image_type="$1"
    local repo_root="$2"

    if [[ -z "$image_type" || -z "$repo_root" ]]; then
        echo "build_context: missing required argument" >&2
        echo "usage: build_context <sandbox|agent> <repo_root>" >&2
        return 1
    fi

    if [[ "$image_type" != "sandbox" && "$image_type" != "agent" ]]; then
        echo "build_context: unknown image type '$image_type' (expected: sandbox or agent)" >&2
        return 1
    fi

    local context_dir=""
    context_dir=$(mktemp -d)
    trap '[[ -n "$context_dir" ]] && rm -rf "$context_dir"' ERR

    case "$image_type" in
        sandbox)
            _build_context_copy "$repo_root/scripts/sandbox-entrypoint.sh" "$context_dir/" || return 1
            _build_context_copy "$repo_root/libs/snapshot.sh"              "$context_dir/" || return 1
            _build_context_copy "$repo_root/libs/diff.sh"                  "$context_dir/" || return 1
            _build_context_copy "$repo_root/libs/dirs.sh"                  "$context_dir/" || return 1
            ;;
        agent)
            _build_context_copy "$repo_root/libs/dirs.sh" "$context_dir/" || return 1
            ;;
    esac

    echo "$context_dir"
}

_build_context_copy() {
    local src="$1"
    local dst="$2"

    if [[ ! -f "$src" ]]; then
        echo "build_context: missing required file: $src" >&2
        return 1
    fi

    cp "$src" "$dst"
}

# check_template_version <label> <template_file> <installed_file> <display_name> <project_name> <sandbox_dir>
#
# Compares the "# agent-sandbox template version: N" comment in an installed
# file against the current template. Emits a warning and refresh instructions
# if they differ. Called at build time so the operator is notified before
# building a potentially inconsistent image.
#
# Only meaningful for operator-installed files in SANDBOX_DIR (e.g.
# Dockerfile.sandbox) — repo-controlled files are always current by definition.
check_template_version() {
    local label="$1"
    local template="$2"
    local installed="$3"
    local display_name="$4"
    local project_name="$5"
    local sandbox_dir="$6"

    local tmpl_ver inst_ver
    tmpl_ver=$(grep -m1 "^# agent-sandbox template version:" "$template" 2>/dev/null | awk '{print $NF}' || true)
    inst_ver=$(grep -m1 "^# agent-sandbox template version:" "$installed" 2>/dev/null | awk '{print $NF}' || true)

    if [[ -n "$tmpl_ver" && "$inst_ver" != "$tmpl_ver" ]]; then
        echo "Warning: $label is based on template version ${inst_ver:-unknown}, current template is version ${tmpl_ver}."
        echo "  Your $display_name may be out of date."
        echo "  To refresh: agent-sandbox onboard --refresh --name=${project_name} --sandbox=${sandbox_dir}"
        echo ""
    fi
}
