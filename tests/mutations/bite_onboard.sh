#!/usr/bin/env bash
# Bite sweep for scripts/onboard.sh. Each mutant runs against the FULL suite.
set -uo pipefail
cd /home/agentuser/sandbox || exit 1
cp scripts/onboard.sh /tmp/onboard.orig
trap 'cp /tmp/onboard.orig scripts/onboard.sh' EXIT

bite() {
  local id="$1" desc="$2" expr="$3"
  cp /tmp/onboard.orig scripts/onboard.sh
  sed -i "$expr" scripts/onboard.sh
  if cmp -s /tmp/onboard.orig scripts/onboard.sh; then
    printf '%s NO-OP     | %s (sed did not match)\n' "$id" "$desc"; return
  fi
  if [[ "${DRY:-}" == 1 ]]; then
    diff /tmp/onboard.orig scripts/onboard.sh | sed -n '2,7p' | cut -c1-100 | sed 's/^/       /'
    cp /tmp/onboard.orig scripts/onboard.sh; return
  fi
  local log="/tmp/bite_onboard_$id.log"
  if bash scripts/run_tests.sh > "$log" 2>&1; then
    printf '%s SURVIVED  | %s\n' "$id" "$desc"
  else
    printf '%s PROVEN    | %s\n     -> %s\n' "$id" "$desc" "$(grep -m4 -E '^FAIL |^  - ' "$log" | tr '\n' ' ' | sed 's/  */ /g')"
  fi
  cp /tmp/onboard.orig scripts/onboard.sh
}

bite O1  "template_version: the grep absorb is gone"              's@^  { grep -m1 .*$@  grep -m1 "^# agent-sandbox template version:" "$1"@'
bite O2  "_validate_onboard: the clobber guard never fires"        's|    if \[\[ -e "$SANDBOX_DIR/$F" \]\]; then|    if false; then|'
bite O3  "resolve_and_validate: the Windows-path check disabled"   's|  if \[\[ "$VAL" =~ ^\[A-Za-z\]:\[/\\\\\] \]\]; then|  if false; then|'
bite O4  "resolve_and_validate: the absolute-path check disabled"  's|  if \[\[ "$VAL" != /\* \]\]; then|  if false; then|'
bite O5  "refresh: no PROJECT_NAME migration for a pre-P1 .env"    's@  if grep -q .\^PROJECT_NAME=.*$@  if true; then@'
bite O7  "non-tty detection disabled (always interactive)"         's|  if \[\[ ! -t 0 \]\]; then|  if false; then|'
bite O8  "confirm_or_exit: a declined answer no longer cancels"    's|  if \[\[ -n "$REPLY" && "$REPLY" != \[Yy\] && "$REPLY" != \[Yy\]\[Ee\]\[Ss\] \]\]; then|  if false; then|'
bite O10 "--yes no longer forces non-interactive"                  's|  if \[\[ "$YES_FLAG" == true \]\]; then|  if false; then|'
bite O11 "refresh: PROJECT_DIR is not derived from .env"           's@^      PROJECT_DIR=\$(grep.*$@      PROJECT_DIR=""@'
bite O12 "provider .env.example stubs are never appended"          's|      cat "$PROVIDER_ENV" >> "$ENV_FILE"|      :|'
bite O13 "env.stub is not renamed to .env"                          's|        mv "$PROVIDER_SANDBOX_DIR/env.stub" "$PROVIDER_SANDBOX_DIR/.env"|        :|'
bite O14 "the provider setup hook never runs"                       's|      if ! source "$PROVIDER_SETUP"; then|      if false; then|'
bite O15 "rsync drops the file mode contract (Fo=)"                 's|--chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=r|--chmod=Du=rwx,Dg=rwx,Do=rx,Fu=rw,Fg=rw,Fo=|'
bite O18 "_write_env_file: MAKEFILE_VERSION is not written"         's|^MAKEFILE_VERSION=\${VERSION}$|MAKEFILE_VERSION_REMOVED=${VERSION}|'

cp /tmp/onboard.orig scripts/onboard.sh
cmp -s /tmp/onboard.orig scripts/onboard.sh && echo "restored: pristine"
