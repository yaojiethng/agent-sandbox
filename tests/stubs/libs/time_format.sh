#!/usr/bin/env bash
# tests/stubs/libs/time_format.sh
# Test stand-in for src/libs/time_format.sh. The format has one definition, so
# this stub sources the production file rather than keeping a copy that can
# drift -- the same shape tests/stubs/libs/dirs.sh and routing.sh already use.
#
# The stub lib dir is a second source root for the entrypoint: it neutralises
# the docker-facing libs (snapshot, diff_export), and every library the
# entrypoint names has to resolve from it. A lib added to the entrypoint's
# sources needs its line here, which is the hand-kept list M3.4.7's per-image
# inventory row owns.

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/time_format.sh"
