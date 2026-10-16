#!/usr/bin/env node
// src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs
//
// The active task tracker as data. The task tree is an edge list: every node
// names exactly one parent, and the root names none. The path from the root to
// the pointer node and the frontier still to visit are both derived from the
// edges, so neither is stored.
//
// The tool owns the move; the model owns the ids, the labels and the states.
//
// Usage: node active-tracker.mjs push <id> <parent> [--label <text>] [--state <mark>] [--stay]
//        node active-tracker.mjs pop <id>
//        node active-tracker.mjs view
//
// Exit codes: 0 ok, 1 a refusal with a message on stderr.

import { existsSync, readFileSync, writeFileSync } from "node:fs";

const STATES = ["[ ]", "[~]", "[-]"];
const OPEN = "[ ]";
const MARKER = "  <- resume here";

const raw = process.argv.slice(2);
let storePath = ".scratchpad/ACTIVE_TASK_TRACKER.json";
let trackerPath = ".scratchpad/ACTIVE_TASK_TRACKER.md";
const argv = [];
while (raw.length > 0) {
  const token = raw.shift();
  if (token === "--store") storePath = raw.shift();
  else if (token === "--tracker") trackerPath = raw.shift();
  else argv.push(token);
}
const command = argv.shift();

const refuse = (message) => {
  process.stderr.write(`active-tracker: ${message}\n`);
  process.exit(1);
};
const say = (message) => process.stdout.write(`${message}\n`);

function load() {
  if (!existsSync(storePath)) refuse(`no store at ${storePath}`);
  const store = JSON.parse(readFileSync(storePath, "utf8"));
  if (!Array.isArray(store.nodes)) refuse(`${storePath} carries no nodes`);
  return store;
}

function save(store) {
  store.nodes.sort((a, b) => a.id.localeCompare(b.id, undefined, { numeric: true }));
  writeFileSync(storePath, JSON.stringify(store, null, 2) + "\n");
}

const byId = (store) => new Map(store.nodes.map((n) => [n.id, n]));
const childrenOf = (store, id) => store.nodes.filter((n) => (n.parent ?? "") === id);

// The root-to-pointer chain. A node whose parent is absent stops the walk.
function pathTo(store, id) {
  const index = byId(store);
  const path = [];
  let cur = id;
  while (cur !== undefined && cur !== null && index.has(cur)) {
    path.unshift(cur);
    cur = index.get(cur).parent;
  }
  return path;
}

function renderTree(store) {
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
      const state = node.state ?? OPEN;
      const marker = node.id === store.current ? MARKER : "";
      rows.push(`${`${stem}${label}`.padEnd(width)}  ${state}${marker}`.trimEnd());
      walk(node.id, parent === "" ? "" : prefix + (last ? "    " : "│   "));
    });
  };
  walk("", "");
  return rows;
}

function renderStack(store) {
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

// Replace the body of the fenced block under a heading, leaving the rest of the
// tracker alone. A missing region refuses, so a render never half-writes.
function spliceBlock(text, heading, body) {
  const at = text.indexOf(heading);
  if (at < 0) refuse(`the tracker carries no "${heading}" section`);
  const open = text.indexOf("```", at);
  const close = text.indexOf("```", open + 3);
  if (open < 0 || close < 0) refuse(`"${heading}" carries no fenced block`);
  const bodyAt = text.indexOf("\n", open) + 1;
  return text.slice(0, bodyAt) + body + "\n" + text.slice(close);
}

function render(store) {
  if (!existsSync(trackerPath)) refuse(`no tracker at ${trackerPath}`);
  let text = readFileSync(trackerPath, "utf8");
  const node = byId(store).get(store.current);
  if (node !== undefined) {
    text = text.replace(
      /\*\*Resume here\.\*\* Current node: \*\*.+?\*\*.*/,
      `**Resume here.** Current node: **${node.id}**, ${node.label ?? ""}.`,
    );
  }
  text = spliceBlock(text, "## The work tree", renderTree(store).join("\n"));
  text = spliceBlock(text, "## The stack", renderStack(store).join("\n"));
  writeFileSync(trackerPath, text);
}

function cmdPush() {
  const id = argv.shift();
  const parent = argv.shift();
  if (id === undefined || parent === undefined) refuse("push needs an id and a parent");
  let label;
  let state = OPEN;
  let stay = false;
  while (argv.length > 0) {
    const flag = argv.shift();
    if (flag === "--label") label = argv.shift();
    else if (flag === "--state") state = argv.shift();
    else if (flag === "--stay") stay = true;
    else refuse(`unknown flag ${flag}`);
  }
  if (!STATES.includes(state)) refuse(`state must be one of ${STATES.join(" ")}`);
  const store = load();
  const node = byId(store).get(id);
  if (node === undefined) {
    if (parent !== "-" && !byId(store).has(parent)) refuse(`parent ${parent} is not a node`);
    store.nodes.push({ id, parent: parent === "-" ? null : parent, label: label ?? id, state });
  } else {
    if (label !== undefined) node.label = label;
    node.state = state;
  }
  if (!stay) store.current = id;
  save(store);
  render(store);
  say(`pushed ${id} under ${parent}${stay ? ", pointer stayed" : `, pointer -> ${id}`}`);
}

function cmdPop() {
  const id = argv.shift();
  if (id === undefined) refuse("pop needs an id");
  const store = load();
  const doomed = new Set([id]);
  let grew = true;
  while (grew) {
    grew = false;
    for (const node of store.nodes) {
      if (node.parent !== null && doomed.has(node.parent) && !doomed.has(node.id)) {
        doomed.add(node.id);
        grew = true;
      }
    }
  }
  if (doomed.size === 0 || !byId(store).has(id)) {
    say(`popped ${id}: not present, nothing changed`);
    return;
  }
  const parent = byId(store).get(id).parent ?? null;
  store.nodes = store.nodes.filter((n) => !doomed.has(n.id));
  if (doomed.has(store.current)) store.current = parent;
  save(store);
  render(store);
  say(`popped ${id} and ${doomed.size - 1} descendant(s); pointer -> ${store.current ?? "(none)"}`);
}

function cmdView() {
  const store = load();
  render(store);
  say(renderTree(store).join("\n"));
}

if (command === "push") cmdPush();
else if (command === "pop") cmdPop();
else if (command === "view") cmdView();
else refuse("unknown command; one of push, pop, view");
