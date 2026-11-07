#!/usr/bin/env bash
# tests/test_build_rebuild.sh  --  the --rebuild flag reaches every tier.
#
# `--rebuild` is the operator's "from scratch" switch. The build has three
# tiers, and a flag that stops after tier 2 leaves the provider image cached,
# so the operator's rebuild does not rebuild the image the session runs. This
# is the static wiring the probe's old `no-cache` row was replaced by: the flag
# is checked where the calls are made, not by grepping a Dockerfile.
#
# Run:
#   bash tests/test_build_rebuild.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# build.sh is dual-use: sourcing defines its functions and runs no main.
source "$REPO_ROOT/scripts/build.sh"

# Every tier's build_image call, as `<image>|<no_cache>`. The real build_image
# is replaced so no docker runs; the argument position is the one build_agent
# passes it in.
CALLS=()
build_image() {
  CALLS+=("$1|${5:-}")
}

# Given: build_agent runs with --no-cache
# When:  the three tiers are invoked
# Then:  every tier's build_image call carries --no-cache
test_rebuild_reaches_all_three_tiers() {
  CALLS=()
  build_agent pi probe "$REPO_ROOT" --no-cache >/dev/null 2>&1
  assert_eq "${#CALLS[@]}" "3" "build_agent invokes three tiers"
  assert_eq "${CALLS[0]}" "agent-base|--no-cache" "tier 1 is built from scratch"
  assert_eq "${CALLS[1]}" "agent-runtimes|--no-cache" "tier 2 is built from scratch"
  assert_eq "${CALLS[2]}" "pi-agent-probe|--no-cache" "tier 3 is built from scratch"
}

# Given: build_agent runs without --no-cache
# When:  the three tiers are invoked
# Then:  no tier carries the flag, so docker's layer cache is the only reuse rule
test_the_default_build_passes_no_cache_to_no_tier() {
  CALLS=()
  build_agent pi probe "$REPO_ROOT" >/dev/null 2>&1
  assert_eq "${#CALLS[@]}" "3" "build_agent invokes three tiers"
  assert_eq "${CALLS[0]}" "agent-base|" "tier 1 is cached"
  assert_eq "${CALLS[1]}" "agent-runtimes|" "tier 2 is cached"
  assert_eq "${CALLS[2]}" "pi-agent-probe|" "tier 3 is cached"
}

echo "=== --rebuild propagation tests ==="
echo

run_test test_rebuild_reaches_all_three_tiers
run_test test_the_default_build_passes_no_cache_to_no_tier

test_done
