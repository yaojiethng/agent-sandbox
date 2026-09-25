#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
SRC=src/build/image.sh
run_bite() {
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
run_bite V1 's@echo "$(echo "$provider" | tr .*@echo "${provider}-base"@'
run_bite V3 's@-agent-$(echo "$project"@-agent-$(echo "$project"@; s@echo "${provider}@echo "${provider,,}@'
run_bite V4 's@echo "sandbox-$(echo "$project" | tr .*@echo "sandbox-${project}"@'
cp /tmp/img.orig "$SRC"; cmp -s /tmp/img.orig "$SRC" && echo "restored ok"
