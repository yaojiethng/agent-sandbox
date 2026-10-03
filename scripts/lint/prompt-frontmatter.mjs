// Frontmatter parse gate for prompts and skills.
//
// Enforces docs/development/prompt-authoring-conventions.md
// `## Structure of a workflow document`: "The frontmatter is YAML, so a
// malformed value breaks the prompt." A prompt whose frontmatter does not
// parse is dropped by pi at load time with no message in the session, so the
// prompt simply never appears. The authoring rule existed before this gate
// and was still missed, so the rule is enforced here rather than restated.
//
// A file with no frontmatter block is skipped, not flagged. A prompt draft
// that opens on its title is a separate, tracked defect; only a block that
// parses badly is the silent failure this gate exists to catch.
//
// Exit codes: 0 = every block parsed, 1 = a block failed to parse or the gate
// could not run. The finding count is printed, never encoded in the exit code.

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { loadYaml } from "./yaml-loader.mjs";

const REPO_ROOT = process.env.PROMPT_FRONTMATTER_SCAN_ROOT
  ? resolve(process.env.PROMPT_FRONTMATTER_SCAN_ROOT)
  : resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

/** Roots holding a prompt or a skill. A missing root is skipped. */
const ROOTS = [
  // workflow/coding-agent/drafts is deliberately absent: a draft is not a live prompt.
  "workflow/coding-agent/prompts",
  "workflow/coding-agent/skills",
  "src/reasoning/providers/pi/config/agent/prompts",
  "src/reasoning/agent/skills",
  "src/reasoning/providers/pi/config/agent/skills",
];

/** Every markdown file under a root, or nothing when the root is absent. */
function collect(root) {
  const out = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) {
        walk(full);
      } else if (entry.endsWith(".md")) {
        out.push(full);
      }
    }
  };
  if (existsSync(root)) walk(root);
  return out;
}

/** The frontmatter block, or null when the file does not open with one. */
function frontmatterOf(text) {
  if (!text.startsWith("---\n") && text !== "---") return null;
  const end = text.indexOf("\n---", 3);
  if (end < 0) return null;
  return { body: text.slice(4, end), offset: text.slice(0, 4).split("\n").length - 1 };
}

const { parse } = loadYaml("Frontmatter gate");
const files = ROOTS.flatMap((root) => collect(join(REPO_ROOT, root)));
const findings = [];

for (const file of files) {
  const text0 = readFileSync(file, "utf8");
  const block = frontmatterOf(text0);
  if (block === null) continue;
  try {
    parse(block.body);
  } catch (error) {
    const rel = file.slice(REPO_ROOT.length + 1);
    const at = error.linePos ? error.linePos[0] : null;
    // `parse` sees the block body, so its line numbers start at the second
    // line of the file; the offset is where the body began.
    const text = at ? text0.split("\n")[block.offset + at.line - 1] : undefined;
    findings.push({ rel, line: at ? block.offset + at.line : 0, text, first: String(error.message).split("\n")[0] });
  }
}

for (const f of findings) {
  console.log(f.rel + ":" + f.line + " frontmatter does not parse");
  console.log("  " + f.first);
  if (f.text) console.log("  offending line: " + f.text.trim().slice(0, 100));
}

if (findings.length === 0) {
  console.log("Frontmatter gate: clean across " + files.length + " prompt and skill files");
} else {
  console.error(
    "Blocking gate: " + findings.length + " of " + files.length + " frontmatter blocks do not parse. " +
      "Quote any value holding a colon, a leading dash, or a trailing colon.",
  );
}
process.exit(findings.length === 0 ? 0 : 1);
