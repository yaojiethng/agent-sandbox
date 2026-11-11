#!/usr/bin/env bash
# run_case.sh -- run one eval case against one instruction-set candidate, then score the runs.
#
# The candidate is a directory that overlays the fixture's project tree: every
# relative path under it is copied onto the same path in the project. A case
# declares its candidate trees, its fixture and its measure in one JSON case
# file, and the harness runs the case from that declaration.
#
# The clone is scratch and lives in a work root: a temp directory removed when the
# script exits. EVAL_KEEP_WORK=1 keeps it, and --work=<dir> names the root and keeps
# it. The run's change travels as a bundle of the delta from the fixture's base
# commit, written beside the run's measure, and a run that left the tree dirty also
# writes a patch of the remainder. The measures, logs and session files stay under
# --out, so a graded case leaves no worktree behind.
#
# usage:
#   run_case.sh --check=<case.json>
#   run_case.sh --case=<case.json> --config=<name> [--runs=N] [--out=<dir>] [--label=<id>] [--work=<dir>] [--measure-only]
#   run_case.sh --case=<case.json> --cells=<name,name> [--runs=N] [--out=<dir>] [--work=<dir>] [--measure-only]
#   run_case.sh --bundle=<repo.bundle> --patch=<diff> --candidate=<overlay-dir> --runs=N --out=<dir>
#                  --measure=<script> [--package-root=<dir>] [--label=<id>] [--work=<dir>] [--measure-only]
#
# --config names one of the case file's configurations, each declaring an overlay
# tree, a package root, or both. --cells runs several of the case's configurations
# under this one invocation, with at most EVAL_MAX_PARALLEL concurrent (default 5).
# --measure names the grading script; it takes <project-dir> and <base-commit-count>
# and prints one JSON object. There is no default: a run names its measure on the
# command line, with EVAL_MEASURE, or in the case's harness.measure field.
# --package-root seeds a directory's skills and prompts onto the run's config copy,
# which is how a skill under test becomes the single variable. Without one, the run
# config stays the value of EVAL_CONFIG_DIR.
# with --measure-only, --work must name the root of the run being re-scored, because
# that run's worktree carries the commits to measure.
# prints a JSON summary and writes it to <out>/measure-<label>.json; a --cells
# dispatch also writes <out>/benchmark.json.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=layout.sh
source "$HERE/layout.sh"
BUNDLE=""; PATCH=""; CANDIDATE=""; RUNS=3; OUT=""; WORK_ROOT=""; LABEL=""; MEASURE_ONLY=false
CASE=""; CONFIG=""; CELLS=""; MEASURE=""; PACKAGE_ROOT=""; CASE_PROMPT=""; CHECK=""; RUNS_SET=false
OVERLAY_COMMITTED=false
REQUIRE_VALID=false
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"
for arg in "$@"; do
  case "$arg" in
  --bundle=*) BUNDLE="${arg#*=}" ;;
  --check=*) CHECK="${arg#*=}" ;;
  --patch=*) PATCH="${arg#*=}" ;;
  --candidate=*) CANDIDATE="${arg#*=}" ;;
  --runs=*) RUNS="${arg#*=}"; RUNS_SET=true ;;
  --out=*) OUT="${arg#*=}" ;;
  --work=*) WORK_ROOT="${arg#*=}" ;;
  --label=*) LABEL="${arg#*=}" ;;
  --measure-only) MEASURE_ONLY=true ;;
  --require-valid) REQUIRE_VALID=true ;;
  --case=*) CASE="${arg#*=}" ;;
  --config=*) CONFIG="${arg#*=}" ;;
  --cells=*) CELLS="${arg#*=}" ;;
  --measure=*) MEASURE="${arg#*=}" ;;
  --package-root=*) PACKAGE_ROOT="${arg#*=}" ;;
  *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# The layout is declared once, in the eval skill's assets/layout.json. An argument
# beats the declaration: an explicit --out wins, and a case with none writes under
# the declared output root, named for the case's directory.
GRADE_DIR="$(layout_get gradeDir)"
GRADE_RAW_DIR="$(layout_get gradeRawDir)"
GRADE_MAP_FILE="$(layout_get gradeMapFile)"
CELL_PREFIX="$(layout_get cellPrefix)"
CASE_PREFIX="$(layout_get casePrefix)"
if [[ -z "$OUT" && -n "$CASE" ]]; then
  OUT="$(expand_home "$(layout_get outputRoot)")/$(basename "$(dirname "$CASE")")"
fi

MEASURE="${MEASURE:-${EVAL_MEASURE:-}}"

# Read one harness field out of a case file. Paths resolve against the case's
# fixture_root; absolute paths and the case file's own directory are honoured. The
# measure resolves against the case file itself, because it ships with the skill.
case_field() { # <case-file> <jq-path> -> raw value
  jq -r "$2 | if type == \"string\" then . else empty end" "$1"
}
# A case file names the artifact home the way the documents do, with a literal
# $HOME, because JSON does no expansion. Only a leading $HOME or ${HOME} expands.
abs_path() { # <path> -> the absolute path, with .. resolved when the parent exists
  local p="$1" d b
  case "$p" in /*) ;; *) p="$PWD/$p" ;; esac
  d="$(dirname "$p")"; b="$(basename "$p")"
  if [[ -d "$d" ]]; then printf '%s/%s\n' "$(cd "$d" && pwd)" "$b"; else printf '%s\n' "$p"; fi
}
resolve_fixture_path() { # <case-file> <relative-value> -> an absolute path
  local base dir val out
  val="$(expand_home "$2")"
  base="$(expand_home "$(case_field "$1" '.harness.fixture_root')")"
  dir="$(dirname "$1")"
  case "$val" in
  /*) out="$val" ;;
  *)
    if [[ -z "$base" ]]; then
      out="$dir/$val"
    elif [[ "$base" == /* ]]; then
      out="${base%/}/$val"
    else
      out="$dir/${base%/}/$val"
    fi
    ;;
  esac
  abs_path "$out"
}
resolve_case_path() { # <case-file> <relative-value> -> an absolute path
  local val out
  val="$(expand_home "$2")"
  case "$val" in
  /*) out="$val" ;;
  *) out="$(dirname "$1")/$val" ;;
  esac
  abs_path "$out"
}

resolve_measure() { # <case-file> <value> -> an absolute path
  # A bare name is one of this runner's own measures, so a case names the measure and
  # not the path to it: the case is test data and the measure ships with the harness.
  local val
  val="$(expand_home "$2")"
  case "$val" in
  */*) resolve_case_path "$1" "$val" ;;
  *) abs_path "$HERE/$val" ;;
  esac
}

verify_fixture_hashes() { # <case-file> <bundle> <patch>
  local cfile="$1" bundle="$2" patch="$3" key declared actual file
  jq -e '.harness.fixture_sha256 | type == "object"' "$cfile" >/dev/null 2>&1 || return 0
  for key in bundle patch; do
    declared="$(jq -r --arg k "$key" '.harness.fixture_sha256[$k] // empty' "$cfile")"
    [[ -n "$declared" ]] || continue
    if [[ "$key" == bundle ]]; then file="$bundle"; else file="$patch"; fi
    actual="$(sha256sum "$file" | awk '{print $1}')"
    [[ "$declared" == "$actual" ]] || {
      printf 'fixture_sha256.%s does not match the file: %s\n' "$key" "$file" >&2
      return 2
    }
  done
}

# check_case <case-file>: validate a case declaration without running it. Prints
# 'case ok: <path>' and returns 0 when every rule passes; otherwise prints
# 'case rejected: <reason>' and returns 2. Each rule names its own reason, so a
# rejected case says which declaration it broke.
check_case() { # <case-file>
  local cfile="$1"
  [[ -f "$cfile" ]] || { printf 'case rejected: file not found: %s\n' "$cfile"; return 2; }
  jq -e . "$cfile" >/dev/null 2>&1 || { printf 'case rejected: invalid json: %s\n' "$cfile"; return 2; }
  jq -e '.harness | type == "object"' "$cfile" >/dev/null 2>&1 \
    || { printf 'case rejected: harness is not an object\n'; return 2; }

  local fixture_root bundle patch measure prompt
  fixture_root="$(case_field "$cfile" '.harness.fixture_root')"
  [[ -n "$fixture_root" ]] || { printf 'case rejected: fixture_root is missing\n'; return 2; }

  local bundle_rel patch_rel measure_rel
  bundle_rel="$(case_field "$cfile" '.harness.bundle')"
  patch_rel="$(case_field "$cfile" '.harness.patch')"
  bundle="$(resolve_fixture_path "$cfile" "$bundle_rel")"
  patch="$(resolve_fixture_path "$cfile" "$patch_rel")"
  [[ -n "$bundle_rel" && -f "$bundle" ]] \
    || { printf 'case rejected: bundle does not resolve: %s\n' "$bundle"; return 2; }
  [[ -n "$patch_rel" && -f "$patch" ]] \
    || { printf 'case rejected: patch does not resolve: %s\n' "$patch"; return 2; }

  measure_rel="$(case_field "$cfile" '.harness.measure')"
  measure="$(resolve_measure "$cfile" "$measure_rel")"
  [[ -n "$measure_rel" && -f "$measure" ]] \
    || { printf 'case rejected: measure does not resolve: %s\n' "$measure"; return 2; }

  prompt="$(case_field "$cfile" '.harness.prompt')"
  [[ -n "$prompt" ]] || { printf 'case rejected: prompt is missing\n'; return 2; }

  local config_count
  config_count="$(jq -r 'if (.harness.configurations | type) == "object" then (.harness.configurations | length) else -1 end' "$cfile")"
  [[ "$config_count" =~ ^[0-9]+$ && "$config_count" -ge 1 ]] \
    || { printf 'case rejected: the case declares no configuration\n'; return 2; }

  local name overlay package resolved has_source
  while IFS= read -r name; do
    jq -e --arg c "$name" '.harness.configurations[$c] | type == "object"' "$cfile" >/dev/null 2>&1 \
      || { printf 'case rejected: configuration %s is not an object\n' "$name"; return 2; }
    overlay="$(case_field "$cfile" ".harness.configurations[\"$name\"].overlay")"
    package="$(case_field "$cfile" ".harness.configurations[\"$name\"].package_root")"
    has_source=false
    if [[ -n "$overlay" ]]; then
      resolved="$(resolve_fixture_path "$cfile" "$overlay")"
      [[ -e "$resolved" ]] || { printf 'case rejected: configuration %s overlay does not resolve: %s\n' "$name" "$overlay"; return 2; }
      has_source=true
    fi
    if [[ -n "$package" ]]; then
      resolved="$(resolve_fixture_path "$cfile" "$package")"
      [[ -e "$resolved" ]] || { printf 'case rejected: configuration %s package_root does not resolve: %s\n' "$name" "$package"; return 2; }
      has_source=true
    fi
    [[ "$has_source" == true ]] \
      || { printf 'case rejected: configuration %s has no overlay or package_root\n' "$name"; return 2; }
  done < <(jq -r '.harness.configurations | keys[]' "$cfile")

  jq -e '.harness.fixture_sha256 | type == "object"' "$cfile" >/dev/null 2>&1 \
    || { printf 'case rejected: fixture_sha256 is not an object\n'; return 2; }
  local key declared actual
  for key in bundle patch; do
    declared="$(jq -r --arg k "$key" '.harness.fixture_sha256[$k] // empty' "$cfile")"
    [[ "$declared" =~ ^[0-9a-f]{64}$ ]] \
      || { printf 'case rejected: fixture_sha256.%s is not a lowercase 64-character hex string\n' "$key"; return 2; }
    if [[ "$key" == bundle ]]; then
      actual="$(sha256sum "$bundle" | awk '{print $1}')"
    else
      actual="$(sha256sum "$patch" | awk '{print $1}')"
    fi
    [[ "$declared" == "$actual" ]] \
      || { printf 'case rejected: fixture_sha256.%s does not match the file\n' "$key"; return 2; }
  done

  jq -e '.harness.decision | type == "object"' "$cfile" >/dev/null 2>&1 \
    || { printf 'case rejected: decision is not an object\n'; return 2; }
  jq -e '.harness.decision.runs | type == "number" and . >= 2' "$cfile" >/dev/null 2>&1 \
    || { printf 'case rejected: decision.runs is not a number at least 2\n'; return 2; }

  # A case is graded when it carries a decision rule; otherwise it is an
  # observation and says why. The kind decides which fields are required, so a
  # case cannot read as graded while its evidence is missing.
  local control aa rule graded has_design has_checks observation
  rule="$(case_field "$cfile" '.harness.decision.rule')"
  graded=false
  [[ -n "$rule" ]] && graded=true
  has_design="$(jq -r '.harness | has("design")' "$cfile")"
  has_checks="$(jq -r '.harness | has("checks")' "$cfile")"
  observation="$(case_field "$cfile" '.harness.observation')"

  if [[ "$graded" == true ]]; then
    [[ "$config_count" -ge 2 ]] \
      || { printf 'case rejected: a graded case needs at least two configurations\n'; return 2; }
    [[ -z "$observation" ]] \
      || { printf 'case rejected: a graded case carries a rule, not an observation\n'; return 2; }
    [[ "$has_design" == true && "$has_checks" == true ]] \
      || { printf 'case rejected: a graded case declares design and checks\n'; return 2; }
    control="$(case_field "$cfile" '.harness.decision.control')"
    [[ -n "$control" ]] || { printf 'case rejected: decision.control is missing\n'; return 2; }
    jq -e --arg c "$control" '.harness.configurations | has($c)' "$cfile" >/dev/null 2>&1 \
      || { printf 'case rejected: decision.control names no configuration: %s\n' "$control"; return 2; }
    aa="$(case_field "$cfile" '.harness.decision.aa')"
    if [[ -n "$aa" ]]; then
      jq -e --arg c "$aa" '.harness.configurations | has($c)' "$cfile" >/dev/null 2>&1 \
        || { printf 'case rejected: decision.aa names no configuration: %s\n' "$aa"; return 2; }
      [[ "$aa" != "$control" ]] \
        || { printf 'case rejected: decision.aa repeats the control: %s\n' "$aa"; return 2; }
    fi
  else
    [[ -n "$observation" ]] \
      || { printf 'case rejected: a case with no decision rule declares observation\n'; return 2; }
    [[ "$has_design" == false && "$has_checks" == false ]] \
      || { printf 'case rejected: an observation declares no design or checks\n'; return 2; }
  fi

  if ! jq -e '.harness.stop_classes // [] | type == "array"' "$cfile" >/dev/null 2>&1; then
    printf 'case rejected: stop_classes is not an array\n'; return 2
  fi
  if ! jq -e '.harness.stop_classes // [] | all(.[]; . == "timeout" or . == "exit-nonzero" or . == "unattributed" or . == "escaped")' "$cfile" >/dev/null 2>&1; then
    printf 'case rejected: stop_classes holds an unknown class\n'; return 2
  fi
  if ! jq -e '.harness.stop_classes // [] | length == (unique | length)' "$cfile" >/dev/null 2>&1; then
    printf 'case rejected: stop_classes repeats a class\n'; return 2
  fi

  # A graded case is complete when it is present, and every check it declares is
  # proven against a known-bad input the measure must fail.
  if [[ "$graded" == true ]]; then
    jq -e '.harness.design | type == "object"' "$cfile" >/dev/null 2>&1 \
      || { printf 'case rejected: design is not an object\n'; return 2; }
    local method primary attrition
    method="$(case_field "$cfile" '.harness.design.method')"
    [[ -n "$method" ]] || { printf 'case rejected: design.method is missing\n'; return 2; }
    primary="$(case_field "$cfile" '.harness.design.primary_measure')"
    [[ -n "$primary" ]] || { printf 'case rejected: design.primary_measure is missing\n'; return 2; }
    jq -e '.harness.design.valid_n | type == "number" and . >= 2' "$cfile" >/dev/null 2>&1 \
      || { printf 'case rejected: design.valid_n is not a number at least 2\n'; return 2; }
    attrition="$(case_field "$cfile" '.harness.design.attrition')"
    [[ -n "$attrition" ]] || { printf 'case rejected: design.attrition is missing\n'; return 2; }
    if jq -e '.harness.design | has("arms")' "$cfile" >/dev/null 2>&1; then
      jq -e '.harness.design.arms | type == "array" and length > 0' "$cfile" >/dev/null 2>&1 \
        || { printf 'case rejected: design.arms is not a non-empty array\n'; return 2; }
      local arm
      while IFS= read -r arm; do
        jq -e --arg c "$arm" '.harness.configurations | has($c)' "$cfile" >/dev/null 2>&1 \
          || { printf 'case rejected: design.arms names no configuration: %s\n' "$arm"; return 2; }
      done < <(jq -r '.harness.design.arms[]' "$cfile")
    fi
    jq -e '.harness.checks | type == "array" and length > 0' "$cfile" >/dev/null 2>&1 \
      || { printf 'case rejected: checks is not a non-empty array\n'; return 2; }

    local cid role kb kb_path kb_out kb_pass
    while IFS=$'\t' read -r cid role kb; do
      [[ -n "$cid" ]] || { printf 'case rejected: a check has no id\n'; return 2; }
      [[ "$role" == gate || "$role" == discriminator ]] \
        || { printf 'case rejected: check %s role is not gate or discriminator: %s\n' "$cid" "$role"; return 2; }
      [[ -n "$kb" ]] || { printf 'case rejected: check %s has no known_bad\n' "$cid"; return 2; }
      kb_path="$(resolve_fixture_path "$cfile" "$kb")"
      [[ -d "$kb_path" ]] \
        || { printf 'case rejected: check %s known_bad does not resolve to a directory: %s\n' "$cid" "$kb"; return 2; }
      kb_out="$(timeout 20 bash "$measure" "$kb_path" 0 2>/dev/null)" \
        || { printf 'case rejected: check %s known_bad could not be measured: %s\n' "$cid" "$kb"; return 2; }
      jq -e --arg id "$cid" '.assertions // [] | map(select(.id == $id)) | length == 1' <<<"$kb_out" >/dev/null 2>&1 \
        || { printf 'case rejected: check %s is not emitted by the measure\n' "$cid"; return 2; }
      kb_pass="$(jq -r --arg id "$cid" '.assertions[] | select(.id == $id) | .pass' <<<"$kb_out")"
      [[ "$kb_pass" == false ]] \
        || { printf 'case rejected: check %s passes its known_bad: %s\n' "$cid" "$kb"; return 2; }
    done < <(jq -r '.harness.checks[] | [.id // "", .role // "", .known_bad // ""] | @tsv' "$cfile")
  fi

  printf 'case ok: %s\n' "$cfile"
  return 0
}

# assemble_grade <dest-out> <raw-dir>...: blind the graders by renaming every raw
# case to case-NN and recording the original stem only in
# <dest-out>/grade-map.json. The grade directory, its file names and the map keys
# carry no configuration label; the map, which does, lives outside the grade dir.
assemble_grade() { # <dest-out> <raw-dir>...
  local dest="$1"; shift
  local grade="$dest/$GRADE_DIR"
  local map_file="$dest/$GRADE_MAP_FILE"
  local index="$dest/.grade-index"
  rm -rf "$grade"
  mkdir -p "$grade"
  : >"$index"
  local dir file
  for dir in "$@"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      printf '%s\n' "$file" >>"$index"
    done < <(find "$dir" -maxdepth 1 -type f -name '*.txt' | sort)
  done
  if [[ ! -s "$index" ]]; then
    printf '{"cases":{}}\n' >"$map_file"
    rm -f "$index"
    return 0
  fi
  local -a shuffled=()
  while IFS= read -r file; do shuffled+=("$file"); done < <(shuf "$index")
  local n=0 target stem
  : >"$index.new"
  for file in "${shuffled[@]}"; do
    n=$((n + 1))
    printf -v target "${CASE_PREFIX}%02d.txt" "$n"
    cp "$file" "$grade/$target"
    stem="$(basename "$file" .txt)"
    printf '%s%02d\t%s\n' "$CASE_PREFIX" "$n" "$stem" >>"$index.new"
  done
  jq -Rn '[inputs | split("\t") | {(.[0]): .[1]}] | add // {} | {cases: .}' <"$index.new" >"$map_file"
  rm -f "$index" "$index.new"
}

if [[ -n "$CHECK" ]]; then
  check_case "$CHECK"
  exit $?
fi

if [[ -n "$CASE" ]]; then
  [[ -f "$CASE" ]] || { echo "case file not found: $CASE" >&2; exit 2; }
  if [[ -z "$CELLS" && -z "$CONFIG" ]]; then
    echo "--case needs --config=<name> or --cells=<name,name>" >&2; exit 2
  fi
  if [[ -n "$CELLS" && -n "$CONFIG" ]]; then
    echo "--cells and --config pick one dispatch each: give --cells alone" >&2; exit 2
  fi
  if [[ -n "$BUNDLE" || -n "$PATCH" || -n "$CANDIDATE" || -n "$PACKAGE_ROOT" ]]; then
    echo "a case file declares the fixture; drop --bundle, --patch, --candidate and --package-root" >&2; exit 2
  fi
  [[ -n "$OUT" ]] || { echo "--out is required" >&2; exit 2; }
  # A run admits only a declaration --check would accept. The --cells parent
  # validates once before it schedules; its children skip, so the cost is one
  # known-bad measurement per declared check per invocation, not per run or cell.
  if [[ "${EVAL_CELL:-}" != 1 ]]; then
    if ! DECL_OUT="$(check_case "$CASE")"; then
      printf '%s\n' "$DECL_OUT" >&2
      exit 2
    fi
  fi
  BUNDLE_REL="$(case_field "$CASE" '.harness.bundle')"
  PATCH_REL="$(case_field "$CASE" '.harness.patch')"
  [[ -n "$BUNDLE_REL" && -n "$PATCH_REL" ]] || { echo "the case file declares no fixture: $CASE" >&2; exit 2; }
  BUNDLE="$(resolve_fixture_path "$CASE" "$BUNDLE_REL")"
  PATCH="$(resolve_fixture_path "$CASE" "$PATCH_REL")"
  MEASURE_REL="$(case_field "$CASE" '.harness.measure')"
  [[ -n "$MEASURE_REL" ]] && MEASURE="$(resolve_measure "$CASE" "$MEASURE_REL")"
  CASE_PROMPT="$(case_field "$CASE" '.harness.prompt')"
  MEASURE="${MEASURE:-${EVAL_MEASURE:-}}"
  verify_fixture_hashes "$CASE" "$BUNDLE" "$PATCH" || exit $?
  if [[ "$RUNS_SET" == false ]]; then
    declared_runs="$(jq -r '.harness.decision.runs // empty' "$CASE")"
    [[ -n "$declared_runs" ]] && RUNS="$declared_runs"
  fi
  STOP_CLASSES_JSON="$(jq -c '.harness.stop_classes // []' "$CASE" 2>/dev/null || echo '[]')"
fi
if [[ -n "$CELLS" && -z "$CASE" ]]; then
  echo "--cells needs --case=<case.json>" >&2; exit 2
fi
if [[ -n "$CELLS" && -z "$OUT" ]]; then
  echo "--out is required" >&2; exit 2
fi
if [[ -n "$CELLS" ]]; then
  # Pool dispatch: one cell per named configuration, bounded by EVAL_MAX_PARALLEL.
  # Cells own their own temp roots and outputs, so the pool's only state is the cost.
  # A run that matches a declared stop class halts new scheduling; cells already
  # running finish, and the batch record names the class and the split.
  CELL_CAP="${EVAL_MAX_PARALLEL:-5}"
  mkdir -p "$OUT"
  read -r -a CELL_LIST <<<"${CELLS//,/ }"
  declare -a LAUNCHED=()
  STOP_JSON=null
  STOP_SEEN=0
  find_stop() {
    local f cell rec
    for f in "$OUT"/"$CELL_PREFIX"*/measure-*.json; do
      [[ -f "$f" ]] || continue
      cell="${f%/measure-*.json}"; cell="${cell##*/}"; cell="${cell#"$CELL_PREFIX"}"
      rec="$(jq -c --arg cell "$cell" '[.runs_detail[] | select(.stop_class != null) | {class: .stop_class, cell: $cell, run: .run}] | first // empty' "$f" 2>/dev/null)" || true
      if [[ -n "$rec" ]]; then
        STOP_JSON="$rec"
        STOP_SEEN=1
        return 0
      fi
    done
    return 1
  }
  RUNNING=0
  for cell in "${CELL_LIST[@]}"; do
    jq -e --arg c "$cell" '.harness.configurations | has($c)' "$CASE" >/dev/null || {
      echo "the case has no configuration named $cell" >&2; exit 2; }
    while (( RUNNING >= CELL_CAP )); do
      wait -n || true; RUNNING=$(( RUNNING - 1 ))
      find_stop && break
    done
    (( STOP_SEEN == 1 )) && break
    EVAL_CELL=1 bash "$0" --case="$CASE" --config="$cell" --runs="$RUNS" --out="$OUT/$CELL_PREFIX$cell" \
      ${WORK_ROOT:+--work="$WORK_ROOT/$CELL_PREFIX$cell"} >"$OUT/$CELL_PREFIX$cell.log" 2>&1 &
    LAUNCHED+=("$cell")
    RUNNING=$(( RUNNING + 1 ))
  done
  wait
  (( STOP_SEEN == 0 )) && find_stop || true
  # Each cell left its grade-raw directory in place; the pool assembles one
  # sanitized grade dir from them and removes them, so the label survives only
  # in the pool's grade-map.json.
  assemble_grade "$OUT" "$OUT"/"$CELL_PREFIX"*/"$GRADE_RAW_DIR"
  rm -rf "${OUT:?}"/"${CELL_PREFIX:?}"*/"${GRADE_RAW_DIR:?}"
  jq -s 'map({key: .candidate, value: .}) | from_entries' "$OUT"/"$CELL_PREFIX"*/measure-*.json \
    >"$OUT/benchmark.json" || { echo "no cell wrote a measure" >&2; exit 1; }
  LAUNCHED_JSON="$(printf '%s\n' "${LAUNCHED[@]:-}" | jq -R . | jq -s 'map(select(. != ""))')"
  ALL_JSON="$(printf '%s\n' "${CELL_LIST[@]}" | jq -R . | jq -s .)"
  REMAINING_JSON="$(jq -n --argjson all "$ALL_JSON" --argjson run "$LAUNCHED_JSON" '$all - $run')"
  BATCH_JSON="$(jq -n --argjson stop "$STOP_JSON" --argjson run "$LAUNCHED_JSON" --argjson remain "$REMAINING_JSON" \
    '{stop: $stop, cells_run: $run, cells_remaining: $remain}')"
  ANALYSIS_JSON="$(jq '
    . as $b
    | ($b | to_entries | map(select(.key != "batch"))) as $cells
    | {
        non_discriminating: ([ $cells[] | .value.runs_detail[] | select(.valid) | (.measure.assertions // [])[] ] | group_by(.id) | map({id: .[0].id, pass: (map(.pass) | all)}) | map(select(.pass)) | map(.id)),
        cells_without_spread: [ $cells[] | select((.value.correctness_runs | length) > 0 and ((.value.correctness_runs | unique | length) == 1)) | .key ],
        failed_assertions: ([ $cells[] | select((.value.failed_assertions // []) | length > 0) | {key: .key, value: .value.failed_assertions} ] | from_entries)
      }' "$OUT/benchmark.json")"
  jq --argjson batch "$BATCH_JSON" --argjson analysis "$ANALYSIS_JSON" '. + {batch: $batch, analysis: $analysis}' "$OUT/benchmark.json" >"$OUT/.benchmark.tmp" \
    && mv "$OUT/.benchmark.tmp" "$OUT/benchmark.json"
  cat "$OUT/benchmark.json"
  exit 0
fi

# A configuration from the case file supplies its overlay tree, its package root,
# or both. An ad-hoc run names them on the command line. The label defaults to the
# configuration's name, so a case run's measure file is measure-<configuration>.json.
if [[ -n "$CASE" && -n "$CONFIG" ]]; then
  jq -e --arg c "$CONFIG" '.harness.configurations | has($c)' "$CASE" >/dev/null || {
    echo "the case has no configuration named $CONFIG" >&2; exit 2; }
  OVERLAY_COMMITTED="$(jq -r '.harness.overlay_committed // false' "$CASE" 2>/dev/null || echo false)"
  OVERLAY_REL="$(case_field "$CASE" ".harness.configurations[\"$CONFIG\"].overlay")"
  PACKAGE_REL="$(case_field "$CASE" ".harness.configurations[\"$CONFIG\"].package_root")"
  [[ -n "$OVERLAY_REL" ]] && CANDIDATE="$(resolve_fixture_path "$CASE" "$OVERLAY_REL")"
  [[ -n "$PACKAGE_REL" ]] && PACKAGE_ROOT="$(resolve_fixture_path "$CASE" "$PACKAGE_REL")"
fi
LABEL="${LABEL:-${CONFIG:-candidate}}"

if [[ "$MEASURE_ONLY" == false ]]; then
  [[ -n "$BUNDLE" && -n "$PATCH" && -n "$OUT" ]] || { echo "usage: run_case.sh --bundle= --patch= [--candidate=] --out= [--runs= --label=]" >&2; exit 2; }
  [[ -f "$BUNDLE" ]] || { echo "bundle not found: $BUNDLE" >&2; exit 2; }
  [[ -f "$PATCH" ]] || { echo "patch not found: $PATCH" >&2; exit 2; }
fi
[[ -n "$OUT" ]] || { echo "--out is required" >&2; exit 2; }
[[ -n "$MEASURE" ]] || { echo "no measure: name one with --measure, EVAL_MEASURE or the case's harness.measure" >&2; exit 2; }
[[ -f "$MEASURE" ]] || { echo "measure not found: $MEASURE" >&2; exit 2; }

# The candidate is an overlay tree: it must hold at least one file, and nothing
# else about its shape is fixed.
if [[ -n "$CANDIDATE" ]]; then
  [[ -d "$CANDIDATE" ]] || { echo "candidate is not a directory: $CANDIDATE" >&2; exit 2; }
  [[ -n "$(find "$CANDIDATE" -type f -o -type l | head -1)" ]] || { echo "candidate holds no files: $CANDIDATE" >&2; exit 2; }
fi
if [[ -n "$PACKAGE_ROOT" ]]; then
  [[ -d "$PACKAGE_ROOT" ]] || { echo "package root is not a directory: $PACKAGE_ROOT" >&2; exit 2; }
fi

WORK_KEPT=false
if [[ -n "$WORK_ROOT" ]]; then
  WORK_KEPT=true
elif [[ "$MEASURE_ONLY" == true ]]; then
  echo "--measure-only needs --work=<dir>, the work root of the run being re-scored" >&2
  exit 2
else
  WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ws.XXXXXX")" || { echo "cannot create a work root" >&2; exit 1; }
  [[ "${EVAL_KEEP_WORK:-0}" == "1" ]] && WORK_KEPT=true
  [[ "$WORK_KEPT" == true ]] || trap 'rm -rf "$WORK_ROOT"' EXIT
fi
mkdir -p "$WORK_ROOT"
[[ "$WORK_KEPT" == true ]] && echo "work root kept: $WORK_ROOT"

RUN_TIMEOUT="${EVAL_RUN_TIMEOUT:-600}"
CONFIG_DIR="${EVAL_CONFIG_DIR:-$HOME/.pi/agent}"

DISPATCH_SH="${EVAL_DISPATCH_SH:-$HERE/../../../../scripts/dispatch.sh}"
# The eval default is the _ORCHESTRATOR role, resolved by the dispatch entrypoint
# and launched through the command it prints. Nothing here composes a launch flag:
# a consumer that took the model from the table and the provider from a literal
# ran the table's entry against a runtime the table did not choose, and the
# runtime forwarded the request while the provider refused it.
# A named table wins; otherwise dispatch resolves the repository's committed table.
# Do not synthesize a path here: the dispatch seam owns the default, and a second
# guess sent an eval to a per-user file the repository does not ship.
RECOMMENDATIONS_FILE="${EVAL_RECOMMENDATIONS_FILE:-}"
if [[ -z "$RECOMMENDATIONS_FILE" && -n "${PROJECT_DIR:-}" && -f "$PROJECT_DIR/.agents/model-recommendations.md" ]]; then
  RECOMMENDATIONS_FILE="$PROJECT_DIR/.agents/model-recommendations.md"
fi
# A pin is a whole assignment: EVAL_MODEL names one, and EVAL_THINKING replaces
# the level the table carries.
PIN=()
[[ -n "${EVAL_MODEL:-}" ]] && PIN+=(--model "$EVAL_MODEL")
[[ -n "${EVAL_THINKING:-}" ]] && PIN+=(--thinking "$EVAL_THINKING")
PROMPT="${EVAL_PROMPT:-${CASE_PROMPT:-The working tree holds the pending work for this iteration. Land it as the delivery commit.}}"

# A package root makes the run's config vary, so the configuration gets its own
# config copy under the case's output slug, with the package root's skills and
# prompts seeded over it. Without a package root the run config is EVAL_CONFIG_DIR,
# exactly as an overlay-only case needs.
RUN_CONFIG="$CONFIG_DIR"
if [[ -n "$PACKAGE_ROOT" && "$MEASURE_ONLY" == false ]]; then
  RUN_CONFIG="$OUT/$CASE_PREFIX$LABEL/config"
  mkdir -p "$RUN_CONFIG"
  tar -C "$CONFIG_DIR" --exclude='./sessions' -cf - . | tar -C "$RUN_CONFIG" -xf - \
    || { echo "config copy failed" >&2; exit 1; }
  for entry in skills prompts packages bin; do
    [[ -d "$PACKAGE_ROOT/$entry" ]] || continue
    mkdir -p "$RUN_CONFIG/$entry"
    tar -C "$PACKAGE_ROOT/$entry" -cf - . | tar -C "$RUN_CONFIG/$entry" -xf - \
      || { echo "package seed failed for $entry" >&2; exit 1; }
  done
fi

CASE_DIR="$OUT/$CASE_PREFIX$LABEL"
mkdir -p "$CASE_DIR"
: >"$CASE_DIR/runs.jsonl"
START=$(date +%s)

apply_overlay() { # <overlay-dir> <project-dir>
  tar -C "$1" -cf - . | tar -C "$2" -xf - || { echo "overlay failed for $1" >&2; exit 1; }
}

if [[ "$MEASURE_ONLY" == false ]]; then
for i in $(seq 1 "$RUNS"); do
  RUN_DIR="$CASE_DIR/run-$i"
  PROJ="$WORK_ROOT/$i/project"
  rm -rf "$RUN_DIR" "${WORK_ROOT:?}/$i"
  mkdir -p "$RUN_DIR"
  git clone -q "$BUNDLE" "$PROJ" || { echo "clone failed for run $i" >&2; exit 1; }
  # The clone's origin is the fixture bundle, whose path names the case and the
  # eval output root; the model reads a path before it reads anything else, so
  # the origin is removed rather than left as a signpost.
  git -C "$PROJ" remote remove origin 2>/dev/null || true
  # A clone inherits no identity, so a run that commits would stop on "Author
  # identity unknown" or invent one. The identity is the harness's to set, and it
  # is the one this project's own commits carry.
  git -C "$PROJ" config user.name "${EVAL_GIT_NAME:-agent}"
  git -C "$PROJ" config user.email "${EVAL_GIT_EMAIL:-agent@sandbox}"
  [[ -n "$CANDIDATE" ]] && apply_overlay "$CANDIDATE" "$PROJ"
  # A prompt benchmark's overlay is the starting state, not the run's delivery:
  # committing it keeps the prompt out of `git status`, so the run reads it as the
  # repository's own instruction and the grade carries only the report.
  if [[ -n "$CANDIDATE" && "$OVERLAY_COMMITTED" == true ]]; then
    git -C "$PROJ" add -A
    if ! git -C "$PROJ" diff --cached --quiet; then
      git -C "$PROJ" commit -q -m "chore: fixture state" || {
        echo "overlay commit failed for run $i" >&2; exit 1; }
    fi
  fi
  if [[ -s "$PATCH" ]]; then
    git -C "$PROJ" apply "$PATCH" || { echo "patch failed for run $i" >&2; exit 1; }
  fi
  git -C "$PROJ" rev-list --count HEAD >"$RUN_DIR/base-count"
  git -C "$PROJ" rev-parse HEAD >"$RUN_DIR/base-sha"
  printf 'You are working in the git repository at %s. %s Work only inside that directory. Reply DONE when the commit is made.\n' \
    "$PROJ" "$PROMPT" >"$RUN_DIR/prompt.txt"
  # One door: the command comes from the entrypoint, so the runtime, the provider
  # and the model are the table's decision rather than this script's.
  CMD="$(DISPATCH_REC_FILE="$RECOMMENDATIONS_FILE" \
    DISPATCH_STATE_FILE="$RUN_DIR/dispatch-state.json" \
    bash "$DISPATCH_SH" --role _ORCHESTRATOR --brief "$RUN_DIR/prompt.txt" \
      --dir "$PROJ" --session "$RUN_DIR/session.jsonl" \
      ${PIN[@]+"${PIN[@]}"})" || { echo "the eval command cannot be resolved" >&2; exit 2; }
  (
    cd "$PROJ" || exit 1
    run_start="$(date +%s)"
    timeout "$RUN_TIMEOUT" env PI_CODING_AGENT_DIR="$RUN_CONFIG" bash -c "$CMD" \
      >"$RUN_DIR/run.log" 2>&1
    run_rc=$?
    printf '%s\n' "$(( $(date +%s) - run_start ))" >"$RUN_DIR/elapsed"
    printf '%s\n' "$run_rc" >"$RUN_DIR/rc"
    run_model="$(grep -o '"model":"[^"]*"' "$RUN_DIR/session.jsonl" 2>/dev/null | tail -1 | cut -d'"' -f4)"
    printf '%s\n' "${run_model:-unknown}" >"$RUN_DIR/model"
  ) &
done
wait
fi

for i in $(seq 1 "$RUNS"); do
  RUN_DIR="$CASE_DIR/run-$i"
  PROJ="$WORK_ROOT/$i/project"
  bash "$MEASURE" "$PROJ" "$(cat "$RUN_DIR/base-count")" >"$RUN_DIR/measure.json"
  # The session measure reads the transcripts, so cost, wall and every path the run
  # opened outside its own clone come from the record the runtime wrote.
  node "$HERE/measure_session.mjs" --root "$PROJ" --repo-root "$REPO_ROOT" \
    --work-root "$WORK_ROOT" --session "$RUN_DIR/session.jsonl" \
    >"$RUN_DIR/session.json" 2>/dev/null \
    || printf '{"invalid":true,"invalid_reason":"session measure failed","attributed":false}\n' >"$RUN_DIR/session.json"
  base="$(cat "$RUN_DIR/base-sha")"
  head="$(git -C "$PROJ" rev-parse HEAD 2>/dev/null || echo "$base")"
  rm -f "$RUN_DIR/run.bundle" "$RUN_DIR/run.patch"
  [[ "$head" != "$base" ]] && { git -C "$PROJ" bundle create -q "$RUN_DIR/run.bundle" "$base..HEAD" || { echo "bundle failed for run $i" >&2; exit 1; }; }
  git -C "$PROJ" diff HEAD >"$RUN_DIR/run.patch"
  run_rc="$(cat "$RUN_DIR/rc" 2>/dev/null || echo 'null')"
  run_elapsed="$(cat "$RUN_DIR/elapsed" 2>/dev/null || echo 0)"
  run_model="$(cat "$RUN_DIR/model" 2>/dev/null || echo unknown)"
  run_valid=false
  sess_invalid="$(jq -r '.invalid // false' "$RUN_DIR/session.json" 2>/dev/null || echo true)"
  [[ "$run_rc" == "0" && "$sess_invalid" != "true" ]] && run_valid=true
  printf '{"run":%s,"rc":%s,"elapsed":%s,"valid":%s,"model":"%s","measure":%s,"session":%s}\n' \
    "$i" "$run_rc" "$run_elapsed" "$run_valid" "$run_model" \
    "$(cat "$RUN_DIR/measure.json")" "$(cat "$RUN_DIR/session.json")" >>"$CASE_DIR/runs.jsonl"

  # Raw grading artefact: the file name keeps the label, and the assembler
  # renames it later so the grader never sees the label.
  mkdir -p "$OUT/$GRADE_RAW_DIR"
  {
    printf 'run: %s\n' "$i"
    printf 'subject: %s\n' "$(git -C "$PROJ" log -1 --format=%s 2>/dev/null)"
    printf 'body: %s\n' "$(git -C "$PROJ" log -1 --format=%b 2>/dev/null)"
    git -C "$PROJ" status --porcelain 2>/dev/null || true
    printf '%s\n' '--- committed change ---'
    git -C "$PROJ" diff "$base" HEAD 2>/dev/null || true
    printf '%s\n' '--- untracked ---'
    while IFS= read -r f; do
      printf '%s\n' "--- $f ---"
      cat "$PROJ/$f" 2>/dev/null || true
    done < <(git -C "$PROJ" ls-files --others --exclude-standard 2>/dev/null)
    printf '%s\n' '--- diff ---'
    git -C "$PROJ" diff HEAD 2>/dev/null || true
  } >"$OUT/$GRADE_RAW_DIR/$LABEL-$i.txt"
done

# The single-configuration path assembles its own sanitized grade dir; a cell
# leaves its grade-raw for the pool parent and sets EVAL_CELL to stay out of the
# way.
if [[ "${EVAL_CELL:-0}" != "1" ]]; then
  assemble_grade "$OUT" "$OUT/$GRADE_RAW_DIR"
  rm -rf "${OUT:?}/${GRADE_RAW_DIR:?}"
fi

HARNESS_COMMIT="$(git -C "$HERE" rev-parse HEAD 2>/dev/null || echo unknown)"
FIXTURE_BUNDLE_SHA="$(sha256sum "$BUNDLE" 2>/dev/null | awk '{print $1}')"
FIXTURE_PATCH_SHA="$(sha256sum "$PATCH" 2>/dev/null | awk '{print $1}')"

jq -s --arg cand "$LABEL" --argjson runs "$RUNS" --argjson secs "$(( $(date +%s) - START ))" \
  --arg commit "$HARNESS_COMMIT" --arg bundle_sha "$FIXTURE_BUNDLE_SHA" --arg patch_sha "$FIXTURE_PATCH_SHA" \
  --argjson stop_classes "${STOP_CLASSES_JSON:-[]}" '
  def committed_runs: [.[] | select(.measure.committed)];
  def valid_committed_runs: [.[] | select(.valid and .measure.committed)];
  def scored_runs: [.[] | select(.valid and .measure.committed and ((.measure.rules_total // 0) > 0))];
  def num(f): map(f) | add;
  def mean: if length > 0 then add / length else 0 end;
  def sd: if length == 0 then 0 else (mean) as $m | (map(($m - .) * ($m - .)) | add / length | sqrt) end;
  def stop_class: if .rc == 124 then "timeout" elif .rc != 0 then "exit-nonzero" elif ((.session.attributed // false) | not) then "unattributed" elif (((.session.escapes // []) | length) > 0) then "escaped" else null end;
  def failed_assertions: [.[] | select(.valid) | (.measure.assertions // [])[] | select(.pass == false) | .id] | unique;
  (scored_runs | map(.measure.rules_satisfied / .measure.rules_total)) as $valid_correctness |
  {
    "candidate": $cand,
    runs: $runs,
    committed: (committed_runs | length),
    one_commit_rate: (([.[] | select(.measure.one_commit // false)] | length) / $runs),
    correctness: (if ($valid_correctness | length) > 0 then ($valid_correctness | mean) else null end),
    consistency: (if ($valid_correctness | length) > 0 then (([.[] | select(.valid and .measure.committed and ((.measure.rules_total // 0) > 0) and .measure.rules_satisfied == .measure.rules_total)] | length) / ($valid_correctness | length)) else null end),
    failed_assertions: failed_assertions,
    body_chars_mean: (if (committed_runs | length) > 0 then ((committed_runs | num(.measure.body_chars // 0)) / (committed_runs | length)) else 0 end),
    body_chars_max: (if (committed_runs | length) > 0 then (committed_runs | map(.measure.body_chars // 0) | max) else 0 end),
    subject_chars_max: (if (committed_runs | length) > 0 then (committed_runs | map(.measure.subject_len // 0) | max) else 0 end),
    valid: ([.[] | select(.valid)] | length),
    invalid: ([.[] | select(.valid == false)] | length),
    invalid_rate: (([.[] | select(.valid == false)] | length) / $runs),
    unattributed: ([.[] | select((.session.attributed // false) == false)] | length),
    escaped_runs: ([.[] | select(((.session.escapes // []) | length) > 0)] | length),
    tokens_in: ([.[] | .session.tokens.input // 0] | add),
    tokens_out: ([.[] | .session.tokens.output // 0] | add),
    tokens_total: ([.[] | .session.tokens.total // 0] | add),
    files_opened_mean: (([.[] | .session.files_opened // 0] | add) / $runs),
    turns: ([.[] | .session.turns // 0] | add),
    correctness_runs: $valid_correctness,
    correctness_sd: ($valid_correctness | sd),
    elapsed_mean: (([.[] | .elapsed // 0] | add) / $runs),
    models: ([.[] | .model] | unique),
    harness_commit: $commit,
    fixture: {bundle_sha256: $bundle_sha, patch_sha256: $patch_sha},
    wall_seconds: $secs,
    runs_detail: map({run, rc, valid, model, new_commits: (.measure.new_commits // 0), one_commit: (.measure.one_commit // false), body_chars: (.measure.body_chars // 0), subject_len: (.measure.subject_len // 0), rules: (.measure.rules_satisfied // 0), turns: (.session.turns // 0), tokens_total: (.session.tokens.total // 0), escapes: ((.session.escapes // []) | length), stop_class: (stop_class as $s | if $s != null and ($stop_classes | index($s)) then $s else null end), measure})
  }' "$CASE_DIR/runs.jsonl" | tee "$OUT/measure-$LABEL.json"

if [[ "$REQUIRE_VALID" == true ]]; then
  if ! jq -e '(.invalid == 0) and (.unattributed == 0) and (.escaped_runs == 0)' \
    "$OUT/measure-$LABEL.json" >/dev/null 2>&1; then
    echo "refused: not evidence -- $(jq -r '"invalid \(.invalid), unattributed \(.unattributed), escaped \(.escaped_runs) of \(.runs)"' "$OUT/measure-$LABEL.json")" >&2
    exit 3
  fi
fi
