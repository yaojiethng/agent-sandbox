#!/usr/bin/env bash
# scripts/build_probe.sh
# Host-side build probe for the reasoning layer.
#
# The agent's container has no Docker by design, so the build's cache behaviour
# and its cost cannot be measured from inside it. This script runs a small
# perturbation matrix over scripts/build.sh from the host, records what rebuilt
# and what it cost, checks each row against its expected rebuild set, and writes
# one JSON report for the agent to read back on its next run.
#
# Why each row exists is in the ROWS table below. A row whose observed rebuild
# set differs from its expected set is a failure, so a cache that is wrong is
# reported rather than silently measured.
#
# Usage, on the host, from anywhere:
#
#   bash scripts/build_probe.sh
#
# Options:
#   --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
#   --provider=<name>   The provider chain to probe. Default: pi.
#   --project=<name>    The name that tags the tier-3 image. Default: probe.
#
# The report lands at <input-dir>/build/<timestamp>.json, and its row logs and
# docker history dumps beside it in <input-dir>/build/<timestamp>/. The agent
# reads the input channel read-only at /home/agentuser/workspace/input/, so the
# report reaches it at input/build/<timestamp>.json.
#
# It edits two Dockerfiles to perturb the cache key and restores them from a
# backup on exit, including on a failure or an interrupt. It refuses to start
# on a dirty tree, so the restore is checkable.

# Observe-and-report, per bash-coding-conventions rule 1.17: every row runs and
# is counted and the exit status carries the verdict. `set -e` would abort the
# matrix at the first failing row and defeat the report. The flags sit inside
# the execution guard at the foot of this file, so a test that sources the file
# keeps its own shell regime.

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/libs/cli.sh"

PROBE_INPUT_DIR=""
PROBE_PROVIDER="pi"
PROBE_PROJECT="probe"

usage() {
  cat <<'USAGE'
Usage: bash scripts/build_probe.sh [options]

Runs the build perturbation matrix on the host and writes one JSON report to
<input-dir>/build/<timestamp>.json.

Options:
  --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
  --provider=<name>   The provider chain to probe. Default: pi.
  --project=<name>    The name that tags the tier-3 image. Default: probe.
  -h, --help          Print this help.

The script refuses a dirty working tree and restores every Dockerfile it edits.
USAGE
}

# -------------------------
# Output helpers
# -------------------------

say() { echo "build_probe: $*"; }

# A missing tool or an unusable output directory is a finding, not a special
# exit code: report it and exit 1 (bash-coding-conventions rule 3.2).
die() {
  echo "build_probe: ERROR: $*" >&2
  exit 1
}

# json_string TEXT
# A JSON string literal. The host toolchain carries no jq
# (docs/development/host_requirements.md), so the escaping lives here.
json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

# json_array ITEM...
# A JSON array of string literals, one line, empty array when given no item.
json_array() {
  local out="" item
  for item in "$@"; do
    [[ -n "$out" ]] && out+=", "
    out+="$(json_string "$item")"
  done
  printf '[%s]' "$out"
}

# join_commas ITEM...
# The items as one comma-joined line, with no trailing separator.
join_commas() {
  local out="" item
  for item in "$@"; do
    [[ -n "$out" ]] && out+=", "
    out+="$item"
  done
  printf '%s' "$out"
}

# -------------------------
# Identity
# -------------------------

sha256_of() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sha256sum "$file" | awk '{print $1}'
  else
    printf ''
  fi
}

# The reasoning-layer Dockerfiles, in a stable order, one path per line.
reasoning_dockerfiles() {
  find "$REPO_ROOT/src/reasoning" -type f \
    \( -name '*.dockerfile' -o -name 'Dockerfile*' \) | sort
}

# -------------------------
# The build invocation
# -------------------------

# run_build LOG NO_CACHE
# Builds the probed provider's chain through scripts/build.sh and captures
# every line of its output in LOG. Returns the builder's status.
run_build() {
  local log="$1" no_cache="$2"
  local -a args=(
    "--name=$PROBE_PROJECT"
    "--project=$REPO_ROOT"
    "--targets=$PROBE_PROVIDER"
    "--progress=plain"
  )
  [[ "$no_cache" == "true" ]] && args+=(--rebuild)
  bash "$REPO_ROOT/scripts/build.sh" "${args[@]}" >"$log" 2>&1
}

# The image names that rebuilt, from the builder's own progress lines.
log_rebuilt() { sed -n 's/^Building image: //p' "$1"; }
# The image names the builder skipped as up to date.
log_skipped() { sed -n 's/^Image up to date, skipping: //p' "$1"; }
# The per-step DONE lines from `docker build --progress=plain`.
log_steps() { grep -E '^#[0-9]+ DONE ' "$1" || true; }

# The images the log rebuilt, restricted to the three tiers, as a sorted list.
# The order is by image name, so the report reads the same way on every run.
tiers_rebuilt() {
  local log="$1" want
  while read -r image; do
    [[ -n "$image" ]] || continue
    for want in "$SHARED_BASE" "$AGENT_BASE" "$AGENT_IMAGE"; do
      [[ "$image" == "$want" ]] && printf '%s\n' "$image"
    done
  done < <(log_rebuilt "$log") | sort -u
}

# -------------------------
# Perturbation
# -------------------------

PERTURBED_FILE=""
PERTURBED_BACKUP=""

# perturb_backup FILE
# A copy to restore from, kept outside the work tree so the tree stays clean.
perturb_backup() {
  local file="$1"
  PERTURBED_FILE="$file"
  PERTURBED_BACKUP="$PROBE_RUN_DIR/$(basename "$file").orig"
  cp -p "$file" "$PERTURBED_BACKUP"
}

perturb_restore() {
  if [[ -n "$PERTURBED_FILE" && -f "$PERTURBED_BACKUP" ]]; then
    cp -p "$PERTURBED_BACKUP" "$PERTURBED_FILE"
    PERTURBED_FILE=""
    PERTURBED_BACKUP=""
  fi
}

on_exit() {
  local rc=$?
  perturb_restore
  exit "$rc"
}

# -------------------------
# The matrix
# -------------------------

# One row per perturbation. Columns: name, no-cache, perturbation, trigger
# description, and the rebuild set expected of tiers 1, 2 and 3.
#
#   baseline  brings tiers 1 and 2 to their current key, so every later row
#             starts from a known cache state. Its rebuild set is recorded, not
#             asserted, because a cold machine builds and a warm one skips.
#   mtime     touches a tier-2 Dockerfile. The key excludes mtime, so tiers 1
#             and 2 must still skip. This is the row that proves the key reads
#             content rather than the file's identity.
#   content   appends a comment to the tier-1 Dockerfile. Tier 1 must rebuild,
#             and tier 2 must follow through the base image's content id.
#   restore   removes the comment. Tier 1 must rebuild again, because the key
#             it holds describes the perturbed file.
#   no-cache  rebuilds from scratch. Every tier must rebuild.
#
# Expected sets are written for tiers 1, 2 and 3 as the letters of the tiers
# that must rebuild; an empty expectation means the row is recorded only.

ROWS=(
  "baseline|false|none|the tree as it stands|"
  "mtime|false|touch|touched the tier-2 Dockerfile|3"
  "content|false|append|appended a comment to the tier-1 Dockerfile|1,2,3"
  "restore|false|restore|removed the appended comment|1,2,3"
  "no-cache|true|none|the tree as it stands, with --rebuild|1,2,3"
)

# The tier letter of an image name, newline terminated so the letters of two
# images cannot splice together when they are read as lines.
tier_of() {
  case "$1" in
    "$SHARED_BASE") printf '1\n' ;;
    "$AGENT_BASE") printf '2\n' ;;
    "$AGENT_IMAGE") printf '3\n' ;;
    *) printf '?\n' ;;
  esac
}

# The tier letters of the images a log rebuilt, comma joined and sorted, in the
# form the expected sets are written in.
tiers_of_log() {
  tiers_rebuilt "$1" | while read -r image; do
    [[ -n "$image" ]] && tier_of "$image"
  done | sort -u | paste -sd, -
}

# apply_perturbation KIND
apply_perturbation() {
  local kind="$1"
  case "$kind" in
    touch)
      perturb_backup "$AGENT_BASE_DOCKERFILE"
      touch "$AGENT_BASE_DOCKERFILE"
      ;;
    append)
      perturb_backup "$SHARED_BASE_DOCKERFILE"
      printf '# build_probe perturbation %s\n' "$PROBE_STAMP" >>"$SHARED_BASE_DOCKERFILE"
      ;;
    restore)
      [[ -n "$PERTURBED_FILE" ]] || die "the restore row ran with nothing to restore"
      perturb_restore
      ;;
    none) ;;
    *) die "unknown perturbation: $kind" ;;
  esac
}

# -------------------------
# Report
# -------------------------

# One row's JSON object. Every field the row recorded is emitted, so a reader
# never has to infer a value the probe did not take.
row_json() {
  local name="$1" no_cache="$2" trigger="$3" expect="$4"
  local log="$5" seconds="$6" rc="$7"
  local -a rebuilt=() skipped=()
  local image

  while read -r image; do
    [[ -n "$image" ]] && rebuilt+=("$image")
  done < <(tiers_rebuilt "$log")
  while read -r image; do
    [[ -n "$image" ]] && skipped+=("$image")
  done < <(log_skipped "$log" | sort -u)

  local observed_tiers expected_tiers result
  observed_tiers="$(tiers_of_log "$log")"
  expected_tiers="$expect"

  if [[ -z "$expected_tiers" ]]; then
    result="recorded"
  elif [[ "$observed_tiers" == "$expected_tiers" ]]; then
    result="pass"
  else
    result="fail"
  fi

  local -a image_fields=() step_lines=()
  for image in "$SHARED_BASE" "$AGENT_BASE" "$AGENT_IMAGE"; do
    local id label
    id="$(image_digest "$image")"
    label="$(image_label "$image" "agent-sandbox.base-build-key")"
    image_fields+=("\"$image\": {\"id\": $(json_string "$id"), \"build_key\": $(json_string "$label")}")
  done
  while IFS= read -r image; do
    [[ -n "$image" ]] && step_lines+=("$image")
  done < <(log_steps "$log")

  local step_seconds
  step_seconds="$(log_steps "$log" | awk '{s += $NF + 0} END {printf "%.1f", s}')"

  printf '    {\n'
  printf '      "name": %s,\n' "$(json_string "$name")"
  printf '      "trigger": %s,\n' "$(json_string "$trigger")"
  printf '      "no_cache": %s,\n' "$no_cache"
  printf '      "exit_status": %s,\n' "$rc"
  printf '      "wall_seconds": %s,\n' "$seconds"
  printf '      "expect_rebuild_tiers": %s,\n' "$(json_string "$expected_tiers")"
  printf '      "observed_rebuild_tiers": %s,\n' "$(json_string "$observed_tiers")"
  printf '      "rebuilt": %s,\n' "$(json_array "${rebuilt[@]}")"
  printf '      "skipped": %s,\n' "$(json_array "${skipped[@]}")"
  printf '      "step_seconds": %s,\n' "${step_seconds:-0}"
  printf '      "log": %s,\n' "$(json_string "$log")"
  printf '      "images": {%s},\n' "$(join_commas "${image_fields[@]}")"
  printf '      "result": %s\n' "$(json_string "$result")"
  printf '    }'
}

# -------------------------
# Main
# -------------------------

main() {
  parse_args usage \
    --input-dir=PROBE_INPUT_DIR \
    --provider=PROBE_PROVIDER \
    --project=PROBE_PROJECT \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  command -v docker >/dev/null 2>&1 || die "docker is not on PATH; the probe needs it"
  command -v git >/dev/null 2>&1 || die "git is not on PATH"

  [[ -n "$PROBE_INPUT_DIR" ]] || PROBE_INPUT_DIR="${INPUT_DIR:-}"
  [[ -n "$PROBE_INPUT_DIR" ]] || die "no output directory: set \$INPUT_DIR or pass --input-dir=<path>"
  [[ -d "$PROBE_INPUT_DIR" ]] || die "output directory does not exist: $PROBE_INPUT_DIR"
  [[ -w "$PROBE_INPUT_DIR" ]] || die "output directory is not writable: $PROBE_INPUT_DIR"

  local dirty
  dirty="$(git -C "$REPO_ROOT" status --porcelain)"
  [[ -z "$dirty" ]] || die "the working tree is dirty; commit or stash first, so the Dockerfile restore is checkable"

  PROBE_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  PROBE_RUN_DIR="$PROBE_INPUT_DIR/build/$PROBE_STAMP"
  local report="$PROBE_INPUT_DIR/build/$PROBE_STAMP.json"
  mkdir -p "$PROBE_RUN_DIR" || die "could not create $PROBE_RUN_DIR"

  trap on_exit EXIT

  SHARED_BASE="$(shared_base_image_name)"
  AGENT_BASE="$(agent_base_image_name "$PROBE_PROVIDER")"
  AGENT_IMAGE="$(agent_image_name "$PROBE_PROVIDER" "$PROBE_PROJECT")"
  SHARED_BASE_DOCKERFILE="$REPO_ROOT/src/reasoning/base.dockerfile"
  AGENT_BASE_DOCKERFILE="$REPO_ROOT/src/reasoning/providers/$PROBE_PROVIDER/base.dockerfile"
  [[ -f "$AGENT_BASE_DOCKERFILE" ]] || die "no base Dockerfile for provider: $PROBE_PROVIDER"

  say "provider $PROBE_PROVIDER, images $SHARED_BASE, $AGENT_BASE, $AGENT_IMAGE"
  say "report $report"

  local -a row_json_blocks=() failures=()
  local row name no_cache kind trigger expect log start end seconds status observed

  for row in "${ROWS[@]}"; do
    IFS='|' read -r name no_cache kind trigger expect <<<"$row"
    log="$PROBE_RUN_DIR/$name.log"
    say "row $name: $trigger"

    apply_perturbation "$kind"

    start="$SECONDS"
    run_build "$log" "$no_cache"
    status=$?
    end="$SECONDS"
    seconds=$(( end - start ))

    if [[ $status -ne 0 ]]; then
      failures+=("$name: the build exited $status, see $log")
    fi

    observed="$(tiers_of_log "$log")"

    if [[ $status -eq 0 ]]; then
      if [[ -n "$expect" && "$observed" != "$expect" ]]; then
        failures+=("$name: expected to rebuild tiers $expect, saw $observed (see $log)")
      fi
    fi

    # The restore perturbation clears itself inside the row; a backup left over
    # means the restore row did not run and the trap must undo the edit.
    if [[ "$kind" == "append" ]]; then
      : # keep the edit until the restore row
    elif [[ "$kind" == "touch" ]]; then
      perturb_restore
    fi

    for image in "$SHARED_BASE" "$AGENT_BASE" "$AGENT_IMAGE"; do
      docker history --no-trunc "$image" >"$PROBE_RUN_DIR/$name.history.$image.txt" 2>/dev/null || true
    done

    row_json_blocks+=("$(row_json "$name" "$no_cache" "$trigger" "$expect" "$log" "$seconds" "$status")")
    say "  rebuilt: ${observed:-none} (expected ${expect:-recorded}), ${seconds}s"
  done

  perturb_restore

  local restored_dirty
  restored_dirty="$(git -C "$REPO_ROOT" status --porcelain)"
  [[ -z "$restored_dirty" ]] || failures+=("the working tree is dirty after the restore: $restored_dirty")

  local verdict="pass"
  (( ${#failures[@]} > 0 )) && verdict="fail"

  {
    printf '{\n'
    printf '  "probe": "build_probe",\n'
    printf '  "format": 1,\n'
    printf '  "timestamp": %s,\n' "$(json_string "$PROBE_STAMP")"
    printf '  "verdict": %s,\n' "$(json_string "$verdict")"
    printf '  "repo": {"root": %s, "head": %s, "dirty_at_start": false},\n' \
      "$(json_string "$REPO_ROOT")" "$(json_string "$(git -C "$REPO_ROOT" rev-parse HEAD)")"
    printf '  "host": {"uname": %s, "docker": %s},\n' \
      "$(json_string "$(uname -srm)")" "$(json_string "$(docker --version)")"
    printf '  "provider": %s,\n' "$(json_string "$PROBE_PROVIDER")"
    printf '  "project": %s,\n' "$(json_string "$PROBE_PROJECT")"
    printf '  "images": {"tier1": %s, "tier2": %s, "tier3": %s},\n' \
      "$(json_string "$SHARED_BASE")" "$(json_string "$AGENT_BASE")" "$(json_string "$AGENT_IMAGE")"
    printf '  "dockerfiles": [\n'
    local first=true path
    while IFS= read -r path; do
      [[ -n "$path" ]] || continue
      $first || printf ',\n'
      first=false
      printf '    {"path": %s, "sha256": %s}' \
        "$(json_string "${path#"$REPO_ROOT"/}")" "$(json_string "$(sha256_of "$path")")"
    done < <(reasoning_dockerfiles)
    printf '\n  ],\n'
    printf '  "rows": [\n'
    local block idx=0
    for block in "${row_json_blocks[@]}"; do
      (( idx > 0 )) && printf ',\n'
      printf '%s' "$block"
      idx=$(( idx + 1 ))
    done
    printf '\n  ],\n'
    printf '  "failures": %s\n' "$(json_array "${failures[@]}")"
    printf '}\n'
  } >"$report"

  say "wrote $report"
  if [[ "$verdict" == "fail" ]]; then
    say "VERDICT: fail"
    local f
    for f in "${failures[@]}"; do say "  $f"; done
    exit 1
  fi
  say "VERDICT: pass"
}

# Sourced by tests/test_build_probe.sh, and executed by the operator. The
# guard separates the two modes, per bash-coding-conventions rule 3.3.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  main "$@"
fi
