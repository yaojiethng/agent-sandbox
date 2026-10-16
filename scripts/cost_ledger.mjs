#!/usr/bin/env node

import { readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";

// A reader that closes the pipe early, such as `head`, is not an error here.
process.stdout.on("error", (error) => {
  if (error.code !== "EPIPE") throw error;
  process.exit(0);
});

function parseArgs(argv) {
  let session = null;
  let root = null;
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--session") {
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
  return { session, root };
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

function readSession(path) {
  const lines = readFileSync(path, "utf8").split(/\r?\n/).filter((line) => line.trim() !== "");
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

  for (const line of lines) {
    let entry;
    try { entry = JSON.parse(line); } catch (error) { continue; }
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
    backend: "pi",
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


function main() {
  const { session, root } = parseArgs(process.argv.slice(2));
  const files = session ? [resolve(session)] : jsonlFiles(resolve(root));
  for (const file of files) {
    process.stdout.write(JSON.stringify(readSession(file)) + "\n");
  }
}

main();
