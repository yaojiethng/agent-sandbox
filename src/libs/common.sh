#!/usr/bin/env bash
# libs/common.sh
# Shared flag parsing and validation for agent-sandbox scripts.
# Sourced by scripts that need --name and --sandbox (stop.sh, prune.sh, etc.).
#
# Pure flag-parsing library: it parses flags and does NOT set caller-owned
# path variables (SCRIPT_DIR, REPO_ROOT, etc.). Callers derive their own
# paths self-referentially from BASH_SOURCE[0] and define their own usage().
#
# Sets in caller's scope:
#   PROJECT_NAME — parsed from --name flag
#   SANDBOX_DIR  — parsed from --sandbox flag
#
# Provides:
#   parse_base_flags()   — parse --name and --sandbox from "$@"
#   check_base_flags()   — validate PROJECT_NAME and SANDBOX_DIR are set
#   parse_help_flag()    — check for --help/-h, print usage and exit
#
# Scripts should define their own usage() before sourcing this file.

parse_help_flag() {
  for _arg in "$@"; do
    case "$_arg" in
      --help|-h) usage; exit 0 ;;
    esac
  done
}

parse_base_flags() {
  PROJECT_NAME=""
  SANDBOX_DIR=""
  for _arg in "$@"; do
    case "$_arg" in
      --name=*)    PROJECT_NAME="${_arg#--name=}" ;;
      --sandbox=*) SANDBOX_DIR="${_arg#--sandbox=}" ;;
    esac
  done
}

check_base_flags() {
  if [[ -z "$PROJECT_NAME" || -z "$SANDBOX_DIR" ]]; then
    echo "Error: --name and --sandbox are required" >&2
    usage >&2
    exit 1
  fi
  if [[ -z "$SANDBOX_DIR" || "$SANDBOX_DIR" == "/" ]]; then
    echo "Error: invalid SANDBOX_DIR: $SANDBOX_DIR" >&2
    exit 1
  fi
}
