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
#   Darwin probe isolation  --  one unit per GNU probe, only that probe failing
#   Darwin GNU shim         --  GNU-style PATH detected, install proceeds
#   Linux missing git       --  git check fails closed, without a brew hint
#   INSTALL_DIR resolution  --  env override, <repo>/.env fallback, ~ expansion
#   re-install              --  force-replaces an existing entry at the CLI path
#   standalone entry point  --  the guard runs install_main and uninstall as a subprocess

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

# One isolation shim per GNU probe. Each dir shadows a single tool while
# gnu_shim supplies the rest, so exactly one check fails and the printed hint
# pins which requirement was detected. PATH carries the shim dirs only  --  a
# host tool leaked in by the system PATH would mask the failure.
mkdir -p "$FIXTURE_ROOT/iso_readlink" "$FIXTURE_ROOT/iso_date" \
         "$FIXTURE_ROOT/iso_sed" "$FIXTURE_ROOT/gnu_shim_nosha"
printf '#!/bin/sh\nexit 1\n' > "$FIXTURE_ROOT/iso_readlink/realpath"
printf '#!/bin/sh\nexit 1\n' > "$FIXTURE_ROOT/iso_date/date"
printf '#!/bin/sh\necho "sed: illegal option -- -"\nexit 1\n' > "$FIXTURE_ROOT/iso_sed/sed"
chmod +x "$FIXTURE_ROOT/iso_readlink/realpath" "$FIXTURE_ROOT/iso_date/date" "$FIXTURE_ROOT/iso_sed/sed"
for t in realpath date sed git grep; do
  ln -s "$FIXTURE_ROOT/gnu_shim/$t" "$FIXTURE_ROOT/gnu_shim_nosha/$t"
done

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

  if [[ $RC -ne 0 && "$OUT" == *"git: missing"* && "$OUT" != *"brew"* ]]; then
    pass "Linux install aborts when git is missing, without a macOS hint"
  else
    fail "missing-git gate broken: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Darwin and a shim where only realpath/readlink fails
# When:  install_main runs
# Then:  rc is non-zero and the output names the realpath/readlink requirement
# Asserts: the readlink probe is detected in isolation
test_install_detects_missing_readlink_on_darwin() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_ROOT/iso_readlink:$FIXTURE_ROOT/gnu_shim" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_readlink" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"realpath or readlink -f missing"* ]]; then
    pass "Darwin install aborts when only realpath/readlink is missing"
  else
    fail "readlink probe not isolated: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Darwin and a shim where only sha256sum is absent
# When:  install_main runs
# Then:  rc is non-zero and the output names the sha256sum requirement
# Asserts: the sha256sum probe is detected in isolation
test_install_detects_missing_sha256sum_on_darwin() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_ROOT/gnu_shim_nosha" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_nosha" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"sha256sum missing"* ]]; then
    pass "Darwin install aborts when only sha256sum is missing"
  else
    fail "sha256sum probe not isolated: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Darwin and a shim where only date rejects -d
# When:  install_main runs
# Then:  rc is non-zero and the output names the GNU date requirement
# Asserts: the GNU date probe is detected in isolation
test_install_detects_missing_gnu_date_on_darwin() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_ROOT/iso_date:$FIXTURE_ROOT/gnu_shim" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_date" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"GNU date (date -d) missing"* ]]; then
    pass "Darwin install aborts when only GNU date is missing"
  else
    fail "GNU date probe not isolated: rc=$RC out='$OUT'"
  fi
}

# Given: INSTALL_OS=Darwin and a shim where only sed is non-GNU
# When:  install_main runs
# Then:  rc is non-zero and the output names the GNU sed requirement
# Asserts: the GNU sed probe is detected in isolation
test_install_detects_missing_gnu_sed_on_darwin() {
  local OUT RC=0
  OUT=$(INSTALL_OS=Darwin PATH="$FIXTURE_ROOT/iso_sed:$FIXTURE_ROOT/gnu_shim" \
        INSTALL_DIR="$FIXTURE_DIR/bin_darwin_sed" \
        install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -ne 0 && "$OUT" == *"GNU sed missing"* ]]; then
    pass "Darwin install aborts when only GNU sed is missing"
  else
    fail "GNU sed probe not isolated: rc=$RC out='$OUT'"
  fi
}

# Given: a fixture repo whose .env records INSTALL_DIR
# When:  install_dir resolves with no INSTALL_DIR in the environment
# Then:  the value comes from <repo>/.env
# Asserts: the .env fallback of the INSTALL_DIR resolution tail
test_install_dir_reads_repo_env() {
  local FAKE="$FIXTURE_DIR/fake_repo_env"
  mkdir -p "$FAKE"
  printf 'INSTALL_DIR=%s\n' "$FIXTURE_DIR/from_env_bin" > "$FAKE/.env"

  local OUT
  OUT="$( unset INSTALL_DIR; REPO_ROOT="$FAKE"; install_dir )"

  assert_eq "$OUT" "$FIXTURE_DIR/from_env_bin" "install_dir reads <repo>/.env INSTALL_DIR"
}

# Given: no INSTALL_DIR in the environment and no <repo>/.env
# When:  install_dir resolves
# Then:  the default ~/.local/bin is expanded to $HOME/.local/bin
# Asserts: the default and the leading-~ expansion of the resolution tail
test_install_dir_default_expands_tilde() {
  local NODOTENV="$FIXTURE_DIR/no_env_repo"
  mkdir -p "$NODOTENV"

  local OUT
  OUT="$( unset INSTALL_DIR; REPO_ROOT="$NODOTENV"; install_dir )"

  assert_eq "$OUT" "$HOME/.local/bin" "install_dir expands the default ~/.local/bin to HOME"
}

# Given: a non-symlink file already occupies the CLI entry path
# When:  install_main runs
# Then:  the entry is force-replaced with the CLI symlink
# Asserts: a re-install forces past an existing destination (-f)
test_install_replaces_existing_entry() {
  local DIR="$FIXTURE_DIR/bin_replace"
  mkdir -p "$DIR"
  printf 'stale\n' > "$DIR/agent-sandbox"

  local OUT RC=0
  OUT=$(INSTALL_OS=Linux INSTALL_DIR="$DIR" install_main 2>&1 </dev/null) || RC=$?

  if [[ $RC -eq 0 && -L "$DIR/agent-sandbox" ]]; then
    pass "install force-replaces an existing entry at the CLI path"
  else
    fail "install did not replace the existing entry: rc=$RC out='$OUT'"
  fi
}

# Given: the install script run as a standalone process
# When:  install.sh runs with no subcommand
# Then:  the entry-point guard sets REPO_ROOT and installs the symlink
# Asserts: the path make install actually runs
test_install_standalone_entry_point_installs() {
  local DIR="$FIXTURE_DIR/bin_standalone"

  local OUT RC=0
  OUT="$( INSTALL_OS=Linux INSTALL_DIR="$DIR" bash "$REPO_ROOT/scripts/install.sh" 2>&1 </dev/null )" || RC=$?

  if [[ $RC -eq 0 && -L "$DIR/agent-sandbox" ]]; then
    pass "the standalone entry point installs the CLI symlink"
  else
    fail "standalone install broken: rc=$RC out='$OUT'"
  fi
}

# Given: a completed standalone install
# When:  install.sh --uninstall runs as a standalone process
# Then:  the symlink is removed and rc is 0
# Asserts: the standalone uninstall path behind the entry-point guard
test_install_standalone_entry_point_uninstalls() {
  local DIR="$FIXTURE_DIR/bin_standalone_rm"
  INSTALL_OS=Linux INSTALL_DIR="$DIR" bash "$REPO_ROOT/scripts/install.sh" > /dev/null 2>&1 </dev/null

  local OUT RC=0
  OUT="$( INSTALL_DIR="$DIR" bash "$REPO_ROOT/scripts/install.sh" --uninstall 2>&1 </dev/null )" || RC=$?

  if [[ $RC -eq 0 && ! -e "$DIR/agent-sandbox" ]]; then
    pass "the standalone entry point uninstalls the CLI symlink"
  else
    fail "standalone uninstall broken: rc=$RC out='$OUT'"
  fi
}

run_test test_install_passes_on_linux_default
run_test test_install_uninstall_removes_symlink
run_test test_install_detects_missing_gnu_tools_on_darwin
run_test test_install_detects_missing_readlink_on_darwin
run_test test_install_detects_missing_sha256sum_on_darwin
run_test test_install_detects_missing_gnu_date_on_darwin
run_test test_install_detects_missing_gnu_sed_on_darwin
run_test test_install_passes_on_darwin_with_gnu_shim
run_test test_install_detects_missing_git_on_linux
run_test test_install_dir_reads_repo_env
run_test test_install_dir_default_expands_tilde
run_test test_install_replaces_existing_entry
run_test test_install_standalone_entry_point_installs
run_test test_install_standalone_entry_point_uninstalls

test_done test_install.sh