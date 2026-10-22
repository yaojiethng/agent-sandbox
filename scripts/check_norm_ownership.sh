#!/usr/bin/env bash
# scripts/check_norm_ownership.sh
# The norm ledger and its gate: every prose line of the two prose standards
# carries an observer, and every line that cites a skill is held to that skill as
# its source of truth.
#
# A norm is a rule when an observer catches its violation. An observer is a gate
# in scripts/lint.sh, a lint rule under scripts/lint/, a prompt, or a maintenance
# skill a prompt dispatches. A norm with no observer is a judgement: it states
# how a writer decides, and nothing detects a breach. The label follows from the
# observer, so the ledger stores no label: it stores the observer and one mark
# for the prose that states what is rather than how to decide. A judgement that more than
# one document uses lives in a skill, and the line cites that skill. The cited
# skill is the line's `source_of_truth`; it is derived from the text, never typed.
#
# Usage:
#   check_norm_ownership.sh --generate   rewrite the ledger from the sources,
#                                       preserving the mark and observer already
#                                       recorded for a line whose text is
#                                       unchanged, deriving the source of truth, and marking
#                                       a new line UNCLASSIFIED
#   check_norm_ownership.sh --check      fail when a source line is unclassified,
#                                       a ledger row no longer exists, a mark is
#                                       neither norm nor description, a description
#                                       carries an observer, an observer names nothing
#                                       that runs, a source of truth is stale or names a
#                                       skill that does not exist, or a line cites two
#                                       skills
#   check_norm_ownership.sh --groups     print the judgement map, one row per
#                                       group, and fail when a judgement line has
#                                       no group, a group's note names a skill
#                                       that does not exist, a row's source of truth
#                                       disagrees with its group, or two notes
#                                       claim one group
#   check_norm_ownership.sh --regroup    rewrite the grouping file: group every
#                                       sourced judgement under `j-source-of-truth-<skill>`,
#                                       keep the group of a line that names no
#                                       source of truth, and drop a row whose line is gone
#
# Test seam: NORM_OWNERSHIP_SCAN_ROOT points the scan at a fixture root that
# mirrors the repository layout.
#
# The ledger is `scripts/lint/norm-ownership.tsv`, six tab-separated columns:
# hash, source, mark, observer, source_of_truth, text. The hash is the line's
# SHA-1, so an edited sentence loses its row and fails the gate until a reader
# marks it again. The mark is `norm` or `description`; rule and judgement are
# read off the observer, so no row states them. A description states what is and
# carries no observer; a norm with an observer is a rule, and a norm without one
# is a judgement. The source of truth is `none` or `skill:<name>`, derived from the skill path the
# sentence cites.
#
# The grouping is `scripts/lint/norm-judgements.tsv`, three tab-separated
# columns: hash, group, note. It is hand-maintained only for a judgement that
# names no source of truth, because which judgement a line states is a reading. A sourced
# line needs no row here: its group is derived, and a map row that disagrees
# with the derivation fails.
#
# The scan set is the two source documents. A judgement that a convention skill
# also states is outside this ledger, because the independence of that skill is
# its own guide's subject; the map header names the limit.
#
# The scan reads paragraph lines only. A fenced block, a heading, a table row and
# a horizontal rule are not candidate lines, so a rule stated in a table is
# outside this ledger, and no row here claims to cover it.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="${NORM_OWNERSHIP_SCAN_ROOT:-$REPO_ROOT}"
INTERFACE="$REPO_ROOT/src/build/container-interface.mjs"
LEDGER="$SCAN_ROOT/scripts/lint/norm-ownership.tsv"
JUDGEMENTS="$SCAN_ROOT/scripts/lint/norm-judgements.tsv"
SOURCES=(
  "docs/policies/documentation_policy.md"
  "docs/development/prompt-authoring-conventions.md"
)
# The project convention corpus is read from the repository, not shipped as a
# container surface, so the manifest does not declare it.
EXTRA_SKILL_ROOT=".agents/skills"
# TAB keyes the per-source maps in `check`: a line's identity is its source
# document together with its text, so the same sentence in both documents is
# still two lines to classify.
TAB=$'\t'

usage() { echo "usage: check_norm_ownership.sh [--generate|--check|--groups|--regroup]" >&2; exit 2; }

# SKILL_NAME_LIST and PROMPT_FILE_LIST -- the declared roots, read once. A
# per-line derivation and a per-row observer test both need them, and walking
# the roots per row makes the gate cost seconds instead of milliseconds.
SKILL_NAME_LIST=""
PROMPT_FILE_LIST=""
declare -A OBSERVER_OK=()
with_skill_names() {
  [[ -n "$SKILL_NAME_LIST" ]] && return 0
  SKILL_NAME_LIST="$(skill_names | tr '\n' ' ')"
  SKILL_NAME_LIST="${SKILL_NAME_LIST% }"
}
with_prompt_files() {
  [[ -n "$PROMPT_FILE_LIST" ]] && return 0
  PROMPT_FILE_LIST="$(prompt_files)"
}

manifest_roots() {
  local kind="$1"
  [[ -f "$INTERFACE" ]] || return 1
  node "$INTERFACE" roots --kind "$kind" --root "$SCAN_ROOT" || return 1
}

skill_roots() {
  manifest_roots skills || true
  [[ -d "$SCAN_ROOT/$EXTRA_SKILL_ROOT" ]] && printf '%s\n' "$EXTRA_SKILL_ROOT"
  return 0
}

prompt_roots() { manifest_roots prompts; }

# skill_names  --  every skill a declared skill root holds, one name per line.
skill_names() {
  local root dir name
  while IFS= read -r root; do
    [[ -d "$SCAN_ROOT/$root" ]] || continue
    for dir in "$SCAN_ROOT/$root"/*/; do
      [[ -f "$dir/SKILL.md" ]] || continue
      name="${dir%/}"
      printf '%s\n' "${name##*/}"
    done
  done < <(skill_roots) | sort -u
}

# prompt_files  --  every prompt file a declared prompt root holds.
prompt_files() {
  local root file
  while IFS= read -r root; do
    [[ -d "$SCAN_ROOT/$root" ]] || continue
    for file in "$SCAN_ROOT/$root"/*.md; do
      [[ -f "$file" ]] && printf '%s\n' "$file"
    done
  done < <(prompt_roots)
}

# candidate_lines FILE  --  print every prose line of FILE, one per output line:
# non-blank, not a heading, not a frontmatter or rule line, not a table row, and
# not inside a fenced block. Each printed line is one ledger unit.
candidate_lines() {
  local file="$1"
  awk '
    /^```/ { fence = !fence; next }
    fence { next }
    /^---$/ { next }
    /^[[:space:]]*$/ { next }
    /^#/ { next }
    /^\|/ { next }
    { print }
  ' "$SCAN_ROOT/$file"
}

# line_hash TEXT  --  the SHA-1 of the line, used as the ledger key so an edit
# to the sentence retires the old row and demands a new classification.
line_hash() { printf '%s' "$1" | sha1sum | cut -d' ' -f1; }

# derive_source_of_truth TEXT  --  `none`, `skill:NAME` for the one skill the line cites,
# or `ambiguous:A,B` when it cites more than one. A citation is the path form
# `skills/<name>/`, which every local skill path in the corpus carries. A URL is
# stripped first, so an upstream project's own skill folder is not a source of truth.
derive_source_of_truth() {
  local rest="$1" name names=""
  while [[ "$rest" =~ (https?://[^\ \)\`]+) ]]; do rest="${rest/"${BASH_REMATCH[1]}"/}"; done
  while [[ "$rest" =~ skills/([A-Za-z0-9._-]+)/ ]]; do
    name="${BASH_REMATCH[1]}"
    rest="${rest#*"skills/$name/"}"
    case " $names " in *" $name "*) ;; *) names="$names $name" ;; esac
  done
  names="${names# }"
  case "$names" in
    "") printf 'none' ;;
    *" "*) printf 'ambiguous:%s' "${names// /,}" ;;
    *) printf 'skill:%s' "$names" ;;
  esac
}

observer_known() {
  local obs="$1"
  if [[ -n "${OBSERVER_OK[$obs]:-}" ]]; then
    return "${OBSERVER_OK[$obs]}"
  fi
  observer_resolves "$obs"
  OBSERVER_OK["$obs"]=$?
  return "${OBSERVER_OK[$obs]}"
}

# observer_resolves OBSERVER  --  the resolution itself, cached by the caller so
# a table of 17 reviewed rows does not grep the prompt corpus 17 times.
# named_in NAME FILE  --  NAME appears in FILE as a whole name, not as a
# fragment of a longer name, a path segment or a URL. A prompt that names a
# skill is the evidence that it dispatches it; `docs` inside `docs/policies/`
# is not a dispatch of a skill called `docs`.
named_in() {
  local name="${1//./\\.}"
  grep -qE "(^|[^A-Za-z0-9._/-])${name}([^A-Za-z0-9._/-]|\$)" "$2"
}

observer_resolves() {
  local obs="$1" name file
  case "$obs" in
    none) return 0 ;;
    gate:*)
      name="${obs#gate:}"
      named_in "$name" "$SCAN_ROOT/scripts/lint.sh" && return 0
      return 1 ;;
    lint:*)
      name="${obs#lint:}"
      [[ -f "$SCAN_ROOT/scripts/lint/$name" ]] && return 0
      return 1 ;;
    prompt:*)
      with_prompt_files
      name="${obs#prompt:}"
      grep -qE "/$name\.md$" <<< "$PROMPT_FILE_LIST" && return 0
      return 1 ;;
    review:*)
      with_skill_names
      with_prompt_files
      name="${obs#review:}"
      [[ " $SKILL_NAME_LIST " == *" $name "* ]] || return 1
      # A reviewer is admitted by the reference only as a skill a prompt
      # dispatches. A prompt that names the skill is the evidence; prose that
      # mentions it without dispatching it is not distinguishable, so the test
      # is the name alone.
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        named_in "$name" "$file" && return 0
      done <<< "$PROMPT_FILE_LIST"
      return 1 ;;
    *) return 1 ;;
  esac
}

generate() {
  local tmp file text hash mark obs source_of_truth prior
  tmp="$(mktemp)"
  {
    echo "# Norm ledger. Generated by scripts/check_norm_ownership.sh --generate."
    echo "# Columns: hash, source, mark, observer, source_of_truth, text. Unit: one prose line."
    echo "# mark is norm or description. A description states what is and carries no observer; a norm with an observer is a rule, and a norm without one is a judgement. UNCLASSIFIED fails --check."
    echo "# observer is none, gate:<script>, lint:<file>, prompt:<name> or review:<skill>. A review skill must be one a prompt names, at a word boundary."
    echo "# source_of_truth is none or skill:<name>, derived for a judgement from the skill path it cites. --check rejects a hand edit."
  } > "$tmp"
  for file in "${SOURCES[@]}"; do
    while IFS= read -r text; do
      hash="$(line_hash "$text")"
      mark="UNCLASSIFIED"; obs="UNCLASSIFIED"
      if [[ -f "$LEDGER" ]]; then
        prior="$(awk -F'\t' -v h="$hash" '$1==h {print $3"\t"$4; exit}' "$LEDGER")"
        if [[ -n "$prior" ]]; then
          mark="${prior%%$'\t'*}"
          obs="${prior#*$'\t'}"
        fi
      fi
      source_of_truth="$(derive_source_of_truth "$text")"
      [[ "$mark" == norm && "$obs" == none ]] || source_of_truth=none
      case "$source_of_truth" in
        ambiguous:*)
          echo "norm-ownership: $file cites two skills (${source_of_truth#ambiguous:}); reword the line so it names one, or --check will reject it: ${text:0:70}..." >&2 ;;
      esac
      printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$hash" "$file" "$mark" "$obs" "$source_of_truth" "$text" >> "$tmp"
    done < <(candidate_lines "$file")
  done
  mv "$tmp" "$LEDGER"
  echo "norm-ownership: wrote $(( $(wc -l < "$LEDGER") - 5 )) row(s) to ${LEDGER#"$SCAN_ROOT"/}"
}

check() {
  with_skill_names
  [[ -f "$LEDGER" ]] || { echo "norm-ownership: missing ledger $LEDGER" >&2; return 1; }
  local rc=0 file text hash mark obs source_of_truth derived label count=0 gated=0 reviewed=0 judge=0 description=0 sourced=0
  # One read of both sources: `present` holds every line under its source, and
  # `unclassified` holds every line under the same key, the ledger loop removing
  # each key it accounts for. Both answers come from one pass, not a process per row.
  local -A present=() unclassified=()
  local key
  for file in "${SOURCES[@]}"; do
    while IFS= read -r text; do
      key="${file}${TAB}${text}"
      present["$key"]=1
      unclassified["${file}${TAB}$(line_hash "$text")"]="$file: $text"
    done < <(candidate_lines "$file")
  done
  while IFS= read -r row; do
    [[ "$row" == \#* || -z "$row" ]] && continue
    IFS=$'\t' read -r hash file mark obs source_of_truth text <<< "$row"
    unset "unclassified[${file}${TAB}${hash}]"
    count=$((count + 1))
    case "$mark" in
      norm) label=$([[ "$obs" == none ]] && echo judgement || echo rule) ;;
      description)
        if [[ "$obs" != none ]]; then
          echo "norm-ownership: $file marks a description with an observer '$obs', for: ${text:0:70}..." >&2
          rc=1
          continue
        fi
        label=description ;;
      *)
        echo "norm-ownership: $file has mark '$mark', which is neither norm nor description, for: ${text:0:70}..." >&2
        rc=1
        continue ;;
    esac
    derived="$(derive_source_of_truth "$text")"
    if [[ "$label" != judgement ]]; then
      if [[ "$source_of_truth" != none ]]; then
        echo "norm-ownership: $file derives a source of truth only for a judgement, and records '$source_of_truth': ${text:0:70}..." >&2
        rc=1
        continue
      fi
      derived=none
    fi
    case "$derived" in
      ambiguous:*)
        echo "norm-ownership: $file cites more than one skill (${derived#ambiguous:}), so its source of truth is ambiguous: ${text:0:70}..." >&2
        rc=1
        continue ;;
    esac
    if [[ "$source_of_truth" != "$derived" ]]; then
      echo "norm-ownership: $file records source of truth '$source_of_truth' but its text derives '$derived'; rerun --generate, do not hand-edit the ledger: ${text:0:70}..." >&2
      rc=1
      continue
    fi
    if [[ "$source_of_truth" != none ]] && [[ " $SKILL_NAME_LIST " != *" ${source_of_truth#skill:} "* ]]; then
      echo "norm-ownership: $file has source of truth '${source_of_truth#skill:}', which no declared skill root holds, for: ${text:0:70}..." >&2
      rc=1
      continue
    fi
    if ! observer_known "$obs"; then
      echo "norm-ownership: $file names observer '$obs' that does not run, for: ${text:0:70}..." >&2
      rc=1
      continue
    fi
    if [[ -z "${present[${file}${TAB}${text}]:-}" ]]; then
      # A ledger row whose sentence left its source is an orphan: either the
      # sentence was deleted and its rule needs re-homing, or the plan drifted.
      echo "norm-ownership: orphaned row for $file: ${text:0:70}..." >&2
      rc=1
      continue
    fi
    [[ "$source_of_truth" != none ]] && sourced=$((sourced + 1))
    case "$label-$obs" in
      rule-gate:*) gated=$((gated + 1)) ;;
      rule-lint:*) gated=$((gated + 1)) ;;
      rule-review:*) reviewed=$((reviewed + 1)) ;;
      rule-prompt:*) reviewed=$((reviewed + 1)) ;;
      judgement-none) judge=$((judge + 1)) ;;
      description-none) description=$((description + 1)) ;;
      *) gated=$((gated + 1)) ;;
    esac
  done < "$LEDGER"
  for key in "${!unclassified[@]}"; do
    echo "norm-ownership: unclassified line in ${unclassified[$key]:0:120}..." >&2
    rc=1
  done
  if [[ $rc -eq 0 ]]; then
    groups --quiet >/dev/null || rc=1
  fi
  if [[ $rc -eq 0 ]]; then
    echo "norm-ownership: clean across $count row(s), $gated gated, $reviewed reviewed, $judge judgement, $description description, $sourced sourced"
  fi
  return $rc
}

regroup() {
  [[ -f "$LEDGER" ]] || { echo "norm-ownership: missing ledger $LEDGER" >&2; return 1; }
  [[ -f "$JUDGEMENTS" ]] || : > "$JUDGEMENTS"
  local out
  out="$(mktemp)"
  {
    echo "# Judgement grouping map. Keyed by the ledger hash."
    echo "# Columns: hash, group, note. Unit: one prose line the ledger classes as a judgement."
    echo "# A line that cites a skill is sourced there. --regroup derives its group as j-source-of-truth-<skill> and its note as skill:<skill>, so no hand edit is needed and a map row that disagrees fails."
    echo "# A line that cites no skill carries a hand row. note is skill:<name> when the source of truth is a skill the line does not name, candidate[:<name>] for one document's judgement that should generalise, or - for a judgement that stays local."
    echo "# The scan set is the two source documents, so a judgement a convention skill also states counts one document here. Read a class-1 group with that limit."
  } > "$out"
  awk -F'\t' '
    NR==FNR { if ($0 ~ /^#/ || $0 == "") next; group[$1] = $2; note[$1] = $3; next }
    $0 ~ /^#/ || $0 == "" { next }
    !($3 == "norm" && $4 == "none") { next }
    {
      if ($5 != "none") printf "%s\tj-source-of-truth-%s\t%s\n", $1, substr($5, 7), $5
      else if ($1 in group) printf "%s\t%s\t%s\n", $1, group[$1], note[$1]
      else printf "%s\tj-ungrouped\t-\n", $1
    }
  ' "$JUDGEMENTS" "$LEDGER" >> "$out"
  mv "$out" "$JUDGEMENTS"
  echo "norm-ownership: regrouped, $(grep -c . "$JUDGEMENTS" || true) map line(s)"
}

groups() {
  local quiet=0
  [[ "${1:-}" == "--quiet" ]] && quiet=1
  [[ -f "$LEDGER" ]] || { echo "norm-ownership: missing ledger $LEDGER" >&2; return 1; }
  [[ -f "$JUDGEMENTS" ]] || { echo "norm-ownership: missing grouping map $JUDGEMENTS" >&2; return 1; }
  local out rc=0 names
  with_skill_names
  names="$SKILL_NAME_LIST"
  out="$(awk -F'\t' -v quiet="$quiet" -v names="$names" '
    function skill_ok(name) { return index(" " names " ", " " name " ") > 0 }
    FNR==NR {
      if ($0 ~ /^#/ || $0 == "") next
      group[$1] = $2; note[$1] = $3; mapped[$1] = 1; next
    }
    $0 ~ /^#/ || $0 == "" { next }
    !($3 == "norm" && $4 == "none") { next }
    {
      judged++
      g = ""; n = ""
      if ($5 != "none") {
        name = substr($5, 7)
        if (!skill_ok(name)) {
          printf "norm-ownership: source of truth %s does not resolve to a skill, for: %s\n", $5, substr($6, 1, 70) > "/dev/stderr"
          failed = 1
        }
        g = "j-source-of-truth-" name; n = $5
        if ($1 in mapped && (group[$1] != g || note[$1] != n)) {
          printf "norm-ownership: ledger row %s is sourced in %s but its map row says %s; rerun --regroup\n", substr($1, 1, 8), g, group[$1] > "/dev/stderr"
          failed = 1
        }
      } else {
        if (!($1 in mapped)) {
          printf "norm-ownership: ungrouped judgement line in %s: %s\n", $2, substr($6, 1, 70) > "/dev/stderr"
          failed = 1; next
        }
        g = group[$1]; n = note[$1]
        if (n ~ /^skill:/) {
          name = substr(n, 7)
          if (!skill_ok(name)) {
            printf "norm-ownership: group %s names source of truth %s, which no declared skill root holds\n", g, name > "/dev/stderr"
            failed = 1
          }
        }
      }
      sites[g]++
      doc[g SUBSEP $2] = 1
      if (g in note_of) {
        if (n != note_of[g]) {
          printf "norm-ownership: group %s carries two notes, %s and %s\n", g, note_of[g], n > "/dev/stderr"
          failed = 1
        }
      } else {
        note_of[g] = n
      }
      joined[$1] = 1
      if ($5 != "none") sourced_count++
    }
    END {
      for (key in doc) { split(key, parts, SUBSEP); docs[parts[1]]++ }
      for (g in sites) {
        d = docs[g] + 0
        cls = (d >= 2) ? "class-1" : (note_of[g] ~ /^candidate/) ? "class-2" : (note_of[g] ~ /^skill:/) ? "sourced" : "local"
        if (cls == "class-1" && note_of[g] !~ /^skill:/) {
          printf "norm-ownership: group %s is stated by %d documents, so it needs a source of truth: give it a skill note, or repoint its sites at one\n", g, d > "/dev/stderr"
          failed = 1
        }
        if (cls == "class-1") wide++
        if (!quiet) printf "%s\t%d\t%d\t%s\t%s\n", g, sites[g], d, cls, note_of[g]
      }
      for (h in mapped) if (!(h in joined)) {
        printf "norm-ownership: grouping row names a line the ledger no longer holds: %s\n", h > "/dev/stderr"
        failed = 1
      }
      if (!quiet) printf "%d judgement line(s), %d of them sourced, %d group(s) stated by 2+ document(s)\n", judged, sourced_count, wide + 0 > "/dev/stderr"
      exit failed
    }
    ' "$JUDGEMENTS" "$LEDGER" | sort -t$'\t' -k4,4 -k1,1)" || rc=$?
  if [[ $quiet -eq 0 ]]; then
    printf 'group\tsites\tdocuments\tclass\tnote\n'
    printf '%s\n' "$out"
  fi
  return $rc
}

case "${1:---check}" in
  --generate) generate ;;
  --check) check ;;
  --groups) groups ;;
  --regroup) regroup ;;
  *) usage ;;
esac
