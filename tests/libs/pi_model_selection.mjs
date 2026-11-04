import { spawn } from "node:child_process";
import { once } from "node:events";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const settingsPath = path.resolve(
  scriptDir,
  "../../src/reasoning/providers/pi/config/agent/settings.json",
);

const AUTH = {
  deepseek: { type: "api_key", key: "$DEEPSEEK_API_KEY" },
  openrouter: { type: "api_key", key: "$OPENROUTER_API_KEY" },
  "opencode-go": { type: "api_key", key: "$OPENCODE_API_KEY" },
};

const SCENARIOS = {
  "all-providers": {
    auth: ["deepseek", "opencode-go", "openrouter"],
    env: ["DEEPSEEK_API_KEY", "OPENCODE_API_KEY", "OPENROUTER_API_KEY"],
  },
  "no-deepseek": {
    auth: ["opencode-go", "openrouter"],
    env: ["OPENCODE_API_KEY", "OPENROUTER_API_KEY"],
  },
  "no-opencode": {
    auth: ["deepseek", "openrouter"],
    env: ["DEEPSEEK_API_KEY", "OPENROUTER_API_KEY"],
  },
  "openrouter-only": {
    auth: ["openrouter"],
    env: ["OPENROUTER_API_KEY"],
  },
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function run(scenario) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "pi-model-selection-"));
  const agentDir = path.join(root, "agent");
  const cwd = path.join(root, "project");
  fs.mkdirSync(agentDir, { recursive: true });
  fs.mkdirSync(cwd, { recursive: true });
  fs.copyFileSync(settingsPath, path.join(agentDir, "settings.json"));

  const auth = {};
  for (const name of scenario.auth) auth[name] = AUTH[name];
  fs.writeFileSync(path.join(agentDir, "auth.json"), JSON.stringify(auth, null, 2));

  const env = { ...process.env, PI_CODING_AGENT_DIR: agentDir };
  for (const entry of Object.values(AUTH)) delete env[entry.key.slice(1)];
  for (const name of scenario.env) env[name] = "test-key";

  const child = spawn(process.env.PI_BIN ?? "pi", ["--mode", "rpc", "--no-session"], {
    cwd,
    env,
    stdio: ["pipe", "pipe", "pipe"],
  });

  let buffer = "";
  let stderr = "";
  const pending = new Map();

  const rejectPending = (message) => {
    for (const waiter of pending.values()) {
      clearTimeout(waiter.timer);
      waiter.reject(new Error(message));
    }
    pending.clear();
  };

  child.stdout.setEncoding("utf8");
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    stderr = (stderr + chunk).slice(-2000);
  });
  child.on("error", (error) => rejectPending(error.message));
  child.on("exit", (code, signal) => {
    rejectPending(`pi exited before responding (code ${code}, signal ${signal}): ${stderr}`);
  });

  child.stdout.on("data", (chunk) => {
    buffer += chunk;
    let index;
    while ((index = buffer.indexOf("\n")) !== -1) {
      const line = buffer.slice(0, index);
      buffer = buffer.slice(index + 1);
      if (!line.trim()) continue;
      let message;
      try {
        message = JSON.parse(line);
      } catch {
        continue;
      }
      if (message.type !== "response") continue;
      const waiter = pending.get(message.id);
      if (!waiter) continue;
      pending.delete(message.id);
      clearTimeout(waiter.timer);
      waiter.resolve(message);
    }
  });

  const request = (command) =>
    new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(command.id);
        reject(new Error(`timeout waiting for ${command.id}: ${stderr}`));
      }, 30000);
      pending.set(command.id, { resolve, reject, timer });
      child.stdin.write(JSON.stringify(command) + "\n");
    });

  try {
    const state = await request({ type: "get_state", id: "state" });
    const model = state.data?.model;
    if (!model) throw new Error(`get_state carried no model: ${JSON.stringify(state)}`);
    return `${model.provider}/${model.id}`;
  } finally {
    rejectPending("probe finished");
    try {
      child.stdin.end();
    } catch {
    }
    if (child.exitCode === null && child.signalCode === null) {
      child.kill("SIGTERM");
      await Promise.race([once(child, "exit"), sleep(2000)]);
    }
    if (child.exitCode === null && child.signalCode === null) child.kill("SIGKILL");
    fs.rmSync(root, { recursive: true, force: true });
  }
}

const name = process.argv[2];
if (!name || !(name in SCENARIOS)) {
  console.error(`usage: pi_model_selection.mjs <${Object.keys(SCENARIOS).join("|")}>`);
  process.exit(2);
}

try {
  console.log(await run(SCENARIOS[name]));
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
