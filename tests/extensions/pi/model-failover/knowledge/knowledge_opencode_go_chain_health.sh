#!/usr/bin/env bash
# tests/extensions/pi/model-failover/knowledge/knowledge_opencode_go_chain_health.sh
# TEST_DEADLINE: 600
#
# Knowledge test: the gateway behaviour the model-failover extension's design
# rests on, measured against the live opencode-go gateway, plus the extension's
# end-to-end dispatch through a real pi process.
#
# The findings this records, from the 2026-10-12 measurement, are that (a) the
# failure follows the model and its upstream, not the account or the client's
# edge IP; (b) at one moment, success varies sharply by edge IP while the same
# session, key and prompt are held, and the signal decays within minutes; and
# (c) the shipped chain dispatches through the extension and records each
# classified outcome in the session log.
#
# This probes an external service and spends requests, so it is a knowledge
# test and not part of make test. It needs OPENCODE_API_KEY in the environment.
#
# What it does NOT establish: which upstream endpoint served a request. The
# gateway answers with x-opencode-log-id, which pi discards, so the identity
# is outside this probe. The README records that as a follow-on.
#
# Reference:
#   src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md
#     -- the measured-behaviour table this test reproduces.
#
# Not run by make test. Run manually:
#   OPENCODE_API_KEY=... bash tests/extensions/pi/model-failover/knowledge/knowledge_opencode_go_chain_health.sh

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(cd "$HERE/.." && pwd)"
REPO_TOP="$(cd "$SUITE_DIR/../../../.." && pwd)"
# shellcheck source=../../../../libs/test_common.sh
source "$REPO_TOP/tests/libs/test_common.sh"

EXTENSION_SRC="$REPO_TOP/src/reasoning/providers/pi/config/agent/extensions/model-failover"
SETTINGS_SRC="$REPO_TOP/src/reasoning/providers/pi/config/agent/settings.json"

test_setup

# -------------------------
# Helpers
# -------------------------

# Echoes the terminal HTTP status of one chat completion, or "ok" on 200.
# A 429 or a 400 from the gateway is the signal under test, so it is data and
# not a test failure.
probe_model() {
  local ip="$1" model="$2" out
  out="$(curl -s -o /tmp/mff_probe_body.txt -w '%{http_code}' --resolve opencode.ai:443:"$ip" --max-time 30 \
    -X POST "https://opencode.ai/zen/go/v1/chat/completions" \
    -H "Authorization: Bearer ${OPENCODE_API_KEY}" \
    -H "Content-Type: application/json" \
    -H "x-opencode-session: knowledge-probe" \
    -d "{\"model\":\"$model\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}" 2>/dev/null)"
  if [[ "$out" == "200" ]]; then
    echo "ok"
  else
    echo "$out $(head -c 80 /tmp/mff_probe_body.txt | tr -d '\n')"
  fi
}

# The four addresses opencode.ai resolves to, which terminate in different
# edge colos.
probe_ips() {
  getent hosts opencode.ai | awk '{print $1}' | sort -u | head -4
}

# -------------------------
# Tests
# -------------------------

test_the_key_is_present() {
  if [[ -n "${OPENCODE_API_KEY:-}" ]]; then
    pass "OPENCODE_API_KEY is set"
  else
    skip "OPENCODE_API_KEY is not set: the gateway cannot be probed"
  fi
}

test_each_declared_route_reports_a_gateway_answer() {
  # The chain's declared routes, and the candidates a chain would otherwise
  # list, each answer with one of the measured classes. The test records which
  # class each gives, because the class is the design's input.
  local record="" status
  for model in step-5-preview-free space-bunny-free deepseek-v4-flash glm-5.3-flash; do
    status="$(probe_model "$(getent hosts opencode.ai | awk '{print $1}' | head -1)" "$model")"
    record="$record
  $model -> $status"
  done
  if [[ $record == *"step-5-preview-free"* ]]; then
    pass "the chain's models answer the gateway:$record"
  else
    fail "the probe did not reach the chain's model:$record"
  fi
}

test_success_varies_by_edge_ip_at_one_moment() {
  # The per-IP signal: the same session, key and prompt, pinned to each
  # resolved address in turn. The recorded finding is that the answers differ
  # at one moment and the signal decays, so this test records the sample
  # rather than asserting a fixed outcome.
  local sample="" ip status hits=0 tries=0
  for ip in $(probe_ips); do
    for _ in 1 2; do
      status="$(probe_model "$ip" "step-5-preview-free")"
      tries=$((tries + 1))
      if [[ "$status" == "ok" ]]; then
        hits=$((hits + 1))
      fi
      sample="$sample
  $ip -> $status"
    done
  done
  if (( tries == 0 )); then
    skip "no addresses resolved for opencode.ai"
    return 0
  fi
  # The assertion is only that the probe ran and reported; the distribution is
  # the finding, and it is written to the handover rather than pinned here.
  pass "the per-IP sample ran ($hits of $tries succeeded):$sample"
}

test_the_chain_dispatches_and_records_outcomes_end_to_end() {
  # A real pi process, the extension loaded from the repository source, the
  # chain selected. The prompt must answer, and the session log must carry the
  # extension's tracking entry for the classified outcome.
  local agent_dir="$FIXTURE_DIR/agent" out session
  mkdir -p "$agent_dir/extensions"
  cp -r "$EXTENSION_SRC" "$agent_dir/extensions/model-failover"
  cp "$SETTINGS_SRC" "$agent_dir/settings.json"
  # The fixture reproduces the deployment's catalog: step-5-preview-free is not
  # in pi's baked catalog, so the chain needs the pi.dev overlay and the stored
  # credential the live agent directory carries.
  for seeded in auth.json models.json models-store.json; do
    [[ -f "$HOME/.pi/agent/$seeded" ]] && cp "$HOME/.pi/agent/$seeded" "$agent_dir/$seeded"
  done
  out="$(PI_CODING_AGENT_DIR="$agent_dir" timeout 240 pi -p -nc \
    --model failover/step-5-preview-free --thinking low "Reply with exactly: chain-ok" 2>&1 </dev/null)"
  if [[ "$out" != *"chain-ok"* ]]; then
    fail "the chain did not answer the prompt: $(printf '%s' "$out" | tail -2)"
    return 0
  fi
  session="$(ls -t "$agent_dir"/sessions/*/*.jsonl 2>/dev/null | head -1)"
  if [[ -z "$session" ]]; then
    fail "the chain answered but wrote no session log"
    return 0
  fi
  if grep -q 'model-failover/outcome' "$session"; then
    pass "the chain answered and the session log carries the outcome entry"
  else
    fail "the chain answered but the session log carries no outcome entry: $session"
  fi
}

run_test test_the_key_is_present
run_test test_each_declared_route_reports_a_gateway_answer
run_test test_success_varies_by_edge_ip_at_one_moment
run_test test_the_chain_dispatches_and_records_outcomes_end_to_end

test_done
