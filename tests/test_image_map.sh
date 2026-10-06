#!/usr/bin/env bash
# TEST_DEADLINE: 60
# tests/test_image_map.sh
# Behavioural tests for scripts/lint/image-map.mjs -- the single reader of the
# image manifest -- and the scripts/check_image_map.sh gate it wraps.
#
# Covers:
#   a conforming manifest and dockerfiles   --  rc 0
#   a manifest row no COPY line carries     --  rc 1; the row is named
#   a COPY line no manifest row carries     --  rc 1; the line is named
#   an ENV line no manifest row carries     --  rc 1; the line is named
#   a template the entrypoint disagrees with--  rc 1; both values are named
#   a missing manifest                      --  rc 1 (fails closed)
#   no provider dockerfile                  --  rc 1 (fails closed)
#   the `pairs` CLI                         --  the image rows and the
#                                              provisioning row, the latter
#                                              resolved through AGENT_HOME
#
# The fixtures sit under $FIXTURE_DIR, outside the repo tree, and the scan is
# pointed at them with IMAGE_MAP_SCAN_ROOT, so the repository's own manifest is
# never the subject.
#
# Run:   bash tests/test_image_map.sh
# Exit:  0 = all passed, non-zero = failure count

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"

source "$TEST_DIR/libs/test_common.sh"
test_setup

GATE="$REPO_ROOT/scripts/check_image_map.sh"
MODULE="$REPO_ROOT/scripts/lint/image-map.mjs"

# write_root ROOT  --  a repository shape the manifest describes: one provider
# dockerfile, the entrypoint's provisioning template, and the manifest itself.
write_root() {
  local root="$1"
  mkdir -p "$root/src/reasoning/providers/pi" "$root/scripts/lint"
  {
    printf 'FROM scratch\n'
    printf 'COPY src/reasoning/agent/prompts/   /opt/workflow/agent/prompts/\n'
    printf 'COPY src/reasoning/providers/pi/config/   /opt/workflow/agent/config/\n'
    printf 'ENV AGENT_HOME=/home/agentuser/.pi\n'
    printf 'ENV PROVIDER_NAME=pi\n'
  } > "$root/src/reasoning/providers/pi/provider.dockerfile"
  printf 'PROVISION_TEMPLATE="/opt/workflow/agent/config"\n' > "$root/src/reasoning/entrypoint.sh"
  cat > "$root/scripts/lint/image-map.json" <<'EOF'
{
  "image": [
    { "provider": "pi", "source": "src/reasoning/agent/prompts/", "destination": "/opt/workflow/agent/prompts/" },
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
    { "provider": "pi", "name": "AGENT_HOME", "value": "/home/agentuser/.pi" },
    { "provider": "pi", "name": "PROVIDER_NAME", "value": "pi" }
  ]
}
EOF
}

run_gate() {
  GATE_RC=0
  GATE_OUT=$(IMAGE_MAP_SCAN_ROOT="$1" bash "$GATE" 2>&1) || GATE_RC=$?
}

run_module() {
  MODULE_RC=0
  MODULE_OUT=$(node "$MODULE" "$@" 2>&1) || MODULE_RC=$?
}

test_conforming_root_passes() {
  local root="$FIXTURE_DIR/conforming"
  write_root "$root"
  run_gate "$root"
  assert_rc 0 "$GATE_RC" 'a manifest the dockerfiles agree with passes'
}

test_manifest_row_with_no_copy_line_flagged() {
  local root="$FIXTURE_DIR/rowonly"
  write_root "$root"
  node -e '
    const fs = require("fs");
    const manifest = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
    manifest.image.push({ provider: "pi", source: "docs/concepts/", destination: "/opt/sandbox/docs/concepts/" });
    fs.writeFileSync(process.argv[1], JSON.stringify(manifest, null, 2));
  ' "$root/scripts/lint/image-map.json"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a manifest row no COPY line carries fails'
  assert_contains "$GATE_OUT" $'image: the manifest declares \'pi\tdocs/concepts/' 'the row is named'
  assert_contains "$GATE_OUT" 'which the dockerfiles do not carry' 'the direction is named'
}

test_copy_line_with_no_manifest_row_flagged() {
  local root="$FIXTURE_DIR/lineonly"
  write_root "$root"
  printf 'COPY docs/operations/   /opt/sandbox/docs/operations/\n' \
    >> "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a COPY line no manifest row carries fails'
  assert_contains "$GATE_OUT" 'carries' 'the line is named'
  assert_contains "$GATE_OUT" 'which the manifest does not declare' 'the direction is named'
}

test_env_line_with_no_manifest_row_flagged() {
  local root="$FIXTURE_DIR/envonly"
  write_root "$root"
  printf 'ENV WORKSPACE_DIR=/home/agentuser/workspace\n' \
    >> "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'an ENV line no manifest row carries fails'
  assert_contains "$GATE_OUT" "env: " 'the layer is named'
  assert_contains "$GATE_OUT" "WORKSPACE_DIR" 'the variable is named'
}

test_template_entrypoint_disagreement_flagged() {
  local root="$FIXTURE_DIR/template"
  write_root "$root"
  printf 'PROVISION_TEMPLATE="/opt/elsewhere/config"\n' > "$root/src/reasoning/entrypoint.sh"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a template the entrypoint disagrees with fails'
  assert_contains "$GATE_OUT" 'PROVISION_TEMPLATE reads' 'the entrypoint value is named'
}

test_missing_manifest_fails_closed() {
  local root="$FIXTURE_DIR/nomanifest"
  mkdir -p "$root/src/reasoning/providers/pi"
  printf 'FROM scratch\n' > "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_gate "$root"
  assert_rc 1 "$GATE_RC" 'a missing manifest fails closed'
  assert_contains "$GATE_OUT" 'image-map.json is missing' 'the missing input is named'
}

test_no_provider_dockerfile_reported() {
  local root="$FIXTURE_DIR/nodockerfile"
  write_root "$root"
  rm "$root/src/reasoning/providers/pi/provider.dockerfile"
  run_module check --root "$root"
  assert_rc 1 "$MODULE_RC" 'no provider dockerfile is a finding, not an empty map'
  assert_contains "$MODULE_OUT" 'no provider dockerfile' 'the missing input is named'
}

test_pairs_cli_emits_both_layers() {
  local root="$FIXTURE_DIR/pairs"
  write_root "$root"
  run_module pairs --root "$root"
  assert_rc 0 "$MODULE_RC" 'the pairs command succeeds'
  assert_contains "$MODULE_OUT" 'image	pi	src/reasoning/agent/prompts/	/opt/workflow/agent/prompts/' 'the image pair is emitted'
  # The provision row resolves through the provider's AGENT_HOME, so a file
  # beneath the template has a second destination.
  assert_contains "$MODULE_OUT" 'provision	pi	src/reasoning/providers/pi/config/	/home/agentuser/.pi/' 'the provision pair is resolved'
}

run_test test_conforming_root_passes
run_test test_manifest_row_with_no_copy_line_flagged
run_test test_copy_line_with_no_manifest_row_flagged
run_test test_env_line_with_no_manifest_row_flagged
run_test test_template_entrypoint_disagreement_flagged
run_test test_missing_manifest_fails_closed
run_test test_no_provider_dockerfile_reported
run_test test_pairs_cli_emits_both_layers

test_done
