#!/usr/bin/env bash
# Prints the measured context use of the current pi session.
# Reads the provider's own usage from the session file, so the number is measured, not estimated.
set -uo pipefail

if [[ -z "${PI_SESSION_FILE:-}" || ! -f "${PI_SESSION_FILE}" ]]; then
  echo "no PI_SESSION_FILE in this shell, so the context use cannot be read" >&2
  exit 1
fi

tokens=$(jq -r 'select(.type == "message" and .message.role == "assistant" and (.message.usage.totalTokens // 0) > 0)
  | .message.usage.totalTokens' "$PI_SESSION_FILE" 2>/dev/null | tail -n 1)

if [[ -z "$tokens" ]]; then
  echo "no assistant usage in $PI_SESSION_FILE yet, so the context use is unknown" >&2
  exit 1
fi

# The denominator is the model's declared window from the catalog pi resolved the model against.
window=$(node -e '
const store = process.env.HOME + "/.pi/agent/models-store.json";
let d;
try { d = require(store); } catch { process.exit(0); }
const want = process.env.PI_MODEL || "";
const provider = process.env.PI_PROVIDER || "";
const hits = [];
(function walk(o) {
  if (!o || typeof o !== "object") return;
  if (o.id === want && o.contextWindow) hits.push(o);
  for (const v of Object.values(o)) walk(v);
})(d);
const pick = hits.find((h) => h.provider === provider) ?? hits[0];
if (pick) process.stdout.write(String(pick.contextWindow));
' 2>/dev/null)

if [[ -z "$window" ]]; then
  printf 'context %s tokens; the declared window is not in the catalog, so no percentage\n' "$tokens"
  exit 0
fi

awk -v a="$tokens" -v b="$window" 'BEGIN {
  printf "context %d of %d tokens, %.1f%% used, %d left\n", a, b, 100 * a / b, b - a
}'
