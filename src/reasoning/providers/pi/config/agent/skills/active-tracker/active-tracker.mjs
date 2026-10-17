#!/usr/bin/env node
// src/reasoning/providers/pi/config/agent/skills/active-tracker/active-tracker.mjs
//
// The active task tracker: the task tree and the steering memory, composed. The
// two libraries are tree.mjs and memory.mjs; this file is the facade that holds
// the paths, renders the one tracker file, and emits the one report. It is both
// the library and the CLI.
//
// Usage: node active-tracker.mjs init [--root <dir>]
//        node active-tracker.mjs push <id> <parent> [--label <text>] [--state <state>] [--stay] [--note <text>] [--home <path>]
//        node active-tracker.mjs pop <id> [<id>...]
//        node active-tracker.mjs view
//        node active-tracker.mjs report
//        node active-tracker.mjs memory <wake|note|merge|zoom|forget|retire> [args]
//        node active-tracker.mjs log [--since <n>]
//
// Every command takes --root, defaulting to .scratchpad. The filenames under it
// belong to this file, not to the caller.
//
// Exit codes: 0 ok, 1 a refusal with a message on stderr.

import { resolve, join, dirname } from "node:path";
import fs from "node:fs";
import { fileURLToPath } from "node:url";
import * as tree from "./tree.mjs";
import * as memory from "./memory.mjs";

export { tree, memory };

export const DEFAULT_ROOT = ".scratchpad";

// The names are this skill's, not the caller's. A caller names a root, and the
// four files are fixed under it, so the store, the tracker and the log cannot
// be split across three directories.
export const NAMES = {
  store: "ACTIVE_TASK_TRACKER.json",
  tracker: "ACTIVE_TASK_TRACKER.md",
  log: "SESSION_MEMORY_LOG.jsonl",
};

export const STATES = tree.STATES;

const TEMPLATE_TEXT = "# Active task tracker\n\nThe session's working state: the task tree, the pointer, and the steering memory.\n\n**Resume here.** Current node: **(none)**, nothing is in hand.\n\nWorkspace HEAD at last write: `0000000`\n\n## The work tree\n\nThe decomposition. A node is `open`, `later` (continues later), or `elsewhere` (continues elsewhere). A resolved node is pruned.\n\n```text\n(empty)\n```text\n\n## The stack\n\n```text\n(empty)\n```text\n\n## Session memory\n\n```text\n(empty)\n```text\n";

const paths = ({ root } = {}) => {
  const r = root ?? DEFAULT_ROOT;
  return {
    root: r,
    store: join(r, NAMES.store),
    tracker: join(r, NAMES.tracker),
    log: join(r, NAMES.log),
  };
};

// A fresh session must open the tracker, not fail on its absence. The refusal
// stays where it belongs, on a render against a store that is not there.
export function init({ root } = {}) {
  const p = paths({ root });
  if (fs.existsSync(p.store)) throw new Error(`store already at ${p.store}`);
  if (fs.existsSync(p.tracker)) throw new Error(`tracker already at ${p.tracker}`);
  fs.mkdirSync(dirname(p.store), { recursive: true });
  fs.writeFileSync(p.store, JSON.stringify({ current: null, head: tree.gitHead(), nodes: [] }, null, 2) + "\n");
  fs.writeFileSync(p.tracker, TEMPLATE_TEXT);
  return p;
}

// The one writer of the tracker file: the tree blocks first, then the memory
// block, so the two writers never interleave.
export function draw(p) {
  const data = tree.load(p.store);
  tree.render(data, p.store, p.tracker);
  memory.render({ log: p.log, block: p.tracker });
  return data;
}

export function push({ root, id, parent, label, state, stay = false, note, home, restates }) {
  const p = paths({ root });
  const out = tree.push({ store: p.store, id, parent, label, state, stay });
  const mem = note === undefined ? null : memory.note({ log: p.log, text: note, home, restates });
  draw(p);
  return { tree: out, memory: mem };
}

export function pop({ root, ids }) {
  const p = paths({ root });
  const out = tree.pop({ store: p.store, ids });
  if (out.popped > 0) draw(p);
  return out;
}

export function view({ root } = {}) {
  const p = paths({ root });
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

export function report({ root } = {}) {
  const p = paths({ root });
  const markdown = formatReport(tree.diff(p.store), memory.diff({ log: p.log }), memory.wake({ log: p.log }));
  tree.mark(p.store);
  memory.mark({ log: p.log });
  return markdown;
}

function main(raw) {
  let root = DEFAULT_ROOT;
  const argv = [];
  while (raw.length > 0) {
    const token = raw.shift();
    if (token === "--root") root = raw.shift();
    else if (token === "--store" || token === "--tracker" || token === "--log") {
      // The three paths are gone in favour of one root. A caller that kept one
      // would otherwise write to the default root and never be told.
      process.stderr.write(`active-tracker: ${token} is gone; name one --root instead\n`);
      process.exit(1);
    } else argv.push(token);
  }
  const resolved = paths({ root });
  const command = argv.shift();
  const out = (text) => process.stdout.write(`${text}\n`);
  try {
    if (command === "init") {
      const made = init({ root });
      out(`seeded ${made.store} and ${made.tracker}`);
      return;
    }
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
      const result = push({ root, id, parent, label, state, stay, note, home, restates });
      out(`pushed ${result.tree.id}${result.tree.created ? "" : " (updated)"}; pointer -> ${result.tree.current}`);
      if (result.memory !== null) {
        out(`noted n=${result.memory.n}${result.memory.mergeDue ? `; merge due: ${result.memory.mergeDue}` : ""}`);
      }
    } else if (command === "pop") {
      const result = pop({ root, ids: argv.length > 0 ? argv : undefined });
      out(result.popped === 0 ? "pop: nothing present, nothing changed" : `popped ${result.removed.join(", ")}; pointer -> ${result.current ?? "(none)"}`);
    } else if (command === "view") {
      out(view({ root }).join("\n"));
    } else if (command === "report") {
      out(report({ root }));
    } else if (command === "log") {
      let since = 0;
      while (argv.length > 0) {
        const flag = argv.shift();
        if (flag === "--since") since = Number(argv.shift());
        else throw new Error(`unknown flag ${flag}`);
      }
      for (const event of tree.readLog(resolved.store, since)) out(JSON.stringify(event));
    } else if (command === "memory") {
      const sub = argv.shift();
      if (sub === "wake") out(memory.wake({ log: resolved.log }));
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
        const result = memory.note({ log: resolved.log, text, home, restates });
        out(`noted n=${result.n}${result.mergeDue ? `; merge due: ${result.mergeDue}` : ""}`);
      } else if (sub === "merge") out(`merged ${memory.merge({ log: resolved.log, lo: Number(argv.shift()), hi: Number(argv.shift()), text: argv.shift() }).merged} line(s)`);
      else if (sub === "forget") out(`forgot ${memory.forget({ log: resolved.log, ...range(argv.shift()) }).removed} line(s)`);
      else if (sub === "retire") {
        const result = memory.retire({ log: resolved.log, ...range(argv.shift()) });
        out(`retired ${result.retired} line(s) covering [${result.range}]; logged as n=${result.n}`);
      }
      else if (sub === "zoom") for (const entry of memory.zoom({ log: resolved.log, ...range(argv.shift()) })) out(JSON.stringify(entry));
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
