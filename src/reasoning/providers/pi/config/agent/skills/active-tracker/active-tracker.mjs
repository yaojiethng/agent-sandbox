#!/usr/bin/env node
// src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs
//
// The active task tracker: the task tree and the steering memory, composed. The
// two libraries are tree.mjs and memory.mjs; this file is the facade that holds
// the paths, renders the one tracker file, and emits the one report. It is both
// the library and the CLI.
//
// Usage: node active-tracker.mjs push <id> <parent> [--label <text>] [--state <state>] [--stay] [--note <text>] [--home <path>]
//        node active-tracker.mjs pop <id> [<id>...]
//        node active-tracker.mjs view
//        node active-tracker.mjs report
//        node active-tracker.mjs memory <wake|note|merge|zoom|forget|retire> [args]
//        node active-tracker.mjs log [--since <n>]
//
// Exit codes: 0 ok, 1 a refusal with a message on stderr.

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";
import * as tree from "./tree.mjs";
import * as memory from "./memory.mjs";

export { tree, memory };

export const DEFAULT_STORE = ".scratchpad/ACTIVE_TASK_TRACKER.json";
export const DEFAULT_TRACKER = ".scratchpad/ACTIVE_TASK_TRACKER.md";
export const DEFAULT_LOG = ".scratchpad/SESSION_MEMORY_LOG.jsonl";
export const STATES = tree.STATES;

const paths = ({ store, tracker, log }) => ({
  store: store ?? DEFAULT_STORE,
  tracker: tracker ?? DEFAULT_TRACKER,
  log: log ?? DEFAULT_LOG,
});

// The one writer of the tracker file: the tree blocks first, then the memory
// block, so the two writers never interleave.
export function draw(p) {
  const data = tree.load(p.store);
  tree.render(data, p.store, p.tracker);
  memory.render({ log: p.log, block: p.tracker });
  return data;
}

export function push({ store, tracker, log, id, parent, label, state, stay = false, note, home, restates }) {
  const p = paths({ store, tracker, log });
  const out = tree.push({ store: p.store, id, parent, label, state, stay });
  const mem = note === undefined ? null : memory.note({ log: p.log, text: note, home, restates });
  draw(p);
  return { tree: out, memory: mem };
}

export function pop({ store, tracker, log, ids }) {
  const p = paths({ store, tracker, log });
  const out = tree.pop({ store: p.store, ids });
  if (out.popped > 0) draw(p);
  return out;
}

export function view({ store, tracker, log } = {}) {
  const p = paths({ store, tracker, log });
  const data = draw(p);
  return tree.renderTree(data);
}

const bullet = (label, values) => `- ${label}: ${values.length === 0 ? "none" : values.join(", ")}`;

// The report is a pure function of the log since each mark and the two views,
// so the same events produce the same report.
export function formatReport(t, m, memoryText) {
  return [
    "## Push report",
    "",
    `**Tree.** ${t.through - t.since} event(s) since n=${t.since}.`,
    bullet("pruned", t.pruned),
    bullet("added", t.added),
    bullet("state moved", t.moved),
    bullet("pointer", t.pointer),
    bullet("head", t.head === null ? [] : [t.head]),
    "",
    `**Memory.** ${m.appended.length} occurrence(s) since the mark.`,
    bullet("appended", m.appended.map((e) => `n=${e.n}`)),
    bullet("view added", m.added.map((l) => `[${l.lo}-${l.hi}]`)),
    bullet("view dropped", m.dropped.map((l) => `[${l.lo}-${l.hi}]`)),
    "",
    "## Session memory",
    "",
    "```text",
    memoryText,
    "```",
  ].join("\n");
}

export function report({ store, tracker, log } = {}) {
  const p = paths({ store, tracker, log });
  const markdown = formatReport(tree.diff(p.store), memory.diff({ log: p.log }), memory.wake({ log: p.log }));
  tree.mark(p.store);
  memory.mark({ log: p.log });
  return markdown;
}

function main(raw) {
  let store = DEFAULT_STORE;
  let tracker = DEFAULT_TRACKER;
  let log = DEFAULT_LOG;
  const argv = [];
  while (raw.length > 0) {
    const token = raw.shift();
    if (token === "--store") store = raw.shift();
    else if (token === "--tracker") tracker = raw.shift();
    else if (token === "--log") log = raw.shift();
    else argv.push(token);
  }
  const command = argv.shift();
  const out = (text) => process.stdout.write(`${text}\n`);
  try {
    if (command === "push") {
      const id = argv.shift();
      const parent = argv.shift();
      let label;
      let state;
      let stay = false;
      let note;
      let home;
      let restates;
      while (argv.length > 0) {
        const flag = argv.shift();
        if (flag === "--label") label = argv.shift();
        else if (flag === "--state") state = argv.shift();
        else if (flag === "--stay") stay = true;
        else if (flag === "--note") note = argv.shift();
        else if (flag === "--home") home = argv.shift();
        else if (flag === "--restates") restates = Number(argv.shift());
        else throw new Error(`unknown flag ${flag}`);
      }
      const result = push({ store, tracker, log, id, parent, label, state, stay, note, home, restates });
      out(`pushed ${result.tree.id}${result.tree.created ? "" : " (updated)"}; pointer -> ${result.tree.current}`);
      if (result.memory !== null) {
        out(`noted n=${result.memory.n}${result.memory.mergeDue ? `; merge due: ${result.memory.mergeDue}` : ""}`);
      }
    } else if (command === "pop") {
      const result = pop({ store, tracker, log, ids: argv.length > 0 ? argv : undefined });
      out(result.popped === 0 ? "pop: nothing present, nothing changed" : `popped ${result.removed.join(", ")}; pointer -> ${result.current ?? "(none)"}`);
    } else if (command === "view") {
      out(view({ store, tracker, log }).join("\n"));
    } else if (command === "report") {
      out(report({ store, tracker, log }));
    } else if (command === "log") {
      let since = 0;
      while (argv.length > 0) {
        const flag = argv.shift();
        if (flag === "--since") since = Number(argv.shift());
        else throw new Error(`unknown flag ${flag}`);
      }
      for (const event of tree.readLog(store, since)) out(JSON.stringify(event));
    } else if (command === "memory") {
      const sub = argv.shift();
      if (sub === "wake") out(memory.wake({ log }));
      else if (sub === "note") {
        const text = argv.shift();
        let home;
        let restates;
        while (argv.length > 0) {
          const flag = argv.shift();
          if (flag === "--home") home = argv.shift();
          else if (flag === "--restates") restates = Number(argv.shift());
          else throw new Error(`unknown flag ${flag}`);
        }
        const result = memory.note({ log, text, home, restates });
        out(`noted n=${result.n}${result.mergeDue ? `; merge due: ${result.mergeDue}` : ""}`);
      } else if (sub === "merge") out(`merged ${memory.merge({ log, lo: Number(argv.shift()), hi: Number(argv.shift()), text: argv.shift() }).merged} line(s)`);
      else if (sub === "forget") out(`forgot ${memory.forget({ log, ...range(argv.shift()) }).removed} line(s)`);
      else if (sub === "retire") {
        const result = memory.retire({ log, ...range(argv.shift()) });
        out(`retired ${result.retired} line(s) covering [${result.range}]; logged as n=${result.n}`);
      }
      else if (sub === "zoom") for (const entry of memory.zoom({ log, ...range(argv.shift()) })) out(JSON.stringify(entry));
      else throw new Error("memory needs one of wake, note, merge, zoom, forget, retire");
    } else {
      throw new Error("unknown command; one of push, pop, view, report, memory, log");
    }
  } catch (error) {
    process.stderr.write(`active-tracker: ${error.message}\n`);
    process.exit(1);
  }
}

function range(text) {
  const match = /^(\d+)-(\d+)$/.exec(text ?? "");
  if (!match) throw new Error("the range must be <lo>-<hi>");
  return { lo: Number(match[1]), hi: Number(match[2]) };
}

if (process.argv[1] !== undefined && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main(process.argv.slice(2));
}
