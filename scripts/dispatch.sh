#!/usr/bin/env bash
# scripts/dispatch.sh
#
# The runner-seam entry point. Prints the command that runs one subagent for a
# named role, resolving the role to a model and the backend that reaches it.
# `--run` executes the command in place instead of printing it.
#
# Usage:
#   dispatch.sh --role _IMPLEMENTER --brief <file> --dir <dir> \
#               [--model <provider>/<model>] [--thinking <level>] \
#               [--session <id>] [--run]
#
# A brief names a role, not a runtime: the seam reads the role table at
# $AGENT_HOME/model-recommendations.md and chooses pi or the OpenCode CLI.
#
# Separation follows the repo convention: this script is control flow, and
# libs/dispatch.sh holds the reusable builder.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/src/libs/dispatch.sh"

ROLE=""
BRIEF=""
DIR="$(pwd)"
MODEL=""
THINKING=""
SESSION=""
RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="${2:-}"; shift 2 ;;
    --brief) BRIEF="${2:-}"; shift 2 ;;
    --dir) DIR="${2:-}"; shift 2 ;;
    --model) MODEL="${2:-}"; shift 2 ;;
    --thinking) THINKING="${2:-}"; shift 2 ;;
    --session) SESSION="${2:-}"; shift 2 ;;
    --run) RUN=1; shift ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "dispatch: unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$ROLE" || -z "$BRIEF" ]]; then
  echo "dispatch: --role and --brief are required" >&2
  exit 2
fi

CMD="$(dispatch_command "$ROLE" "$BRIEF" "$DIR" "$MODEL" "$THINKING" "$SESSION")"

if (( RUN )); then
  bash -c "$CMD"
else
  printf '%s\n' "$CMD"
fi
