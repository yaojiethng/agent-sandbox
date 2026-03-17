#!/usr/bin/env bash
# libs/dirs.sh — Directory name defaults for the agent-sandbox harness.
#
# Defines the default names for all harness-managed directories. Both the
# capability layer and reasoning layer entrypoints source this file so that
# directory names have a single source of truth.
#
# All values are overridable via environment variables — set them in the
# compose .env file or via docker run -e to change them without rebuilding
# the image.
#
# Usage:
#   source /libs/dirs.sh
#   # Then use $AGENT_INPUT_DIR_NAME, $SANDBOX_DIR_NAME, etc.

# Input channel: snapshot, brief, operator-placed task files.
# Bind-mounted read-only into the reasoning layer container from SANDBOX_DIR.
AGENT_INPUT_DIR_NAME="${AGENT_INPUT_DIR_NAME:-.agent-input}"

# Snapshot subdirectory within the input channel.
# Bind-mounted read-only into the capability layer container from SANDBOX_DIR.
SNAPSHOT_DIR_NAME="${SNAPSHOT_DIR_NAME:-.snapshot}"

# Working content directory: owned by the capability layer container.
# Exposed to the reasoning layer via --volumes-from, not a named volume.
# Lifecycle is tied to the capability layer container — if it is not
# running, the reasoning layer cannot attach to this directory.
SANDBOX_DIR_NAME="${SANDBOX_DIR_NAME:-sandbox}"

# Output channel: diff, logs. Bind-mounted read-write into the reasoning layer
# container from SANDBOX_DIR.
WORKSPACE_DIR_NAME="${WORKSPACE_DIR_NAME:-.workspace}"
