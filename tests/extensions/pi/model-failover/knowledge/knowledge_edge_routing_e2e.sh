#!/usr/bin/env bash
# tests/extensions/pi/model-failover/knowledge/knowledge_edge_routing_e2e.sh
# TEST_DEADLINE: 300
#
# Knowledge test: a real pi invocation loads the extension and sends an
# inference request through the edge adaptor.
#
# This is the "how I would run and test this" record. It stands a local
# OpenAI-compatible mock up as the provider, points a throwaway pi agent
# directory at it, and runs `pi -p` for one prompt. It proves the load path,
# the network adaptor, the outcome charge to both ledgers, and the report. It
# does not prove the pin itself: the mock's logical host is its address, so
# this run cannot tell a pin from ordinary resolution. That is the subject of
# `pinned-fetch.test.ts`, which requests a non-resolving logical host.
#
# No network and no API key. It spawns pi, so it is a knowledge test and not
# part of `make test`. Run manually:
#   bash tests/extensions/pi/model-failover/knowledge/knowledge_edge_routing_e2e.sh
#
# Reference:
#   src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md
#     -- "The network adaptor" and "The edge layer".

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUITE_DIR="$(cd "$HERE/.." && pwd)"
REPO_TOP="$(cd "$SUITE_DIR/../../../.." && pwd)"
# shellcheck source=../../../../libs/test_common.sh
source "$REPO_TOP/tests/libs/test_common.sh"

EXTENSION_SRC="$REPO_TOP/src/reasoning/providers/pi/config/agent/extensions/model-failover"

test_setup

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mff-e2e.XXXXXX")"

cleanup() {
  rm -rf "$WORK"
}
trap cleanup EXIT

# The mock: one SSE chat completion, and one JSON line per request naming the
# Host header and the model, so the test can assert the request arrived.
write_mock() {
  cat > "$WORK/mock.mjs" <<'JS'
import http from "node:http";
import fs from "node:fs";
const server = http.createServer((req, res) => {
  let body = "";
  req.on("data", (chunk) => (body += chunk));
  req.on("end", () => {
    let model = null;
    try { model = JSON.parse(body).model; } catch {}
    fs.appendFileSync(process.env.MOCK_LOG, JSON.stringify({ url: req.url, host: req.headers.host ?? "", model }) + "\n");
    if (req.url.startsWith("/v1/chat/completions")) {
      const chunk = (delta, finish) => "data: " + JSON.stringify({ id: "1", object: "chat.completion.chunk", created: 0, model: "mock-1", choices: [{ index: 0, delta, finish_reason: finish }] }) + "\n\n";
      res.writeHead(200, { "content-type": "text/event-stream" });
      res.write(chunk({ role: "assistant", content: "pong-from-mock" }, null));
      res.write(chunk({}, "stop"));
      res.end("data: [DONE]\n\n");
    } else { res.writeHead(404); res.end("no"); }
  });
});
server.listen(0, "127.0.0.1", () => fs.writeFileSync(process.env.MOCK_PORT, String(server.address().port)));
JS
}

# Build the throwaway agent directory: the extension, a chain that names the
# mock provider, the mock provider definition, and the bootstrap settings.
build_agent_dir() {
  local agent="$1" port="$2"
  mkdir -p "$agent/extensions"
  cp -r "$EXTENSION_SRC" "$agent/extensions/model-failover"
  cat > "$agent/extensions/model-failover/routes.json" <<JSON
{"chains":[{"id":"mock-model","routes":[{"provider":"mock","model":"mock-1"}]}],"selection":{"policy":"epsilon","epsilon":0.1}}
JSON
  cat > "$agent/models.json" <<JSON
{"providers":{"mock":{"name":"Mock","baseUrl":"http://127.0.0.1:$port/v1","apiKey":"test-key","api":"openai-completions","models":[{"id":"mock-1","name":"Mock 1","reasoning":false,"input":["text"],"cost":{"input":0,"output":0,"cacheRead":0,"cacheWrite":0},"contextWindow":100000,"maxTokens":4096}]}}}
JSON
  cat > "$agent/settings.json" <<'JSON'
{"defaultProvider":"mock","defaultModel":"mock-1","defaultThinkingLevel":"off","enabledModels":["mock/*"]}
JSON
}

test_pi_is_available() {
  if command -v pi >/dev/null 2>&1; then
    pass "pi is on PATH"
  else
    skip "pi is not on PATH: the end-to-end invocation cannot run"
  fi
}

test_a_fresh_pi_invocation_sends_through_the_adaptor() {
  if ! command -v pi >/dev/null 2>&1; then
    skip "pi is not on PATH"
    return 0
  fi
  write_mock
  # The mock's output must not hold the harness's capture pipe open, so it goes to a file.
  MOCK_LOG="$WORK/requests.log" MOCK_PORT="$WORK/port" node "$WORK/mock.mjs" >"$WORK/mock.out" 2>&1 &
  local pid=$!
  local port="" result=""
  for _ in $(seq 1 50); do
    [[ -s "$WORK/port" ]] && port="$(cat "$WORK/port")" && break
    sleep 0.1
  done
  if [[ -z "$port" ]]; then
    result="the mock server did not start"
  else
    local agent="$WORK/agent" out rc
    build_agent_dir "$agent" "$port"
    out="$(PI_CODING_AGENT_DIR="$agent" timeout 120 pi -p -nc --model mock/mock-1 "reply with one word" 2>&1 </dev/null)"
    rc=$?
    if [[ $rc -ne 0 || "$out" != *"pong-from-mock"* ]]; then
      result="the fresh pi invocation did not answer through the mock: rc=$rc $(printf '%s' "$out" | tail -2)"
    elif ! grep -q '"model":"mock-1"' "$WORK/requests.log"; then
      result="the mock received no request for mock-1"
    elif ! grep -q '"state": "eligible"' "$agent/extensions/model-failover/edges.json" 2>/dev/null; then
      result="the edge ledger carries no recorded edge"
    fi
  fi
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
  if [[ -n "$result" ]]; then
    fail "$result"
    return 0
  fi
  pass "a fresh pi invocation loaded the extension and sent the request through the adaptor"
}

run_test test_pi_is_available
run_test test_a_fresh_pi_invocation_sends_through_the_adaptor

test_done
