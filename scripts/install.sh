#!/usr/bin/env bash
# scripts/install.sh  --  host-side install gate + CLI symlink install.
#
# Verifies the host against docs/development/host_requirements.md, then
# installs the agent-sandbox CLI. Fails closed: it exits non-zero and prints
# per-tool install hints when a requirement is missing.
#
# The gate exists because the harness uses modern bash (mapfile, associative
# arrays) and GNU userland (realpath, sha256sum, GNU date/sed, GNU xargs).
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

check_bash_version() {
  if (( BASH_VERSINFO[0] < 4 )); then
    echo "  - bash 4.0+ required (found ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]})" >&2
    echo "    The harness uses mapfile and associative arrays (bash 4.0+)." >&2
    echo "    macOS: brew install bash; then run bash scripts/install.sh with /opt/homebrew/bin first in PATH." >&2
    return 1
  fi
}

check_git() {
  if ! command -v git >/dev/null 2>&1; then
    echo "  - git: missing" >&2
    echo "    macOS: brew install git" >&2
    return 1
  fi
}

check_gnu_readlink() {
  if ! realpath / >/dev/null 2>&1 && ! readlink -f / >/dev/null 2>&1; then
    echo "  - GNU coreutils: realpath or readlink -f missing" >&2
    echo "    Used by scripts/onboard.sh and scripts/run_agent.sh to resolve paths." >&2
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

check_gnu_xargs() {
  if ! xargs --version 2>/dev/null | grep -q 'GNU findutils'; then
    echo "  - GNU findutils: xargs --no-run-if-empty missing" >&2
    echo "    Used by src/libs/container_sig.sh (xargs -0 -r)." >&2
    echo "    macOS: brew install findutils" >&2
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

do_uninstall() {
  local dir
  dir="$(install_dir)"
  rm -f "$dir/agent-sandbox"
  echo "Removed $dir/agent-sandbox"
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
    check_gnu_xargs || failures=$((failures + 1))
  fi

  if (( failures > 0 )); then
    echo "Install aborted: $failures requirement(s) missing." >&2
    echo "See docs/development/host_requirements.md (macOS setup section)." >&2
    return 1
  fi

  do_install
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  install_main "$@"
fi