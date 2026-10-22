#!/usr/bin/env bash
# Tests for the reach gate: `scripts/check_reach.sh` over a fixture pair of the
# taxonomy and the manifest.
#
# The gate holds two hand-stated lists together, so each case moves one side and
# asserts the gate names the side that moved. A gate that passes on both would
# be satisfied by two artifacts that had drifted together, so the clean case is
# asserted first and every mutation is asserted against it.
#
# Covers:
#   clean      --  a mount the taxonomy covers and a folder it states are clean
#   unmounted  --  a manifest destination no route covers is named
#   empty      --  a mount point nothing mounts is named
#   shipped    --  a folder stated repository-only that the manifest reaches is named
#   missing    --  a delivered folder the tree lacks is named

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GATE="$REPO_ROOT/scripts/check_reach.sh"

FIXTURE_ROOT_DIR="$FIXTURE_DIR/fixture"
MANIFEST="$FIXTURE_ROOT_DIR/src/build/container-interface.json"
TAXONOMY="$FIXTURE_ROOT_DIR/docs/reference/documentation_taxonomy.md"

# write_manifest DESTINATION...  --  one image row per destination, each sourced
# from `src/libs/`, plus an optional extra source named by EXTRA_SOURCE.
write_manifest() {
  local rows=""
  mkdir -p "$(dirname "$MANIFEST")"
  for destination in "$@"; do
    rows+="{\"provider\":\"pi\",\"source\":\"src/libs/\",\"destination\":\"$destination\"},"
  done
  [[ -n "${EXTRA_SOURCE:-}" ]] && rows+="{\"provider\":\"pi\",\"source\":\"$EXTRA_SOURCE\",\"destination\":\"/opt/workflow/agent/modules/\"},"
  printf '{"note":"fixture","image":[%s],"cells":[]}\n' "${rows%,}" > "$MANIFEST"
}

# write_taxonomy MOUNT...  --  a `## Reach` section naming the mounts and the
# folder in FOLDER, followed by a second section so the scanner must stop at it.
write_taxonomy() {
  local mounts=""
  for mount in "$@"; do mounts+="\`$mount\`, "; done
  mkdir -p "$(dirname "$TAXONOMY")"
  cat > "$TAXONOMY" <<EOF
# Fixture taxonomy

## Reach

| Delivered by | The roots it carries | Reach |
|---|---|---|
| the image, as a module payload | the roots the manifest mounts at ${mounts%, } | every session |
| nothing | the repository-only folders, \`${FOLDER}\` | a session with the tree |

## Record lifecycle view

\`/opt/not/a/root/\` is outside the section, so the scanner never reads it.
EOF
}

run_gate() {
  assert_run 0 "$GATE --manifest $MANIFEST --taxonomy $TAXONOMY --root $FIXTURE_ROOT_DIR" \
    "the fixture is clean" || return 1
  assert_contains "$RUN_OUT" "reach: clean" "the clean summary is printed"
}

test_clean() {
  mkdir -p "$FIXTURE_ROOT_DIR/src/libs" "$FIXTURE_ROOT_DIR/devlog"
  FOLDER="devlog/"
  write_manifest "/opt/sandbox/lib/"
  write_taxonomy "/opt/sandbox/"
  run_gate
}

test_unmounted_destination_is_named() {
  mkdir -p "$FIXTURE_ROOT_DIR/src/libs" "$FIXTURE_ROOT_DIR/devlog"
  FOLDER="devlog/"
  write_manifest "/opt/sandbox/lib/" "/opt/elsewhere/data/"
  write_taxonomy "/opt/sandbox/"
  assert_run 1 "$GATE --manifest $MANIFEST --taxonomy $TAXONOMY --root $FIXTURE_ROOT_DIR" \
    "a destination no route covers fails the gate"
  assert_contains "$RUN_OUT" "/opt/elsewhere/data/" "the finding names the destination"
}

test_empty_mount_is_named() {
  mkdir -p "$FIXTURE_ROOT_DIR/src/libs" "$FIXTURE_ROOT_DIR/devlog"
  FOLDER="devlog/"
  write_manifest "/opt/sandbox/lib/"
  write_taxonomy "/opt/sandbox/" "/opt/nothing/"
  assert_run 1 "$GATE --manifest $MANIFEST --taxonomy $TAXONOMY --root $FIXTURE_ROOT_DIR" \
    "a mount point nothing mounts fails the gate"
  assert_contains "$RUN_OUT" "/opt/nothing/" "the finding names the mount point"
}

test_shipped_repository_folder_is_named() {
  mkdir -p "$FIXTURE_ROOT_DIR/src/libs" "$FIXTURE_ROOT_DIR/devlog"
  FOLDER="devlog/"
  EXTRA_SOURCE="devlog/"
  write_manifest "/opt/sandbox/lib/"
  write_taxonomy "/opt/sandbox/"
  assert_run 1 "$GATE --manifest $MANIFEST --taxonomy $TAXONOMY --root $FIXTURE_ROOT_DIR" \
    "a repository-only folder the manifest ships fails the gate"
  assert_contains "$RUN_OUT" "devlog/" "the finding names the folder"
  unset EXTRA_SOURCE
}

test_missing_delivered_folder_is_named() {
  mkdir -p "$FIXTURE_ROOT_DIR/src/libs"
  FOLDER="workflow/absent/"
  EXTRA_SOURCE="workflow/"
  mkdir -p "$FIXTURE_ROOT_DIR/workflow"
  write_manifest "/opt/sandbox/lib/"
  write_taxonomy "/opt/sandbox/"
  assert_run 1 "$GATE --manifest $MANIFEST --taxonomy $TAXONOMY --root $FIXTURE_ROOT_DIR" \
    "a delivered folder the tree lacks fails the gate"
  assert_contains "$RUN_OUT" "workflow/absent/" "the finding names the folder"
  unset EXTRA_SOURCE
}

test_section_boundary() {
  mkdir -p "$FIXTURE_ROOT_DIR/src/libs" "$FIXTURE_ROOT_DIR/devlog"
  FOLDER="devlog/"
  write_manifest "/opt/sandbox/lib/"
  write_taxonomy "/opt/sandbox/"
  assert_run 0 "$GATE --manifest $MANIFEST --taxonomy $TAXONOMY --root $FIXTURE_ROOT_DIR" \
    "a root outside the section is not read"
  assert_not_contains "$RUN_OUT" "/opt/not/a/root/" "the later section's path is ignored"
}

run_test test_clean
run_test test_unmounted_destination_is_named
run_test test_empty_mount_is_named
run_test test_shipped_repository_folder_is_named
run_test test_missing_delivered_folder_is_named
run_test test_section_boundary

test_done "reach gate"
