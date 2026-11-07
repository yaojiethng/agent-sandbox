#!/usr/bin/env bash
# tests/test_build_probe.sh  --  the host build recorder's parsing and schema.
#
# The recorder runs on the host, where no test here can reach it. What is
# covered is the part that reads the builder's log and the part that emits the
# report: the per-tier state and seconds, the tier mapping, the JSON escaping,
# and the report object the operator reads back.
#
# The recorder's own host run is the integration test, and it is the one thing
# the agent's container cannot perform.
#
# Run:
#   bash tests/test_build_probe.sh

# shellcheck disable=SC2034  # the report globals are read by emit_report in scripts/build_probe.sh
set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# The probe is dual-use: sourcing defines its helpers and runs no main.
source "$REPO_ROOT/scripts/build_probe.sh"

# The names the probe derives inside main; a sourcing test sets them here.
SHARED_BASE="agent-base"
AGENT_BASE="agent-runtimes"
AGENT_IMAGE="pi-agent-probe"

write_log() {
  cat > "$FIXTURE_DIR/build.log"
}

# Given: one tier that ran a step and one whose every step was a cache hit
# When:  the per-tier records are read
# Then:  each tier is reported once, in log order, with its own state and seconds
# Asserts: a cache hit on every step reads as cached, and the DONE lines of the
#          internal load and the closing export step decide no state but do
#          count toward the tier's seconds
test_tier_records_reads_each_tier_on_its_own_steps() {
  write_log <<'EOF'
Building image: agent-base
#1 [internal] load build definition from base.dockerfile
#1 DONE 0.0s
#3 [1/2] FROM docker.io/library/node:22
#3 CACHED
#4 [2/2] RUN apt-get update
#4 DONE 3.2s
#5 exporting to image
#5 DONE 0.2s
Building image: agent-runtimes
#1 [internal] load build definition from runtimes.dockerfile
#1 DONE 0.0s
#3 [1/2] FROM agent-base
#3 CACHED
#4 [2/2] RUN npm install -g pi
#4 CACHED
#5 exporting to image
#5 DONE 0.0s
EOF
  assert_eq "$(tier_records "$FIXTURE_DIR/build.log" | paste -sd, -)" \
    "agent-base|ran|3.4,agent-runtimes|cached|0.0" \
    "each tier carries its own state and its own summed step seconds"
}

# Given: a log whose every tier printed only CACHED step lines
# When:  each tier's state is read
# Then:  every tier is cached, which is not the same as reporting none
# Asserts: a fully cached build is observed rather than read as an absent tier
test_a_fully_cached_build_reports_every_tier_cached() {
  write_log <<'EOF'
Building image: agent-base
#3 [1/2] FROM docker.io/library/node:22
#3 CACHED
#4 [2/2] RUN apt-get update
#4 CACHED
Building image: agent-runtimes
#3 [1/2] FROM agent-base
#3 CACHED
#4 [2/2] RUN npm install -g pi
#4 CACHED
Building image: pi-agent-probe
#3 [1/1] COPY config /opt
#3 CACHED
EOF
  assert_eq "$(tier_cache_state "$FIXTURE_DIR/build.log" agent-base)" "cached" \
    "the shared base of a fully cached build is cached"
  assert_eq "$(tier_cache_state "$FIXTURE_DIR/build.log" agent-runtimes)" "cached" \
    "the runtime tier of a fully cached build is cached"
  assert_eq "$(tier_cache_state "$FIXTURE_DIR/build.log" pi-agent-probe)" "cached" \
    "the provider image of a fully cached build is cached"
}

# Given: a log that carries no segment for a tier
# When:  that tier's state is read
# Then:  it is unobserved, not cached and not ran
test_a_tier_with_no_segment_is_unobserved() {
  write_log <<'EOF'
Building image: agent-base
#4 [1/1] RUN true
#4 DONE 1.0s
EOF
  assert_eq "$(tier_cache_state "$FIXTURE_DIR/build.log" pi-agent-probe)" "unobserved" \
    "a tier with no segment is unobserved"
  assert_eq "$(tier_step_seconds "$FIXTURE_DIR/build.log" pi-agent-probe)" "0.0" \
    "an unobserved tier has no step seconds"
}

# Given: the three tier image names, and one from another layer
# When:  each is mapped to its tier
# Then:  the tier letters are the ones the report writes
test_tier_of_maps_each_image_to_its_tier() {
  assert_eq "$(tier_of "$SHARED_BASE")" "1" "the shared base is tier 1"
  assert_eq "$(tier_of "$AGENT_BASE")" "2" "the runtime tier is tier 2"
  assert_eq "$(tier_of "$AGENT_IMAGE")" "3" "the provider image is tier 3"
  assert_eq "$(tier_of "sandbox-myproject")" "?" "an image outside the three tiers has no tier"
}

# Given: text carrying the characters JSON reserves
# When:  it is emitted as a JSON string
# Then:  the escaping is what a parser reads back as the original text
test_json_string_escapes_the_metacharacters() {
  assert_eq "$(json_string 'plain')" '"plain"' "a plain string is quoted"
  assert_eq "$(json_string 'a"b')" '"a\"b"' "a quote is escaped"
  assert_eq "$(json_string 'a\b')" '"a\\b"' "a backslash is escaped"
  assert_eq "$(json_string $'a\nb')" '"a\nb"' "a newline becomes an escape"
  assert_eq "$(json_string $'a\tb')" '"a\tb"' "a tab becomes an escape"
}

# Given: one item and two
# When:  they are joined
# Then:  the separator sits between items only, so no object ends on a comma
test_join_commas_leaves_no_trailing_separator() {
  assert_eq "$(join_commas a)" "a" "one item has no separator"
  assert_eq "$(join_commas a b)" "a, b" "two items join once"
}

# Given: a tier's values
# When:  its JSON object is emitted
# Then:  it carries the name, the tier, the image id, the size, the cache state
#        and the step seconds
test_tier_json_carries_the_six_fields() {
  assert_eq "$(tier_json agent-base 1 'sha256:abc' 123 cached 0.0)" \
    '{"name": "agent-base", "tier": 1, "id": "sha256:abc", "size_bytes": 123, "cache_state": "cached", "step_seconds": 0.0}' \
    "the tier object carries every field the page names"
}

# Given: the report globals and one tier object
# When:  the report is emitted
# Then:  it parses as JSON and carries the four questions' signals
test_emit_report_carries_the_run_signals() {
  REPO_ROOT="$FIXTURE_DIR"
  PROBE_STAMP="20261107T000000Z"
  PROBE_LABEL="baseline"
  PROBE_PROVIDER="pi"
  PROBE_PROJECT="probe"
  REBUILD=false
  PROBE_RUN_STATUS=0
  PROBE_WALL_SECONDS=42
  PROBE_ERROR=""
  PROBE_LOG="$FIXTURE_DIR/build.log"
  PROBE_REPO_DIRTY=false
  git_head() { printf '%s\n' "test-head"; }
  host_uname() { printf '%s\n' "Linux test"; }
  docker_version() { printf '%s\n' "Docker test"; }
  reasoning_dockerfiles() { printf '%s\n' "$FIXTURE_DIR/probe.sh"; }
  printf '#!/usr/bin/env bash\n' > "$FIXTURE_DIR/probe.sh"

  emit_report "$FIXTURE_DIR/report.json" "$(tier_json agent-base 1 'sha256:abc' 123 cached 0.0)"

  node -e '
    const fs = require("fs");
    const r = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const fail = (m) => { throw new Error(m); };
    if (r.probe !== "build_probe") fail("probe");
    if (r.format !== 2) fail("format");
    if (r.repo.head !== "test-head" || r.repo.dirty !== false) fail("repo");
    if (r.run.exit_status !== 0 || r.run.wall_seconds !== 42) fail("run");
    if (!Array.isArray(r.dockerfiles) || r.dockerfiles.length !== 1) fail("dockerfiles");
    if (!Array.isArray(r.tiers) || r.tiers.length !== 1) fail("tiers");
    const t = r.tiers[0];
    if (t.name !== "agent-base" || t.tier !== 1 || t.size_bytes !== 123 ||
        t.cache_state !== "cached" || t.step_seconds !== 0) fail("tier");
  ' "$FIXTURE_DIR/report.json"
  assert_eq "$?" "0" "the report parses and carries the run's signals"
}

# Given: a real cached build's log, where the FROM resolve prints DONE because
#        the base image is already local and only the RUN steps print CACHED
# When:  the tier's state is read
# Then:  it is cached, because no step that changes the filesystem ran
# Asserts: the FROM step's DONE does not read as a rebuild
test_a_cached_build_with_a_from_done_reads_as_cached() {
  write_log <<'EOF'
Building image: agent-base
#1 [internal] load build definition from base.dockerfile
#1 transferring dockerfile: 1.96kB done
#1 DONE 0.0s
#2 [internal] load metadata for docker.io/library/node:22
#2 DONE 1.6s
#4 [1/6] FROM docker.io/library/node:22@sha256:e21f
#4 resolve docker.io/library/node:22@sha256:e21f 0.0s done
#4 DONE 0.0s
#5 [2/6] RUN apt-get update
#5 CACHED
#6 [3/6] RUN curl -LsSf https://astral.sh/uv/install.sh | sh
#6 CACHED
#10 exporting to image
#10 DONE 0.1s
EOF
  assert_eq "$(tier_cache_state "$FIXTURE_DIR/build.log" agent-base)" "cached" \
    "a cached build whose FROM step prints DONE reads as cached"
}

# Given: the same shape with one filesystem step that ran
# When:  the tier's state is read
# Then:  it is ran, so the FROM step's DONE is not what decides it either way
# Asserts: the positive check's pair, so the rule is not "always cached"
test_one_ran_step_reads_as_ran() {
  write_log <<'EOF'
Building image: agent-base
#4 [1/6] FROM docker.io/library/node:22@sha256:e21f
#4 DONE 0.0s
#5 [2/6] RUN apt-get update
#5 CACHED
#6 [3/6] RUN rm -rf /var/lib/apt/lists/*
#6 DONE 2.4s
EOF
  assert_eq "$(tier_cache_state "$FIXTURE_DIR/build.log" agent-base)" "ran" \
    "one filesystem step that ran reads as ran"
}

run_test test_tier_records_reads_each_tier_on_its_own_steps
run_test test_a_cached_build_with_a_from_done_reads_as_cached
run_test test_one_ran_step_reads_as_ran
run_test test_a_fully_cached_build_reports_every_tier_cached
run_test test_a_tier_with_no_segment_is_unobserved
run_test test_tier_of_maps_each_image_to_its_tier
run_test test_json_string_escapes_the_metacharacters
run_test test_join_commas_leaves_no_trailing_separator
run_test test_tier_json_carries_the_six_fields
# Given: the probe as a program, with docker stubbed
# When:  it is invoked the way the operator invokes it
# Then:  it reaches the build, writes one report and prints its verdict
# Asserts: the program's wiring, which is where a name the functions never
#          define shows up -- the unit tests call the functions directly
test_probe_runs_end_to_end_and_writes_a_report() {
  local dir="$FIXTURE_DIR/e2e"
  mkdir -p "$dir"
  local rc=0
  (
    export PATH="$REPO_ROOT/tests/stubs:$PATH"
    export DOCKER_TRACE_LOG="$dir/trace.log"
    bash "$REPO_ROOT/scripts/build_probe.sh" --label=e2e --input-dir="$dir"
  ) > "$dir/out.txt" 2>&1 || rc=$?

  assert_rc 0 "$rc" "the probe runs end to end"
  assert_contains "$(cat "$dir/out.txt")" "VERDICT: recorded" "the probe prints its verdict"

  local report
  report="$(find "$dir/build" -name '*.json' -type f 2>/dev/null | head -1)"
  if [[ -z "$report" ]]; then
    fail "the probe wrote no report"
    return
  fi
  pass "the probe wrote one report"

  node -e '
    const fs = require("fs");
    const r = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    const fail = (m) => { console.error(m); process.exit(1); };
    if (r.format !== 2) fail("format");
    if (r.label !== "e2e") fail("label");
    if (r.run.exit_status !== 0) fail("exit_status");
    if (r.run.no_cache !== false) fail("no_cache");
    if (!Array.isArray(r.tiers) || r.tiers.length !== 3) fail("tiers");
  ' "$report" && pass "the report carries the run's signals" || fail "the report is missing a signal"
}

run_test test_emit_report_carries_the_run_signals
run_test test_probe_runs_end_to_end_and_writes_a_report

test_done
