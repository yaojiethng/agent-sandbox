#!/usr/bin/env bash
# scripts/check_commit_message.sh
# Validates a delivery commit message in two layers: the Conventional Commits
# 1.0.0 grammar, then this project's policy -- the active type set from
# `workflow/coding-agent/skills/git-discipline/references/commit-types.md`, no scope field,
# a subject 72 characters at most, and a body 280 characters at most.
#
# Usage: check_commit_message.sh [--root=DIR] <message-file>
#
# Exit 0 when the message conforms, 1 when it does not, 2 on a usage error.
# Every violation is printed with the layer that owns it, so a reader knows
# whether the world's grammar or this project's policy refused it.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
files=()
for arg in "$@"; do
  case "$arg" in
    --root=*) ROOT="${arg#--root=}" ;;
    -h|--help) sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) files+=("$arg") ;;
  esac
done

if [ ${#files[@]} -ne 1 ]; then
  echo "usage: $(basename "$0") [--root=DIR] <message-file>" >&2
  exit 2
fi

FILE="${files[0]}"
TYPES="$ROOT/workflow/coding-agent/skills/git-discipline/references/commit-types.md"

if [ ! -f "$FILE" ]; then
  echo "error: no such message file: $FILE" >&2
  exit 2
fi
if [ ! -f "$TYPES" ]; then
  echo "error: no commit-types reference at $TYPES" >&2
  exit 2
fi

# The active set is the rows of the first table under `## The active types`.
mapfile -t ACTIVE < <(
  awk -F'|' '
    /^## The active types/ { on = 1; next }
    on && /^## /          { exit }
    on && $2 ~ /`[a-z]+`/ { gsub(/[ `]/, "", $2); print $2 }
  ' "$TYPES"
)
active_list="$(printf '%s, ' "${ACTIVE[@]}")"; active_list="${active_list%, }"
if [ ${#ACTIVE[@]} -eq 0 ]; then
  echo "error: no active types parsed from $TYPES" >&2
  exit 2
fi

errors=()

subject="$(head -n 1 "$FILE")"
rest="$(tail -n +2 "$FILE")"

grammar='^([a-z]+)(\([^)]*\))?(!)?: (.+)$'
if [[ ! "$subject" =~ $grammar ]]; then
  errors+=("grammar: the subject must read 'type[(scope)][!]: description'")
else
  type="${BASH_REMATCH[1]}"
  scope="${BASH_REMATCH[2]}"

  active=0
  for candidate in "${ACTIVE[@]}"; do
    [ "$candidate" = "$type" ] && active=1 && break
  done
  [ "$active" -eq 1 ] || errors+=("policy: the type '$type' is not an active type (${active_list})")

  [ -z "$scope" ] || errors+=("policy: the project does not use a scope field")

fi
[ "${#subject}" -le 72 ] || errors+=("policy: the subject is ${#subject} characters; 72 at most")

body=""
if [ -n "$rest" ]; then
  first_rest="${rest%%$'\n'*}"
  if [ -n "$first_rest" ]; then
    errors+=("grammar: a blank line must separate the subject and the body")
    body="$rest"
  else
    body="${rest#$'\n'}"
  fi
  [ "${#body}" -le 280 ] || errors+=("policy: the body is ${#body} characters; 280 at most")
fi

if [ ${#errors[@]} -gt 0 ]; then
  printf '%s\n' "${errors[@]}" >&2
  exit 1
fi
exit 0
