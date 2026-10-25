#!/usr/bin/env node

import { readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { classify as classifyLibrary } from "../src/libs/dispatch/classify.ts";
import { classifyVerdict, isAborted } from "../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts";

// A reader that closes the pipe early, such as `head`, is not an error here.
process.stdout.on("error", (error) => {
  if (error.code !== "EPIPE") throw error;
  process.exit(0);
});

function parseArgs(argv) {
  let session = null;
  let root = null;
  let failures = false;
  let census = false;
  let attribution = false;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--failures") {
      failures = true;
    } else if (arg === "--census") {
      census = true;
    } else if (arg === "--attribution") {
      attribution = true;
    } else if (arg === "--session") {
      session = argv[i + 1];
      i += 1;
    } else if (arg === "--root") {
      root = argv[i + 1];
      i += 1;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  if ((session == null) === (root == null)) {
    throw new Error("Pass exactly one of --session <file> or --root <dir>");
  }
  return { session, root, failures, census, attribution };
}

function jsonlFiles(root) {
  const found = [];
  for (const entry of readdirSync(root, { recursive: true, withFileTypes: true })) {
    if (!entry.isFile() || !entry.name.endsWith(".jsonl")) continue;
    const parent = entry.parentPath ?? entry.path;
    found.push(join(parent, entry.name));
  }
  return found.sort();
}

function* entries(path) {
  for (const line of readFileSync(path, "utf8").split(/\r?\n/)) {
    if (line.trim() === "") continue;
    try {
      yield JSON.parse(line);
    } catch {
      continue;
    }
  }
}

function readSession(path) {
  let provider = null;
  let model = null;
  let thinking = null;
  let sessionId = null;
  let cwd = null;
  let start = null;
  let end = null;
  let messages = 0;
  const tokens = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, reasoning: 0, total: 0 };
  const cost = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 };

  for (const entry of entries(path)) {
    if (sessionId == null && entry.id != null) sessionId = entry.id;
    if (cwd == null && entry.cwd != null) cwd = entry.cwd;
    if (entry.timestamp != null) {
      if (start == null) start = entry.timestamp;
      end = entry.timestamp;
    }
    if (entry.type === "thinking_level_change" && entry.thinkingLevel != null) {
      thinking = entry.thinkingLevel;
    }
    if (entry.type === "message" && entry.message?.role === "assistant") {
      messages += 1;
      provider = entry.message.provider ?? provider;
      model = entry.message.model ?? model;
      const usage = entry.message.usage ?? {};
      const turnCost = usage.cost ?? {};
      tokens.input += usage.input ?? 0;
      tokens.output += usage.output ?? 0;
      tokens.cacheRead += usage.cacheRead ?? 0;
      tokens.cacheWrite += usage.cacheWrite ?? 0;
      tokens.reasoning += usage.reasoning ?? 0;
      tokens.total += usage.totalTokens ?? 0;
      cost.input += turnCost.input ?? 0;
      cost.output += turnCost.output ?? 0;
      cost.cacheRead += turnCost.cacheRead ?? 0;
      cost.cacheWrite += turnCost.cacheWrite ?? 0;
      cost.total += turnCost.total ?? 0;
    }
  }

  const wallMs = start != null && end != null ? Date.parse(end) - Date.parse(start) : 0;
  const sessionValue = sessionId != null ? sessionId : path.split(/[/\\]/).pop();

  return {
    runtime: "pi",
    session: sessionValue,
    cwd,
    provider,
    model,
    thinking,
    start,
    end,
    wall_ms: wallMs,
    messages,
    tokens,
    cost,
  };
}


// The failure projection of the same store: one record per provider failure,
// with the request it came from and both classifiers' verdicts. It is a view,
// computed on read, so no corpus file can drift from the sessions it names.
function collectFailures(path) {
  let provider = null;
  let model = null;
  let thinking = null;
  let cwd = null;
  let sessionId = null;
  const failures = [];
  for (const entry of entries(path)) {
    if (sessionId == null && entry.id != null) sessionId = entry.id;
    if (cwd == null && entry.cwd != null) cwd = entry.cwd;
    if (entry.type === "thinking_level_change" && entry.thinkingLevel != null) thinking = entry.thinkingLevel;
    if (entry.type === "model_change") {
      provider = entry.provider ?? provider;
      model = entry.modelId ?? model;
    }
    if (entry.type !== "message" || entry.message?.role !== "assistant") continue;
    const message = entry.message;
    provider = message.provider ?? provider;
    model = message.model ?? model;
    if (message.stopReason !== "error" || !message.errorMessage) continue;
    if (isAborted(message.errorMessage)) continue;
    const at = Date.parse(entry.timestamp);
    const extensionVerdict = classifyVerdict(message.errorMessage);
    failures.push({
      kind: "failure",
      runtime: "pi",
      session: sessionId ?? path.split(/[/\\]/).pop(),
      cwd,
      at,
      provider,
      model,
      thinking,
      text: message.errorMessage,
      extension: { class: extensionVerdict.recoverable ? "transient" : "limited", scope: extensionVerdict.scope },
      library: classifyLibrary(message.errorMessage, at),
    });
  }
  return failures;
}

function countBy(target, key) {
  target[key] = (target[key] ?? 0) + 1;
}

// The per-actor census: for each rule and each (class, scope), which actors the
// failures sit on. The store records no call site, so the working directory and
// the session are the provenance it keeps, and a failure whose actors are one
// directory is the harness's, not the population's.
function censusOf(failures) {
  const rows = [];
  for (const rule of ["extension", "library"]) {
    const cells = new Map();
    for (const failure of failures) {
      const verdict = failure[rule];
      const key = rule + "\u0000" + verdict.class + "\u0000" + verdict.scope;
      if (!cells.has(key)) {
        cells.set(key, { kind: "census", rule, class: verdict.class, scope: verdict.scope, count: 0, first: null, last: null, providers: {}, models: {}, cwds: {}, sessions: {} });
      }
      const cell = cells.get(key);
      cell.count += 1;
      if (Number.isFinite(failure.at)) {
        cell.first = cell.first === null || failure.at < cell.first ? failure.at : cell.first;
        cell.last = cell.last === null || failure.at > cell.last ? failure.at : cell.last;
      }
      countBy(cell.providers, failure.provider ?? "unknown");
      countBy(cell.models, failure.model ?? "unknown");
      countBy(cell.cwds, failure.cwd ?? "unknown");
      countBy(cell.sessions, failure.session ?? "unknown");
    }
    rows.push(...cells.values());
  }
  return rows;
}

function shapeOf(text) {
  return text
    .replace(/\b[0-9a-f]{8}-[0-9a-f-]{20,}\b/gi, "<id>")
    .replace(/\d+/g, "<n>")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 160);
}

// The attribution view: every text shape either rule calls the request's, the
// distinct models it was observed on, and whether a second model saw it. A
// shape seen on one model only has no cross-model pair, which is the evidence
// the claim needs and the corpus does not carry.
function attributionOf(failures) {
  const shapes = new Map();
  for (const failure of failures) {
    const requestScoped = failure.extension.scope === "request" || failure.library.scope === "request";
    if (!requestScoped) continue;
    const shape = shapeOf(failure.text);
    if (!shapes.has(shape)) {
      shapes.set(shape, { kind: "attribution", shape, text: failure.text, count: 0, atFirst: null, atLast: null, models: {}, cwds: {} });
    }
    const row = shapes.get(shape);
    row.count += 1;
    if (Number.isFinite(failure.at)) {
      row.atFirst = row.atFirst === null || failure.at < row.atFirst ? failure.at : row.atFirst;
      row.atLast = row.atLast === null || failure.at > row.atLast ? failure.at : row.atLast;
    }
    countBy(row.models, (failure.provider ?? "?") + "/" + (failure.model ?? "?"));
    countBy(row.cwds, failure.cwd ?? "unknown");
  }
  const rows = [...shapes.values()].map((row) => ({ ...row, modelCount: Object.keys(row.models).length, first: row.atFirst, last: row.atLast }));
  rows.sort((a, b) => b.count - a.count);
  const absent = rows.filter((row) => row.modelCount < 2).length;
  return { rows, absent };
}

function main() {
  const { session, root, failures, census, attribution } = parseArgs(process.argv.slice(2));
  const files = session ? [resolve(session)] : jsonlFiles(resolve(root));
  if (!failures && !census && !attribution) {
    for (const file of files) {
      process.stdout.write(JSON.stringify(readSession(file)) + "\n");
    }
    return;
  }
  const all = files.flatMap((file) => collectFailures(file));
  if (failures) {
    for (const row of all) process.stdout.write(JSON.stringify(row) + "\n");
  }
  if (census) {
    for (const row of censusOf(all)) process.stdout.write(JSON.stringify(row) + "\n");
  }
  if (attribution) {
    const { rows, absent } = attributionOf(all);
    for (const row of rows) process.stdout.write(JSON.stringify(row) + "\n");
    process.stdout.write(JSON.stringify({ kind: "attribution-summary", shapes: rows.length, absentPairs: absent }) + "\n");
  }
}

main();
