#!/usr/bin/env bash
# tests/test_install.sh
# Unit tests for scripts/install.sh  --  the host-requirement gate and CLI
# symlink install.
#
# Covers:
#   Linux default pass      --  checks pass, symlink created
#   uninstall               --  symlink removed
#   Darwin missing tools    --  BSD-style PATH detected, brew hints printed,
#                               install aborts
#   Darwin GNU shim         --  GNU-style PATH detected, install proceeds
#   Linux missing git       --  git check fails closed

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup
source "$REPO_ROOT/scripts/install.sh"

# Fake GNU tools detect the failed probes; symlinked real git/grep keep the
# probes themselves working. The empty shim makes every probe fail.
mkdir -p "$FIXTURE_ROOT/gnu_shim" "$FIXTURE_ROOT/empty_shim"
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_ROOT/gnu_shim/realpath"
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_ROOT/gnu_shim/sha256sum"
printf '#!/bin/sh\nprintf "2026-09-17\\n"\nexit 0\n' > "$FIXTURE_ROOT/gnu_shim/date"
printf '#!/bin/sh\necho "sed (GNU sed) 4.8.1"\nexit 0\n' > "$FIXTURE_ROOT/gnu_shim/sed"
chmod +x "$FIXTURE_ROOT/gnu_shim"/{realpath,sha256sum,date,sed}
ln -s "$(command -v git)" "$FIXTURE_ROOT/gnu_shim/git"
ln -s "$(command -v grep)" "$FIXTURE_ROOT/gnu_shim/grep"

# Given: INSTALL_OS=Linux and a fixture INSTALL_DIR
# When:  install_main runs
# Then:  rc is 0 and the CLI symlink exists at the requested directory
# Asserts: the Linux default path checks bash and git, then installs
test_install_passes_on_linux_default() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Linux INSTALL_DIR="$FIXTURE_DIR/bin_linux" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && -L "$FIXTURE_DIR/bin_linux/agent-sandbox" ]]; then
    pass "install passes on Linux and creates the CLI symlink"
  else
    fail "Linux install broken: rc=$RC out='$OUT'"
  fi
}

# Given: a completed install under a fixture INSTALL_DIR
# When:  install_main runs with --uninstall
# Then:  rc is 0 and the symlink is gone
# Asserts: uninstall removes the CLI entry
test_install_uninstall_removes_symlink() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Linux INSTALL_DIR="$FIXTURE_DIR/bin_rm" \
        install_main 2>&1 </dev/null) || RC=$?
  OUT=$(INSTALL_DIR="$FIXTURE_DIR/bin_rm" \
        install_main --uninstall 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && ! -e "$FIXTURE_DIR/bin_rm/agent-sandbox" ]]; then
    pass "uninstall removes the CLI symlink"
  else
    fail "uninstall broken: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Darwin and an empty PATH shim, so every GNU probe fails
# When:  install_main runs
# Then:  rc is non-zero and the output names coreutils and the requirements doc
# Asserts: the Darwin branch refuses a host without the GNU toolchain
# Note:  all four probes fail together, so the unit cannot tell which was detected (finding 127)
test_install_detects_missing_gnu_tools_on_darwin() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_ROOT/empty_shim" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_bad" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"coreutils"* && "$OUT" == *"host_requirements"* ]]; then
    pass "Darwin install aborts with brew hints when GNU tools are missing"
  else
    fail "Darwin missing-tools gate broken: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Darwin and a shim whose probes answer the GNU way
# When:  install_main runs
# Then:  rc is 0 and the symlink exists
# Asserts: the Darwin branch proceeds when the toolchain is present
test_install_passes_on_darwin_with_gnu_shim() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_ROOT/gnu_shim:$PATH" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_ok" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && -L "$FIXTURE_DIR/bin_darwin_ok/agent-sandbox" ]]; then
    pass "Darwin install passes when the GNU toolchain is present"
  else
    fail "Darwin GNU-shim install broken: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Linux and an empty PATH shim
# When:  install_main runs
# Then:  rc is non-zero and the message names git as missing
# Asserts: the git probe fails closed, on Linux, through the empty shim
test_install_detects_missing_git_on_linux() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Linux PATH="$FIXTURE_ROOT/empty_shim" \
        INSTALL_DIR="$FIXTURE_DIR/bin_linux_nogit" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"git: missing"* ]]; then
    pass "Linux install aborts when git is missing"
  else
    fail "missing-git gate broken: rc=$RC out='$OUT'"
  fi
}

run_test test_install_passes_on_linux_default
run_test test_install_uninstall_removes_symlink
run_test test_install_detects_missing_gnu_tools_on_darwin
run_test test_install_passes_on_darwin_with_gnu_shim
run_test test_install_detects_missing_git_on_linux

test_done test_install.sh