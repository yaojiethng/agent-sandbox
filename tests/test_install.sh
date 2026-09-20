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
mkdir -p "$FIXTURE_DIR/gnu_shim" "$FIXTURE_DIR/empty_shim"
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/gnu_shim/realpath"
printf '#!/bin/sh\nexit 0\n' > "$FIXTURE_DIR/gnu_shim/sha256sum"
printf '#!/bin/sh\nprintf "2026-09-17\\n"\nexit 0\n' > "$FIXTURE_DIR/gnu_shim/date"
printf '#!/bin/sh\necho "sed (GNU sed) 4.8.1"\nexit 0\n' > "$FIXTURE_DIR/gnu_shim/sed"
chmod +x "$FIXTURE_DIR/gnu_shim"/{realpath,sha256sum,date,sed}
ln -s "$(command -v git)" "$FIXTURE_DIR/gnu_shim/git"
ln -s "$(command -v grep)" "$FIXTURE_DIR/gnu_shim/grep"

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

test_install_detects_missing_gnu_tools_on_darwin() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_DIR/empty_shim" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_bad" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"coreutils"* && "$OUT" == *"host_requirements"* ]]; then
    pass "Darwin install aborts with brew hints when GNU tools are missing"
  else
    fail "Darwin missing-tools gate broken: rc=$RC out='$OUT'"
  fi
}

test_install_passes_on_darwin_with_gnu_shim() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_DIR/gnu_shim:$PATH" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_ok" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && -L "$FIXTURE_DIR/bin_darwin_ok/agent-sandbox" ]]; then
    pass "Darwin install passes when the GNU toolchain is present"
  else
    fail "Darwin GNU-shim install broken: rc=$RC out='$OUT'"
  fi
}

test_install_detects_missing_git_on_linux() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Linux PATH="$FIXTURE_DIR/empty_shim" \
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