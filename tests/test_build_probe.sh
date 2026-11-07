#!/usr/bin/env bash
# tests/test_build_probe.sh  --  the host build probe's verdict logic and its
# restore guarantee.
#
# The probe runs on the host, where no test here can reach it. What is covered
# is the part that decides the verdict and the part that edits the tree: the
# builder's progress-line parsing, the tier mapping, the JSON emitter, and the
# backup/restore pair that guarantees a perturbed Dockerfile is put back.
#
# The probe's own host run is the integration test, and it is the one thing the
# agent's container cannot perform.
#
# Run:
#   bash tests/test_build_probe.sh

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

# The probe is dual-use: sourcing defines its helpers and runs no main.
source "$REPO_ROOT/scripts/build_probe.sh"

# The names the probe derives inside main; a sourcing test sets them here.
SHARED_BASE="agent-base"
AGENT_BASE="pi-base"
AGENT_IMAGE="pi-agent-probe"

write_log() {
  cat > "$FIXTURE_DIR/build.log"
}

# Given: one tier that ran a step and one whose every step was a cache hit
# When:  the per-tier state is read
# Then:  each tier is reported once, in log order, with its own state
# Asserts: a cache hit on every step reads as cached, and the DONE lines of the
#          internal load and the closing export step decide nothing
test_tier_step_states_reads_each_tier_on_its_own_steps() {
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
Building image: pi-base
#1 [internal] load build definition from base.dockerfile
#1 DONE 0.0s
#3 [1/2] FROM agent-base
#3 CACHED
#4 [2/2] RUN npm install -g x
#4 CACHED
#5 exporting to image
#5 DONE 0.0s
EOF
  assert_eq "$(tier_step_states "$FIXTURE_DIR/build.log" | paste -sd, -)" \
    "agent-base ran,pi-base cached" \
    "the tier with a step that ran reads ran, the fully cached tier reads cached"
}

# Given: a log whose every tier printed only CACHED step lines and no DONE line
# When:  the per-tier state is read
# Then:  every tier is reported cached, which is not the same as reporting none
# Asserts: a fully cached build is observed rather than read as an absent tier
test_a_fully_cached_build_reports_every_tier_cached() {
  write_log <<'EOF'
Building image: agent-base
#1 [internal] load build definition from base.dockerfile
#3 [1/2] FROM docker.io/library/node:22
#3 CACHED
#4 [2/2] RUN apt-get update
#4 CACHED
Building image: pi-base
#1 [internal] load build definition from base.dockerfile
#3 [1/2] FROM agent-base
#3 CACHED
#4 [2/2] RUN npm install -g x
#4 CACHED
Building image: pi-agent-probe
#3 [1/1] COPY config /opt
#3 CACHED
EOF
  assert_eq "$(tiers_cached "$FIXTURE_DIR/build.log" | paste -sd, -)" \
    "agent-base,pi-agent-probe,pi-base" "every tier of a fully cached build reads cached"
  assert_eq "$(tiers_not_cached "$FIXTURE_DIR/build.log")" "" \
    "a fully cached build has no tier with a step that ran"
  assert_eq "$(tier_letters_not_cached "$FIXTURE_DIR/build.log")" "" \
    "a fully cached build observes the empty set"
}

# Given: plain-progress output with a step done line and unrelated lines
# When:  the steps are read
# Then:  only the DONE lines come back, and their durations are summable
test_log_steps_reads_progress_plain_done_lines() {
  write_log <<'EOF'
#1 [internal] load build definition from Dockerfile
#5 DONE 1.2s
#7 DONE 0.0s
Step 3/4 : RUN true
#9 DONE 4.1s
EOF
  assert_eq "$(log_steps "$FIXTURE_DIR/build.log" | paste -sd, -)" \
    "#5 DONE 1.2s,#7 DONE 0.0s,#9 DONE 4.1s" "log_steps takes the DONE lines and nothing else"
  assert_eq "$(log_steps "$FIXTURE_DIR/build.log" | awk '{s += $NF + 0} END {printf "%.1f", s}')" \
    "5.3" "the step durations sum"
}

# Given: a log whose three tiers all ran a step, plus an image outside them
# When:  the tiers that ran a step are read
# Then:  the three tiers come back sorted and unique, and nothing else does
test_tiers_not_cached_keeps_the_three_tiers_sorted_and_unique() {
  write_log <<'EOF'
Building image: pi-agent-probe
#4 [1/1] COPY config /opt
#4 DONE 0.1s
Building image: agent-base
#4 [1/1] RUN true
#4 DONE 1.0s
Building image: sandbox-myproject
#2 [1/1] RUN true
#2 DONE 0.2s
Building image: pi-base
#4 [1/1] RUN true
#4 DONE 0.3s
EOF
  assert_eq "$(tiers_not_cached "$FIXTURE_DIR/build.log" | paste -sd, -)" \
    "agent-base,pi-agent-probe,pi-base" \
    "tiers_not_cached keeps the three tiers, sorted, and drops the image outside them"
}

# Given: a log whose tiers are the three in a scrambled order
# When:  the observed set is built the way the probe builds it
# Then:  the letters are comma separated, not spliced into one number
# Asserts: the reported set is '1,2,3' rather than '132'
test_the_observed_set_is_comma_separated_letters() {
  write_log <<'EOF'
Building image: pi-agent-probe
#4 [1/1] COPY config /opt
#4 DONE 0.1s
Building image: agent-base
#4 [1/1] RUN true
#4 DONE 1.0s
Building image: pi-base
#4 [1/1] RUN true
#4 DONE 0.3s
EOF
  assert_eq "$(tier_letters_not_cached "$FIXTURE_DIR/build.log")" "1,2,3" \
    "the observed set is three comma-separated tier letters"
}

# Given: a log that opened no tier build at all
# When:  the observed set is built
# Then:  it is empty, which is what an unasserted row records
test_the_observed_set_is_empty_when_no_tier_is_observed() {
  write_log <<'EOF'
Building image: sandbox-myproject
#2 [1/1] RUN true
#2 DONE 0.2s
EOF
  assert_eq "$(tier_letters_not_cached "$FIXTURE_DIR/build.log")" "" \
    "a log with no tier step gives an empty observed set"
}

# Given: an expected-set column holding the empty-set marker and one holding a set
# When:  each is read
# Then:  the marker stands for the empty set and a set passes through unchanged
# Asserts: a row can assert that no tier ran a step, rather than record that fact
test_expected_tier_set_reads_the_none_marker() {
  assert_eq "$(expected_tier_set none)" "" "the marker stands for the empty set"
  assert_eq "$(expected_tier_set 1,2,3)" "1,2,3" "a set passes through unchanged"
  assert_eq "$(expected_tier_set '')" "" "an empty column stays empty"
}

# Given: the three tier image names, and one from another layer
# When:  each is mapped to its tier
# Then:  the tier letters are the ones the expected sets are written in
test_tier_of_maps_each_image_to_its_tier() {
  assert_eq "$(tier_of "$SHARED_BASE")" "1" "the shared base is tier 1"
  assert_eq "$(tier_of "$AGENT_BASE")" "2" "the provider base is tier 2"
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

# Given: no item, one item, and two
# When:  the array is emitted
# Then:  an empty set is an empty array, not an array holding an empty string
test_json_array_is_empty_without_items() {
  assert_eq "$(json_array)" "[]" "no items gives an empty array"
  assert_eq "$(json_array one)" '["one"]' "one item gives one literal"
  assert_eq "$(json_array one two)" '["one", "two"]' "two items give two literals"
}

# Given: one item and two
# When:  they are joined
# Then:  the separator sits between items only, so no object ends on a comma
test_join_commas_leaves_no_trailing_separator() {
  assert_eq "$(join_commas a)" "a" "one item has no separator"
  assert_eq "$(join_commas a b)" "a, b" "two items join once"
}

# Given: a file the probe has backed up and perturbed
# When:  the restore runs
# Then:  the original bytes are back and no restore is left pending
test_perturb_restore_puts_the_file_back() {
  local target="$FIXTURE_DIR/Dockerfile"
  # Read by the sourced probe's perturb_backup.
  # shellcheck disable=SC2034
  PROBE_RUN_DIR="$FIXTURE_DIR"
  printf 'FROM scratch\n' > "$target"
  perturb_backup "$target"
  printf '# build_probe perturbation\n' >> "$target"
  assert_ne "$(cat "$target")" "FROM scratch" "the perturbation changed the file"
  assert_not_empty "$PERTURBED_FILE" "the backup left a restore pending"
  perturb_restore
  assert_eq "$(cat "$target")" "FROM scratch" "the restore returned the original content"
  assert_empty "$PERTURBED_FILE" "the restore cleared the pending file"
}

# Given: the perturbation matrix
# When:  each row is read
# Then:  every asserted row carries the expected set its verdict compares
#        against, and the baseline row is the one that records rather than asserts
test_the_matrix_asserts_every_row_except_the_baseline() {
  assert_eq "${#ROWS[@]}" "5" "the matrix has five rows"
  local row name kind trigger expect
  for row in "${ROWS[@]}"; do
    IFS='|' read -r name _ kind trigger expect <<<"$row"
    assert_not_empty "$name" "row names itself"
    assert_not_empty "$kind" "row names its perturbation"
    assert_not_empty "$trigger" "row describes its trigger"
    case "$name" in
      baseline) assert_empty "$expect" "the baseline row records rather than asserts" ;;
      mtime|restore) assert_eq "$expect" "none" \
        "the $name row asserts that every tier is served from the layer cache" ;;
      *) assert_not_empty "$expect" "the $name row carries an expected set" ;;
    esac
  done
}

# The matrix's order is load-bearing: the baseline normalizes the cache, and the
# restore row depends on the content row having perturbed it.
# Given: the matrix
# When:  the row names are read in order
# Then:  the perturbing rows come after the baseline and before the restore
test_the_matrix_order_puts_restore_after_the_perturbation() {
  local row name order=""
  for row in "${ROWS[@]}"; do
    IFS='|' read -r name _ <<<"$row"
    order+="$name "
  done
  assert_eq "$order" "baseline mtime content restore no-cache " \
    "the matrix normalizes, perturbs, restores and then rebuilds cold"
}

run_test test_tier_step_states_reads_each_tier_on_its_own_steps
run_test test_a_fully_cached_build_reports_every_tier_cached
run_test test_log_steps_reads_progress_plain_done_lines
run_test test_tiers_not_cached_keeps_the_three_tiers_sorted_and_unique
run_test test_the_observed_set_is_comma_separated_letters
run_test test_the_observed_set_is_empty_when_no_tier_is_observed
run_test test_expected_tier_set_reads_the_none_marker
run_test test_tier_of_maps_each_image_to_its_tier
run_test test_json_string_escapes_the_metacharacters
run_test test_json_array_is_empty_without_items
run_test test_join_commas_leaves_no_trailing_separator
run_test test_perturb_restore_puts_the_file_back
run_test test_the_matrix_asserts_every_row_except_the_baseline
run_test test_the_matrix_order_puts_restore_after_the_perturbation

test_done
