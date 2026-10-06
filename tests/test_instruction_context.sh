#!/usr/bin/env bash
# TEST_DEADLINE: 20
# tests/test_instruction_context.sh
# Behavioural tests for scripts/check_instruction_context.sh -- the gate that
# asserts the CONTEXT.md of each instruction runtime path against the image map.
#
# Covers:
#   a conforming set             --  rc 0
#   a runtime path with no file  --  rc 1; the path is named
#   two files on one path        --  rc 1; the collision is named
#   a missing heading            --  rc 1; the heading is named
#   an unlisted source folder    --  rc 1
#   an empty Loaded when         --  rc 1
#   a provider name in a provider-neutral folder  --  rc 1; the marker is named
#   an always row that drifts between files       --  rc 1; the paths are named
#   a layer scope row outside the always set      --  rc 1; the path is named
#   an always row no layer covers                  --  rc 1; the path is named
#   an always row two layers cover                 --  rc 1; both layers are named
#   a layer with no Scope heading                  --  rc 1; the heading is named
#   an inventory that omits a scope prompt          --  rc 1; the prompt is named
#   an inventory row the policy does not govern     --  rc 1; the row is named
#   an /opt path no COPY makes   --  rc 1
#   a 'none' for a copied tree   --  rc 1
#   an /opt path outside the pi settings roots  --  rc 1
#   a provisioned path with no copied parent     --  rc 1
#   two destinations for one source               --  rc 1; the source is named
#   no manifest at all  --  rc 1 (fails closed)
#   a missing settings.json        --  rc 1 (fails closed)
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with INSTRUCTION_CONTEXT_SCAN_ROOT, so the repository's own
# instruction directories are never the subject. Each fixture carries its own
# image manifest, which is the gate's truth for the runtime paths.
#
# Run:   bash tests/test_instruction_context.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_instruction_context.sh"

# write_settings ROOT  --  the pi settings record, holding the two /opt roots
# the gate looks for.
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

# write_provider_dockerfile ROOT NAME COPY_LINES...  --  one provider dockerfile
# holding the given COPY lines, verbatim.
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

# write_manifest ROOT  --  the image manifest the default map's dockerfile
# declares, as scripts/lint/image-map.mjs reads it. The gate and the manifest
# both come from the fixture root, so the fixture is the whole subject.
write_manifest() {
  local root="$1"
  local path="$root/scripts/lint/image-map.json"
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
  ]
}
EOF
}

# The default image map: the two prompt directories merge, the skill directory
# ships, the pi config tree is copied for provisioning, and the coding-agent
# skills are not copied.
write_default_image_map() {
  local root="$1"
  write_provider_dockerfile "$root" pi \
    'COPY src/reasoning/agent/skills/                     /opt/workflow/agent/skills/' \
    'COPY src/reasoning/agent/prompts/                    /opt/workflow/agent/prompts/' \
    'COPY workflow/coding-agent/prompts/                  /opt/workflow/agent/prompts/' \
    'COPY src/reasoning/providers/pi/config/              /opt/workflow/agent/config/'
  write_manifest "$root"
}

# write_context ROOT DIR SOURCE_DIRS RUNTIME_PATH  --  a conforming CONTEXT.md
# for DIR. The caller adjusts one field per case.
write_context() {
  local root="$1" dir="$2" source_dirs="$3" runtime_path="$4"
  local path="$root/$dir/CONTEXT.md"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
# System Assumptions

A folder of instructions.

## Runtime identity

| Field | Value |
|---|---|
| Source folders | \`$source_dirs\` |
| Runtime path | \`$runtime_path\` |
| Loaded when | the settings record lists the folder |

## Reachable

| Path | Holds | Condition |
|---|---|---|
| \`/opt/workflow/agent/\` | the agent tree | always |
| \`/home/agentuser/sandbox/\` | the project tree | always |
| \`devlog/\` | the record layer | the reader has the repository tree |

## Not reachable

- \`devlog/\` through the image.

## Assumptions

- The reader has the repository.
EOF
}

# write_layers ROOT  --  the two AGENTS.md layers, each with a `## Scope` table
# covering its half of the always set the contexts declare, plus the loop
# inventory and the policy scope it must match.
write_layers() {
  local root="$1"
  mkdir -p "$root/src/reasoning/providers/pi/config/agent" "$root/docs/operations"
  cat > "$root/src/reasoning/providers/pi/config/agent/AGENTS.md" <<'EOF'
# Provider layer

## Scope

| Path | What is there |
|---|---|
| `/opt/workflow/agent/` | the agent tree |
EOF
  cat > "$root/AGENTS.md" <<'EOF'
# Project layer

## Scope

| Path | What is there |
|---|---|
| `/home/agentuser/sandbox/` | the project tree |

## Iteration Lifecycle

### Loop prompts

| Prompt | Runs from |
|---|---|
| `/iter` | `workflow/coding-agent/prompts/iter.md` |
| `/wrapup` | `workflow/coding-agent/prompts/wrapup.md` |
EOF
  cat > "$root/docs/operations/iteration_policy.md" <<'EOF'
---
description: "Owns the iteration grain."
scope: ["/iter", "/wrapup"]
---

# Iteration Policy
EOF
}

# write_conforming_tree ROOT  --  four runtime paths, the image map and the
# settings record, all agreeing. The merged prompt root carries one file.
write_conforming_tree() {
  local root="$1"
  write_settings "$root"
  write_default_image_map "$root"
  write_layers "$root"
  write_context "$root" "src/reasoning/agent/prompts" \
    "src/reasoning/agent/prompts/, workflow/coding-agent/prompts/" "/opt/workflow/agent/prompts/"
  write_context "$root" "src/reasoning/agent/skills" \
    "src/reasoning/agent/skills/" "/opt/workflow/agent/skills/"
  write_context "$root" "src/reasoning/providers/pi/config/agent/prompts" \
    "src/reasoning/providers/pi/config/agent/prompts/" '$AGENT_HOME/agent/prompts/'
  write_context "$root" "src/reasoning/providers/pi/config/agent/skills" \
    "src/reasoning/providers/pi/config/agent/skills/" '$AGENT_HOME/skills/'
  write_context "$root" "workflow/coding-agent/skills" \
    "workflow/coding-agent/skills/" "none"
}

# run_gate ROOT  --  runs the real gate against ROOT. Sets GATE_RC and GATE_OUT.
GATE_RC=0
GATE_OUT=""
run_gate() {
  GATE_RC=0
  GATE_OUT=$(INSTRUCTION_CONTEXT_SCAN_ROOT="$1" bash "$GATE" 2>&1) || GATE_RC=$?
}

test_conforming_tree_passes() {
  local root="$FIXTURE_DIR/conforming"
  write_conforming_tree "$root"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a conforming tree passes'
  assert_contains "$GATE_OUT" 'clean across 5 file(s)' 'one file per runtime path is checked'
}

test_runtime_path_without_file_flagged() {
  local root="$FIXTURE_DIR/nofile"
  write_conforming_tree "$root"
  rm "$root/workflow/coding-agent/skills/CONTEXT.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a runtime path with no file fails'
  assert_contains "$GATE_OUT" 'no CONTEXT.md for this runtime path' 'the missing file is named'
}

test_two_files_on_one_path_flagged() {
  local root="$FIXTURE_DIR/collision"
  write_conforming_tree "$root"
  write_context "$root" "workflow/coding-agent/prompts" \
    "src/reasoning/agent/prompts/, workflow/coding-agent/prompts/" "/opt/workflow/agent/prompts/"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'two files on one runtime path fail'
  assert_contains "$GATE_OUT" 'CONTEXT.md files claim this runtime path' 'the collision is named'
}

test_missing_heading_flagged() {
  local root="$FIXTURE_DIR/heading"
  write_conforming_tree "$root"
  local file="$root/workflow/coding-agent/skills/CONTEXT.md"
  grep -v '^## Assumptions$' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a missing heading fails'
  assert_contains "$GATE_OUT" "missing heading '## Assumptions'" 'the heading is named'
}

test_unlisted_source_folder_flagged() {
  local root="$FIXTURE_DIR/sourcedirs"
  write_conforming_tree "$root"
  local file="$root/src/reasoning/agent/prompts/CONTEXT.md"
  sed -i 's#`src/reasoning/agent/prompts/, workflow/coding-agent/prompts/`#`src/reasoning/agent/prompts/`#' "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a source folder the file leaves unlisted fails'
  assert_contains "$GATE_OUT" "expected 'src/reasoning/agent/prompts/, workflow/coding-agent/prompts/'" 'the expected list is named'
}

test_empty_loaded_when_flagged() {
  local root="$FIXTURE_DIR/loadedwhen"
  write_conforming_tree "$root"
  local file="$root/src/reasoning/agent/skills/CONTEXT.md"
  sed -i 's#| Loaded when | the settings record lists the folder |#| Loaded when |  |#' "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an empty Loaded when fails'
  assert_contains "$GATE_OUT" 'Loaded when is empty' 'the field is named'
}

test_reachable_set_drift_flagged() {
  local root="$FIXTURE_DIR/drift"
  write_conforming_tree "$root"
  local file="$root/src/reasoning/agent/skills/CONTEXT.md"
  sed -i 's#| `/opt/workflow/agent/` |#| `/opt/workflow/agent/other/` |#' "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an always row that differs between files fails'
  assert_contains "$GATE_OUT" 'the always reachable set differs' 'the drift is named'
  assert_contains "$GATE_OUT" '/opt/workflow/agent/other/' 'the extra path is named'
}

test_conditioned_rows_may_differ() {
  local root="$FIXTURE_DIR/conditioned"
  write_conforming_tree "$root"
  local file="$root/workflow/coding-agent/skills/CONTEXT.md"
  sed -i 's#| `/home/agentuser/sandbox/` | the project tree | always |#| `/home/agentuser/sandbox/` | the project tree | always |\n| `devlog/` | the record layer | the reader has the repository tree |#' "$file"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a conditioned row in one file alone passes'
}

test_provider_name_in_neutral_folder_flagged() {
  local root="$FIXTURE_DIR/providername"
  write_conforming_tree "$root"
  local file="$root/src/reasoning/agent/skills/CONTEXT.md"
  sed -i 's#| `devlog/` | the record layer | the reader has the repository tree |#| `/home/agentuser/.pi/` | the provider home | always |#' "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a provider path in a provider-neutral folder fails'
  assert_contains "$GATE_OUT" 'provider-neutral folder names' 'the rule and the marker are named'
}

test_runtime_path_without_copy_flagged() {
  local root="$FIXTURE_DIR/nocopy"
  write_conforming_tree "$root"
  local file="$root/workflow/coding-agent/skills/CONTEXT.md"
  sed -i 's#`none`#`/opt/workflow/agent/skills/`#' "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an /opt path no dockerfile copies fails'
  assert_contains "$GATE_OUT" 'the image manifest declares no destination for the directory' 'the missing destination is named'
}

test_none_for_copied_directory_flagged() {
  local root="$FIXTURE_DIR/nonecopied"
  write_conforming_tree "$root"
  local file="$root/src/reasoning/agent/skills/CONTEXT.md"
  sed -i 's#`/opt/workflow/agent/skills/`#`none`#' "$file"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" "a 'none' for a copied directory fails"
  assert_contains "$GATE_OUT" "Runtime path reads 'none' while the image manifest sends" 'the destination is named'
}

test_path_outside_settings_roots_flagged() {
  local root="$FIXTURE_DIR/notroot"
  write_conforming_tree "$root"
  sed -i 's#/opt/workflow/agent/skills/#/opt/elsewhere/skills/#' \
    "$root/src/reasoning/providers/pi/provider.dockerfile" \
    "$root/src/reasoning/agent/skills/CONTEXT.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a path outside the settings roots fails'
  assert_contains "$GATE_OUT" 'is not a root in' 'the settings record is named'
}

test_provisioned_path_without_parent_copy_flagged() {
  local root="$FIXTURE_DIR/noparent"
  write_settings "$root"
  write_default_image_map "$root"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const manifest = JSON.parse(fs.readFileSync(file, "utf8"));
    manifest.image = manifest.image.filter((row) => !row.source.startsWith("src/reasoning/providers/pi/config/"));
    delete manifest.provision;
    fs.writeFileSync(file, JSON.stringify(manifest, null, 2));
  ' "$root/scripts/lint/image-map.json"
  write_context "$root" "src/reasoning/agent/prompts" \
    "src/reasoning/agent/prompts/, workflow/coding-agent/prompts/" "/opt/workflow/agent/prompts/"
  write_context "$root" "src/reasoning/agent/skills" \
    "src/reasoning/agent/skills/" "/opt/workflow/agent/skills/"
  write_context "$root" "src/reasoning/providers/pi/config/agent/prompts" \
    "src/reasoning/providers/pi/config/agent/prompts/" '$AGENT_HOME/agent/prompts/'
  write_context "$root" "src/reasoning/providers/pi/config/agent/skills" \
    "src/reasoning/providers/pi/config/agent/skills/" '$AGENT_HOME/skills/'
  write_context "$root" "workflow/coding-agent/skills" \
    "workflow/coding-agent/skills/" "none"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a provisioned path with no copied parent fails'
  assert_contains "$GATE_OUT" 'the manifest declares no copied parent of the directory' 'the missing parent is named'
}

test_disagreeing_destinations_flagged() {
  local root="$FIXTURE_DIR/disagree"
  write_conforming_tree "$root"
  node -e '
    const fs = require("fs");
    const file = process.argv[1];
    const manifest = JSON.parse(fs.readFileSync(file, "utf8"));
    manifest.image.push({ provider: "hermes", source: "src/reasoning/agent/skills/", destination: "/opt/other/skills/" });
    fs.writeFileSync(file, JSON.stringify(manifest, null, 2));
  ' "$root/scripts/lint/image-map.json"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'two destinations for one source fail'
  assert_contains "$GATE_OUT" 'gives this runtime path two destinations' 'the disagreement is named'
}

test_missing_manifest_fails_closed() {
  local root="$FIXTURE_DIR/nomanifest"
  write_settings "$root"
  write_provider_dockerfile "$root" pi \
    'COPY src/reasoning/agent/skills/                     /opt/workflow/agent/skills/'
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'no manifest fails closed'
  assert_contains "$GATE_OUT" 'image-map.json is missing' 'the missing input is named'
}

test_missing_settings_fails_closed() {
  local root="$FIXTURE_DIR/nosettings"
  write_default_image_map "$root"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a missing settings.json fails closed'
  assert_contains "$GATE_OUT" 'settings.json is missing' 'the missing input is named'
}

test_layer_scope_row_outside_the_always_set_flagged() {
  local root="$FIXTURE_DIR/layerextra"
  write_conforming_tree "$root"
  sed -i 's#| `/opt/workflow/agent/` | the agent tree |#| `/opt/workflow/agent/` | the agent tree |\n| `/opt/elsewhere/` | another tree |#' \
    "$root/src/reasoning/providers/pi/config/agent/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a layer path outside the always set fails'
  assert_contains "$GATE_OUT" 'which no CONTEXT.md declares always reachable' 'the path is named'
}

test_uncovered_always_row_flagged() {
  local root="$FIXTURE_DIR/uncovered"
  write_conforming_tree "$root"
  sed -i 's#| `/home/agentuser/sandbox/` | the project tree |#| `/home/agentuser/elsewhere/` | the project tree |#' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an always row no layer covers fails'
  assert_contains "$GATE_OUT" 'no layer covers' 'the uncovered row is named'
}

test_always_row_covered_twice_flagged() {
  local root="$FIXTURE_DIR/doublecover"
  write_conforming_tree "$root"
  sed -i 's#| `/home/agentuser/sandbox/` | the project tree |#| `/opt/workflow/agent/` | the agent tree again |#' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an always row two layers cover fails'
  assert_contains "$GATE_OUT" 'more than one layer covers' 'the collision is named'
}

test_layer_without_scope_heading_flagged() {
  local root="$FIXTURE_DIR/noheading"
  write_conforming_tree "$root"
  sed -i 's/^## Scope$/## Not the scope/' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a layer with no Scope heading fails'
  assert_contains "$GATE_OUT" "missing heading '## Scope'" 'the heading is named'
}

test_inventory_omitting_a_scope_prompt_flagged() {
  local root="$FIXTURE_DIR/invomit"
  write_conforming_tree "$root"
  sed -i '/| `\/wrapup` |/d' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an inventory that omits a scope prompt fails'
  assert_contains "$GATE_OUT" "the inventory omits [/wrapup]" 'the omitted prompt is named'
}

test_inventory_row_outside_scope_flagged() {
  local root="$FIXTURE_DIR/invextra"
  write_conforming_tree "$root"
  sed -i 's#| `/wrapup` | `workflow/coding-agent/prompts/wrapup.md` |#| `/wrapup` | `workflow/coding-agent/prompts/wrapup.md` |\n| `/gm` | `workflow/coding-agent/prompts/gm.md` |#' "$root/AGENTS.md"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an inventory row the policy does not govern fails'
  assert_contains "$GATE_OUT" "the inventory names [/gm]" 'the ungoverned row is named'
}

run_test test_conforming_tree_passes
run_test test_runtime_path_without_file_flagged
run_test test_two_files_on_one_path_flagged
run_test test_missing_heading_flagged
run_test test_unlisted_source_folder_flagged
run_test test_empty_loaded_when_flagged
run_test test_reachable_set_drift_flagged
run_test test_conditioned_rows_may_differ
run_test test_provider_name_in_neutral_folder_flagged
run_test test_runtime_path_without_copy_flagged
run_test test_none_for_copied_directory_flagged
run_test test_path_outside_settings_roots_flagged
run_test test_provisioned_path_without_parent_copy_flagged
run_test test_disagreeing_destinations_flagged
run_test test_missing_manifest_fails_closed
run_test test_missing_settings_fails_closed
run_test test_layer_scope_row_outside_the_always_set_flagged
run_test test_uncovered_always_row_flagged
run_test test_always_row_covered_twice_flagged
run_test test_layer_without_scope_heading_flagged
run_test test_inventory_omitting_a_scope_prompt_flagged
run_test test_inventory_row_outside_scope_flagged

test_done
