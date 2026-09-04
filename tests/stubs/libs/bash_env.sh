#!/usr/bin/env bash
# tests/stubs/libs/bash_env.sh
# Loaded by every non-interactive bash in the probe harness via BASH_ENV.
# Bash -c sub-shells spawned by the probes (e.g. the export_path warn_check)
# do not inherit function definitions from the probe's top-level source, so
# this loader re-sources the stubs into those sub-shells. Idempotent (re-source
# is harmless) and must produce no output.
source "$(dirname "${BASH_SOURCE[0]}")/session_state.sh"
source "$(dirname "${BASH_SOURCE[0]}")/diff_export.sh"
source "$(dirname "${BASH_SOURCE[0]}")/routing.sh"
source "$(dirname "${BASH_SOURCE[0]}")/dirs.sh"