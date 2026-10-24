#!/usr/bin/env bash
# tests/test_cost_ledger.sh  --  pi session cost ledger

set -uo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/libs/test_common.sh"
test_setup

make_session() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "$dir/session.jsonl" <<'JSON'
{"type":"session","version":3,"id":"11111111-2222-3333-4444-555555555555","timestamp":"2026-01-01T00:00:00.000Z","cwd":"/tmp/fixture-cwd"}
{"type":"thinking_level_change","id":"think-1","timestamp":"2026-01-01T00:00:00.500Z","thinkingLevel":"high"}
{"type":"message","id":"msg-1","timestamp":"2026-01-01T00:00:01.000Z","message":{"role":"assistant","provider":"anthropic","model":"claude-opus-4","stopReason":"stop","usage":{"input":10,"output":20,"cacheRead":30,"cacheWrite":40,"reasoning":5,"totalTokens":105,"cost":{"input":0.001,"output":0.002,"cacheRead":0.003,"cacheWrite":0.004,"total":0.01}}}}
{"type":"message","id":"msg-2","timestamp":"2026-01-01T00:00:04.000Z","message":{"role":"assistant","provider":"anthropic","model":"claude-opus-4","stopReason":"stop","usage":{"input":7,"output":8,"cacheRead":5,"cacheWrite":4,"reasoning":2,"totalTokens":26,"cost":{"input":0.0007,"output":0.0008,"cacheRead":0.0005,"cacheWrite":0.0004,"total":0.0024}}}}
JSON
}

test_cost_ledger_sums_single_session() {
  local root file out
  root="$(get_fixture_dir)"
  make_session "$root"
  file="$root/session.jsonl"
  out="$(node "$REPO_ROOT/scripts/cost_ledger.mjs" --session "$file")"
  assert_eq "$(printf '%s' "$out" | jq -r '.runtime')" "pi" "runtime"
  assert_eq "$(printf '%s' "$out" | jq -r '.session')" "11111111-2222-3333-4444-555555555555" "session id"
  assert_eq "$(printf '%s' "$out" | jq -r '.provider')" "anthropic" "provider"
  assert_eq "$(printf '%s' "$out" | jq -r '.model')" "claude-opus-4" "model"
  assert_eq "$(printf '%s' "$out" | jq -r '.thinking')" "high" "thinking"
  assert_eq "$(printf '%s' "$out" | jq -r '.start')" "2026-01-01T00:00:00.000Z" "start"
  assert_eq "$(printf '%s' "$out" | jq -r '.end')" "2026-01-01T00:00:04.000Z" "end"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.wall_ms')" 4000 "wall_ms"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.messages')" 2 "message count"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.tokens.input')" 17 "tokens.input"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.tokens.output')" 28 "tokens.output"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.tokens.cacheRead')" 35 "tokens.cacheRead"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.tokens.cacheWrite')" 44 "tokens.cacheWrite"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.tokens.reasoning')" 7 "tokens.reasoning"
  assert_eq_num "$(printf '%s' "$out" | jq -r '.tokens.total')" 131 "tokens.total"
  assert_eq "$(printf '%s' "$out" | jq -r '.cost.input')" "0.0017000000000000001" "cost.input"
  assert_eq "$(printf '%s' "$out" | jq -r '.cost.output')" "0.0028" "cost.output"
  assert_eq "$(printf '%s' "$out" | jq -r '.cost.cacheRead')" "0.0035" "cost.cacheRead"
  assert_eq "$(printf '%s' "$out" | jq -r '.cost.cacheWrite')" "0.0044" "cost.cacheWrite"
  assert_eq "$(printf '%s' "$out" | jq -r '.cost.total')" "0.0124" "cost.total"
}

test_cost_ledger_root_walks() {
  local root out count
  root="$(get_fixture_dir)"
  make_session "$root"
  out="$(node "$REPO_ROOT/scripts/cost_ledger.mjs" --root "$root")"
  count="$(printf '%s\n' "$out" | grep -c . || true)"
  assert_eq_num "$count" 1 "one record per session"
}

make_failure_session() {
  local dir="$1" model="$2" tag="$3"
  mkdir -p "$dir"
  cat > "$dir/$tag.jsonl" <<JSON
{"type":"session","version":3,"id":"session-$tag","timestamp":"2026-01-01T00:00:00.000Z","cwd":"/tmp/fixture-cwd"}
{"type":"message","id":"m1","timestamp":"2026-01-01T00:00:01.000Z","message":{"role":"assistant","provider":"deepseek","model":"$model","stopReason":"error","errorMessage":"400 invalid_request_error: reasoning_effort: unknown variant \`minimal\`"}}
{"type":"message","id":"m2","timestamp":"2026-01-01T00:00:02.000Z","message":{"role":"assistant","provider":"deepseek","model":"deepseek-flash","stopReason":"error","errorMessage":"429 usage limit reached"}}
{"type":"message","id":"m3","timestamp":"2026-01-01T00:00:03.000Z","message":{"role":"assistant","provider":"deepseek","model":"$model","stopReason":"aborted","errorMessage":"This operation was aborted"}}
JSON
}

test_cost_ledger_failure_view() {
  local root out count
  root="$(get_fixture_dir)"
  make_failure_session "$root" "deepseek-flash" "one"
  out="$(node "$REPO_ROOT/scripts/cost_ledger.mjs" --root "$root" --failures)"
  count="$(printf '%s\n' "$out" | grep -c . || true)"
  assert_eq_num "$count" 2 "one record per failure, and a cancelled turn is not one"
  assert_eq "$(printf '%s\n' "$out" | head -1 | jq -r '.extension.scope')" "request" "the extension's rule reads the request scope"
  assert_eq "$(printf '%s\n' "$out" | head -1 | jq -r '.library.scope')" "request" "the library's rule reads the request scope"
  assert_eq "$(printf '%s\n' "$out" | head -1 | jq -r '.provider')" "deepseek" "the request's provenance carries the provider"
}

test_cost_ledger_census_and_attribution() {
  local root out absent count
  root="$(get_fixture_dir)"
  make_failure_session "$root" "deepseek-flash" "one"
  out="$(node "$REPO_ROOT/scripts/cost_ledger.mjs" --root "$root" --census)"
  count="$(printf '%s\n' "$out" | jq -s '[.[] | select(.rule == "library" and .scope == "request")][0].count' -r)"
  assert_eq_num "$count" 1 "the census counts the request-scope failure per rule"
  local first last
  first="$(printf '%s\n' "$out" | head -1 | jq -r '.first')"
  last="$(printf '%s\n' "$out" | head -1 | jq -r '.last')"
  assert_eq "$([ "$first" != "null" ] && [ "$last" != "null" ] && [ "$first" -le "$last" ] && echo ok)" "ok" "each census cell carries the window it was measured over"
  out="$(node "$REPO_ROOT/scripts/cost_ledger.mjs" --root "$root" --attribution)"
  absent="$(printf '%s\n' "$out" | jq -s '[.[] | select(.kind == "attribution-summary")][0].absentPairs' -r)"
  assert_eq_num "$absent" 1 "a shape seen on one model only has no cross-model pair"
  make_failure_session "$root" "deepseek-v4-flash" "two"
  out="$(node "$REPO_ROOT/scripts/cost_ledger.mjs" --root "$root" --attribution)"
  absent="$(printf '%s\n' "$out" | jq -s '[.[] | select(.kind == "attribution-summary")][0].absentPairs' -r)"
  assert_eq_num "$absent" 0 "the same shape on a second model is a cross-model pair"
}

run_test test_cost_ledger_sums_single_session
run_test test_cost_ledger_root_walks
run_test test_cost_ledger_failure_view
run_test test_cost_ledger_census_and_attribution

test_done "cost_ledger"
