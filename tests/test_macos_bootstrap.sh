#!/usr/bin/env bash
# tests/test_macos_bootstrap.sh
# Unit tests for scripts/macos_bootstrap.sh  --  the macOS requirements
# install bootstrap.
#
# Covers:
#   non-macOS abort          --  script refuses to run outside Darwin
#   missing Homebrew        --  fails closed with the install command
#   package install          --  absent packages install via brew; present ones skip
#   verification             --  brew bash version + gnubin binaries checked
#   --patch-shell            --  PATH export appended once to ~/.zshrc

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/scripts/macos_bootstrap.sh"

# fake brew: mode from BOOTSTRAP_FAKE_BREW. "absent" -> list fails, install
# logs the package. "present" -> list succeeds.
mkdir -p "$FIXTURE_DIR/shim_brew" "$FIXTURE_DIR/empty_shim"
printf '#!/bin/sh\nif [ "$1" = "list" ] && [ "${BOOTSTRAP_FAKE_BREW:-absent}" = "absent" ]; then exit 1; fi\nif [ "$1" = "install" ]; then echo "$2" >> "${BOOTSTRAP_LOG:-/dev/null}"; fi\nexit 0\n' \
  > "$FIXTURE_DIR/shim_brew/brew"
chmod +x "$FIXTURE_DIR/shim_brew/brew"

# homebrew-prefix fixture: brew bash + the gnubin binaries.
make_prefix() {
  local PREFIX="$1" WITH_GNUBIN="$2"
  mkdir -p "$PREFIX/bin"
  printf '#!/bin/sh\nprintf "5.2.0"\nexit 0\n' > "$PREFIX/bin/bash"
  chmod +x "$PREFIX/bin/bash"
  if [[ "$WITH_GNUBIN" == "yes" ]]; then
    mkdir -p "$PREFIX/opt/coreutils/libexec/gnubin" \
             "$PREFIX/opt/gnu-sed/libexec/gnubin"
    for bin in "$PREFIX/opt/coreutils/libexec/gnubin/realpath" \
               "$PREFIX/opt/coreutils/libexec/gnubin/sha256sum" \
               "$PREFIX/opt/gnu-sed/libexec/gnubin/sed"; do
      printf '#!/bin/sh\nexit 0\n' > "$bin"
      chmod +x "$bin"
    done
  fi
}

test_bootstrap_aborts_on_non_macos() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Linux macos_bootstrap_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"macOS only"* ]]; then
    pass "bootstrap refuses to run outside macOS"
  else
    fail "non-macOS abort broken: rc=$RC out='$OUT'"
  fi
}

test_bootstrap_aborts_without_homebrew() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_DIR/empty_shim" \
        macos_bootstrap_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"Homebrew is required"* && "$OUT" == *"install.sh"* ]]; then
    pass "missing Homebrew aborts with the install command"
  else
    fail "missing-Homebrew abort broken: rc=$RC out='$OUT'"
  fi
}

test_bootstrap_installs_missing_packages() {
  make_prefix "$FIXTURE_DIR/hb_fresh" yes
  local LOG="$FIXTURE_DIR/brew.log" OUT RC=0
  OUT=$(INSTALL_OS=Darwin HOMEBREW_PREFIX="$FIXTURE_DIR/hb_fresh" \
        PATH="$FIXTURE_DIR/shim_brew:$PATH" \
        BOOTSTRAP_FAKE_BREW=absent BOOTSTRAP_LOG="$LOG" \
        macos_bootstrap_main 2>&1 </dev/null) || RC=$?

  local installed
  installed="$(sort "$LOG" | tr '\n' ' ')"
  if [[ $RC -eq 0 && "$installed" == "bash coreutils git gnu-sed " \
     && "$OUT" == *"ok: brew bash 5.2.0"* && "$OUT" == *"make install"* ]]; then
    pass "absent packages install via brew and verification passes"
  else
    fail "install path broken: rc=$RC log='$installed' out='$OUT'"
  fi
}

test_bootstrap_skips_present_packages() {
  make_prefix "$FIXTURE_DIR/hb_full" yes
  local LOG="$FIXTURE_DIR/brew2.log" OUT RC=0
  OUT=$(INSTALL_OS=Darwin HOMEBREW_PREFIX="$FIXTURE_DIR/hb_full" \
        PATH="$FIXTURE_DIR/shim_brew:$PATH" \
        BOOTSTRAP_FAKE_BREW=present BOOTSTRAP_LOG="$LOG" \
        macos_bootstrap_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && ! -s "$LOG" && "$OUT" == *"present: bash"* ]]; then
    pass "present packages are skipped, nothing reinstalled"
  else
    fail "present-skip path broken: rc=$RC log='$(cat "$LOG" 2>/dev/null)' out='$OUT'"
  fi
}

test_bootstrap_verification_flags_missing_gnubin() {
  make_prefix "$FIXTURE_DIR/hb_partial" no
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin HOMEBREW_PREFIX="$FIXTURE_DIR/hb_partial" \
        PATH="$FIXTURE_DIR/shim_brew:$PATH" \
        BOOTSTRAP_FAKE_BREW=present \
        macos_bootstrap_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"missing: $FIXTURE_DIR/hb_partial/opt/coreutils"* ]]; then
    pass "verification flags missing gnubin binaries"
  else
    fail "verification broken: rc=$RC out='$OUT'"
  fi
}

test_patch_shell_appends_once() {
  make_prefix "$FIXTURE_DIR/hb_patch" yes
  mkdir -p "$FIXTURE_DIR/home"
  local OUT RC=0
  OUT=$(HOMEBREW_PREFIX="$FIXTURE_DIR/hb_patch" HOME="$FIXTURE_DIR/home" \
        patch_shell_rc 2>&1 </dev/null)
  OUT=$(HOMEBREW_PREFIX="$FIXTURE_DIR/hb_patch" HOME="$FIXTURE_DIR/home" \
        patch_shell_rc 2>&1 </dev/null) || RC=$?

  local lines
  lines="$(grep -c "export PATH=" "$FIXTURE_DIR/home/.zshrc")"
  assert_eq "$lines" "1" "--patch-shell appends the PATH export exactly once"
}

run_test test_bootstrap_aborts_on_non_macos
run_test test_bootstrap_aborts_without_homebrew
run_test test_bootstrap_installs_missing_packages
run_test test_bootstrap_skips_present_packages
run_test test_bootstrap_verification_flags_missing_gnubin
run_test test_patch_shell_appends_once

test_done test_macos_bootstrap.sh
