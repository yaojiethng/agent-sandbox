#!/usr/bin/env bash
# scripts/check_launch_sites.sh
# One door for a model launch: the library builds the argv, and nothing else does.
#
# The defect this gate exists for is a consumer that assembles half a decision.
# A launch site that takes the model from the role table and names the provider
# itself runs the table's entry against a runtime the table did not choose: the
# runtime forwards the request, the provider refuses it, and the failure reads as
# a spent route rather than as a misroute. Two such sites existed and both were
# found by reading, which is not a mechanism.
#
# A launch site is a line in an executable file that names a launcher's own flags:
# `pi -p`, `--provider`, or `opencode run`. Markdown is exempt, because a document
# states the invocation as an example and runs nothing. Tests are exempt, because
# a case asserts the argv a launch site builds.
#
# The allowlist is the mechanism's own surface:
#
#   src/libs/dispatch/launch.ts   the only builder of a launch argv
#   scripts/dispatch.sh           the entrypoint that prints or runs it
#   config/agent/bin/review-dispatch.sh  the reviewer's runner, which takes its pair
#                                      from its caller and resolves nothing
#
# Test seam: LAUNCH_SITE_SCAN_ROOT points the scan at a fixture root that mirrors
# the repository layout, so the gate's branches run without touching the real tree.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The finding
# count is printed, never encoded (bash-coding-conventions.md 3.2).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_ROOT="${LAUNCH_SITE_SCAN_ROOT:-$REPO_ROOT}"

ALLOWED=(
  "src/libs/dispatch/launch.ts"
  "scripts/dispatch.sh"
  "src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh"
  "scripts/check_launch_sites.sh"
)

# One pattern per launcher's own shape. A document's example and a test's
# assertion are excluded by the file filters, not by the pattern.
PATTERN='(^|[^[:alnum:]_-])(pi[[:space:]]+(--provider|-p)|opencode[[:space:]]+run)([^[:alnum:]_-]|$)'

is_allowed() {
  local rel="$1" entry
  for entry in "${ALLOWED[@]}"; do
    [[ "$rel" == "$entry" ]] && return 0
  done
  return 1
}

# candidate_files  --  every tracked executable source file under SCAN_ROOT, as a
# path relative to it. A file outside git is still scanned when the scan root is a
# fixture, because the fixture is not a repository.
candidate_files() {
  # Source files only: a data file or a document may quote a launcher's flags
  # without being able to run one.
  if [[ "$SCAN_ROOT" == "$REPO_ROOT" ]]; then
    git -C "$SCAN_ROOT" ls-files
    return 0
  fi
  ( cd "$SCAN_ROOT" && find . -type f ) | sed 's|^./||'
}

# source_file REL  --  whether REL is a file that can execute a launcher.
source_file() {
  case "$1" in
    *.sh|*.bash|*.ts|*.mjs|*.js) return 0 ;;
  esac
  return 1
}

findings=0

while IFS= read -r rel; do
  [[ -n "$rel" ]] || continue
  source_file "$rel" || continue
  case "$rel" in
    tests/*|test/*|*.test.ts) continue ;;
  esac
  is_allowed "$rel" && continue
  file="$SCAN_ROOT/$rel"
  [[ -f "$file" ]] || continue
  hits="$(grep -nE "$PATTERN" "$file" 2>/dev/null)" || continue
  [[ -n "$hits" ]] || continue
  while IFS= read -r hit; do
    printf '%s:%s\n' "$rel" "$hit"
    findings=$((findings + 1))
  done <<<"$hits"
done < <(candidate_files)

if (( findings > 0 )); then
  printf '\nlaunch sites: %d finding(s). A launch belongs behind the library, so the\nprovider, the model and the runtime come from one assignment. Add the file to\nthe allowlist only when it is a declared fixed run.\n' "$findings"
  exit 1
fi

echo "launch sites: clean; every launcher call is behind the library"
