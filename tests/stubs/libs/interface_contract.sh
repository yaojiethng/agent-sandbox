#!/usr/bin/env bash
# tests/stubs/libs/interface_contract.sh
# Test stand-in for src/libs/interface_contract.sh. The real library declares
# the contract version and reads it from an image label; only the declaration
# matters to the entrypoints and probes, so the stub sources the real file to
# keep one source of truth for the version.
#
# The file exists so the entrypoint preflight sees the library it marks
# CRITICAL, which mirrors the image layout where the whole src/libs/ tree ships
# together.

# shellcheck source=/dev/null
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/src/libs/interface_contract.sh"
