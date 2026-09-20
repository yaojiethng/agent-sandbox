#!/usr/bin/env bash
# tests/stubs/libs/dirs.sh
# Test stand-in for src/libs/dirs.sh. `dirs_resolve` is pure path derivation
# with no docker dependency, so the stub sources the production file rather
# than keeping a copy that can drift. The probe harness's fallback path uses it
# when a dir env var is unset.

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/dirs.sh"
