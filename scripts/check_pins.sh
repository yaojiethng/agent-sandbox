#!/usr/bin/env bash
# scripts/check_pins.sh
# The build-input pin gate: every input carries a pin at the strictest form its
# class supports, and src/build/pins.json records what it resolved to. The
# comparison lives in src/build/pins.mjs; this script is the gate wrapper.
#
#   (no flag)   local: read the tree, block on a finding
#   --remote    re-resolve against the registries and report what moved
#   --write     with --remote, record the moved resolutions into pins.json
#   --report    print what each input carries now
#
# A moved artifact is a warning rather than a failure: a republished package is
# information, and the build's own exit status is what fails.
#
# Test seam: PINS_SCAN_ROOT points the check at a fixture root.
#
# Exit codes: 0 = clean, 1 = findings or the gate could not run.

set -uo pipefail

SECONDS=0

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN_MODULE="$REPO_ROOT/src/build/pins.mjs"
SCAN_ROOT="${PINS_SCAN_ROOT:-$REPO_ROOT}"

remote=false
write=false
report=false

for arg in "$@"; do
  case "$arg" in
    --remote) remote=true ;;
    --write) write=true ;;
    --report) report=true ;;
    -h|--help)
      sed -n '3,20p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *)
      echo "check_pins: unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

if ! command -v node >/dev/null 2>&1; then
  echo "Pin gate: node is not on PATH; cannot read the pins file." >&2
  exit 1
fi

if [[ ! -f "$SCAN_MODULE" ]]; then
  echo "Pin gate: $SCAN_MODULE is missing; cannot read the pins file." >&2
  exit 1
fi

if [[ "$report" == true ]]; then
  node "$SCAN_MODULE" report --root "$SCAN_ROOT"
  exit $?
fi

out="$(node "$SCAN_MODULE" check --root "$SCAN_ROOT")"
rc=$?
printf '%s\n' "$out"
if (( rc != 0 )); then
  echo "Pin gate: an input carries no pin, or its pin and the Dockerfile disagree"
  echo "Findings (${SECONDS}s)"
  exit 1
fi

if [[ "$remote" == true ]]; then
  drift_args=(bump --root "$SCAN_ROOT")
  [[ "$write" == true ]] && drift_args+=(--write)
  drift="$(node "$SCAN_MODULE" "${drift_args[@]}")"
  if [[ -n "$drift" ]]; then
    echo "$drift"
    echo "Pin drift: the registries serve artifacts this file did not record"
  else
    echo "Pin drift: none; every remote artifact still resolves as recorded"
  fi
fi

echo "Pin gate: clean; every build input carries its class's strictest pin"
echo "Clean (${SECONDS}s)"
exit 0
