#!/usr/bin/env bash
# tests/stubs/libs/session_state.sh
# Test stand-in for src/libs/session_state.sh. The real library is file I/O over
# SESSION_STATE plus the container contract check, with no docker dependency, so
# the stub sources it rather than forking it: tests drive outcomes purely by what
# they write into the SESSION_STATE file, and the reader under test is the
# shipped one. Keeping a copy here let the stub and the library drift (the stub
# carried the missing-file guard the library once lacked).

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/session_state.sh"
