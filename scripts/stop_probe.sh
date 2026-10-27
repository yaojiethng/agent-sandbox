#!/usr/bin/env bash
# scripts/stop_probe.sh
# Host-side stop forensics probe for `make stop`.
#
# `make stop` blocks after its banner and returns only on Ctrl-C. The agent's
# container has no Docker by design, so where the block lives cannot be seen
# from inside it. This script runs on the host, inspects the stop path without
# changing anything, optionally performs the stop under a timing wrapper, and
# writes one JSON report plus raw artifact logs for the agent to read back.
#
# Usage, on the host, from anywhere:
#
#   bash scripts/stop_probe.sh --sandbox=<path> [--name=<project>] [--input-dir=<path>]
#   bash scripts/stop_probe.sh --sandbox=<path> --perform-stop [--stop-grace=<seconds>]
#
# Options:
#   --name=<project>    The project name. Default: the sandbox dir's basename.
#   --sandbox=<path>    The sandbox directory. Required.
#   --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
#   --perform-stop      Run the stop and capture the event window. Without it
#                       the probe is read-only and stops, removes, or creates
#                       nothing.
#   --stop-grace=<secs> Bound the stop invocation with `timeout <secs>`. When
#                       unset, no timeout flag is passed.
#
# The report lands at <input-dir>/stop/<timestamp>.json, and its raw logs beside
# it in <input-dir>/stop/<timestamp>/. The agent reads the input channel
# read-only at /home/agentuser/workspace/input/, so the report reaches it at
# input/stop/<timestamp>.json.
#
# Every check runs and is counted; a failing check never aborts the capture.

# Observe-and-report, per pattern p-11: every check runs and
# the exit status carries the verdict. `set -e` would abort the capture at the
# first failing check and defeat the report. The flags sit inside the execution
# guard at the foot of this file, so a test that sources the file keeps its own
# shell regime.

_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$_self_dir/.." && pwd)"

source "$REPO_ROOT/src/libs/common.sh"
source "$REPO_ROOT/src/libs/cli.sh"
source "$REPO_ROOT/src/libs/dirs.sh"

PROBE_INPUT_DIR=""
PROBE_NAME=""
PROBE_SANDBOX=""
STOP_GRACE=""
PERFORM_STOP=false
SESSION_ID=""
ALL_SESSIONS=false
MATCHED_SESSION_IDS=()

CANON_SANDBOX=""
MODE=""
STAMP=""
RUN_DIR=""
REPO_HEAD=""
REPO_BRANCH=""
INSTALLED_STOP=""
GRACE_USED=""
CAL_CONTAINER=""
STOP_CAPTURED=false
STOP_T0=""
STOP_T1=""
STOP_RC=""
STOP_SCRIPT=""
STOP_ERROR=""
STOP_REFUSED=false

FAILURES=()
CHECK_BLOCKS=()
CONTAINER_IDS=()

IDENTITY_JSON="{}"
COMPOSE_JSON="[]"
ENGINE_JSON="{}"
CONTAINERS_JSON="[]"
EVENTS_JSON="[]"
STOP_CALLS_JSON="[]"
CALIBRATION_JSON="{}"

usage() {
  cat <<'USAGE'
Usage: bash scripts/stop_probe.sh [options]

Captures host-side evidence for where `make stop` blocks and writes one JSON
report to <input-dir>/stop/<timestamp>.json.

Options:
  --name=<project>    Project name. Default: the sandbox dir's basename.
  --sandbox=<path>    Path to the sandbox directory. Required.
  --input-dir=<path>  Where to write the report. Defaults to $INPUT_DIR.
  --session-id=<id>   Scope the capture and the stop to one session. Without it
                      every session in the sandbox is matched.
  --perform-stop      Run the stop and capture the event window. Without it the
                      probe is read-only and changes nothing.
  --all-sessions      Allow --perform-stop to stop every matched session. Without
                      this or --session-id, a capture that would stop more than
                      one session is refused before anything is stopped.
  --stop-grace=<secs> Bound the stop invocation with `timeout <secs>`.
  -h, --help          Print this help.

A failing check is recorded and never aborts the capture. The exit status is 0
when every check is PASS or INCONCLUSIVE, and 1 when the verdict is FAIL.
USAGE
}

# -------------------------
# Output helpers
# -------------------------

say() { echo "stop_probe: $*"; }

# A missing tool or an unusable output directory is a finding, not a special
# exit code: report it and exit 1 (pattern p-14).
die() {
  echo "stop_probe: ERROR: $*" >&2
  exit 1
}

have() { command -v "$1" >/dev/null 2>&1; }

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

# sha256_of FILE
sha256_of() {
  local file="$1"
  if [[ -f "$file" ]]; then
    sha256sum "$file" | awk '{print $1}'
  else
    printf ''
  fi
}

# mtime_of PATH
mtime_of() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf ''
    return 0
  fi
  stat -c '%y' "$path" 2>/dev/null || stat -f '%Sm' -t '%Y-%m-%dT%H:%M:%S' "$path" 2>/dev/null || printf ''
}

# wsl_present
wsl_present() {
  if have wsl.exe; then printf 'true'; else printf 'false'; fi
}

# -------------------------
# Check rows and their evidence sections
# -------------------------

# check_json NAME RESULT DETAIL EVIDENCE
# One check's JSON object. Emitted with printf so every interpolated value is
# escaped through json_string.
check_json() {
  local name="$1" result="$2" detail="$3" evidence="$4"
  printf '    {\n'
  printf '      "name": %s,\n' "$(json_string "$name")"
  printf '      "result": %s,\n' "$(json_string "$result")"
  printf '      "detail": %s,\n' "$(json_string "$detail")"
  printf '      "evidence": %s\n' "$(json_string "$evidence")"
  printf '    }'
}

# add_check NAME RESULT DETAIL EVIDENCE
# Appends the row in execution order and records a FAIL in the failure list. The
# verdict is derived once, at the end, from that list.
add_check() {
  local name="$1" result="$2" detail="$3" evidence="$4"
  CHECK_BLOCKS+=("$(check_json "$name" "$result" "$detail" "$evidence")")
  if [[ "$result" == "FAIL" ]]; then
    FAILURES+=("$name: $detail")
  fi
}

# -------------------------
# identity
# -------------------------

check_identity() {
  local log="$RUN_DIR/identity.log"
  : > "$log"

  local head branch dirty dirty_count
  head="$(git -C "$REPO_ROOT" rev-parse HEAD 2>>"$log")"
  branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>>"$log")"
  dirty="$(git -C "$REPO_ROOT" status --porcelain 2>>"$log")"
  if [[ -z "$dirty" ]]; then
    dirty_count=0
  else
    dirty_count="$(printf '%s\n' "$dirty" | wc -l)"
    dirty_count="${dirty_count//[[:space:]]/}"
  fi

  local cli_path cli_real cli_sha cli_mtime installed_stop installed_sha
  local repo_stop="$REPO_ROOT/scripts/stop.sh" repo_sha
  cli_path=""
  cli_real=""
  cli_sha=""
  cli_mtime=""
  installed_stop=""
  installed_sha=""
  repo_sha=""
  INSTALLED_STOP=""

  if have agent-sandbox; then
    cli_path="$(command -v agent-sandbox 2>/dev/null)"
  fi
  if [[ -n "$cli_path" ]]; then
    cli_real="$(readlink -f "$cli_path" 2>/dev/null)"
    if [[ -n "$cli_real" ]]; then
      cli_sha="$(sha256_of "$cli_real")"
      cli_mtime="$(mtime_of "$cli_real")"
      local installed_repo
      installed_repo="$(cd "$(dirname "$cli_real")/.." 2>/dev/null && pwd)"
      if [[ -n "$installed_repo" ]]; then
        installed_stop="$installed_repo/scripts/stop.sh"
        INSTALLED_STOP="$installed_stop"
      fi
    fi
  fi
  installed_sha="$(sha256_of "$installed_stop")"
  repo_sha="$(sha256_of "$repo_stop")"

  {
    printf 'head: %s\n' "$head"
    printf 'branch: %s\n' "$branch"
    printf 'dirty_lines: %s\n' "$dirty_count"
    printf 'installed_cli: %s\n' "$cli_path"
    printf 'installed_cli_real: %s\n' "$cli_real"
    printf 'installed_cli_sha256: %s\n' "$cli_sha"
    printf 'installed_stop: %s\n' "$installed_stop"
    printf 'installed_stop_sha256: %s\n' "$installed_sha"
    printf 'repo_stop: %s\n' "$repo_stop"
    printf 'repo_stop_sha256: %s\n' "$repo_sha"
  } >>"$log"

  local result detail evidence
  evidence="$installed_stop"
  if [[ -z "$cli_path" ]]; then
    result="INCONCLUSIVE"
    detail="no agent-sandbox shim on PATH"
    evidence="$log"
  elif [[ -n "$installed_sha" && "$installed_sha" == "$repo_sha" ]]; then
    result="PASS"
    detail="installed stop.sh matches the repo under review (${repo_sha})"
  elif [[ -n "$installed_sha" ]]; then
    result="FAIL"
    detail="installed stop.sh sha256 ${installed_sha} differs from repo ${repo_sha}; the code that ran is not the code under review"
  else
    result="INCONCLUSIVE"
    detail="the installed CLI resolved, but its scripts/stop.sh could not be read"
    evidence="$cli_real"
  fi

  IDENTITY_JSON="$(
    {
      printf '{'
      printf '"head": %s, ' "$(json_string "$head")"
      printf '"branch": %s, ' "$(json_string "$branch")"
      printf '"dirty_lines": %s, ' "$dirty_count"
      printf '"installed_cli": %s, ' "$(json_string "$cli_path")"
      printf '"installed_cli_real": %s, ' "$(json_string "$cli_real")"
      printf '"installed_cli_sha256": %s, ' "$(json_string "$cli_sha")"
      printf '"installed_cli_mtime": %s, ' "$(json_string "$cli_mtime")"
      printf '"installed_stop": %s, ' "$(json_string "$installed_stop")"
      printf '"installed_stop_sha256": %s, ' "$(json_string "$installed_sha")"
      printf '"repo_stop": %s, ' "$(json_string "$repo_stop")"
      printf '"repo_stop_sha256": %s' "$(json_string "$repo_sha")"
      printf '}'
    }
  )"

  add_check identity "$result" "$detail" "$evidence"
}

# -------------------------
# compose_records
# -------------------------

check_compose_records() {
  local log="$RUN_DIR/compose_records.log"
  : > "$log"

  local dir="$CANON_SANDBOX/.compose"
  local -a records=()
  local any_grace=false grace_values=""
  local f

  for f in "$dir"/*.yml; do
    [[ -e "$f" ]] || continue
    local mt has_grace has_signal grace_val
    mt="$(mtime_of "$f")"
    has_grace=false
    has_signal=false
    grace_val=""
    if grep -q 'stop_grace_period' "$f"; then
      has_grace=true
      grace_val="$(sed -n 's/^[[:space:]]*stop_grace_period:[[:space:]]*//p' "$f" | head -n1)"
      any_grace=true
      grace_values+="${grace_val} "
    fi
    if grep -q 'stop_signal' "$f"; then
      has_signal=true
    fi
    records+=("{\"path\": $(json_string "$f"), \"mtime\": $(json_string "$mt"), \"has_stop_grace_period\": $has_grace, \"stop_grace_period\": $(json_string "$grace_val"), \"has_stop_signal\": $has_signal}")
    printf '%s grace=%s value=%s signal=%s\n' "$f" "$has_grace" "$grace_val" "$has_signal" >>"$log"
  done

  COMPOSE_JSON="[$(join_commas "${records[@]}")]"

  local result detail evidence
  evidence="$dir"
  if [[ "$any_grace" == true ]]; then
    result="INCONCLUSIVE"
    detail="a compose record sets stop_grace_period=${grace_values% }"
  elif [[ ${#records[@]} -eq 0 ]]; then
    result="INCONCLUSIVE"
    detail="no .compose record under ${dir}; nothing to inspect"
  else
    result="PASS"
    detail="${#records[@]} .compose record(s), none sets stop_grace_period"
  fi
  add_check compose_records "$result" "$detail" "$evidence"
}

# -------------------------
# engine
# -------------------------

check_engine() {
  local log="$RUN_DIR/engine.log"
  : > "$log"

  local uname_out wsl
  uname_out="$(uname -srm 2>/dev/null)"
  wsl="$(wsl_present)"

  local docker_present=false client="" server="" dinfv="" ditype=""
  local cgroup="" ncpu="" rootdir="" context_out=""

  local result detail
  if ! have docker; then
    result="FAIL"
    detail="docker is not on PATH"
  else
    docker_present=true
    local ver_out ver_rc info_out info_rc ctx_out ctx_rc
    ver_out="$(docker version --format '{{.Client.Version}} {{.Server.Version}}' 2>&1)"
    ver_rc=$?
    info_out="$(docker info --format '{{.ServerVersion}}|{{.OSType}}|{{.CgroupDriver}}|{{.NCPU}}|{{.DockerRootDir}}' 2>&1)"
    info_rc=$?
    ctx_out="$(docker context ls 2>&1)"
    ctx_rc=$?
    context_out="$ctx_out"
    if [[ $ver_rc -eq 0 ]]; then
      read -r client server <<<"$ver_out"
    fi
    if [[ $info_rc -eq 0 ]]; then
      IFS='|' read -r dinfv ditype cgroup ncpu rootdir <<<"$info_out"
    fi
    printf 'uname: %s\n' "$uname_out" >>"$log"
    printf 'version rc=%s: %s\n' "$ver_rc" "$ver_out" >>"$log"
    printf 'info rc=%s: %s\n' "$info_rc" "$info_out" >>"$log"
    printf 'context rc=%s:\n%s\n' "$ctx_rc" "$ctx_out" >>"$log"
    if [[ $ver_rc -eq 0 && -n "$client" && -n "$server" ]]; then
      result="PASS"
      detail="client ${client}, server ${server}"
    else
      result="FAIL"
      detail="docker version failed (rc=${ver_rc}): ${ver_out}"
    fi
  fi

  ENGINE_JSON="$(
    {
      printf '{'
      printf '"docker_present": %s, ' "$docker_present"
      printf '"client_version": %s, ' "$(json_string "$client")"
      printf '"server_version": %s, ' "$(json_string "$server")"
      printf '"server_version_info": %s, ' "$(json_string "$dinfv")"
      printf '"os_type": %s, ' "$(json_string "$ditype")"
      printf '"cgroup_driver": %s, ' "$(json_string "$cgroup")"
      printf '"ncpu": %s, ' "$(json_string "$ncpu")"
      printf '"docker_root_dir": %s, ' "$(json_string "$rootdir")"
      printf '"context": %s, ' "$(json_string "$context_out")"
      printf '"uname": %s, ' "$(json_string "$uname_out")"
      printf '"wsl_exe": %s' "$wsl"
      printf '}'
    }
  )"

  add_check engine "$result" "$detail" "$log"
}

# -------------------------
# containers
# -------------------------

check_containers() {
  local log="$RUN_DIR/containers.log"
  : > "$log"
  : > "$RUN_DIR/inspect.txt"
  : > "$RUN_DIR/containers.txt"

  local result detail
  if ! have docker; then
    CONTAINERS_JSON="[]"
    add_check containers INCONCLUSIVE "docker is not on PATH" "$RUN_DIR/containers.txt"
    return 0
  fi

  local ids_out ps_rc
  local -a label_filters=(
    --filter "label=agent-sandbox.project-name=${PROBE_NAME}"
    --filter "label=agent-sandbox.sandbox-dir=${CANON_SANDBOX}"
  )
  if [[ -n "$SESSION_ID" ]]; then
    label_filters+=(--filter "label=agent-sandbox.session-id=${SESSION_ID}")
  fi
  ids_out="$(docker ps -aq "${label_filters[@]}" 2>&1)"
  ps_rc=$?
  printf 'docker ps rc=%s: %s\n' "$ps_rc" "$ids_out" >>"$log"
  if [[ $ps_rc -ne 0 ]]; then
    CONTAINERS_JSON="[]"
    add_check containers INCONCLUSIVE "docker ps failed: ${ids_out}" "$RUN_DIR/containers.txt"
    return 0
  fi

  CONTAINER_IDS=()
  mapfile -t CONTAINER_IDS <<<"$ids_out"
  if [[ ${#CONTAINER_IDS[@]} -eq 1 && -z "${CONTAINER_IDS[0]}" ]]; then
    CONTAINER_IDS=()
  fi
  printf '%s\n' "${CONTAINER_IDS[@]}" | sed '/^$/d' >"$RUN_DIR/containers.txt"

  if [[ ${#CONTAINER_IDS[@]} -eq 0 ]]; then
    CONTAINERS_JSON="[]"
    add_check containers INCONCLUSIVE "no containers found for ${PROBE_NAME}" "$RUN_DIR/containers.txt"
    return 0
  fi

  # One field format, pipe-delimited, because a value cannot contain a pipe for
  # these fields and a delimiter failure then shows up as an empty field rather
  # than as a silent misread. A table output is additionally written to
  # inspect.txt and echoed, so the operator's terminal carries the evidence
  # without opening the report.
  local fmt='{{.Name}}|{{.State.Status}}|{{.State.ExitCode}}|{{.Config.StopSignal}}|{{.State.FinishedAt}}|{{.Path}}'
  local -a cjson=()
  local any_running=false bad="" running_count=0 unreadable=""
  local e137=0 e143=0 e0=0 other=0
  local id line sid inspect_rc
  for id in "${CONTAINER_IDS[@]}"; do
    inspect_rc=0
    line="$(docker inspect --format "$fmt" "$id" 2>>"$log")" || inspect_rc=$?
    local cname cstatus cexit csig cfinish cpath
    IFS='|' read -r cname cstatus cexit csig cfinish cpath <<<"$line"
    cname="${cname#/}"
    sid="$(docker inspect --format '{{index .Config.Labels "agent-sandbox.session-id"}}' "$id" 2>>"$log")"
    printf '%s session=%s name=%s status=%s exit=%s signal=%s finished=%s path=%s rc=%s\n' \
      "$id" "${sid:-none}" "${cname:-?}" "${cstatus:-?}" "${cexit:-?}" "${csig:-?}" "${cfinish:-?}" "${cpath:-?}" "$inspect_rc" >>"$RUN_DIR/inspect.txt"
    say "container ${id:0:12} ${cname:-?} status=${cstatus:-?} exit=${cexit:-?} session=${sid:-none}"
    if [[ -n "$sid" ]]; then
      local known=false seen
      for seen in ${MATCHED_SESSION_IDS[@]+"${MATCHED_SESSION_IDS[@]}"}; do
        [[ "$seen" == "$sid" ]] && known=true
      done
      [[ "$known" == true ]] || MATCHED_SESSION_IDS+=("$sid")
    fi
    if [[ -z "$cstatus" ]]; then
      unreadable+="${id:0:12}(rc=${inspect_rc}) "
    elif [[ "$cstatus" == "running" ]]; then
      any_running=true
      running_count=$(( running_count + 1 ))
    elif [[ "$cexit" == "137" ]]; then
      e137=$(( e137 + 1 ))
    elif [[ "$cexit" == "143" ]]; then
      e143=$(( e143 + 1 ))
    elif [[ "$cexit" == "0" ]]; then
      e0=$(( e0 + 1 ))
    else
      other=$(( other + 1 ))
      bad+="${cname:-$id}(exit=${cexit:-unknown}) "
    fi
    cjson+=("{\"id\": $(json_string "$id"), \"name\": $(json_string "$cname"), \"session_id\": $(json_string "$sid"), \"status\": $(json_string "$cstatus"), \"exit_code\": ${cexit:-null}, \"stop_signal\": $(json_string "$csig"), \"finished_at\": $(json_string "$cfinish"), \"path\": $(json_string "$cpath"), \"inspect_rc\": $inspect_rc}")
  done

  CONTAINERS_JSON="[$(join_commas "${cjson[@]}")]"

  local sessions="${#MATCHED_SESSION_IDS[@]}"
  say "containers: ${#CONTAINER_IDS[@]} matched across ${sessions} session(s); running=${running_count} exit137=${e137} exit143=${e143} exit0=${e0} other=${other}"
  if [[ -n "$unreadable" ]]; then
    result="FAIL"
    detail="docker inspect returned no status for: ${unreadable% } (see inspect.txt)"
  elif [[ "$any_running" == true ]]; then
    result="INCONCLUSIVE"
    detail="${running_count} of ${#CONTAINER_IDS[@]} container(s) still running across ${sessions} session(s); exit-code evidence needs that session stopped"
  elif [[ -n "$bad" ]]; then
    result="FAIL"
    detail="unexpected container exit codes: ${bad% }"
  else
    result="PASS"
    detail="${#CONTAINER_IDS[@]} container(s) stopped with 0, 137 or 143"
  fi
  add_check containers "$result" "$detail" "$RUN_DIR/containers.txt"
}

# -------------------------
# The stop capture (shared by the events and stop_calls checks)
# -------------------------

# write_docker_wrapper WRAPPER REAL_DOCKER CALL_LOG
# A docker shim that logs each call's BEGIN/END times around the real docker.
# The real docker's absolute path is baked in before the wrapper dir is put on
# PATH, so the shim never resolves itself.
write_docker_wrapper() {
  local wrapper="$1" real="$2" log="$3"
  mkdir -p "$(dirname "$wrapper")"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'real=%s\n' "$(printf '%q' "$real")"
    printf 'log=%s\n' "$(printf '%q' "$log")"
    printf 'start="$(date +%%s.%%N)"\n'
    printf 'printf "BEGIN %%s" "$start" >> "$log"\n'
    printf 'for a in "$@"; do printf " %%s" "$a" >> "$log"; done\n'
    printf 'printf "\\n" >> "$log"\n'
    printf '"$real" "$@"\n'
    printf 'rc=$?\n'
    printf 'end="$(date +%%s.%%N)"\n'
    printf 'printf "END %%s rc=%%d" "$end" "$rc" >> "$log"\n'
    printf 'for a in "$@"; do printf " %%s" "$a" >> "$log"; done\n'
    printf 'printf "\\n" >> "$log"\n'
    printf 'exit "$rc"\n'
  } >"$wrapper"
  chmod +x "$wrapper"
}

# ensure_stop_captured
# Runs the stop once, under the timing wrapper, and records the event window.
# Both the events and the stop_calls checks call this; the second call is a
# no-op, so the stop is performed exactly once.
ensure_stop_captured() {
  [[ "$STOP_CAPTURED" == true ]] && return 0
  STOP_CAPTURED=true

  local real_docker
  real_docker="$(command -v docker 2>/dev/null)"
  if [[ -z "$real_docker" ]]; then
    STOP_ERROR="docker is not on PATH"
    return 0
  fi
  local resolved
  resolved="$(readlink -f "$real_docker" 2>/dev/null)"
  if [[ -n "$resolved" ]]; then
    real_docker="$resolved"
  fi

  # The stop is about to run against every container the label filters match,
  # and stop.sh has no session scoping unless it is handed one. Refuse rather
  # than silently stop the operator's other sessions: the tool reads, it does
  # not decide whose work ends.
  if [[ -z "$SESSION_ID" && "$ALL_SESSIONS" != true && ${#MATCHED_SESSION_IDS[@]} -gt 1 ]]; then
    STOP_REFUSED=true
    STOP_ERROR="refused: ${#MATCHED_SESSION_IDS[@]} sessions match (${MATCHED_SESSION_IDS[*]}); pass --session-id=<id> to scope the capture, or --all-sessions to stop them all"
    return 0
  fi

  mkdir -p "$RUN_DIR/bin"
  : >"$RUN_DIR/docker-calls.log"
  write_docker_wrapper "$RUN_DIR/bin/docker" "$real_docker" "$RUN_DIR/docker-calls.log"

  STOP_SCRIPT="$REPO_ROOT/scripts/stop.sh"
  if [[ -n "$INSTALLED_STOP" && -f "$INSTALLED_STOP" ]]; then
    STOP_SCRIPT="$INSTALLED_STOP"
  fi

  local -a stop_args=("--name=${PROBE_NAME}" "--sandbox=${CANON_SANDBOX}")
  if [[ -n "$SESSION_ID" ]]; then
    stop_args+=("--session-id=${SESSION_ID}")
  fi
  local -a cmd=(bash -x "$STOP_SCRIPT" "${stop_args[@]}")
  if [[ -n "$STOP_GRACE" ]]; then
    cmd=(timeout "$STOP_GRACE" "${cmd[@]}")
  fi

  STOP_T0="$(date +%s)"
  env PATH="$RUN_DIR/bin:$PATH" PS4='+${EPOCHREALTIME} ' "${cmd[@]}" \
    >"$RUN_DIR/stop.out" 2>"$RUN_DIR/stop-trace.log"
  STOP_RC=$?
  STOP_T1="$(date +%s)"
}

# -------------------------
# events
# -------------------------

check_events() {
  local log="$RUN_DIR/events.log"
  : > "$log"

  local result detail
  if [[ "$MODE" != "perform-stop" ]]; then
    EVENTS_JSON="[]"
    add_check events INCONCLUSIVE "read-only mode" "$log"
    return 0
  fi

  ensure_stop_captured
  if [[ -n "$STOP_ERROR" ]]; then
    EVENTS_JSON="[]"
    if [[ "$STOP_REFUSED" == true ]]; then
      add_check events FAIL "$STOP_ERROR" "$log"
    else
      add_check events INCONCLUSIVE "$STOP_ERROR" "$log"
    fi
    return 0
  fi
  if [[ ${#CONTAINER_IDS[@]} -eq 0 ]]; then
    EVENTS_JSON="[]"
    add_check events INCONCLUSIVE "no containers captured" "$log"
    return 0
  fi

  local -a filters=()
  local id
  for id in "${CONTAINER_IDS[@]}"; do
    filters+=(--filter "container=$id")
  done
  # The stop has already returned, so the window is opened past it: a container
  # killed at the grace boundary can reach its die event a few hundred ms after
  # docker stop returns, and a window closed at the return instant hides exactly
  # the event this check exists to measure.
  local events_until=$(( STOP_T1 + 5 ))
  # The whole event object, not three fields of it. `timeNano` separates a signal
  # from its die inside one second, and the die event carries the container exit
  # code, the only field that distinguishes a graceful end from SIGKILL.
  docker events --since "${STOP_T0}" --until "${events_until}" \
    --format '{{json .}}' \
    "${filters[@]}" >"$log" 2>"$RUN_DIR/events.err"

  local -A first_sig=()
  local -A die_nano=()
  local -A die_code=()
  local -A removed_at=()
  local line action cname nano code
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    action="$(printf '%s' "$line" | sed -n 's/.*"Action":"\([^"]*\)".*/\1/p')"
    cname="$(printf '%s' "$line" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')"
    nano="$(printf '%s' "$line" | sed -n 's/.*"timeNano":\([0-9]*\).*/\1/p')"
    code="$(printf '%s' "$line" | sed -n 's/.*"exitCode":"\([0-9]*\)".*/\1/p')"
    [[ -n "$action" && -n "$cname" && -n "$nano" ]] || continue
    case "$action" in
      kill|signal) [[ -n "${first_sig[$cname]:-}" ]] || first_sig[$cname]="$nano" ;;
      die) die_nano[$cname]="$nano"; die_code[$cname]="$code" ;;
      destroy) removed_at[$cname]="$nano" ;;
    esac
  done <"$log"

  GRACE_USED="${STOP_GRACE:-10}"
  local limit=$(( GRACE_USED + 2 ))
  local -a ejson=()
  local any_missing=false any_over=false any_removed=false any_sigkill=false
  local name

  for name in "${!die_nano[@]}"; do
    local first="${first_sig[$name]:-}" last="${die_nano[$name]}" sec ec
    [[ -n "$first" ]] || first="$last"
    sec="$(awk -v a="$first" -v b="$last" 'BEGIN{printf "%.3f", (b-a)/1000000000}')"
    ec="${die_code[$name]:-}"
    ejson+=("{\"name\": $(json_string "$name"), \"signal_nano\": $(json_string "$first"), \"die_nano\": $(json_string "$last"), \"exit_code\": ${ec:-null}, \"seconds\": $sec}")
    awk -v s="$sec" -v l="$limit" 'BEGIN{exit !(s > l)}' && any_over=true
    if [[ "$ec" == "137" ]] && awk -v s="$sec" -v g="$GRACE_USED" 'BEGIN{exit !(s >= g)}'; then
      any_sigkill=true
    fi
  done
  for name in "${!first_sig[@]}"; do
    [[ -n "${die_nano[$name]:-}" ]] && continue
    # A container another actor removed straight after the stop has no die in
    # this window; that is a teardown race, not a stop that failed to end it.
    if [[ -n "${removed_at[$name]:-}" ]]; then
      any_removed=true
      ejson+=("{\"name\": $(json_string "$name"), \"signal_nano\": $(json_string "${first_sig[$name]}"), \"die_nano\": null, \"removed_nano\": $(json_string "${removed_at[$name]}"), \"seconds\": null}")
      continue
    fi
    any_missing=true
    ejson+=("{\"name\": $(json_string "$name"), \"signal_nano\": $(json_string "${first_sig[$name]}"), \"die_nano\": null, \"seconds\": null}")
  done

  EVENTS_JSON="[$(join_commas "${ejson[@]}")]"

  if [[ ${#ejson[@]} -eq 0 ]]; then
    result="INCONCLUSIVE"
    detail="no events captured in the window"
  elif [[ "$any_missing" == true ]]; then
    result="INCONCLUSIVE"
    detail="a container was signalled but shows no die event within 5s of the stop returning; see events.log and docker ps -a"
  elif [[ "$any_sigkill" == true ]]; then
    result="FAIL"
    detail="a container was SIGKILLed by the ${GRACE_USED}s grace (exit 137); the shutdown path did not end it"
  elif [[ "$any_over" == true ]]; then
    result="FAIL"
    detail="a container took longer than grace+2s (limit ${limit}s)"
  elif [[ "$any_removed" == true ]]; then
    result="PASS"
    detail="every container ended within grace+2s; one was removed by a concurrent teardown"
  else
    result="PASS"
    detail="every container stopped within grace+2s (limit ${limit}s)"
  fi
  add_check events "$result" "$detail" "$log"
}

# -------------------------
# stop_calls
# -------------------------

check_stop_calls() {
  local log="$RUN_DIR/stop_calls.log"
  : > "$log"

  local result detail
  if [[ "$MODE" != "perform-stop" ]]; then
    STOP_CALLS_JSON="[]"
    add_check stop_calls INCONCLUSIVE "read-only mode" "$RUN_DIR/docker-calls.log"
    return 0
  fi

  ensure_stop_captured
  if [[ -n "$STOP_ERROR" ]]; then
    STOP_CALLS_JSON="[]"
    if [[ "$STOP_REFUSED" == true ]]; then
      add_check stop_calls FAIL "$STOP_ERROR" "$RUN_DIR/docker-calls.log"
    else
      add_check stop_calls INCONCLUSIVE "$STOP_ERROR" "$RUN_DIR/docker-calls.log"
    fi
    return 0
  fi

  local -a calls=()
  local open_start="" open_args="" open=false not_returned=false
  local n=0 over="" max="0.000"
  local line
  while IFS= read -r line; do
    case "$line" in
      "BEGIN "*)
        local rest="${line#BEGIN }"
        open_start="${rest%% *}"
        open_args="${rest#* }"
        open=true
        ;;
      "END "*)
        local erest="${line#END }"
        local end="${erest%% *}"
        local tail="${erest#* }"
        local rc="${tail#rc=}"
        rc="${rc%% *}"
        local sec
        if [[ -n "$open_start" && -n "$end" ]]; then
          sec="$(awk -v s="$open_start" -v e="$end" 'BEGIN{printf "%.3f", e - s}')"
        else
          sec="0.000"
        fi
        calls+=("{\"args\": $(json_string "$open_args"), \"start\": $(json_string "$open_start"), \"end\": $(json_string "$end"), \"seconds\": $sec, \"rc\": ${rc:-null}}")
        n=$(( n + 1 ))
        if awk -v s="$sec" -v m="$max" 'BEGIN{exit !(s > m)}'; then max="$sec"; fi
        if awk -v s="$sec" 'BEGIN{exit !(s > 60)}'; then over="$open_args"; fi
        open_start=""
        open_args=""
        open=false
        ;;
    esac
  done <"$RUN_DIR/docker-calls.log"

  if [[ "$open" == true ]]; then
    not_returned=true
    calls+=("{\"args\": $(json_string "$open_args"), \"start\": $(json_string "$open_start"), \"end\": null, \"seconds\": null, \"rc\": null}")
  fi

  STOP_CALLS_JSON="[$(join_commas "${calls[@]}")]"
  printf '%s\n' "${calls[@]}" >"$log"

  if [[ "$not_returned" == true ]]; then
    result="FAIL"
    detail="a docker call did not return: ${open_args}"
  elif [[ -n "$over" ]]; then
    result="FAIL"
    detail="a docker call exceeded 60 seconds: ${over}"
  else
    result="PASS"
    detail="${n} docker call(s) returned; longest ${max}s; stop rc=${STOP_RC}"
  fi
  add_check stop_calls "$result" "$detail" "$RUN_DIR/docker-calls.log"
}

# -------------------------
# calibration
# -------------------------

cleanup_calibration() {
  if [[ -n "$CAL_CONTAINER" ]]; then
    docker rm -f "$CAL_CONTAINER" >/dev/null 2>&1
    CAL_CONTAINER=""
  fi
}

check_calibration() {
  local log="$RUN_DIR/calibration.log"
  : > "$log"

  local result detail evidence
  evidence="$log"

  if ! have docker; then
    CALIBRATION_JSON='{"grace_seconds_measured": null, "reason": "docker is not on PATH"}'
    add_check calibration INCONCLUSIVE "docker is not on PATH" "$evidence"
    return 0
  fi

  # A daemon that cannot answer is not a daemon to measure: a calibration row
  # derived from a missing or wedged engine would be a fabricated number.
  local server_version
  server_version="$(docker version --format '{{.Server.Version}}' 2>>"$log")"
  if [[ -z "$server_version" ]]; then
    CALIBRATION_JSON='{"grace_seconds_measured": null, "reason": "the docker server did not answer"}'
    add_check calibration INCONCLUSIVE "the docker server reported no version; no calibration" "$evidence"
    return 0
  fi

  if ! docker image inspect alpine >/dev/null 2>>"$log"; then
    CALIBRATION_JSON='{"grace_seconds_measured": null, "reason": "alpine image not present"}'
    add_check calibration INCONCLUSIVE "alpine image not present" "$evidence"
    return 0
  fi

  local cal_name="${STAMP}-cal"
  CAL_CONTAINER="$cal_name"
  if ! docker run -d --name "$cal_name" alpine sh -c 'trap "" TERM; sleep 600' >>"$log" 2>&1; then
    CALIBRATION_JSON='{"grace_seconds_measured": null, "reason": "the calibration container did not start"}'
    add_check calibration INCONCLUSIVE "could not start the calibration container" "$evidence"
    return 0
  fi

  local c0 c1 measured
  c0="$(date +%s.%N)"
  docker stop "$cal_name" >>"$log" 2>&1
  c1="$(date +%s.%N)"
  measured="$(awk -v s="$c0" -v e="$c1" 'BEGIN{printf "%.3f", e - s}')"
  docker rm -f "$cal_name" >>"$log" 2>&1
  CAL_CONTAINER=""

  CALIBRATION_JSON="{\"grace_seconds_measured\": $measured, \"container\": $(json_string "$cal_name")}"
  result="PASS"
  detail="measured docker stop grace ${measured}s on alpine"
  add_check calibration "$result" "$detail" "$evidence"
}

# -------------------------
# Main
# -------------------------

main() {
  parse_args usage \
    --input-dir=PROBE_INPUT_DIR \
    --name=PROBE_NAME \
    --sandbox=PROBE_SANDBOX \
    --stop-grace=STOP_GRACE \
    --session-id=SESSION_ID \
    --all-sessions:ALL_SESSIONS \
    --perform-stop:PERFORM_STOP \
    -- "$@"
  local rc=$?
  if [[ $rc -eq 2 ]]; then exit 0; fi
  [[ $rc -eq 0 ]] || exit 1

  [[ -n "$PROBE_SANDBOX" ]] || die "--sandbox is required"

  command -v git >/dev/null 2>&1 || die "git is not on PATH"

  CANON_SANDBOX="$(sandbox_dir_canon "$PROBE_SANDBOX")" || die "cannot canonicalize sandbox: $PROBE_SANDBOX"
  # Default to the sandbox's own input channel, the host path mounted read-only
  # at /home/agentuser/workspace/input inside the agent container, so the probe
  # runs with one argument on the host.
  if [[ -z "$PROBE_INPUT_DIR" && -z "${INPUT_DIR:-}" ]]; then
    dirs_resolve "$CANON_SANDBOX"
  fi
  if [[ -z "$PROBE_INPUT_DIR" ]]; then
    PROBE_INPUT_DIR="${INPUT_DIR:-}"
  fi
  [[ -n "$PROBE_INPUT_DIR" ]] || die "no output directory: set \$INPUT_DIR or pass --input-dir=<path>"
  mkdir -p "$PROBE_INPUT_DIR" || die "could not create output directory: $PROBE_INPUT_DIR"
  [[ -d "$PROBE_INPUT_DIR" ]] || die "output directory does not exist: $PROBE_INPUT_DIR"
  [[ -w "$PROBE_INPUT_DIR" ]] || die "output directory is not writable: $PROBE_INPUT_DIR"

  if [[ -z "$PROBE_NAME" ]]; then
    PROBE_NAME="$(basename "$CANON_SANDBOX")"
  fi
  if [[ "$PERFORM_STOP" == true ]]; then
    MODE="perform-stop"
  else
    MODE="read-only"
  fi

  STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
  RUN_DIR="$PROBE_INPUT_DIR/stop/$STAMP"
  local report="$PROBE_INPUT_DIR/stop/$STAMP.json"
  mkdir -p "$RUN_DIR" || die "could not create $RUN_DIR"

  # The named artifacts exist even when a read-only run produces nothing for
  # them, so a reader never has to distinguish "missing" from "empty".
  : >"$RUN_DIR/docker-calls.log"
  : >"$RUN_DIR/stop-trace.log"
  : >"$RUN_DIR/events.log"
  : >"$RUN_DIR/inspect.txt"
  : >"$RUN_DIR/containers.txt"

  REPO_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
  REPO_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null)"

  trap cleanup_calibration EXIT

  say "sandbox $CANON_SANDBOX, project $PROBE_NAME, mode $MODE${SESSION_ID:+, session $SESSION_ID}"
  say "script ${BASH_SOURCE[0]} sha256=$(sha256_of "${BASH_SOURCE[0]}")"
  say "report $report"

  check_identity
  check_compose_records
  check_engine
  check_containers
  check_events
  check_stop_calls
  check_calibration

  local verdict="PASS"
  (( ${#FAILURES[@]} > 0 )) && verdict="FAIL"

  HOST_JSON="$(
    {
      printf '{'
      printf '"uname": %s, ' "$(json_string "$(uname -srm 2>/dev/null)")"
      printf '"wsl_exe": %s' "$(wsl_present)"
      printf '}'
    }
  )"

  {
    printf '{\n'
    printf '  "timestamp": %s,\n' "$(json_string "$STAMP")"
    printf '  "verdict": %s,\n' "$(json_string "$verdict")"
    printf '  "repo_root": %s,\n' "$(json_string "$REPO_ROOT")"
    printf '  "repo_head": %s,\n' "$(json_string "$REPO_HEAD")"
    printf '  "repo_branch": %s,\n' "$(json_string "$REPO_BRANCH")"
    printf '  "sandbox_dir": %s,\n' "$(json_string "$CANON_SANDBOX")"
    printf '  "project_name": %s,\n' "$(json_string "$PROBE_NAME")"
    printf '  "session_id": %s,\n' "$(json_string "$SESSION_ID")"
    printf '  "mode": %s,\n' "$(json_string "$MODE")"
    printf '  "host": %s,\n' "$HOST_JSON"
    printf '  "engine": %s,\n' "$ENGINE_JSON"
    printf '  "identity": %s,\n' "$IDENTITY_JSON"
    printf '  "compose_records": %s,\n' "$COMPOSE_JSON"
    printf '  "containers": %s,\n' "$CONTAINERS_JSON"
    printf '  "events": %s,\n' "$EVENTS_JSON"
    printf '  "stop_calls": %s,\n' "$STOP_CALLS_JSON"
    printf '  "calibration": %s,\n' "$CALIBRATION_JSON"
    printf '  "checks": [\n'
    local block idx=0
    for block in "${CHECK_BLOCKS[@]}"; do
      (( idx > 0 )) && printf ',\n'
      printf '%s' "$block"
      idx=$(( idx + 1 ))
    done
    printf '\n  ],\n'
    printf '  "failures": %s\n' "$(json_array "${FAILURES[@]}")"
    printf '}\n'
  } >"$report"

  say "wrote $report"
  if [[ "$verdict" == "FAIL" ]]; then
    say "VERDICT: FAIL"
    local f
    for f in "${FAILURES[@]}"; do say "  $f"; done
    exit 1
  fi
  say "VERDICT: $verdict"
}

# Sourced by tests/test_stop_probe.sh, and executed by the operator. The guard
# separates the two modes, per pattern p-15.
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -uo pipefail
  main "$@"
fi
