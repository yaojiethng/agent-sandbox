#!/usr/bin/env node
// session_evidence.mjs -- read one pi session transcript and print the evidence
// a recovery claim needs: when it ran, where, what it wrote or edited, the
// write-shaped commands it ran, and its last assistant text.
//
// Usage:
//   session_evidence.mjs <session-id | path> [--store DIR]
//   session_evidence.mjs --cwd PATH [--latest] [--store DIR]
//
// Store: --store, else $PI_SESSION_STORE, else ~/.pi/agent/sessions.
// A session id is matched as the `_<id>.jsonl` suffix. --cwd resolves by the
// `cwd` in each session header, because the directory encoding is not a rule.
//
// Exit: 0 = printed; 1 = no store, no match, or an unreadable transcript.

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { basename, join, resolve } from "node:path";

const WRITE_SHAPED = [
  /\bgit\s+commit\b/,
  /(?:^|[^0-9>&=])>{1,2}(?!&|=)\s*[^\s&|]/,
  /<<-?\s*['"]?[A-Za-z]/,
  /\btee\b/,
];

const usage = () => {
  console.error("usage: session_evidence.mjs <session-id | path> [--store DIR]");
  console.error("       session_evidence.mjs --cwd PATH [--latest] [--store DIR]");
};

const fail = (message) => {
  console.error(`session_evidence: ${message}`);
  process.exit(1);
};

const parseArgs = (argv) => {
  const out = { positional: null, store: null, cwd: null, latest: false };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--store" || arg === "--cwd") {
      const value = argv[i + 1];
      if (value === undefined) fail(`${arg} needs a value`);
      if (arg === "--store") out.store = value;
      else out.cwd = value;
      i += 1;
    } else if (arg === "--latest") {
      out.latest = true;
    } else if (arg.startsWith("-")) {
      fail(`unknown option '${arg}'`);
    } else if (out.positional === null) {
      out.positional = arg;
    } else {
      fail(`unexpected argument '${arg}'`);
    }
  }
  return out;
};

const walk = (dir, out = []) => {
  for (const entry of readdirSync(dir)) {
    if (entry === ".git" || entry === "node_modules") continue;
    const path = join(dir, entry);
    if (statSync(path).isDirectory()) walk(path, out);
    else if (path.endsWith(".jsonl")) out.push(path);
  }
  return out;
};

const records = (path) =>
  readFileSync(path, "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        return null;
      }
    })
    .filter(Boolean);

const headerOf = (path) => {
  const all = records(path);
  const session = all.find((record) => record.type === "session");
  if (!session) return null;
  const model = all.find((record) => record.type === "model_change");
  return {
    id: session.id,
    cwd: session.cwd,
    start: session.timestamp,
    provider: model ? model.provider : null,
    model: model ? model.modelId : null,
  };
};

const newest = (paths) => {
  const scored = paths.map((path) => {
    const name = basename(path);
    const stamp = name.slice(0, name.indexOf("_"));
    return { path, stamp };
  });
  scored.sort((a, b) => (a.stamp < b.stamp ? 1 : a.stamp > b.stamp ? -1 : 0));
  return scored[0] ? scored[0].path : null;
};

const resolveSession = ({ positional, store, cwd, latest }) => {
  if (!existsSync(store)) fail(`session store not found: ${store}`);
  const all = walk(store);

  if (positional) {
    if (positional.endsWith(".jsonl") || positional.includes("/")) {
      if (!existsSync(positional)) fail(`no such transcript: ${positional}`);
      return positional;
    }
    const matches = all.filter((path) => basename(path).endsWith(`_${positional}.jsonl`));
    if (matches.length === 0) fail(`no session matches id '${positional}'`);
    return newest(matches);
  }

  if (cwd !== null || latest) {
    const wanted = resolve(cwd || process.cwd());
    const matches = [];
    for (const path of all) {
      let header;
      try {
        header = headerOf(path);
      } catch {
        continue;
      }
      if (header && header.cwd === wanted) matches.push(path);
    }
    if (matches.length === 0) fail(`no session ran in ${wanted}`);
    return newest(matches);
  }

  usage();
  process.exit(1);
};

const textOf = (message) => {
  if (typeof message.content === "string") return message.content;
  if (!Array.isArray(message.content)) return "";
  return message.content
    .filter((part) => part && part.type === "text" && typeof part.text === "string")
    .map((part) => part.text)
    .join("\n");
};

const describe = (path) => {
  const all = records(path);
  const files = new Map();
  const commands = [];
  let lastText = "";

  for (const record of all) {
    if (record.type !== "message" || !record.message) continue;
    const message = record.message;
    const when = record.timestamp || message.timestamp || "";
    if (Array.isArray(message.content)) {
      for (const part of message.content) {
        if (!part || part.type !== "toolCall") continue;
        const args = part.arguments || {};
        if (part.name === "write" || part.name === "edit") {
          const target = String(args.path || args.file_path || "");
          if (!target) continue;
          const entry = files.get(target) || { count: 0, last: "" };
          entry.count += 1;
          entry.last = when;
          files.set(target, entry);
        }
        if (part.name === "bash") {
          const command = String(args.command || "");
          if (WRITE_SHAPED.some((pattern) => pattern.test(command))) {
            commands.push({ command, when });
          }
        }
      }
    }
    if (message.role === "assistant") {
      const text = textOf(message).trim();
      if (text) lastText = text;
    }
  }

  return { header: headerOf(path), files, commands, lastText };
};

const oneLine = (text, limit) => {
  const flat = text.replace(/\s+/g, " ").trim();
  return flat.length > limit ? `${flat.slice(0, limit - 1)}…` : flat;
};

const main = () => {
  const args = parseArgs(process.argv.slice(2));
  const store = args.store || process.env.PI_SESSION_STORE || join(homedir(), ".pi/agent/sessions");
  const path = resolveSession({ ...args, store });
  const { header, files, commands, lastText } = describe(path);

  if (!header) fail(`no session header in ${path}`);

  const model = [header.provider, header.model].filter(Boolean).join(" / ") || "unknown";
  console.log(`session  ${header.id}`);
  console.log(`cwd      ${header.cwd}`);
  console.log(`start    ${header.start}`);
  console.log(`model    ${model}`);
  console.log("");

  const touched = [...files.entries()].sort((a, b) => b[1].count - a[1].count || a[0].localeCompare(b[0]));
  const edits = touched.reduce((sum, [, entry]) => sum + entry.count, 0);
  console.log(`files    ${touched.length} file(s), ${edits} edit(s)`);
  for (const [target, entry] of touched) {
    console.log(`  ${String(entry.count).padStart(3)}  ${target}  (last ${entry.last})`);
  }
  console.log("");

  console.log(`bash     ${commands.length} write-shaped command(s)`);
  for (const { command } of commands) console.log(`  ${oneLine(command, 200)}`);
  console.log("");

  console.log("last assistant text");
  console.log(lastText ? lastText.slice(0, 4000) : "  (none)");
};

try {
  main();
} catch (error) {
  fail(error && error.message ? error.message : String(error));
}
