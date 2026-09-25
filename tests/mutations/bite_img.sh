#!/usr/bin/env bash
# Throwaway bite harness for src/build/image.sh (5 functions, 8 units).
cd /home/agentuser/sandbox || exit 1
SRC=src/build/image.sh
run_bite() {  # $1=label  $2=sed-expr
  cp /tmp/img.orig "$SRC"
  sed -i "$2" "$SRC"
  if cmp -s /tmp/img.orig "$SRC"; then echo "$1: NO-OP (sed did not match)"; return; fi
  local n_out o_out
  n_out=$(bash tests/test_image_names.sh 2>&1 | grep -E '^UNIT:' | tail -1)
  o_out=$(bash tests/test_image.sh 2>&1 | grep -E '^UNIT:' | tail -1)
  local verdict="SURVIVED"
  [[ "$n_out" == *"fail=0"* && "$o_out" == *"fail=0"* ]] || verdict="PROVEN"
  printf '%-4s %-9s names[%s] digest[%s]\n' "$1" "$verdict" "$n_out" "$o_out"
  cp /tmp/img.orig "$SRC"
}
run_bite V1 's|echo "$(echo "$provider" | tr .*|echo "${provider}-base"|'
run_bite V2 's|local provider="${1:?agent_base_image_name requires provider}"|local provider="${1:-}"|'
run_bite V3 's|echo "${provider}-agent-$(echo "$project" | tr .*|echo "${provider,,}-agent-$(echo "$project" | tr "[:upper:]" "[:lower:]")"|'
run_bite V4 's|echo "sandbox-$(echo "$project" | tr .*|echo "sandbox-${project}"|'
run_bite V5 's|echo "agent-node-base"|echo "agent-base"|'
run_bite V6 "s|{{.Id}}|{{index .RepoDigests 0}}|"
run_bite V7 "s|inspect --format '{{.Id}}' \"\$image_name\" 2>/dev/null|inspect --format '{{.Id}}' \"\$image_name\"|"
run_bite V8 's|local image_name="${1:?image_digest requires an image name}"|local image_name="${1:-}"|'
run_bite V9 's|local project="${2:?agent_image_name requires project name}"|local project="${2:-}"|'
cp /tmp/img.orig "$SRC"; cmp -s /tmp/img.orig "$SRC" && echo "restored: source identical to backup"
