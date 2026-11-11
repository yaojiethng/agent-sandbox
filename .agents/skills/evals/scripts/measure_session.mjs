#!/usr/bin/env node
// measure_session.mjs -- read a run's session transcripts and emit the fields the
// measurement contract reads: tokens, wall, instruction files opened, stop reasons,
// and every path a run opened outside its own root.
//
// usage: measure_session.mjs --root <project-dir> [--session <file>] [--repo-root <dir>]
//                             [--work-root <dir>] [--sessions-dir <dir>]
//
// A run's own transcript and its seats' transcripts are summed, so the cost is the
// run's whole cost. A path is an escape when it resolves under the harness's own
// repository or under a sibling cell's root: both mean the run read something other
// than its clone.

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const argv = process.argv.slice(2);
const flag = (name, dflt) => {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : dflt;
};

const root = flag("--root", "");
if (!root) {
  console.error("measure_session.mjs: --root is required");
  process.exit(2);
}
const rootAbs = path.resolve(root);
const repoRoot = path.resolve(flag("--repo-root", ""));
const workRoot = path.resolve(flag("--work-root", ""));
const sessionFile = flag("--session", "");
const agentDir = process.env.PI_CODING_AGENT_DIR || path.join(os.homedir(), ".pi", "agent");
const sessionsDir = flag("--sessions-dir", slugDir(rootAbs));

// pi writes one directory per working directory, the path flattened into the name.
function slugDir(dir) {
  return path.join(agentDir, "sessions", `--${dir.replace(/\//g, "-").replace(/^-/, "")}--`);
}

const ABNORMAL = new Set(["error", "aborted", "cancelled", "canceled", "failed", "length", "content_filter"]);

const files = [];
const add = (p) => {
  try {
    if (fs.statSync(p).isFile() && !files.includes(fs.realpathSync(p))) files.push(fs.realpathSync(p));
  } catch {
    /* a path that is not there is not a transcript */
  }
};
if (sessionFile) add(sessionFile);
if (fs.existsSync(sessionsDir)) {
  for (const f of fs.readdirSync(sessionsDir)) if (f.endsWith(".jsonl")) add(path.join(sessionsDir, f));
}

const tokens = { input: 0, output: 0, total: 0 };
let turns = 0;
let wallMs = 0;
let first = null;
let last = null;
const stopReasons = {};
const rawStopReasons = {};
const opened = new Map();
const escapes = new Set();
const toolCalls = {};
const turnsDetail = [];

const sizeOf = (abs) => {
  try {
    const st = fs.statSync(abs);
    return st.isFile() ? st.size : null;
  } catch {
    return null;
  }
};
const displayPath = (abs) => (inside(abs, rootAbs) ? path.relative(rootAbs, abs) : abs);

const inside = (p, base) => base && base !== "/" && (p === base || p.startsWith(base + path.sep));

for (const file of files) {
  const lines = fs.readFileSync(file, "utf8").split("\n").filter(Boolean);
  for (const line of lines) {
    let rec;
    try {
      rec = JSON.parse(line);
    } catch {
      continue;
    }
    const ts = rec.timestamp || rec.message?.timestamp;
    if (ts) {
      if (!first || ts < first) first = ts;
      if (!last || ts > last) last = ts;
    }
    if (rec.type !== "message" || rec.message?.role !== "assistant") continue;
    const m = rec.message;
    turns += 1;
    wallMs += m.durationMs ?? 0;
    const u = m.usage ?? {};
    const inp = u.input ?? 0;
    const out = u.output ?? 0;
    tokens.input += inp;
    tokens.output += out;
    tokens.total += u.totalTokens || inp + out;
    stopReasons[m.stopReason ?? "?"] = (stopReasons[m.stopReason ?? "?"] ?? 0) + 1;
    rawStopReasons[m.rawStopReason ?? "?"] = (rawStopReasons[m.rawStopReason ?? "?"] ?? 0) + 1;
    const turnToolCalls = {};
    const turnPaths = new Map();
    for (const part of Array.isArray(m.content) ? m.content : []) {
      if (part.type !== "toolCall") continue;
      toolCalls[part.name] = (toolCalls[part.name] ?? 0) + 1;
      turnToolCalls[part.name] = (turnToolCalls[part.name] ?? 0) + 1;
      const args = part.arguments ?? {};
      const named = [args.path, args.file_path, args.cwd].filter((v) => typeof v === "string");
      for (const raw of named) {
        const abs = path.resolve(rootAbs, raw);
        opened.set(abs, true);
        if (!turnPaths.has(abs)) turnPaths.set(abs, { path: displayPath(abs), bytes: sizeOf(abs) });
        if (inside(abs, repoRoot) && !inside(abs, rootAbs)) escapes.add(abs);
        else if (inside(abs, workRoot) && !inside(abs, rootAbs)) escapes.add(abs);
      }
      const text = typeof args.command === "string" ? args.command : typeof args.code === "string" ? args.code : "";
      for (const m2 of text.match(/[A-Za-z0-9_./-]+\.(md|json|jsonl|sh|mjs|py|txt)/g) ?? []) {
        const abs = path.resolve(rootAbs, m2);
        if (inside(abs, repoRoot) && !inside(abs, rootAbs)) escapes.add(abs);
        else if (inside(abs, workRoot) && !inside(abs, rootAbs)) escapes.add(abs);
      }
    }
    turnsDetail.push({
      turn: turns,
      input_tokens: inp,
      output_tokens: out,
      total_tokens: u.totalTokens || inp + out,
      tool_calls: turnToolCalls,
      paths: [...turnPaths.values()],
    });
  }
}

const abnormal = Object.keys(rawStopReasons).filter((k) => ABNORMAL.has(k));

const invalid = abnormal.length > 0 || escapes.size > 0;
const reasons = [];
if (abnormal.length) reasons.push(`abnormal stop: ${abnormal.join(",")}`);
if (escapes.size) reasons.push(`${escapes.size} path(s) outside the root`);

console.log(
  JSON.stringify({
    sessions: files.length,
    turns,
    attributed: turns > 0,
    tokens,
    wall_ms_transcript: first && last ? Date.parse(last) - Date.parse(first) : 0,
    wall_ms_sum_of_turns: wallMs,
    files_opened: opened.size,
    turns_detail: turnsDetail,
    escapes: [...escapes].sort().slice(0, 20),
    stop_reasons: stopReasons,
    raw_stop_reasons: rawStopReasons,
    tool_calls: toolCalls,
    invalid,
    invalid_reason: reasons.join("; "),
  }),
);
