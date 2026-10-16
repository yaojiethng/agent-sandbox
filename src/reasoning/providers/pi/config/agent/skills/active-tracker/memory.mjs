// src/reasoning/providers/pi/config/agent/skills/active-tracker/memory.mjs
//
// The session's steering memory, in the OptMem shape: an append-only log as the
// storage, a bounded view as the reading budget, and a summary that is a cache
// rebuildable from the log alone.
//
// This file is a library. The facade is active-tracker.mjs; the model is
// README.md.

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

export const VIEW_LINES = 16;
export const LINE_CHARS = 240;

export const pathsOf = (log) => ({
  log,
  view: join(dirname(log), "SESSION_MEMORY_VIEW.jsonl"),
  state: join(dirname(log), "SESSION_MEMORY_STATE.json"),
});

let clock = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
export const setClock = (fn) => {
  clock = fn;
};

const readLines = (path) =>
  existsSync(path)
    ? readFileSync(path, "utf8").split("\n").filter((l) => l !== "").map((l) => JSON.parse(l))
    : [];
const clip = (text) => (text.length > LINE_CHARS ? `${text.slice(0, LINE_CHARS - 3)}...` : text);

function ensure(log) {
  const dir = dirname(log);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
}

export const logOf = (log) => readLines(log);
export const viewOf = (log) => readLines(pathsOf(log).view);
export const stateOf = (log) => {
  const path = pathsOf(log).state;
  return existsSync(path) ? JSON.parse(readFileSync(path, "utf8")) : { markedN: 0, view: [] };
};

function writeView(log, lines) {
  ensure(log);
  const ordered = [...lines].sort((a, b) => b.hi - a.hi);
  writeFileSync(pathsOf(log).view, ordered.map((l) => JSON.stringify(l)).join("\n") + (ordered.length ? "\n" : ""));
  return ordered;
}

function writeState(log, state) {
  ensure(log);
  writeFileSync(pathsOf(log).state, JSON.stringify(state, null, 2) + "\n");
}

export function wake({ log }) {
  const view = viewOf(log);
  return view.length === 0 ? "steering: none" : view.map((l) => `[${l.lo}-${l.hi}] ${l.text}`).join("\n");
}

export function note({ log, text, home, restates }) {
  if (text === undefined) throw new Error("note needs text");
  ensure(log);
  const n = logOf(log).length + 1;
  const entry = { n, ts: clock(), text };
  if (home !== undefined) entry.home = home;
  if (restates !== undefined) entry.covers = restates;
  appendFileSync(log, JSON.stringify(entry) + "\n");
  let view = viewOf(log);
  let mergeDue = null;
  if (restates !== undefined) {
    if (!view.some((l) => l.lo <= restates && restates <= l.hi)) throw new Error(`no view line covers n=${restates}`);
  } else {
    view = writeView(log, [{ lo: n, hi: n, text: clip(text) }, ...view]);
  }
  if (view.length > VIEW_LINES) {
    const oldest = view.slice(-2);
    mergeDue = `[${oldest[0].lo}-${oldest[0].hi}] and [${oldest[1].lo}-${oldest[1].hi}]`;
  }
  return { n, restates, mergeDue };
}

export function merge({ log, lo, hi, text }) {
  if (!Number.isInteger(lo) || !Number.isInteger(hi) || text === undefined) throw new Error("merge needs <lo> <hi> <text>");
  const view = viewOf(log);
  const covered = view.filter((l) => l.lo >= lo && l.hi <= hi);
  if (covered.length < 2) throw new Error(`merge needs at least two view lines within [${lo}-${hi}]`);
  writeView(log, [...view.filter((l) => !(l.lo >= lo && l.hi <= hi)), { lo, hi, text: clip(text) }]);
  return { merged: covered.length };
}

export function zoom({ log, lo, hi }) {
  const entries = logOf(log).filter((e) => (e.n >= lo && e.n <= hi) || (e.covers !== undefined && e.covers >= lo && e.covers <= hi));
  if (entries.length === 0) throw new Error(`no log entries in [${lo}-${hi}]`);
  return entries;
}

export function forget({ log, lo, hi }) {
  const view = viewOf(log);
  const removed = view.filter((l) => !(l.hi < lo || l.lo > hi));
  if (removed.length === 0) throw new Error(`no view line covers [${lo}-${hi}]`);
  const kept = view.filter((l) => l.hi < lo || l.lo > hi);
  for (const e of logOf(log)) {
    if (e.n >= lo && e.n <= hi && e.covers === undefined) kept.push({ lo: e.n, hi: e.n, text: clip(e.text) });
  }
  writeView(log, kept);
  return { removed: removed.length };
}

// Replace the region from the heading to the next level-2 heading, or append it.
export function render({ log, block, heading = "## Session memory" }) {
  if (block === undefined) throw new Error("render needs a block path");
  const original = existsSync(block) ? readFileSync(block, "utf8") : "";
  const body = `${heading}\n\n\`\`\`text\n${wake({ log })}\n\`\`\`\n`;
  const lines = original.split("\n");
  const start = lines.findIndex((l) => l.trim() === heading.trim());
  let out;
  if (start < 0) {
    out = original.replace(/\n*$/, "") + (original === "" ? "" : "\n\n") + body;
  } else {
    let end = lines.length;
    for (let i = start + 1; i < lines.length; i += 1) {
      if (/^##\s/.test(lines[i])) {
        end = i;
        break;
      }
    }
    out = [...lines.slice(0, start), ...body.split("\n"), ...lines.slice(end)].join("\n");
  }
  writeFileSync(block, out.endsWith("\n") ? out : `${out}\n`);
  return body.trimEnd();
}

export function diff({ log }) {
  const state = stateOf(log);
  const view = viewOf(log);
  const marked = state.view ?? [];
  return {
    appended: logOf(log).filter((e) => e.n > state.markedN),
    added: view.filter((l) => !marked.some((m) => m.lo === l.lo && m.hi === l.hi)),
    dropped: marked.filter((m) => !view.some((l) => l.lo === m.lo && l.hi === m.hi)),
  };
}

export function mark({ log }) {
  const n = logOf(log).length;
  writeState(log, { markedN: n, view: viewOf(log) });
  return n;
}
