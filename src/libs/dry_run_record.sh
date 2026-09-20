#!/usr/bin/env bash
# libs/dry_run_record.sh
#
# Read/validate the per-container diagnostics record that the dry-run bearer
# probes (dry_run_capability.sh / dry_run_reasoning.sh) write to the output
# mount. Orchestration consumes these records (not probe stdout) to assert
# that the correct container was started, per the readiness model in
# devlog/discussions/20260828-design-settled-dry_run_phase_split.md.
#
# Record format (key=value lines, one per line):
#   container=<identity echo-back injected via DRY_RUN_IDENTITY>
#   layer.<name>=<PASS|FAIL>       (names: docker_image workspace_mounts session_state session_data container_network agent_runtime)
#   status=<PASS|FAIL>
#
# Functions:
#   dry_run_record_value <record> <key>    - echo the value for a key (or empty)
#   dry_run_record_verify <name> <expected_identity> <record>
#       - print RECORD-VERIFY PASS/FAIL lines; return 0 iff identity matches,
#         overall status is PASS, and every layer reported PASS.

dry_run_record_value() {
  local record="$1" key="$2"
  awk -F= -v k="$key" '$1==k{print $2}' "$record" 2>/dev/null
}

dry_run_record_verify() {
  local name="$1" expected="$2" record="$3"
  local fails=0
  if [[ ! -f "$record" ]]; then
    echo "  RECORD-VERIFY FAIL: $name record missing: $record" >&2
    return 1
  fi

  local container status layer st line
  container="$(dry_run_record_value "$record" "container")"
  status="$(dry_run_record_value "$record" "status")"

  if [[ "$container" == "$expected" ]]; then
    echo "  RECORD-VERIFY PASS: $name identity matched ($container)"
  else
    echo "  RECORD-VERIFY FAIL: $name identity expected '$expected' got '$container'" >&2
    fails=$(( fails + 1 ))
  fi

  if [[ "$status" == "PASS" ]]; then
    echo "  RECORD-VERIFY PASS: $name overall status PASS"
  else
    echo "  RECORD-VERIFY FAIL: $name overall status '$status'" >&2
    fails=$(( fails + 1 ))
  fi

  while IFS= read -r line; do
    [[ "$line" == layer.* ]] || continue
    layer="${line%%=*}"; st="${line#*=}"
    if [[ "$st" != "FAIL" ]]; then
      echo "  RECORD-VERIFY PASS: $name $layer = $st"
    else
      echo "  RECORD-VERIFY FAIL: $name $layer = FAIL" >&2
      fails=$(( fails + 1 ))
    fi
  done < "$record"

  if [[ "$fails" -eq 0 ]]; then
    return 0
  fi
  return 1
}

# Digest roundtrip hard gate (ADR harness_versioning.md): the digest stamped
# into the generated compose file at generation time (post-build) must equal
# the digest of the image that will run. A rebuild between generation and run
# changes the image ID and fails the gate, so a dry-run can never execute on
# anything but the exact images this invocation built. Same label source as
# make start / resume --list (compose labels via record_label).
#   $1 image_name  $2 compose_file  $3 type (sandbox|agent)
dry_run_image_verify() {
  local image_name="$1" compose_file="$2" type="$3"
  local stamped current
  # record_label equivalent, inlined -- dry_run_record.sh has no dependency on
  # session_inventory.sh.
  stamped="$(grep -m1 -E '[[:space:]]*agent-sandbox.'"$type"'-image-digest:' "$compose_file" \
    | sed -E 's/.*'"$type"'-image-digest:[[:space:]]*//' || true)"
  if [[ -z "$stamped" ]]; then
    echo "  RECORD-VERIFY FAIL: compose file $compose_file carries no $type-image-digest label; cannot run the roundtrip gate" >&2
    return 1
  fi
  current="$(image_digest "$image_name")"
  if [[ -z "$current" ]]; then
    echo "  RECORD-VERIFY FAIL: image $image_name is no longer present in the local daemon (pruned?) -- the record names content that does not exist locally." >&2
    echo "  Remediation: rebuild the images (make build) and re-run; the record's digest cannot resolve to a missing image." >&2
    return 1
  fi
  if [[ "$stamped" == "$current" ]]; then
    echo "  RECORD-VERIFY PASS: image $image_name digest matches the record (roundtrip)"
    return 0
  fi
  echo "  RECORD-VERIFY FAIL: image $image_name digest changed since the record was written (rebuild during the run?); roundtrip gate failed" >&2
  return 1
}