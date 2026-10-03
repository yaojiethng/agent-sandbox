#!/usr/bin/env bash
# scripts/install.sh  --  host-side install gate + CLI symlink install.
#
# Verifies the host against docs/development/host_requirements.md, then
# installs the agent-sandbox CLI. Fails closed: it exits non-zero and prints
# per-tool install hints when a requirement is missing.
#
# Uninstall removes only the harness symlink at the CLI path. Anything else
# at that path - a real file or a foreign symlink - stays untouched, the
# error names the path, and the command fails.
#
# The gate exists because the harness uses modern bash (mapfile, associative
# arrays) and GNU userland (realpath, sha256sum, GNU date/sed).
# macOS ships bash 3.2 and BSD tools; Homebrew provides both.
#
# Usage:
#   bash scripts/install.sh            -- check host, install symlink
#   bash scripts/install.sh --uninstall
#   INSTALL_DIR=<path> bash scripts/install.sh
#
# INSTALL_DIR resolution order: env INSTALL_DIR, <repo>/.env INSTALL_DIR,
# ~/.local/bin. Tests override the host detection with INSTALL_OS.

set -uo pipefail

# install_os -- reports the host OS. INSTALL_OS overrides for tests.
install_os() {
  echo "${INSTALL_OS:-$(uname -s)}"
}

# --- Requirement checks -----------------------------------------------------
# Each check prints a hint on failure and returns non-zero. The checks only
# use subprocesses that exist on both Linux and macOS (grep) or none at all;
# each probe targets one GNU/BSD difference.
#
# Requirement source of truth: docs/development/host_requirements.md. The same
# list is enforced for macOS by scripts/macos_bootstrap.sh (REQUIRED_PACKAGES +
# verify_installed) -- a new requirement must be added to all three.

check_bash_version() {
  if (( BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4) )); then
    echo "  - bash 4.4+ required (found ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]})" >&2
    echo "    A 4.4 feature is required: expanding \"\${arr[@]}\" on an empty array" >&2
    echo "    under set -u (present in build.sh)." >&2
    if [[ "$(install_os)" == "Darwin" ]]; then
      echo "    macOS: brew install bash; then run bash scripts/install.sh with /opt/homebrew/bin first in PATH." >&2
    else
      echo "    Install bash 4.4+ with your package manager." >&2
    fi
    return 1
  fi
}

check_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "  - git: missing" >&2
    if [[ "$(install_os)" == "Darwin" ]]; then
      echo "    macOS: brew install git" >&2
    else
      echo "    Install git with your package manager." >&2
    fi
    return 1
  fi
}

check_gnu_readlink() {
  if ! readlink -f / >/dev/null 2>&1; then
    echo "  - GNU coreutils: readlink -f missing" >&2
    echo "    Used by scripts/agent-sandbox.sh and src/libs/common.sh to resolve paths." >&2
    echo "    macOS: brew install coreutils" >&2
    return 1
  fi
}

check_sha256sum() {
  if ! command -v sha256sum >/dev/null 2>&1; then
    echo "  - GNU coreutils: sha256sum missing" >&2
    echo "    Used for session ids and compose file names." >&2
    echo "    macOS: brew install coreutils" >&2
    return 1
  fi
}

check_gnu_date() {
  if ! date -d '1 day ago' >/dev/null 2>&1; then
    echo "  - GNU date (date -d) missing" >&2
    echo "    Used by scripts/prune.sh for age cutoffs; BSD date uses -v instead." >&2
    echo "    macOS: brew install coreutils" >&2
    return 1
  fi
}

check_gnu_sed() {
  if ! sed --version 2>/dev/null | grep -q 'GNU sed'; then
    echo "  - GNU sed missing" >&2
    echo "    Used by scripts/onboard.sh (sed -i without backup arg)." >&2
    echo "    macOS: brew install gnu-sed" >&2
    return 1
  fi
}

check_gnu_find() {
  if ! find / -maxdepth 0 -printf '%f' >/dev/null 2>&1; then
    echo "  - GNU findutils: find -printf missing" >&2
    echo "    Used by scripts/workflows/interactive.sh for session timestamps and ordering." >&2
    echo "    macOS: brew install findutils" >&2
    return 1
  fi
}

check_rsync() {
  if ! rsync --version >/dev/null 2>&1; then
    echo "  - rsync missing" >&2
    echo "    Used by scripts/onboard.sh to seed a sandbox with permissions preserved." >&2
    echo "    macOS: brew install rsync" >&2
    return 1
  fi
}

# --- Install / uninstall ----------------------------------------------------

# install_dir  -- INSTALL_DIR resolution order: env, <repo>/.env, ~/.local/bin.
install_dir() {
  local dir="${INSTALL_DIR:-}"
  if [[ -z "$dir" && -f "$REPO_ROOT/.env" ]]; then
    dir="$(grep '^INSTALL_DIR=' "$REPO_ROOT/.env" | cut -d'=' -f2- | head -n1)"
  fi
  dir="${dir:-~/.local/bin}"
  dir="${dir/#\~/$HOME}"
  echo "$dir"
}

do_install() {
  local dir
  dir="$(install_dir)"
  mkdir -p "$dir"
  ln -sfn "$REPO_ROOT/scripts/agent-sandbox.sh" "$dir/agent-sandbox"
  echo "Installed agent-sandbox to $dir/agent-sandbox (symlink -> $REPO_ROOT/scripts/agent-sandbox.sh)"
}

# do_uninstall  --  removes the harness symlink at the CLI path. Anything
# else at that path stays untouched: the error names the path and the
# command returns non-zero. An absent target is a silent success.
do_uninstall() {
  local dir path
  dir="$(install_dir)"
  path="$dir/agent-sandbox"
  if [[ -e "$path" || -L "$path" ]]; then
    local target
    target="$(readlink "$path" 2>/dev/null || true)"
    if [[ ! -L "$path" || "$target" != "$REPO_ROOT/scripts/agent-sandbox.sh" ]]; then
      echo "Refusing to remove $path: not the harness symlink" >&2
      return 1
    fi
    rm -f "$path"
    echo "Removed $dir/agent-sandbox"
  fi
}

# --- Entry ------------------------------------------------------------------

install_main() {
  if [[ "${1:-}" == "--uninstall" ]]; then
    do_uninstall
    return $?
  fi

  local failures=0
  echo "Checking host requirements (docs/development/host_requirements.md)..."
  check_bash_version || failures=$((failures + 1))
  check_git || failures=$((failures + 1))
  if [[ "$(install_os)" == "Darwin" ]]; then
    check_gnu_readlink || failures=$((failures + 1))
    check_sha256sum || failures=$((failures + 1))
    check_gnu_date || failures=$((failures + 1))
    check_gnu_sed || failures=$((failures + 1))
    check_gnu_find || failures=$((failures + 1))
    check_rsync || failures=$((failures + 1))
  fi

  if (( failures > 0 )); then
    echo "Install aborted: $failures requirement(s) missing." >&2
    if [[ "$(install_os)" == "Darwin" ]]; then
      echo "See docs/development/host_requirements.md (macOS setup section)." >&2
    else
      echo "See docs/development/host_requirements.md." >&2
    fi
    return 1
  fi

  do_install
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  install_main "$@"
fi
