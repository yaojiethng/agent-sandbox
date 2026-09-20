#!/usr/bin/env bash
# tests/stubs/libs/dry_run_harness.sh
# Test stand-in for src/libs/dry_run_harness.sh. The production file is pure
# bash -- pass/fail/warn counting, section headers, diagnostics-record writing,
# with no docker dependency -- so the stub sources it rather than keeping a
# copy. A verbatim copy sat here and drifted silently; the sibling stubs
# (session_state.sh, interface_contract.sh, diff_export.sh) source the
# production files for the same reason.
#
# This file exists so the probe harness's BASH_ENV loader (bash_env.sh) and the
# test-liveness orphan scan both see a stub at the conventional path.

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/dry_run_harness.sh"
