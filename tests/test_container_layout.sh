#!/usr/bin/env bash
# TEST_DEADLINE: 120
# tests/test_container_layout.sh
# Behavioural tests for src/build/container-interface.mjs -- the single reader
# of the interface manifest -- and the scripts/check_container_layout.sh gate
# it wraps.
#
# Covers the two halves of that gate: the container rows against what implements
# them (the provider dockerfiles, the entrypoint's provisioning template and the
# provider settings record), and each instruction surface's folder set against
# the one the images and the provisioning derive.
#
#   a conforming tree                        --  rc 0
#   a manifest row no COPY line carries      --  rc 1; the row is named
#   a COPY line no manifest row carries      --  rc 1; the line is named
#   an ENV line no manifest row carries      --  rc 1; the line is named
#   a template the entrypoint disagrees with --  rc 1; both values are named
#   a missing manifest                       --  rc 1 (fails closed)
#   no provider dockerfile                   --  rc 1 (fails closed)
#   a missing settings record                --  rc 1 (a finding, not agreement)
#   a cell source no image sends there       --  rc 1; the source is named
#   a destination no cell declares           --  rc 1; the destination is named
#   a copied folder declared as `none`       --  rc 1; the copy is named
#   an /opt path outside the settings roots  --  rc 1; the record is named
#   a $AGENT_HOME cell with no provision row --  rc 1; the home is named
#   one source landing in two places         --  rc 1; both are named
#   two cells claiming one folder            --  rc 1; the other cell is named
#   a `none` cell naming an image path       --  rc 1; the path is named
#   a providerless cell naming a provider    --  rc 1; the provider is named
#   a cell with no loader                    --  rc 1; the field is named
#   the `pairs` CLI                          --  the image rows and the
#                                                provisioning row, the latter
#                                                resolved through AGENT_HOME
#   the `session` CLI                        --  the declared session paths
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with CONTAINER_INTERFACE_SCAN_ROOT, so the repository's own
# manifest is never the subject.
#
# Run:   bash tests/test_container_layout.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_container_layout.sh"
MODULE="$REPO_ROOT/src/build/container-interface.mjs"
MANIFEST_REL="src/build/container-interface.json"

# write_settings ROOT  --  the pi settings record, holding the two /opt roots
# the gate looks for. Its shape is pi's: a list per root kind.
write_settings() {
  local root="$1"
  local path="$root/src/reasoning/providers/pi/config/agent/settings.json"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
{
  "packages": ["/opt/workflow/agent"],
  "skills": ["/opt/workflow/agent/skills"],
  "prompts": ["/opt/workflow/agent/prompts"]
}
EOF
}

# write_provider_dockerfile ROOT NAME LINE...  --  one provider dockerfile
# holding the given lines, verbatim.
write_provider_dockerfile() {
  local root="$1" name="$2"
  shift 2
  local path="$root/src/reasoning/providers/$name/provider.dockerfile"
  mkdir -p "$(dirname "$path")"
  {
    printf 'FROM scratch\n'
    printf '%s\n' "$@"
  } > "$path"
}

# write_manifest ROOT  --  a conforming manifest for the tree
# write_default_tree builds: four image rows, one provision row, one provider's
# environment, two session rows, and one cell per surface form -- an `/opt` cell,
# a `$AGENT_HOME` cell, and a `none` cell.
write_manifest() {
  local root="$1"
  local path="$root/$MANIFEST_REL"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
{
  "image": [
    { "provider": "pi", "source": "src/reasoning/agent/skills/", "destination": "/opt/workflow/agent/skills/" },
    { "provider": "pi", "source": "src/reasoning/agent/prompts/", "destination": "/opt/workflow/agent/prompts/" },
    { "provider": "pi", "source": "workflow/coding-agent/prompts/", "destination": "/opt/workflow/agent/prompts/" },
    { "provider": "pi", "source": "src/reasoning/providers/pi/config/", "destination": "/opt/workflow/agent/config/" }
  ],
  "provision": [
    {
      "provider": "pi",
      "source": "src/reasoning/providers/pi/config/",
      "template": "/opt/workflow/agent/config/",
      "home": "$AGENT_HOME/"
    }
  ],
  "env": [
    { "provider": "pi", "name": "AGENT_HOME", "value": "/home/agentuser/.pi" }
  ],
  "session": [
    { "path": "/home/agentuser/sandbox/", "holds": "the project tree" },
    { "path": "/opt/sandbox/lib/", "holds": "the harness libraries" }
  ],
  "cells": [
    {
      "sources": ["src/reasoning/agent/prompts/", "workflow/coding-agent/prompts/"],
      "runtime_path": "/opt/workflow/agent/prompts/",
      "loader": "the running provider's config lists this path as a prompt root",
      "reachable": [
        { "path": "workflow/coding-agent/skills/", "holds": "the coding-agent skills", "condition": "the reader has the repository tree" }
      ]
    },
    {
      "sources": ["src/reasoning/agent/skills/"],
      "runtime_path": "/opt/workflow/agent/skills/",
      "loader": "the running provider's config lists this path as a skill root"
    },
    {
      "sources": ["src/reasoning/providers/pi/config/"],
      "runtime_path": "$AGENT_HOME/",
      "loader": "pi reads its config home at startup",
      "provider": "pi",
      "reachable": [
        { "path": "/opt/workflow/agent/config/", "holds": "the config template", "condition": "pi delivery" }
      ]
    },
    {
      "sources": ["workflow/coding-agent/skills/"],
      "runtime_path": "none",
      "loader": "a prompt names a file here by its repository-relative path"
    }
  ]
}
EOF
}

# write_default_tree ROOT  --  the dockerfile, entrypoint, settings record and
# manifest that agree, plus the two files the layout check does not read but a
# repository has.
write_default_tree() {
  local root="$1"
  write_settings "$root"
  write_manifest "$root"
  write_provider_dockerfile "$root" pi \
    'COPY src/reasoning/agent/skills/                     /opt/workflow/agent/skills/' \
    'COPY src/reasoning/agent/prompts/                    /opt/workflow/agent/prompts/' \
    'COPY workflow/coding-agent/prompts/                  /opt/workflow/agent/prompts/' \
    'COPY src/reasoning/providers/pi/config/              /opt/workflow/agent/config/' \
    'ENV AGENT_HOME=/home/agentuser/.pi'
  mkdir -p "$root/src/reasoning"
  printf 'PROVISION_TEMPLATE="/opt/workflow/agent/config"\n' > "$root/src/reasoning/entrypoint.sh"
}

# manifest_edit ROOT SCRIPT  --  runs SCRIPT against the fixture's manifest with
# node, with the manifest path as argv[1].
manifest_edit() {
  local root="$1" script="$2"
  node -e "$script" "$root/$MANIFEST_REL"
}

GATE_RC=0
GATE_OUT=""
run_gate() {
  GATE_RC=0
  GATE_OUT=$(CONTAINER_INTERFACE_SCAN_ROOT="$1" bash "$GATE" 2>&1) || GATE_RC=$?
}

MODULE_RC=0
MODULE_OUT=""
run_module() {
  MODULE_RC=0
  MODULE_OUT=$(node "$MODULE" "$@" 2>&1) || MODULE_RC=$?
}

test_conforming_tree_passes() {
  local root="$FIXTURE_DIR/conforming"
  write_default_tree "$root"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a conforming tree passes'
}

test_manifest_row_with_no_copy_line_flagged() {
  local root="$FIXTURE_DIR/rowonly"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.image.push({ provider: "pi", source: "docs/concepts/", destination: "/opt/sandbox/docs/concepts/" });
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a manifest row no COPY line carries fails'
  assert_contains "$GATE_OUT" $'image: the manifest declares \'pi\tdocs/concepts/' 'the row is named'
  assert_contains "$GATE_OUT" 'which the dockerfiles do not carry' 'the direction is named'
}

test_copy_line_with_no_manifest_row_flagged() {
  local root="$FIXTURE_DIR/lineonly"
  write_default_tree "$root"
  printf 'COPY docs/operations/   /opt/sandbox/docs/operations/\n' \
    >> "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a COPY line no manifest row carries fails'
  assert_contains "$GATE_OUT" 'which the manifest does not declare' 'the direction is named'
}

test_env_line_with_no_manifest_row_flagged() {
  local root="$FIXTURE_DIR/envonly"
  write_default_tree "$root"
  printf 'ENV WORKSPACE_DIR=/home/agentuser/workspace\n' \
    >> "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an ENV line no manifest row carries fails'
  assert_contains "$GATE_OUT" "env: " 'the layer is named'
  assert_contains "$GATE_OUT" "WORKSPACE_DIR" 'the variable is named'
}

test_template_entrypoint_disagreement_flagged() {
  local root="$FIXTURE_DIR/template"
  write_default_tree "$root"
  printf 'PROVISION_TEMPLATE="/opt/elsewhere/config"\n' > "$root/src/reasoning/entrypoint.sh"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a template the entrypoint disagrees with fails'
  assert_contains "$GATE_OUT" 'PROVISION_TEMPLATE reads' 'the entrypoint value is named'
}

test_missing_manifest_fails_closed() {
  local root="$FIXTURE_DIR/nomanifest"
  write_settings "$root"
  write_provider_dockerfile "$root" pi 'COPY src/reasoning/agent/skills/   /opt/workflow/agent/skills/'
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a missing manifest fails closed'
  assert_contains "$GATE_OUT" 'container-interface.json is missing' 'the missing input is named'
}

test_no_provider_dockerfile_reported() {
  local root="$FIXTURE_DIR/nodockerfile"
  write_default_tree "$root"
  rm "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_module check --root "$root"
  assert_rc 1 "$MODULE_RC" 'no provider dockerfile is a finding, not an empty map'
  assert_contains "$MODULE_OUT" 'no provider dockerfile' 'the missing input is named'
}

test_missing_settings_reported() {
  local root="$FIXTURE_DIR/nosettings"
  write_default_tree "$root"
  rm "$root/src/reasoning/providers/pi/config/agent/settings.json"
  run_module check --root "$root"
  assert_rc 1 "$MODULE_RC" 'a missing settings record is a finding, not agreement'
  assert_contains "$MODULE_OUT" 'settings.json: missing or does not parse' 'the missing record is named'
}

test_cell_source_no_image_sends_flagged() {
  local root="$FIXTURE_DIR/nosource"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.cells[1].sources = ["src/reasoning/agent/skills/", "docs/concepts/"];
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a declared source no image sends to the path fails'
  assert_contains "$GATE_OUT" "declares source 'docs/concepts/'" 'the source is named'
  assert_contains "$GATE_OUT" 'which no image row sends to this runtime path' 'the direction is named'
}

test_destination_no_cell_declares_flagged() {
  local root="$FIXTURE_DIR/nocell"
  write_default_tree "$root"
  printf 'COPY docs/concepts/   /opt/workflow/agent/concepts/\n' \
    >> "$root/src/reasoning/providers/pi/provider.dockerfile"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.image.push({ provider: "pi", source: "docs/concepts/", destination: "/opt/workflow/agent/concepts/" });
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a destination in the agent tree with no cell fails'
  assert_contains "$GATE_OUT" "sends 'docs/concepts/' to '/opt/workflow/agent/concepts/'" 'the destination is named'
  assert_contains "$GATE_OUT" 'which no cell declares' 'the rule is named'
}

test_none_cell_for_a_copied_folder_flagged() {
  local root="$FIXTURE_DIR/nonecopied"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.cells = manifest.cells.filter((cell) => cell.runtime_path !== "/opt/workflow/agent/skills/");
    manifest.cells.find((cell) => cell.runtime_path === "none").sources = ["src/reasoning/agent/skills/"];
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" "a copied folder declared as 'none' fails"
  assert_contains "$GATE_OUT" "runtime path 'none' while pi copies" 'the copy is named'
}

test_opt_path_outside_settings_roots_flagged() {
  local root="$FIXTURE_DIR/notroot"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    for (const row of manifest.image) {
      if (row.destination === "/opt/workflow/agent/skills/") row.destination = "/opt/elsewhere/skills/";
    }
    manifest.cells.find((cell) => cell.runtime_path === "/opt/workflow/agent/skills/").runtime_path = "/opt/elsewhere/skills/";
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  sed -i 's#/opt/workflow/agent/skills/#/opt/elsewhere/skills/#' "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an /opt path outside the settings roots fails'
  assert_contains "$GATE_OUT" 'is not a root in' 'the settings record is named'
}

test_provisioned_cell_without_provision_row_flagged() {
  local root="$FIXTURE_DIR/noprovision"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    delete manifest.provision;
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a $AGENT_HOME cell with no provision row fails'
  assert_contains "$GATE_OUT" "sits in no provision row's home" 'the home is named'
}

test_one_source_two_destinations_flagged() {
  local root="$FIXTURE_DIR/disagree"
  write_default_tree "$root"
  write_provider_dockerfile "$root" hermes \
    'COPY src/reasoning/agent/skills/   /opt/other/skills/' \
    'ENV AGENT_HOME=/home/agentuser/.hermes'
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.image.push({ provider: "hermes", source: "src/reasoning/agent/skills/", destination: "/opt/other/skills/" });
    manifest.env.push({ provider: "hermes", name: "AGENT_HOME", value: "/home/agentuser/.hermes" });
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'one source landing in two places fails'
  assert_contains "$GATE_OUT" "one source has one runtime path" 'the rule is named'
  assert_contains "$GATE_OUT" '/opt/other/skills/' 'the second destination is named'
}

test_two_cells_claiming_one_folder_flagged() {
  local root="$FIXTURE_DIR/duplicate"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.cells.find((cell) => cell.runtime_path === "none").sources = ["src/reasoning/agent/skills/"];
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'two cells claiming one folder fails'
  assert_contains "$GATE_OUT" 'is already declared by cells[' 'the other cell is named'
}

test_none_cell_naming_an_image_path_flagged() {
  local root="$FIXTURE_DIR/noneimage"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.cells.find((cell) => cell.runtime_path === "none").loader =
      "a prompt names a file here by its repository-relative path, and the image carries it at /opt/workflow/agent/skills/";
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a surface no image carries naming an image path fails'
  assert_contains "$GATE_OUT" 'a surface no image carries names the image path' 'the rule is named'
}

test_providerless_cell_naming_a_provider_flagged() {
  local root="$FIXTURE_DIR/providername"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.cells[0].loader = "pi lists this path as a prompt root";
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a surface that belongs to no provider naming one fails'
  assert_contains "$GATE_OUT" "a surface that belongs to no provider names 'pi'" 'the provider is named'
}

test_cell_without_a_loader_flagged() {
  local root="$FIXTURE_DIR/noloader"
  write_default_tree "$root"
  manifest_edit "$root" '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    delete manifest.cells[0].loader;
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  '
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a cell with no loader fails'
  assert_contains "$GATE_OUT" 'declares no loader' 'the field is named'
}

test_pairs_cli_emits_both_layers() {
  local root="$FIXTURE_DIR/pairs"
  write_default_tree "$root"
  run_module pairs --root "$root"
  assert_rc 0 "$MODULE_RC" 'the pairs command succeeds'
  assert_contains "$MODULE_OUT" 'image	pi	src/reasoning/agent/prompts/	/opt/workflow/agent/prompts/' 'the image pair is emitted'
  # The provision row resolves through the provider's AGENT_HOME, so a file
  # beneath the template has a second destination.
  assert_contains "$MODULE_OUT" 'provision	pi	src/reasoning/providers/pi/config/	/home/agentuser/.pi/' 'the provision pair is resolved'
}

test_session_cli_emits_the_paths() {
  local root="$FIXTURE_DIR/session"
  write_default_tree "$root"
  run_module session --root "$root"
  assert_rc 0 "$MODULE_RC" 'the session command succeeds'
  assert_contains "$MODULE_OUT" '/home/agentuser/sandbox/' 'the project tree is emitted'
  assert_contains "$MODULE_OUT" '/opt/sandbox/lib/' 'the library root is emitted'
}

run_test test_conforming_tree_passes
run_test test_manifest_row_with_no_copy_line_flagged
run_test test_copy_line_with_no_manifest_row_flagged
run_test test_env_line_with_no_manifest_row_flagged
run_test test_template_entrypoint_disagreement_flagged
run_test test_missing_manifest_fails_closed
run_test test_no_provider_dockerfile_reported
run_test test_missing_settings_reported
run_test test_cell_source_no_image_sends_flagged
run_test test_destination_no_cell_declares_flagged
run_test test_none_cell_for_a_copied_folder_flagged
run_test test_opt_path_outside_settings_roots_flagged
run_test test_provisioned_cell_without_provision_row_flagged
run_test test_one_source_two_destinations_flagged
run_test test_two_cells_claiming_one_folder_flagged
run_test test_none_cell_naming_an_image_path_flagged
run_test test_providerless_cell_naming_a_provider_flagged
run_test test_cell_without_a_loader_flagged
run_test test_pairs_cli_emits_both_layers
run_test test_session_cli_emits_the_paths

test_done
