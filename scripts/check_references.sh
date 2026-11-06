#!/usr/bin/env bash
# scripts/check_references.sh
# The reference gate: every reference a declared file makes resolves where its
# reader is. Two rules, and the scanner is `scripts/lint/references.mjs`:
#
#   - a skill invocation names a skill the tree provides, in the broad form a
#     backticked token adjacent to the word "skill";
#   - an absolute mention inside a zone the manifest declares names a root it
#     declares, derived from `image`, `provision`, `mounts`, `env` and `session`.
#
# Both corpora are derived, never listed: the files are the Markdown under each
# cell's `sources`, and the skill names are the `*/SKILL.md` directories in the
# tree. A path outside every declared zone is not the rule's subject, because the
# check asks whether a reference into a zone the manifest builds names a root it
# builds, not whether the container has a `/dev`.
#
# Test seam: --root and --manifest point the scan at a fixture.
#
# Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
# finding count is printed, never encoded in the exit code (see pattern p-14).

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_SCRIPT="$REPO_ROOT/scripts/lint/references.mjs"

if ! command -v node >/dev/null 2>&1; then
  echo "Reference gate: node is not on PATH; cannot read the manifest." >&2
  exit 1
fi

if [[ ! -f "$SCAN_SCRIPT" ]]; then
  echo "Reference gate: $SCAN_SCRIPT is missing; cannot run." >&2
  exit 1
fi

set +e
ARGS=("$@")
# The default root is the repository, and a caller may replace it for a fixture.
# The seam is added only when unset, so the caller's `--root` stays first.
if [[ " $* " != *" --root "* ]]; then
  ARGS=(--root "$REPO_ROOT" "${ARGS[@]}")
fi
node "$SCAN_SCRIPT" "${ARGS[@]}"
rc=$?
set -e

if (( rc != 0 )); then
  echo "Blocking gate: fix the findings above. A skill a shipped file invokes is named in the tree, and a path it names is a root `src/build/container-interface.json` declares."
  echo "Reference gate ($SECONDS s): findings"
  exit 1
fi

echo "Clean (${SECONDS}s)"
