#!/usr/bin/env node
// src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs
//
// The active task tracker. This file is both the library and the CLI: import
// push, pop, view and log to drive the tracker from a script, or run it
// directly for the same operations. The model behind the data is README.md
// beside this file; the agent-facing contract is SKILL.md.
//
// Usage: node active-tracker.mjs push <id> <parent> [--label <text>] [--state <state>] [--stay]
//        node active-tracker.mjs pop <id> [<id>...]
//        node active-tracker.mjs view
//        node active-tracker.mjs log [--since <n>]
//
// Exit codes: 0 ok, 1 a refusal with a message on stderr.

import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const STATES = ["open", "later", "elsewhere"];
export const DEFAULT_STORE = ".scratchpad/ACTIVE_TASK_TRACKER.json";
export const DEFAULT_TRACKER = ".scratchpad/ACTIVE_TASK_TRACKER.md";

const MARKER = "  <- here";
const LEGEND = "The decomposition. A node is `open`, `later` (continues later), or `elsewhere` (continues elsewhere). A resolved node is pruned.";

let clock = () => new Date().toISOString();

// --- the store -----------------------------------------------------------------

export function load(storePath) {
  if (!existsSync(storePath)) throw new Error(`no store at ${storePath}`);
  const store = JSON.parse(readFileSync(storePath, "utf8"));
  if (!Array.isArray(store.nodes)) throw new Error(`${storePath} carries no nodes`);
  return store;
}

function save(storePath, store) {
  store.nodes.sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }));
  writeFileSync(storePath, JSON.stringify(store, null, 2) + "\n");
}

const logFile = (storePath) => join(dirname(storePath), "ACTIVE_TASK_TRACKER_LOG.jsonl");

// The log is append-only and is never edited. It is the change record the store
// is not, so a missed push or pop can be reconciled after the fact.
function emit(storePath, event) {
  const path = logFile(storePath);
  const n = existsSync(path) ? readFileSync(path, "utf8").split("\n").filter(Boolean).length + 1 : 1;
  appendFileSync(path, JSON.stringify({ n, ts: clock(), ...event }) + "\n");
  return n;
}

export function readLog(storePath, since = 0) {
  const path = logFile(storePath);
  if (!existsSync(path)) return [];
  return readFileSync(path, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)).filter((e) => e.n > since);
}

// --- the derived views ---------------------------------------------------------

export const byId = (store) => new Map(store.nodes.map((n) => [n.id, n]));
export const childrenOf = (store, id) => store.nodes.filter((n) => (n.parent ?? "") === id);

export function pathTo(store, id) {
  const index = byId(store);
  const path = [];
  let cur = id;
  while (cur !== undefined && cur !== null && index.has(cur)) {
    path.unshift(cur);
    cur = index.get(cur).parent;
  }
  return path;
}

export function subtreeOf(store, id) {
  if (!byId(store).has(id)) return [];
  const out = new Set([id]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const node of store.nodes) {
      if (node.parent !== null && out.has(node.parent) && !out.has(node.id)) {
        out.add(node.id);
        grew = true;
      }
    }
  }
  return store.nodes.filter((n) => out.has(n.id)).map((n) => n.id);
}

export function renderTree(store) {
  const index = byId(store);
  const depth = (node) => {
    let d = 0;
    let cur = node.parent;
    while (cur !== undefined && cur !== null && index.has(cur)) {
      d++;
      cur = index.get(cur).parent;
    }
    return d;
  };
  const width = Math.max(0, ...store.nodes.map((n) => depth(n) * 4 + `${n.id}. ${n.label ?? ""}`.length));
  const rows = [];
  const walk = (parent, prefix) => {
    const kids = childrenOf(store, parent);
    kids.forEach((node, i) => {
      const last = i === kids.length - 1;
      const stem = parent === "" ? "" : prefix + (last ? "└── " : "├── ");
      const label = `${node.id}. ${node.label ?? ""}`.trimEnd();
      const marker = node.id === store.current ? MARKER : "";
      rows.push(`${`${stem}${label}`.padEnd(width)}  ${node.state ?? "open"}${marker}`.trimEnd());
      walk(node.id, parent === "" ? "" : prefix + (last ? "    " : "│   "));
    });
  };
  walk("", "");
  return rows;
}

export function renderStack(store) {
  const path = pathTo(store, store.current);
  const on = new Set(path);
  const rows = [];
  for (const id of path) {
    const off = childrenOf(store, id).filter((n) => !on.has(n.id));
    if (off.length > 0) rows.push(`at ${id}: ${off.map((n) => n.id).join(", ")}`);
  }
  const lines = [`path:     ${path.join(" -> ") || "(none)"}`];
  if (rows.length === 0) lines.push("frontier: (none)");
  else rows.forEach((row, i) => lines.push(`${i === 0 ? "frontier: " : "          "}${row}`));
  return lines;
}

// A missing region refuses, so a render never half-writes. The legend, when
// given, replaces the prose between the heading and the fence.
function splice(text, heading, body, legend = null) {
  const at = text.indexOf(heading);
  if (at < 0) throw new Error(`the tracker carries no "${heading}" section`);
  const open = text.indexOf("```", at);
  const close = text.indexOf("```", open + 3);
  if (open < 0 || close < 0) throw new Error(`"${heading}" carries no fenced block`);
  const before = text.slice(0, text.indexOf("\n", at) + 1);
  const fenceLine = text.slice(open, text.indexOf("\n", open));
  const legendPart = legend === null ? "" : `\n${legend}\n`;
  return `${before}${legendPart}\n${fenceLine}\n${body}\n${text.slice(close)}`;
}

export function render(store, storePath, trackerPath) {
  if (!existsSync(trackerPath)) throw new Error(`no tracker at ${trackerPath}`);
  let text = readFileSync(trackerPath, "utf8");
  const node = byId(store).get(store.current);
  if (node !== undefined) {
    text = text.replace(
      /\*\*Resume here\.\*\* Current node: \*\*.+?\*\*.*/,
      `**Resume here.** Current node: **${node.id}**, ${node.label ?? ""}.`,
    );
  }
  text = splice(text, "## The work tree", renderTree(store).join("\n"), LEGEND);
  text = splice(text, "## The stack", renderStack(store).join("\n"));
  writeFileSync(trackerPath, text);
}

// --- the operations ------------------------------------------------------------

export function push({ store = DEFAULT_STORE, tracker, id, parent, label, state, stay = false }) {
  if (id === undefined || parent === undefined) throw new Error("push needs an id and a parent");
  if (state !== undefined && !STATES.includes(state)) throw new Error(`state must be one of ${STATES.join(" ")}`);
  const data = load(store);
  const node = byId(data).get(id);
  if (node === undefined) {
    if (parent !== "-" && !byId(data).has(parent)) throw new Error(`parent ${parent} is not a node`);
    data.nodes.push({ id, parent: parent === "-" ? null : parent, label: label ?? id, state: state ?? "open" });
  } else {
    if (label !== undefined) node.label = label;
    if (state !== undefined) node.state = state;
  }
  if (!stay) data.current = id;
  save(store, data);
  emit(store, { op: "push", id, parent: node === undefined ? (parent === "-" ? null : parent) : node.parent, label: label ?? node?.label, state: state ?? node?.state ?? "open", stay, current: data.current });
  if (tracker !== undefined) render(data, store, tracker);
  return { id, current: data.current, nodes: data.nodes.length };
}

export function pop({ store = DEFAULT_STORE, tracker, ids }) {
  const list = Array.isArray(ids) ? ids : [ids];
  if (list.length === 0 || list[0] === undefined) throw new Error("pop needs at least one id");
  const data = load(store);
  const events = [];
  for (const id of list) {
    const gone = subtreeOf(data, id);
    if (gone.length === 0) continue;
    const parent = byId(data).get(id).parent ?? null;
    data.nodes = data.nodes.filter((n) => !gone.includes(n.id));
    if (gone.includes(data.current)) data.current = parent;
    events.push({ op: "pop", id, subtree: gone, parent, current: data.current });
  }
  if (events.length === 0) return { ids: list, popped: 0 };
  save(store, data);
  for (const event of events) emit(store, event);
  if (tracker !== undefined) render(data, store, tracker);
  return { ids: list, popped: events.length, removed: events.flatMap((e) => e.subtree), current: data.current };
}

export function view({ store = DEFAULT_STORE, tracker } = {}) {
  const data = load(store);
  if (tracker !== undefined) render(data, store, tracker);
  return renderTree(data);
}

// --- the CLI -------------------------------------------------------------------

function main(raw) {
  let store = DEFAULT_STORE;
  let tracker = DEFAULT_TRACKER;
  const argv = [];
  while (raw.length > 0) {
    const token = raw.shift();
    if (token === "--store") store = raw.shift();
    else if (token === "--tracker") tracker = raw.shift();
    else argv.push(token);
  }
  const command = argv.shift();
  try {
    if (command === "push") {
      const id = argv.shift();
      const parent = argv.shift();
      let label;
      let state;
      let stay = false;
      while (argv.length > 0) {
        const flag = argv.shift();
        if (flag === "--label") label = argv.shift();
        else if (flag === "--state") state = argv.shift();
        else if (flag === "--stay") stay = true;
        else throw new Error(`unknown flag ${flag}`);
      }
      const out = push({ store, tracker, id, parent, label, state, stay });
      process.stdout.write(`pushed ${out.id}; pointer -> ${out.current}\n`);
    } else if (command === "pop") {
      const out = pop({ store, tracker, ids: argv.length > 0 ? argv : undefined });
      if (out.popped === 0) process.stdout.write("pop: nothing present, nothing changed\n");
      else process.stdout.write(`popped ${out.removed.join(", ")}; pointer -> ${out.current ?? "(none)"}\n`);
    } else if (command === "view") {
      process.stdout.write(view({ store, tracker }).join("\n") + "\n");
    } else if (command === "log") {
      let since = 0;
      while (argv.length > 0) {
        const flag = argv.shift();
        if (flag === "--since") since = Number(argv.shift());
        else throw new Error(`unknown flag ${flag}`);
      }
      for (const event of readLog(store, since)) process.stdout.write(`${JSON.stringify(event)}\n`);
    } else {
      throw new Error("unknown command; one of push, pop, view, log");
    }
  } catch (error) {
    process.stderr.write(`active-tracker: ${error.message}\n`);
    process.exit(1);
  }
}

if (process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
