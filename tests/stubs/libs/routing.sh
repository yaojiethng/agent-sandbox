#!/usr/bin/env bash
# tests/stubs/libs/routing.sh
# Test stand-in for src/libs/routing.sh. `export_path` is pure path derivation
# with no docker dependency, so the stub sources the production file rather
# than keeping a copy. The copy re-implemented the autosave branch shape that
# the checkpoint swap and every autosave reader depend on, so it could drift
# from the layout the code actually uses.

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/routing.sh"
