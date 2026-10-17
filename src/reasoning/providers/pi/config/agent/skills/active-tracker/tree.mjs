// src/reasoning/providers/pi/config/agent/skills/active-tracker/tree.mjs
//
// The task tree, as an edge list. Every node names exactly one parent, and the
// root names none, so the path from the root to the pointer node and the
// frontier still to visit are derived rather than stored.
//
// This file is a library. The facade is active-tracker.mjs; the model is
// README.md.

import { appendFileSync, existsSync, readFileSync, writeFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join } from "node:path";

export const STATES = ["open", "later", "elsewhere"];
const MARKER = "  <- here";

export const pathsOf = (store) => ({
  store,
  log: join(dirname(store), "ACTIVE_TASK_TRACKER_LOG.jsonl"),
  state: join(dirname(store), "ACTIVE_TASK_TRACKER_STATE.json"),
});

let clock = () => new Date().toISOString();
export const setClock = (fn) => {
  clock = fn;
};

export function gitHead() {
  try {
    return execFileSync("git", ["rev-parse", "--short", "HEAD"], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).trim();
  } catch {
    return null;
  }
}

export function load(store) {
  if (!existsSync(store)) throw new Error(`no store at ${store}`);
  const data = JSON.parse(readFileSync(store, "utf8"));
  if (!Array.isArray(data.nodes)) throw new Error(`${store} carries no nodes`);
  return data;
}

function save(store, data) {
  data.nodes.sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }));
  writeFileSync(store, JSON.stringify(data, null, 2) + "\n");
}

// The log is append-only and is never edited. It is the change record the store
// is not, so a report and a missed pop are both reconcilable from it.
function emit(event, { log }) {
  const n = existsSync(log) ? readFileSync(log, "utf8").split("\n").filter(Boolean).length + 1 : 1;
  appendFileSync(log, JSON.stringify({ n, ts: clock(), ...event }) + "\n");
  return n;
}

export function readLog(store, since = 0) {
  const { log } = pathsOf(store);
  if (!existsSync(log)) return [];
  return readFileSync(log, "utf8").split("\n").filter(Boolean).map((line) => JSON.parse(line)).filter((e) => e.n > since);
}

export const byId = (data) => new Map(data.nodes.map((n) => [n.id, n]));
export const childrenOf = (data, id) => data.nodes.filter((n) => (n.parent ?? "") === id);

export function pathTo(data, id) {
  const index = byId(data);
  const path = [];
  let cur = id;
  while (cur !== undefined && cur !== null && index.has(cur)) {
    path.unshift(cur);
    cur = index.get(cur).parent;
  }
  return path;
}

export function subtreeOf(data, id) {
  if (!byId(data).has(id)) return [];
  const out = new Set([id]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const node of data.nodes) {
      if (node.parent !== null && out.has(node.parent) && !out.has(node.id)) {
        out.add(node.id);
        grew = true;
      }
    }
  }
  return data.nodes.filter((n) => out.has(n.id)).map((n) => n.id);
}

export function renderTree(data) {
  const index = byId(data);
  const depth = (node) => {
    let d = 0;
    let cur = node.parent;
    while (cur !== undefined && cur !== null && index.has(cur)) {
      d++;
      cur = index.get(cur).parent;
    }
    return d;
  };
  const width = Math.max(0, ...data.nodes.map((n) => depth(n) * 4 + `${n.id}. ${n.label ?? ""}`.length));
  const rows = [];
  const walk = (parent, prefix) => {
    const kids = childrenOf(data, parent);
    kids.forEach((node, i) => {
      const last = i === kids.length - 1;
      const stem = parent === "" ? "" : prefix + (last ? "└── " : "├── ");
      const label = `${node.id}. ${node.label ?? ""}`.trimEnd();
      const marker = node.id === data.current ? MARKER : "";
      rows.push(`${`${stem}${label}`.padEnd(width)}  ${node.state ?? "open"}${marker}`.trimEnd());
      walk(node.id, parent === "" ? "" : prefix + (last ? "    " : "│   "));
    });
  };
  walk("", "");
  return rows;
}

export function renderStack(data) {
  const path = pathTo(data, data.current);
  const on = new Set(path);
  const rows = [];
  for (const id of path) {
    const off = childrenOf(data, id).filter((n) => !on.has(n.id));
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

export const LEGEND =
  "The decomposition. A node is `open`, `later` (continues later), or `elsewhere` (continues elsewhere). A resolved node is pruned.";

export function render(data, store, tracker) {
  if (!existsSync(tracker)) throw new Error(`no tracker at ${tracker}`);
  let text = readFileSync(tracker, "utf8");
  const node = byId(data).get(data.current);
  if (node !== undefined) {
    text = text.replace(
      /\*\*Resume here\.\*\* Current node: \*\*.+?\*\*.*/,
      `**Resume here.** Current node: **${node.id}**, ${node.label ?? ""}.`,
    );
  }
  text = text.replace(/Workspace HEAD at last write: `[0-9a-f]+`/, `Workspace HEAD at last write: \`${data.head ?? "unknown"}\``);
  text = splice(text, "## The work tree", renderTree(data).join("\n"), LEGEND);
  text = splice(text, "## The stack", renderStack(data).join("\n"));
  writeFileSync(tracker, text);
}

export function push({ store, tracker, id, parent, label, state, stay = false, head }) {
  if (id === undefined || parent === undefined) throw new Error("push needs an id and a parent");
  if (state !== undefined && !STATES.includes(state)) throw new Error(`state must be one of ${STATES.join(" ")}`);
  const data = load(store);
  const node = byId(data).get(id);
  const created = node === undefined;
  const priorState = node?.state;
  if (created) {
    if (parent !== "-" && !byId(data).has(parent)) throw new Error(`parent ${parent} is not a node`);
    data.nodes.push({ id, parent: parent === "-" ? null : parent, label: label ?? id, state: state ?? "open" });
  } else {
    if (label !== undefined) node.label = label;
    if (state !== undefined) node.state = state;
  }
  const stateFrom = created ? undefined : priorState;
  if (!stay) data.current = id;
  data.head = head ?? gitHead();
  save(store, data);
  const event = {
    op: "push",
    id,
    parent: created ? (parent === "-" ? null : parent) : node.parent,
    label: label ?? data.nodes.find((n) => n.id === id)?.label,
    state: state ?? data.nodes.find((n) => n.id === id)?.state ?? "open",
    created,
    stateFrom,
    current: data.current,
    head: data.head,
  };
  emit(event, pathsOf(store));
  if (tracker !== undefined) render(data, store, tracker);
  return { id, created, current: data.current, head: data.head, nodes: data.nodes.length };
}

export function pop({ store, tracker, ids }) {
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
  data.head = gitHead() ?? data.head;
  save(store, data);
  for (const event of events) emit(event, pathsOf(store));
  if (tracker !== undefined) render(data, store, tracker);
  return { ids: list, popped: events.length, removed: events.flatMap((e) => e.subtree), current: data.current };
}

// The change since the last mark, derived from the log alone.
export function diff(store) {
  const { state } = pathsOf(store);
  const since = existsSync(state) ? JSON.parse(readFileSync(state, "utf8")).mark ?? 0 : 0;
  const events = readLog(store, since);
  const out = { since, through: since + events.length, added: [], pruned: [], moved: [], pointer: [], head: null };
  for (const event of events) {
    if (event.op === "push") {
      if (event.created) out.added.push(event.id);
      if (event.stateFrom !== undefined && event.stateFrom !== event.state) {
        out.moved.push(`${event.id} ${event.stateFrom} -> ${event.state}`);
      }
      out.pointer.push(event.current);
    } else if (event.op === "pop") {
      out.pruned.push(...event.subtree);
      out.pointer.push(event.current);
    }
    if (event.head !== undefined) out.head = event.head;
  }
  out.pointer = out.pointer.filter((v, i, a) => i === 0 || v !== a[i - 1]);
  return out;
}

export function mark(store) {
  const { state } = pathsOf(store);
  const events = readLog(store);
  writeFileSync(state, JSON.stringify({ mark: events.length === 0 ? 0 : events[events.length - 1].n }, null, 2) + "\n");
  return events.length === 0 ? 0 : events[events.length - 1].n;
}
