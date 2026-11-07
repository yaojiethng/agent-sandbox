#!/usr/bin/env bash
# tests/test_pins.sh
# The build-input pin gate: every input carries a pin at its class's strictest
# form, the pin and the Dockerfile literal agree, registry packages install
# frozen from committed lockfiles, and the preflight warns where the gate blocks.
#
# Pins cite: docs/adr/build_input_pinning.md, docs/development/build_operational_model.md.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_pins.sh"

# setup_fixture NAME -- a root carrying the files the check reads, copied from
# the tree so the fixture cannot drift from the shape it is checking.
setup_fixture() {
  local name="$1"
  local root="$FIXTURE_DIR/$name"
  rm -rf "$root"
  mkdir -p "$root/src/build" "$root/src/reasoning/registry"
  cp "$REPO_ROOT/src/build/pins.json" "$root/src/build/pins.json"
  cp "$REPO_ROOT/src/build/pins.mjs" "$root/src/build/pins.mjs"
  cp "$REPO_ROOT/src/reasoning/base.dockerfile" "$root/src/reasoning/base.dockerfile"
  cp "$REPO_ROOT/src/reasoning/runtimes.dockerfile" "$root/src/reasoning/runtimes.dockerfile"
  cp -R "$REPO_ROOT/src/reasoning/registry/." "$root/src/reasoning/registry/"
  printf '%s\n' "$root"
}

run_gate() {
  local root="$1"
  GATE_RC=0
  GATE_OUT="$(PINS_SCAN_ROOT="$root" bash "$GATE" 2>&1)" || GATE_RC=$?
}

# Given: the tree as it stands
# When:  the pin gate runs
# Then:  it is clean and names what it holds
# Asserts: every build input carries a pin the Dockerfile agrees with
test_the_tree_is_pinned() {
  run_gate "$REPO_ROOT"
  assert_rc 0 "$GATE_RC" 'the tree is pinned'
  assert_contains "$GATE_OUT" "every build input carries its class's strictest pin" 'the gate names its subject'
}

# Given: the report mode
# When:  the gate runs with --report
# Then:  it prints one row per input, the eight apt packages included
# Asserts: the pins file covers the tree's inputs rather than a subset
test_the_report_covers_every_input() {
  GATE_RC=0
  GATE_OUT="$(PINS_SCAN_ROOT="$REPO_ROOT" bash "$GATE" --report 2>&1)" || GATE_RC=$?
  assert_rc 0 "$GATE_RC" 'the report runs'
  assert_contains "$GATE_OUT" "apt:shellcheck" 'an apt package is reported'
  assert_contains "$GATE_OUT" "npm:pi" 'a registry package is reported'
  assert_contains "$GATE_OUT" "opencode" 'the pinned binary is reported'
  assert_contains "$GATE_OUT" "base-image" 'the base image is reported'
  local rows
  rows="$(printf '%s\n' "$GATE_OUT" | grep -c -E '^(base-image|apt:|hadolint|uv|opencode|python|npm:)')"
  assert_eq "$rows" "15" 'the report carries one row per input'
}

# Given: a Dockerfile whose apt version the pins file does not record
# When:  the gate runs
# Then:  it fails and names the input
# Asserts: the Dockerfile literal and the recorded artifact are compared
test_a_moved_dockerfile_version_fails() {
  local root; root="$(setup_fixture moved)"
  sed -i 's/curl=7\.88\.1-10+deb12u15/curl=7.88.1-10+deb12u99/' "$root/src/reasoning/base.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a Dockerfile version the pins file does not record fails'
  assert_contains "$GATE_OUT" "apt:curl" 'the drifting input is named'
}

# Given: an apt line with no version at all
# When:  the gate runs
# Then:  it fails, because the pin has nothing to bind to
# Asserts: an unpinned install is a finding rather than a pass
test_an_unversioned_apt_line_fails() {
  local root; root="$(setup_fixture unversioned)"
  sed -i -E 's/^        jq=.*$/        jq \\/' "$root/src/reasoning/base.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an apt package with no version fails'
  assert_contains "$GATE_OUT" "apt:jq" 'the unpinned package is named'
}

# Given: a pins file with a row removed
# When:  the gate runs
# Then:  it fails and names the input that has no pin
# Asserts: an input with no pin row is a finding
test_a_missing_pin_row_fails() {
  local root; root="$(setup_fixture norow)"
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const pins = JSON.parse(fs.readFileSync(path, "utf8"));
    pins.pins = pins.pins.filter((row) => row.input !== "hadolint");
    fs.writeFileSync(path, JSON.stringify(pins, null, 2));
  ' "$root/src/build/pins.json"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an input with no pin row fails'
  assert_contains "$GATE_OUT" "hadolint: no pin row" 'the input with no pin is named'
}

# Given: a pin row with no way to move it
# When:  the gate runs
# Then:  it fails, because a pin that never moves freezes its own vulnerabilities
# Asserts: the movement requirement is enforced rather than documented
test_a_pin_with_no_move_fails() {
  local root; root="$(setup_fixture nomove)"
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const pins = JSON.parse(fs.readFileSync(path, "utf8"));
    delete pins.pins.find((row) => row.input === "uv").move;
    fs.writeFileSync(path, JSON.stringify(pins, null, 2));
  ' "$root/src/build/pins.json"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a pin row with no movement path fails'
  assert_contains "$GATE_OUT" "a way to move it" 'the missing movement path is named'
}

# Given: a lockfile entry with its integrity hash stripped
# When:  the gate runs
# Then:  it fails, because a frozen install cannot verify an unpinned tarball
# Asserts: the integrity half of the registry-package form is checked
test_a_lockfile_without_integrity_fails() {
  local root; root="$(setup_fixture nointegrity)"
  node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const lock = JSON.parse(fs.readFileSync(path, "utf8"));
    const key = Object.keys(lock.packages).find((name) => name.startsWith("node_modules/") && lock.packages[name].integrity);
    delete lock.packages[key].integrity;
    fs.writeFileSync(path, JSON.stringify(lock, null, 2));
  ' "$root/src/reasoning/registry/pi/package-lock.json"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a lockfile package with no integrity hash fails'
  assert_contains "$GATE_OUT" "carry no integrity hash" 'the missing hash is named'
}

# Given: a registry install that is not frozen from its lockfile
# When:  the gate runs
# Then:  it fails, because the lockfile only fixes the tree if the install reads it
# Asserts: npm ci is required, not merely a committed lockfile
test_an_unfrozen_install_fails() {
  local root; root="$(setup_fixture unfrozen)"
  sed -i 's|npm ci --ignore-scripts|npm install -g @earendil-works/pi-coding-agent|' \
    "$root/src/reasoning/runtimes.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an install that is not npm ci fails'
  assert_contains "$GATE_OUT" "npm ci" 'the frozen install is named'
}

# Given: the preflight and a pins file that disagrees with its Dockerfile
# When:  check_pin_drift runs
# Then:  it warns on stderr and returns 0, so the build continues
# Asserts: the local check nudges rather than blocks
test_the_preflight_warns_and_continues() {
  local root; root="$(setup_fixture preflight)"
  sed -i 's/curl=7\.88\.1-10+deb12u15/curl=7.88.1-10+deb12u99/' "$root/src/reasoning/base.dockerfile"

  local out rc=0
  out="$(
    {
      export PATH="$TEST_DIR/../tests/stubs:$PATH"
      source "$REPO_ROOT/scripts/build.sh"
      check_pin_drift "$root"
    } 2>&1
  )" || rc=$?

  assert_rc 0 "$rc" 'the preflight does not block the build'
  assert_contains "$out" "WARNING: a build input's pin disagrees" 'the drift is surfaced'
  assert_contains "$out" "scripts/check_pins.sh" 'the gate the warning points at is named'
}

# Given: version pairs the archive actually serves across its three suites
# When:  the resolver compares them
# Then:  it orders them the way dpkg does, so the highest wins across suites
# Asserts: an apt pin is resolved from all three suites, not from bookworm alone
test_the_resolver_orders_debian_versions() {
  local out rc=0
  out="$(cd "$REPO_ROOT" && node --input-type=module -e '
    import { compare_debian_versions as cmp, highest } from "./src/build/pins.mjs";
    const cases = [
      ["1.6-2.1+deb12u3", "1.6-2.1+deb12u2", 1],
      ["1:2.39.5-0+deb12u3", "1:2.39.5-0+deb12u2", 1],
      ["20250419~deb12u2", "20230311+deb12u1", 1],
      ["7.88.1-10+deb12u15", "7.88.1-10+deb12u5", 1],
      ["1.0~rc1", "1.0", -1],
      ["1.0", "1.0", 0],
    ];
    for (const [a, b, want] of cases) {
      const got = cmp(a, b);
      if (got !== want) throw new Error(`${a} vs ${b}: got ${got}, want ${want}`);
    }
    const picked = highest([
      { suite: "bookworm", version: "1.6-2.1+deb12u2" },
      { suite: "bookworm-security", version: "1.6-2.1+deb12u3" },
      { suite: "bookworm-updates", version: "1.6-2.1+deb12u1" },
    ]);
    if (picked.suite !== "bookworm-security") throw new Error("highest did not pick the security suite");
    const older = highest([
      { suite: "bookworm", version: "1:2.39.5-0+deb12u3" },
      { suite: "bookworm-security", version: "1:2.39.5-0+deb12u2" },
    ]);
    if (older.suite !== "bookworm") throw new Error("highest did not pick the greater main version");
  ' 2>&1)" || rc=$?

  assert_rc 0 "$rc" "every version pair orders the way dpkg orders it"
}

run_test test_the_tree_is_pinned
run_test test_the_resolver_orders_debian_versions
run_test test_the_report_covers_every_input
run_test test_a_moved_dockerfile_version_fails
run_test test_an_unversioned_apt_line_fails
run_test test_a_missing_pin_row_fails
run_test test_a_pin_with_no_move_fails
run_test test_a_lockfile_without_integrity_fails
run_test test_an_unfrozen_install_fails
run_test test_the_preflight_warns_and_continues

test_done test_pins
