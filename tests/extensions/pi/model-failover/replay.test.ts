/**
 * The differential replay: one recorded failure stream through two route
 * stores, and the cooldown-hours each one charges.
 *
 * The extension's ledger and the dispatch library's machine hold the same kind
 * of evidence, so they must agree on what one class of evidence means. The
 * class that matters here is the failure that is not the route's: a malformed
 * request, or a text no pattern knows. The library's R8 and R9 leave the record
 * untouched. This file replays a stream through both and asserts that the
 * extension now does the same, and prices what the older rule cost.
 *
 * The stream is a fixture, so the numbers are literals. Pointing CORPUS_ROOT at
 * a session store replays the live corpus as well and prints the table without
 * asserting it, because a live population changes under the test.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { classify as classifyLibrary } from "../../../../src/libs/dispatch/classify.ts";
import { applyOutcome as applyLibrary } from "../../../../src/libs/dispatch/machine.ts";
import type { RouteRecord } from "../../../../src/libs/dispatch/types.ts";
import { classifyError, classifyVerdict, isAborted } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts";
import { applyOutcome as applyExtension, initialRouteState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/ledger.ts";
import type { Outcome as ExtensionOutcome, RouteState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts";

const T0 = 1_700_000_000_000;
const THRESHOLD = 3;
const COOLDOWNS = { transient: 120000, limited: 3600000 };

type Row = { at: number; provider: string; model: string; text: string };

/** A recorded failure stream. Every route is separate unless a row says otherwise. */
const FIXTURE: readonly Row[] = [
  { at: T0, provider: "p", model: "request-only", text: "400 invalid_request_error: reasoning_effort: unknown variant `minimal`" },
  { at: T0 + 10_000, provider: "p", model: "request-only", text: "400 The `reasoning_content` in the thinking mode must be passed back to the API." },
  { at: T0 + 20_000, provider: "p", model: "quota", text: "429 rate limit exceeded" },
  { at: T0 + 30_000, provider: "q", model: "flaky", text: "503 upstream is too busy" },
  { at: T0 + 40_000, provider: "q", model: "flaky", text: "503 upstream is too busy" },
  { at: T0 + 50_000, provider: "q", model: "flaky", text: "503 upstream is too busy" },
  { at: T0 + 60_000, provider: "r", model: "unknown-text", text: "something no pattern knows" },
  { at: T0 + 70_000, provider: "r", model: "account", text: "GoUsageLimitError: usage limit reached" },
  { at: T0 + 80_000, provider: "p", model: "request-only", text: "400 invalid_request_error: invalid request" },
];

/** One route's walk: the state after each row, and which scope set the cooldown. */
type Walk<S> = { state: S; setBy: string | null; requestHours: number; hoursByCause: Record<string, number> };

function closeInterval<S extends { state: string; until?: number }>(walk: Walk<S>, at: number, openedAt: number): void {
  if (walk.state.state !== "cooling" || walk.setBy === null) return;
  const until = walk.state.until ?? 0;
  const end = Math.min(at, until);
  if (end <= openedAt) return;
  const hours = (end - openedAt) / 3_600_000;
  walk.hoursByCause[walk.setBy] = (walk.hoursByCause[walk.setBy] ?? 0) + hours;
  if (walk.setBy === "request") walk.requestHours += hours;
}

function walkExtension(rows: readonly Row[], fabricateNone: boolean): Map<string, Walk<RouteState>> {
  const byRoute = new Map<string, Row[]>();
  for (const row of rows) {
    const key = `${row.provider}/${row.model}`;
    byRoute.set(key, [...(byRoute.get(key) ?? []), row]);
  }
  const walks = new Map<string, Walk<RouteState>>();
  for (const [key, routeRows] of byRoute) {
    const sorted = [...routeRows].sort((a, b) => a.at - b.at);
    const walk: Walk<RouteState> = { state: initialRouteState(), setBy: null, requestHours: 0, hoursByCause: {} };
    let openedAt = sorted[0].at;
    for (const row of sorted) {
      closeInterval(walk, row.at, openedAt);
      const verdict = classifyVerdict(row.text);
      const scope = fabricateNone && (verdict.scope === "request" || verdict.scope === "unclassified") ? "none" : verdict.scope;
      const outcome: ExtensionOutcome = { ok: false, class: classifyError(row.text), scope };
      const before = walk.state;
      walk.state = applyExtension(walk.state, outcome, row.at, THRESHOLD, COOLDOWNS);
      // The cause is the scope when it names one, the class when it does not,
      // and the measured scope of the text under the older rule, so the price
      // of that rule is attributable to the failure it misattributed.
      const cause = verdict.scope === "request" ? "request" : scope === "none" ? classifyError(row.text) : scope;
      if (walk.state !== before && walk.state.state === "cooling") walk.setBy = cause;
      if (walk.state.state !== "cooling") walk.setBy = null;
      openedAt = row.at;
    }
    if (walk.state.state === "cooling") closeInterval(walk, Number.POSITIVE_INFINITY, openedAt);
    walks.set(key, walk);
  }
  return walks;
}

function walkLibrary(rows: readonly Row[]): Map<string, Walk<RouteRecord>> {
  const byRoute = new Map<string, Row[]>();
  for (const row of rows) {
    const key = `${row.provider}/${row.model}`;
    byRoute.set(key, [...(byRoute.get(key) ?? []), row]);
  }
  const walks = new Map<string, Walk<RouteRecord>>();
  for (const [key, routeRows] of byRoute) {
    const sorted = [...routeRows].sort((a, b) => a.at - b.at);
    const walk: Walk<RouteRecord> = { state: { state: "untried" }, setBy: null, requestHours: 0, hoursByCause: {} };
    let openedAt = sorted[0].at;
    for (const row of sorted) {
      closeInterval(walk, row.at, openedAt);
      const c = classifyLibrary(row.text, row.at);
      const before = walk.state;
      walk.state = applyLibrary(walk.state, { at: row.at, class: c.class, scope: c.scope, reason: c.reason, refreshAt: c.refreshAt, text: row.text });
      if (walk.state !== before && walk.state.state === "cooling") walk.setBy = c.scope === "request" ? "request" : c.scope === "none" ? c.class : c.scope;
      if (walk.state.state !== "cooling") walk.setBy = null;
      openedAt = row.at;
    }
    if (walk.state.state === "cooling") closeInterval(walk, Number.POSITIVE_INFINITY, openedAt);
    walks.set(key, walk);
  }
  return walks;
}

function totalRequestHours<S>(walks: Map<string, Walk<S>>): number {
  return [...walks.values()].reduce((sum, walk) => sum + walk.requestHours, 0);
}

describe("the differential replay", () => {
  it("charges nothing for a request-scope failure, in either store", () => {
    assert.equal(totalRequestHours(walkExtension(FIXTURE, false)), 0, "the extension leaves the record untouched");
    assert.equal(totalRequestHours(walkLibrary(FIXTURE)), 0, "the library leaves the record untouched");
  });

  it("prices the older extension rule, which had no scope to read", () => {
    const before = totalRequestHours(walkExtension(FIXTURE, true));
    assert.ok(before > 0, `the class-only rule charged ${before}h for a request-scope failure`);
  });

  it("both stores still cool the routes whose cause is the route's", () => {
    const extFlaky = walkExtension(FIXTURE, false).get("q/flaky");
    const libFlaky = walkLibrary(FIXTURE).get("q/flaky");
    assert.ok((extFlaky?.hoursByCause.transient ?? 0) > 0, "three transient failures still cool the extension's route");
    assert.ok((libFlaky?.hoursByCause.transient ?? 0) > 0, "a transient failure still cools the library's route");
    const extAccount = walkExtension(FIXTURE, false).get("r/account");
    const libAccount = walkLibrary(FIXTURE).get("r/account");
    assert.ok((extAccount?.hoursByCause.account ?? 0) > 0, "an exhausted account still cools the extension's route");
    assert.ok((libAccount?.hoursByCause.account ?? 0) > 0, "an exhausted account still cools the library's route");
  });

  const corpusRoot = process.env.CORPUS_ROOT;
  it("replays the live corpus, printing the table for the record", { skip: corpusRoot === undefined ? "set CORPUS_ROOT to replay a session store" : false }, () => {
    const rows: Row[] = [];
    for (const entry of readdirSync(corpusRoot as string, { recursive: true, withFileTypes: true })) {
      if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
      const file = join(entry.parentPath ?? entry.path, entry.name);
      let provider = "?";
      let model = "?";
      for (const line of readFileSync(file, "utf8").split("\n")) {
        if (!line.trim()) continue;
        let parsed: { type?: string; provider?: string; modelId?: string; timestamp?: string; message?: { role?: string; provider?: string; model?: string; stopReason?: string; errorMessage?: string } };
        try { parsed = JSON.parse(line); } catch { continue; }
        if (parsed.type === "model_change") { provider = parsed.provider ?? provider; model = parsed.modelId ?? model; }
        if (parsed.type === "message" && parsed.message?.role === "assistant") {
          provider = parsed.message.provider ?? provider;
          model = parsed.message.model ?? model;
          if (parsed.message.stopReason !== "error" || !parsed.message.errorMessage) continue;
          if (isAborted(parsed.message.errorMessage)) continue;
          rows.push({ at: Date.parse(parsed.timestamp ?? ""), provider, model, text: parsed.message.errorMessage });
        }
      }
    }
    const ext = walkExtension(rows, false);
    const before = walkExtension(rows, true);
    const lib = walkLibrary(rows);
    const show = <S>(walks: Map<string, Walk<S>>) => [...walks.values()].reduce<Record<string, number>>((acc, walk) => {
      for (const [cause, hours] of Object.entries(walk.hoursByCause)) acc[cause] = Number(((acc[cause] ?? 0) + hours).toFixed(2));
      return acc;
    }, {});
    console.log(`replayed ${rows.length} failures`);
    console.log("extension cooldown-hours before, class-only rule", show(before));
    console.log("extension cooldown-hours after, attribution rule", show(ext));
    console.log("library cooldown-hours by cause", show(lib));
    console.log(`request-attributed hours: extension ${totalRequestHours(ext).toFixed(2)}, library ${totalRequestHours(lib).toFixed(2)}`);
    assert.equal(totalRequestHours(ext), 0);
  });
});
