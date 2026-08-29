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
#   layer.L1..L6=<PASS|FAIL>
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
    [[ "$line" == layer.L* ]] || continue
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

# Correct-container image-signature (staleness) hard gate (option c): assert the
# running image's baked container-sig matches the recomputed source signature, so
# a stale image fails the dry-run rather than merely warning. Delegates the
# classification to image_is_stale (src/libs/container_sig.sh).
#   $1 image_name  $2 type (sandbox|agent)  $3 repo_root  $4 provider
# Returns 0 with a PASS line on fresh; 1 with a FAIL line on stale/unknown;
# 0 with a WARN line when the gate cannot run (missing inputs / image_is_stale).
dry_run_image_verify() {
  local image_name="$1" type="$2" repo_root="${3:-}" provider="${4:-}"
  local st
  if [[ -z "$repo_root" || -z "$provider" ]]; then
    echo "  RECORD-VERIFY WARN: image-signature gate skipped (repo_root/provider not set)" >&2
    return 0
  fi
  if ! type image_is_stale >/dev/null 2>&1; then
    echo "  RECORD-VERIFY WARN: image-signature gate skipped (image_is_stale unavailable)" >&2
    return 0
  fi
  st="$(image_is_stale "$image_name" "$type" "$repo_root" "$provider")"
  case "$st" in
    fresh)   echo "  RECORD-VERIFY PASS: image $image_name container-sig matches source"; return 0 ;;
    stale)   echo "  RECORD-VERIFY FAIL: image $image_name is image-stale (container-sig != source); rebuild required" >&2; return 1 ;;
    unknown) echo "  RECORD-VERIFY FAIL: image $image_name has no container-sig label (pre-two-sig build); cannot confirm correct image" >&2; return 1 ;;
    *)       echo "  RECORD-VERIFY WARN: image $image_name signature gate unexpected result '$st'" >&2; return 0 ;;
  esac
}