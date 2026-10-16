#!/usr/bin/env node
// src/reasoning/providers/pi/config/agent/skills/session-memory/session-memory.mjs
//
// Session-scoped memory: the steering that applies across a session's tasks
// and dies with the session. It survives a pi /fork or /tree, so it is the
// memory a returning traversal reads.
//
// The shape is OptMem's, https://github.com/VictorTaelin/OptMem: an
// append-only log that is never edited, a bounded read, a merge on write, and a
// summary that is a cache rebuildable from the log alone. This is a
// reimplementation of that shape for short-term memory, with the constants
// adjusted and the binary tree dropped, because the view is 16 lines rather
// than a million records.
//
// Two grains, one per file. The log records occurrences. The view holds one
// line per directive, newest first.
//
// Usage: node session-memory.mjs <command> [args] [--log <path>] [--block <path>] [--heading <text>]
//
// The three path flags are read from anywhere in the argument list.
//
// Commands:
//   note <text> [--home <path>] [--restates <n>]   append an occurrence
//   merge <lo> <hi> <text>                          compress a view range
//   wake                                            print the view
//   render                                          write the block into --block
//   zoom <lo>-<hi>                                  print the log range
//   forget <lo>-<hi>                                drop a summary, resurface it
//   diff                                            print the change since the mark
//   mark                                            set the mark
//
// Exit codes: 0 ok, 1 a refusal with a message on stderr.

import { appendFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";

const VIEW_LINES = 16;
const LINE_CHARS = 240;

const argv = [];
let logPath = ".scratchpad/SESSION_MEMORY_LOG.jsonl";
let blockPath = "";
let heading = "## Session memory";
const raw = process.argv.slice(2);
while (raw.length > 0) {
  const token = raw.shift();
  if (token === "--log") logPath = raw.shift();
  else if (token === "--block") blockPath = raw.shift();
  else if (token === "--heading") heading = raw.shift();
  else argv.push(token);
}
const command = argv.shift();

const logDir = dirname(logPath);
const viewPath = join(logDir, "SESSION_MEMORY_VIEW.jsonl");
const statePath = join(logDir, "SESSION_MEMORY_STATE.json");

const refuse = (message) => {
  process.stderr.write(`session-memory: ${message}\n`);
  process.exit(1);
};
const say = (message) => process.stdout.write(`${message}\n`);

const readLines = (path) => {
  if (!existsSync(path)) return [];
  return readFileSync(path, "utf8").split("\n").filter((l) => l !== "").map((l) => JSON.parse(l));
};

const readLog = () => readLines(logPath);
const readView = () => readLines(viewPath);
const readState = () => {
  if (!existsSync(statePath)) return { markedN: 0, view: [] };
  return JSON.parse(readFileSync(statePath, "utf8"));
};

const writeView = (lines) => {
  ensureDir();
  const ordered = [...lines].sort((a, b) => b.hi - a.hi);
  writeFileSync(viewPath, ordered.map((l) => JSON.stringify(l)).join("\n") + (ordered.length ? "\n" : ""));
  return ordered;
};

const writeState = (state) => {
  ensureDir();
  writeFileSync(statePath, JSON.stringify(state, null, 2) + "\n");
};

function ensureDir() {
  if (!existsSync(logDir)) mkdirSync(logDir, { recursive: true });
}

const clip = (text) => (text.length > LINE_CHARS ? text.slice(0, LINE_CHARS - 3) + "..." : text);

const now = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");

// The text a return reads, or the absence marker.
function renderView() {
  const view = readView();
  if (view.length === 0) return "steering: none";
  return view.map((l) => `[${l.lo}-${l.hi}] ${l.text}`).join("\n");
}

const overlap = (line, lo, hi) => !(line.hi < lo || line.lo > hi);

function appendOccurrence(text, home, restates) {
  ensureDir();
  const n = readLog().length + 1;
  const entry = { n, ts: now(), text };
  if (home !== undefined) entry.home = home;
  if (restates !== undefined) entry.covers = restates;
  appendFileSync(logPath, JSON.stringify(entry) + "\n");
  return { n, entry };
}

function cmdNote() {
  const text = argv.shift();
  if (text === undefined) refuse("note needs text");
  let home;
  let restates;
  while (argv.length > 0) {
    const flag = argv.shift();
    if (flag === "--home") home = argv.shift();
    else if (flag === "--restates") restates = Number(argv.shift());
    else refuse(`unknown flag ${flag}`);
  }
  const { n } = appendOccurrence(text, home, restates);
  let view = readView();
  if (restates !== undefined) {
    const anchor = view.find((l) => l.lo <= restates && restates <= l.hi);
    if (anchor === undefined) refuse(`no view line covers n=${restates}`);
    say(`appended n=${n}, restates the directive at n=${restates}`);
  } else {
    view.unshift({ lo: n, hi: n, text: clip(text) });
    view = writeView(view);
    say(`appended n=${n}`);
  }
  if (view.length > VIEW_LINES) {
    const oldest = view.slice(-2);
    const range = `[${oldest[0].lo}-${oldest[0].hi}] and [${oldest[1].lo}-${oldest[1].hi}]`;
    say(`merge due: the view holds ${view.length} lines, over ${VIEW_LINES}; merge ${range}`);
  }
}

function cmdMerge() {
  const lo = Number(argv.shift());
  const hi = Number(argv.shift());
  const text = argv.shift();
  if (!Number.isInteger(lo) || !Number.isInteger(hi) || text === undefined) {
    refuse("merge needs <lo> <hi> <text>");
  }
  const view = readView();
  const covered = view.filter((l) => l.lo >= lo && l.hi <= hi);
  if (covered.length < 2) refuse(`merge needs at least two view lines within [${lo}-${hi}]`);
  const kept = view.filter((l) => !(l.lo >= lo && l.hi <= hi));
  kept.push({ lo, hi, text: clip(text) });
  writeView(kept);
  say(`merged ${covered.length} lines into [${lo}-${hi}]`);
}

function cmdZoom() {
  const match = /^(\d+)-(\d+)$/.exec(argv.shift() ?? "");
  if (!match) refuse("zoom needs <lo>-<hi>");
  const lo = Number(match[1]);
  const hi = Number(match[2]);
  const entries = readLog().filter((e) => (e.n >= lo && e.n <= hi) || (e.covers !== undefined && e.covers >= lo && e.covers <= hi));
  if (entries.length === 0) refuse(`no log entries in [${lo}-${hi}]`);
  for (const e of entries) say(`${JSON.stringify(e)}`);
}

function cmdForget() {
  const match = /^(\d+)-(\d+)$/.exec(argv.shift() ?? "");
  if (!match) refuse("forget needs <lo>-<hi>");
  const lo = Number(match[1]);
  const hi = Number(match[2]);
  const view = readView();
  const removed = view.filter((l) => overlap(l, lo, hi));
  if (removed.length === 0) refuse(`no view line covers [${lo}-${hi}]`);
  const kept = view.filter((l) => !overlap(l, lo, hi));
  for (const e of readLog()) {
    if (e.n >= lo && e.n <= hi && e.covers === undefined) {
      kept.push({ lo: e.n, hi: e.n, text: clip(e.text) });
    }
  }
  writeView(kept);
  say(`forgot [${lo}-${hi}], ${removed.length} summary line(s) dropped, the originals resurface`);
}

function cmdDiff() {
  const state = readState();
  const log = readLog();
  const view = readView();
  const appended = log.filter((e) => e.n > state.markedN);
  const marked = state.view ?? [];
  const added = view.filter((l) => !marked.some((m) => m.lo === l.lo && m.hi === l.hi));
  const dropped = marked.filter((m) => !view.some((l) => l.lo === m.lo && l.hi === m.hi));
  say("memory diff");
  say(appended.length === 0 ? "  appended: none" : `  appended: ${appended.map((e) => `n=${e.n}`).join(", ")}`);
  say(added.length === 0 ? "  view added: none" : `  view added: ${added.map((l) => `[${l.lo}-${l.hi}]`).join(", ")}`);
  say(dropped.length === 0 ? "  view dropped: none" : `  view dropped: ${dropped.map((l) => `[${l.lo}-${l.hi}]`).join(", ")}`);
}

function cmdMark() {
  writeState({ markedN: readLog().length, view: readView() });
  say(`marked at n=${readLog().length}`);
}

// Replace the region from the heading to the next level-2 heading, or append it.
function cmdRender() {
  if (blockPath === "") refuse("render needs --block");
  const original = existsSync(blockPath) ? readFileSync(blockPath, "utf8") : "";
  const block = `${heading}\n\n\`\`\`text\n${renderView()}\n\`\`\`\n`;
  const lines = original.split("\n");
  const start = lines.findIndex((l) => l.trim() === heading.trim());
  let out;
  if (start < 0) {
    out = original.replace(/\n*$/, "") + (original === "" ? "" : "\n\n") + block;
  } else {
    let end = lines.length;
    for (let i = start + 1; i < lines.length; i += 1) {
      if (/^##\s/.test(lines[i])) {
        end = i;
        break;
      }
    }
    out = [...lines.slice(0, start), ...block.split("\n"), ...lines.slice(end)].join("\n");
  }
  writeFileSync(blockPath, out.endsWith("\n") ? out : out + "\n");
  say(`block written into ${blockPath} under ${heading}`);
}

const commands = {
  note: cmdNote,
  merge: cmdMerge,
  wake: () => say(renderView()),
  render: cmdRender,
  zoom: cmdZoom,
  forget: cmdForget,
  diff: cmdDiff,
  mark: cmdMark,
};

if (command === undefined || commands[command] === undefined) {
  refuse(`unknown command ${command ?? "(none)"}; one of ${Object.keys(commands).join(", ")}`);
}
commands[command]();
