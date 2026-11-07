#!/usr/bin/env bash
# scripts/build_probe.sh
# Host-side recorder for the reasoning layer's production run. The agent's
# container has no Docker by design, so the host runs one build and the report
# crosses the read-only input channel. The report's fields, the model and the
# deferred signals are in docs/development/build_operational_model.md.

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/build/image.sh"
source "$REPO_ROOT/src/libs/cli.sh"

PROBE_INPUT_DIR=""
REBUILD=false
PROBE_PROVIDER="pi"
PROBE_PROJECT="probe"
PROBE_LABEL=""

usage() {
  cat <<'USAGE'
Usage: bash scripts/build_probe.sh [options]

Runs one build on the host and records it as JSON at
<input-dir>/build/<timestamp>.json.

Options:
  --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
  --provider=<name>   The provider chain to record. Default: pi.
  --project=<name>    The name that tags the tier-3 image. Default: probe.
  --label=<text>      A label for the run, e.g. baseline or delta.
  --rebuild           Pass --no-cache to every tier through build.sh.
  -h, --help          Print this help.

The script mutates no file; the tree it reads is the tree it reports.
USAGE
}

# -------------------------
# Output helpers
# -------------------------

say() { echo "build_probe: $*"; }

die() {
  echo "build_probe: ERROR: $*" >&2
  exit 1
}

# The host toolchain carries no jq (docs/development/host_requirements.md).
json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

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

reasoning_dockerfiles() {
  find "$REPO_ROOT/src/reasoning" -type f \
    \( -name '*.dockerfile' -o -name 'Dockerfile*' \) | sort
}

image_size() {
  docker image inspect --format '{{.Size}}' "$1" 2>/dev/null || printf '0'
}

git_head() { git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null; }
host_uname() { uname -srm; }
docker_version() { docker --version 2>/dev/null; }

# -------------------------
# The build invocation
# -------------------------

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

# The builder prints `Building image: <name>` before each tier's build, so that
# line opens a segment. Only a step that changes the filesystem decides the
# state: an internal load, the image export and the FROM resolve all print DONE
# on a fully cached build, so their DONE says nothing about the cache. Every
# DONE duration is the tier's step seconds.
tier_records() {
  awk '
    function flush(   i, state, secs) {
      if (image == "" || nsteps == 0) return
      state = "cached"
      for (i = 1; i <= nsteps; i++) if (deciding[stepid[i]] && done[stepid[i]]) state = "ran"
      secs = 0
      for (i = 1; i <= ndone; i++) secs += dur[i]
      printf "%s|%s|%.1f\n", image, state, secs
    }
    /^Building image: / {
      flush()
      image = $0
      sub(/^Building image: /, "", image)
      nsteps = 0
      ndone = 0
      split("", stepid)
      split("", deciding)
      split("", done)
      split("", dur)
      next
    }
    $1 ~ /^#[0-9]+$/ {
      id = substr($1, 2)
      if ($0 ~ /^#[0-9]+ \[[0-9]+[/][0-9]+\]/) {
        cmd = $0
        sub(/^#[0-9]+ \[[0-9]+[/][0-9]+\] /, "", cmd)
        if (cmd ~ /^(RUN|COPY|ADD)( |$)/) deciding[id] = 1
        stepid[++nsteps] = id
        next
      }
      if ($2 == "DONE") { dur[++ndone] = $NF + 0; if (deciding[id]) done[id] = 1 }
      next
    }
    END { flush() }
  ' "$1"
}

tier_cache_state() {
  local log="$1" image="$2" state
  state="$(tier_records "$log" | awk -F'|' -v img="$image" '$1 == img {print $2; exit}')"
  printf '%s\n' "${state:-unobserved}"
}

tier_step_seconds() {
  local log="$1" image="$2" secs
  secs="$(tier_records "$log" | awk -F'|' -v img="$image" '$1 == img {print $3; exit}')"
  printf '%s\n' "${secs:-0.0}"
}

tier_of() {
  case "$1" in
    "$SHARED_BASE") printf '1\n' ;;
    "$AGENT_BASE") printf '2\n' ;;
    "$AGENT_IMAGE") printf '3\n' ;;
    *) printf '?\n' ;;
  esac
}

# -------------------------
# Report
# -------------------------

tier_json() {
  local name="$1" tier="$2" id="$3" size="$4" state="$5" secs="$6"
  printf '{"name": %s, "tier": %s, "id": %s, "size_bytes": %s, "cache_state": %s, "step_seconds": %s}' \
    "$(json_string "$name")" "$tier" "$(json_string "$id")" "${size:-0}" \
    "$(json_string "$state")" "${secs:-0.0}"
}

# main sets the globals; a test sets them to check the schema.
emit_report() {
  local report="$1"
  shift
  local -a tier_blocks=("$@")

  {
    printf '{\n'
    printf '  "probe": "build_probe",\n'
    printf '  "format": 2,\n'
    printf '  "timestamp": %s,\n' "$(json_string "$PROBE_STAMP")"
    printf '  "label": %s,\n' "$(json_string "$PROBE_LABEL")"
    printf '  "repo": {"root": %s, "head": %s, "dirty": %s},\n' \
      "$(json_string "$REPO_ROOT")" "$(json_string "$(git_head)")" "$PROBE_REPO_DIRTY"
    printf '  "host": {"uname": %s, "docker": %s},\n' \
      "$(json_string "$(host_uname)")" "$(json_string "$(docker_version)")"
    printf '  "provider": %s,\n' "$(json_string "$PROBE_PROVIDER")"
    printf '  "project": %s,\n' "$(json_string "$PROBE_PROJECT")"
    printf '  "run": {"no_cache": %s, "exit_status": %s, "wall_seconds": %s, "error": %s, "log": %s},\n' \
      "$REBUILD" "$PROBE_RUN_STATUS" "$PROBE_WALL_SECONDS" \
      "$(json_string "$PROBE_ERROR")" "$(json_string "$PROBE_LOG")"
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
    printf '  "tiers": [\n'
    local block idx=0
    for block in "${tier_blocks[@]}"; do
      (( idx > 0 )) && printf ',\n'
      printf '    %s' "$block"
      idx=$(( idx + 1 ))
    done
    printf '\n  ]\n'
    printf '}\n'
  } >"$report"
}

# -------------------------
# Main
# -------------------------

main() {
  parse_args usage \
    --input-dir=PROBE_INPUT_DIR \
    --provider=PROBE_PROVIDER \
    --project=PROBE_PROJECT \
    --label=PROBE_LABEL \
    --rebuild \
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

  PROBE_STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  local run_dir="$PROBE_INPUT_DIR/build/$PROBE_STAMP"
  local report="$PROBE_INPUT_DIR/build/$PROBE_STAMP.json"
  mkdir -p "$run_dir" || die "could not create $run_dir"
  PROBE_LOG="$run_dir/build.log"

  SHARED_BASE="$(shared_base_image_name)"
  AGENT_IMAGE="$(agent_image_name "$PROBE_PROVIDER" "$PROBE_PROJECT")"
  local provider_base_dockerfile="$REPO_ROOT/src/reasoning/agent-runtime/$PROBE_PROVIDER/base.dockerfile"
  if [[ -f "$provider_base_dockerfile" ]]; then
    AGENT_BASE="$(agent_base_image_name "$PROBE_PROVIDER")"
  else
    AGENT_BASE="$(runtimes_base_image_name)"
  fi

  PROBE_REPO_DIRTY=false
  [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]] && PROBE_REPO_DIRTY=true

  say "provider $PROBE_PROVIDER, images $SHARED_BASE, $AGENT_BASE, $AGENT_IMAGE"
  say "report $report"

  local start="$SECONDS"
  run_build "$PROBE_LOG" "$REBUILD"
  PROBE_RUN_STATUS=$?
  PROBE_WALL_SECONDS=$(( SECONDS - start ))
  PROBE_ERROR="$(grep -E 'ERROR|FAILED' "$PROBE_LOG" | tail -1 || true)"

  local -a tier_blocks=()
  local image tier state secs id size
  for image in "$SHARED_BASE" "$AGENT_BASE" "$AGENT_IMAGE"; do
    tier="$(tier_of "$image")"
    state="$(tier_cache_state "$PROBE_LOG" "$image")"
    secs="$(tier_step_seconds "$PROBE_LOG" "$image")"
    id="$(image_digest "$image")"
    size="$(image_size "$image")"
    tier_blocks+=("$(tier_json "$image" "$tier" "$id" "$size" "$state" "$secs")")
    docker history --no-trunc "$image" >"$run_dir/history.$image.txt" 2>/dev/null || true
  done

  emit_report "$report" "${tier_blocks[@]}"

  say "wrote $report"
  if [[ $PROBE_RUN_STATUS -ne 0 ]]; then
    say "VERDICT: build failed ($PROBE_RUN_STATUS); see $PROBE_LOG"
    exit "$PROBE_RUN_STATUS"
  fi
  say "VERDICT: recorded"
}

# Sourced by the test, executed by the operator (pattern p-15).
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  main "$@"
fi
