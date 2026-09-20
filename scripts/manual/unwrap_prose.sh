#!/usr/bin/env bash
# scripts/manual/unwrap_prose.sh -- sweep manually word-wrapped prose out of
# markdown documents (run on the HOST, repo root).
#
# documentation_policy.md `### Line wrapping`: prose is one paragraph per
# physical line; never insert a line break mid-paragraph. This tool unwraps
# violations and proves it changed nothing else.
#
# Usage:
#   unwrap_prose.sh [--check] FILE...
#
#   default   unwrap each FILE, then verify against a pre-run copy:
#             (1) fenced code regions (``` or ~~~, any indent) byte-identical
#             (2) structural lines (headings, nested lists, tables, quotes,
#                 hr separators, indented code) identical
#             (3) every output line is a merge of consecutive input lines,
#                 keeping the first source line's indent
#             On any check failure the file is restored untouched and the
#             run exits 1.
#   --check   detector only: report remaining wrapped-prose flags, exit 1
#             if any (no files are modified)
#
# The unwrap joiner never touches: fenced regions, blank lines, headings,
# lists (any indent), tables, blockquotes, hr separators, indented code.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && { CHECK_ONLY=true; shift; }
[[ $# -ge 1 ]] || { echo "usage: $0 [--check] FILE..." >&2; exit 2; }

WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/unwrap_prose.XXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT

# _flags FILE -- print wrapped-prose violations: a line lacking terminal
# punctuation whose next line continues lowercase, outside fences/tables.
_flags() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; prev = $0; next }
    fence { prev = $0; next }
    NR>1 && prev !~ /(^$|[.:!?;—–)"\*]$)/ &&
    prev !~ /^[#>|`-]/ && prev !~ /^[0-9]+\./ &&
    $0 ~ /^[a-z]/ { print FILENAME ":" NR-1 ": " prev }
    { prev = $0 }
  ' "$1"
}

# _unwrap FILE -- merge wrapped prose lines (v4 joiner; indent-preserving).
_unwrap() {
  awk '
    /^[[:space:]]*(```|~~~)/ {
      if (para != "") { print indent para; para = ""; indent = "" }
      print; infence = !infence; next
    }
    infence { print; next }
    {
      line = $0
      is_struct = (line ~ /^[[:space:]]*$/) ||
                  (line ~ /^[[:space:]]*#/) ||
                  (line ~ /^[[:space:]]*\|/) ||
                  (line ~ /^[[:space:]]*>/) ||
                  (line ~ /^[[:space:]]*([-*+] )/) ||
                  (line ~ /^[[:space:]]*[0-9]+[.)] /) ||
                  (line ~ /^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/) ||
                  (line ~ /^    /)
      if (is_struct) {
        if (para != "") { print indent para; para = ""; indent = "" }
        print line; next
      }
      cont = line; sub(/^[[:space:]]+/, "", cont)
      if (para == "") {
        match(line, /^[[:space:]]*/)
        indent = substr(line, 1, RLENGTH)
        para = cont; next
      }
      if (para !~ /[.!?:;)"\x27—-]$/ || cont ~ /^[a-z,(]/) {
        para = para " " cont; next
      }
      print indent para
      match(line, /^[[:space:]]*/)
      indent = substr(line, 1, RLENGTH)
      para = cont
    }
    END { if (para != "") print indent para }
  ' "$1"
}

# _verify ORIG UNWRAPPED -- fail loudly if the unwrap changed anything but
# prose line merges; prints the failing check and returns 1.
_verify() {
  local ORIG="$1" NEW="$2"
  awk '/^[[:space:]]*(```|~~~)/{f=!f; print; next} f{print}' "$ORIG" > "$WORKDIR/f.o"
  awk '/^[[:space:]]*(```|~~~)/{f=!f; print; next} f{print}' "$NEW" > "$WORKDIR/f.n"
  cmp -s "$WORKDIR/f.o" "$WORKDIR/f.n" || { echo "  fenced regions differ"; return 1; }

  awk '
    /^[[:space:]]*(```|~~~)/{f=!f; next}
    f{next}
    /^[[:space:]]*$/ {next}
    /^[[:space:]]*#/ || /^[[:space:]]*\|/ || /^[[:space:]]*>/ ||
    /^[[:space:]]*([-*+] )/ || /^[[:space:]]*[0-9]+[.)] / ||
    /^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/ || /^    / {print}
  ' "$ORIG" | sort > "$WORKDIR/s.o"
  awk '
    /^[[:space:]]*(```|~~~)/{f=!f; next}
    f{next}
    /^[[:space:]]*$/ {next}
    /^[[:space:]]*#/ || /^[[:space:]]*\|/ || /^[[:space:]]*>/ ||
    /^[[:space:]]*([-*+] )/ || /^[[:space:]]*[0-9]+[.)] / ||
    /^[[:space:]]*(-{3,}|\*{3,}|_{3,})[[:space:]]*$/ || /^    / {print}
  ' "$NEW" | sort > "$WORKDIR/s.n"
  cmp -s "$WORKDIR/s.o" "$WORKDIR/s.n" || { echo "  structural lines differ"; return 1; }

  # merge-and-indent check: NEW must be OLD with consecutive-line merges,
  # each emitted line keeping the first consumed source line's indent.
  awk -v old="$ORIG" -v new="$NEW" '
    BEGIN {
      while ((getline line < old) > 0) { o[++on] = line }
      while ((getline line < new) > 0) { n[++nn] = line }
      i = 1
      for (j = 1; j <= nn; j++) {
        nstr = n[j]; sub(/^[[:space:]]+/, "", nstr)
        match(n[j], /^[[:space:]]*/); nind = RLENGTH
        acc = ""; firstind = -1
        while (1) {
          if (i > on) { print "  output expands input (new line " j ")"; bad = 1; exit 1 }
          match(o[i], /^[[:space:]]*/); oind = RLENGTH
          if (firstind < 0) firstind = oind
          s = o[i]; sub(/^[[:space:]]+/, "", s)
          acc = (acc == "") ? s : acc " " s
          i++
          if (acc == nstr) break
        }
        if (nind != firstind) { print "  indent lost (new line " j ")"; bad = 1; exit 1 }
      }
      if (i <= on) { print "  input lines dropped"; bad = 1; exit 1 }
    }' || return 1
  return 0
}

if $CHECK_ONLY; then
  hits=0
  for f in "$@"; do
    _flags "$f" || true
    c="$( _flags "$f" | wc -l )" || c=0
    hits=$((hits + c))
  done
  printf '%d wrapped-prose flag(s) remaining.\n' "$hits"
  [[ "$hits" -eq 0 ]]
  exit $?
fi

failed=0 unwrapped=0
for f in "$@"; do
  cp "$f" "$WORKDIR/orig"
  _unwrap "$f" > "$WORKDIR/new" && mv "$WORKDIR/new" "$f"
  if ! out="$(_verify "$WORKDIR/orig" "$f")"; then
    printf 'VERIFY FAILED: %s\n%s\n  restored untouched\n' "$f" "$out"
    cp "$WORKDIR/orig" "$f"
    failed=$((failed + 1))
  elif cmp -s "$WORKDIR/orig" "$f"; then
    printf 'unchanged  %s\n' "$f"
  else
    printf 'unwrapped  %s\n' "$f"
    unwrapped=$((unwrapped + 1))
  fi
done

if [[ "$failed" -gt 0 ]]; then
  printf '%d file(s) failed verification and were restored.\n' "$failed"
  exit 1
fi
printf '%d file(s) unwrapped; all verified structure-preserving.\n' "$unwrapped"
