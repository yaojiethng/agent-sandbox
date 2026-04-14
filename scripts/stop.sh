#!/usr/bin/env bash
# scripts/stop.sh
#
# Stops all containers and removes project-scoped volumes for a given sandbox.
# Identifies containers by Docker Compose project label — does not invoke
# docker compose and does not require resolved compose environment variables.
#
# Usage:
#   stop.sh --name=<project_name> --sandbox=<path>
#
# The compose project name is derived from PROJECT_NAME using the same
# normalisation Docker Compose applies: lowercase, non-alphanumeric chars
# (except hyphens) replaced with hyphens.

set -euo pipefail

PROJECT_NAME=""
SANDBOX_DIR=""

for ARG in "$@"; do
  case "$ARG" in
    --name=*)    PROJECT_NAME="${ARG#--name=}" ;;
    --sandbox=*) SANDBOX_DIR="${ARG#--sandbox=}" ;;
    *)
      echo "Unknown flag: $ARG" >&2
      echo "Usage: stop.sh --name=<project_name> --sandbox=<path>" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
  echo "Error: --name and --sandbox are required" >&2
  echo "Usage: stop.sh --name=<project_name> --sandbox=<path>" >&2
  exit 1
fi

# Derive compose project name from PROJECT_NAME.
# Docker Compose normalisation: lowercase; chars outside [a-z0-9-] → hyphen.
COMPOSE_PROJECT="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
COMPOSE_PROJECT="${COMPOSE_PROJECT//[^a-z0-9-]/-}"

CONTAINER_IDS=$(docker ps -aq --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}")

if [[ -z "$CONTAINER_IDS" ]]; then
  echo "No containers found for project: ${COMPOSE_PROJECT}"
  exit 0
fi

echo "Stopping containers for project: ${COMPOSE_PROJECT}"
# Word splitting is intentional — CONTAINER_IDS is a newline-separated id list.
# shellcheck disable=SC2086
docker stop $CONTAINER_IDS
# shellcheck disable=SC2086
docker rm   $CONTAINER_IDS

# Remove project-scoped anonymous volumes.
VOLUME_IDS=$(docker volume ls -q --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}")
if [[ -n "$VOLUME_IDS" ]]; then
  echo "Removing volumes for project: ${COMPOSE_PROJECT}"
  # shellcheck disable=SC2086
  docker volume rm $VOLUME_IDS
fi

echo "Done."