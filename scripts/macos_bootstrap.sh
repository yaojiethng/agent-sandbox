#!/bin/bash
# scripts/macos_bootstrap.sh  --  install the agent-sandbox host requirements on macOS.
#
# Installs via Homebrew: bash (4.0+), coreutils, gnu-sed, findutils, and git.
# The harness needs the GNU toolchain; macOS ships bash 3.2 and BSD tools.
# See docs/development/host_requirements.md for the requirement matrix.
#
# Idempotent: re-running installs nothing that is already present.
# Fail closed on missing Homebrew: prints the Homebrew install command and
# exits; it does not install Homebrew for you.
#
# Written to run under macOS's system bash 3.2, so it avoids bash 4.0+
# features (mapfile, associative arrays).
#
# Usage:
#   bash scripts/macos_bootstrap.sh                  -- install, print PATH guidance
#   bash scripts/macos_bootstrap.sh --patch-shell    -- also append the PATH export to ~/.zshrc
#   bash scripts/macos_bootstrap.sh --switch-shell   -- also print the login-shell switch commands
#
# Test overrides: INSTALL_OS (host detection), HOMEBREW_PREFIX (brew prefix).

set -uo pipefail

REQUIRED_PACKAGES=(bash coreutils gnu-sed findutils git)

bootstrap_os() {
  echo "${INSTALL_OS:-$(uname -s)}"
}

homebrew_prefix() {
  if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
    echo "$HOMEBREW_PREFIX"
  elif [[ "$(uname -m)" == "arm64" ]]; then
    echo "/opt/homebrew"
  else
    echo "/usr/local"
  fi
}

require_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew is required but not found." >&2
    echo "Install it with:" >&2
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' >&2
    echo "Then re-run this script." >&2
    return 1
  fi
}

# gnubin_paths -- the PATH prefix that shadows BSD tools with the GNU ones.
gnubin_paths() {
  local prefix
  prefix="$(homebrew_prefix)"
  echo "$prefix/opt/coreutils/libexec/gnubin:$prefix/opt/gnu-sed/libexec/gnubin:$prefix/opt/findutils/libexec/gnubin"
}

install_packages() {
  local pkg
  for pkg in "${REQUIRED_PACKAGES[@]}"; do
    if brew list "$pkg" >/dev/null 2>&1; then
      echo "  present: $pkg"
    else
      echo "  installing: $pkg"
      brew install "$pkg" || return 1
    fi
  done
}

patch_shell_rc() {
  local line
  line="export PATH=\"$(gnubin_paths):\$PATH\""
  if grep -Fq "$line" "$HOME/.zshrc" 2>/dev/null; then
    echo "  PATH export already present in ~/.zshrc"
  else
    echo "$line" >> "$HOME/.zshrc"
    echo "  appended PATH export to ~/.zshrc"
  fi
}

# verify_installed -- confirms the brew bash version and the gnubin binaries.
verify_installed() {
  local prefix bashver bashver_major
  prefix="$(homebrew_prefix)"

  bashver="$("$prefix/bin/bash" -c 'echo "$BASH_VERSION"' 2>/dev/null || true)"
  if [[ -z "$bashver" ]]; then
    echo "  missing: $prefix/bin/bash (brew bash not found)" >&2
    return 1
  fi
  bashver_major="${bashver%%.*}"
  if (( bashver_major < 4 )); then
    echo "  brew bash is too old: version $bashver (need 4.0+)" >&2
    return 1
  fi
  echo "  ok: brew bash $bashver"

  local missing=0 bin
  for bin in "$prefix/opt/coreutils/libexec/gnubin/realpath" \
             "$prefix/opt/coreutils/libexec/gnubin/sha256sum" \
             "$prefix/opt/gnu-sed/libexec/gnubin/sed" \
             "$prefix/opt/findutils/libexec/gnubin/xargs"; do
    if [[ ! -x "$bin" ]]; then
      echo "  missing: $bin" >&2
      missing=1
    else
      echo "  ok: $bin"
    fi
  done
  return $missing
}

macos_bootstrap_main() {
  if [[ "$(bootstrap_os)" != "Darwin" ]]; then
    echo "macOS only: this script installs Homebrew packages." >&2
    return 1
  fi

  local patch=0 switch=0 arg
  for arg in "$@"; do
    case "$arg" in
      --patch-shell)  patch=1 ;;
      --switch-shell) switch=1 ;;
      *) echo "Unknown option: $arg" >&2; return 1 ;;
    esac
  done

  require_homebrew || return 1
  install_packages || return 1

  echo
  echo "PATH export to add to your shell rc (or use --patch-shell):"
  echo "  export PATH=\"$(gnubin_paths):\$PATH\""
  if (( patch )); then
    patch_shell_rc
  fi

  if (( switch )); then
    echo
    echo "To make brew bash the login shell (optional):"
    echo "  echo '$(homebrew_prefix)/bin/bash' | sudo tee -a /etc/shells"
    echo "  chsh -s $(homebrew_prefix)/bin/bash"
  fi

  echo
  echo "Verifying the installed requirements..."
  verify_installed || return 1

  echo
  echo "Next: open a new shell so the PATH export applies, then run: make install"
  echo "The install gate (scripts/install.sh) re-checks the requirements."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  macos_bootstrap_main "$@"
fi