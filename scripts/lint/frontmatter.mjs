// Frontmatter parse gate for prompts, skills and policy files.
//
// Enforces docs/development/prompt-authoring-conventions.md
// `## Structure of a workflow document`: "The frontmatter is YAML, so a
// malformed value breaks the prompt." A prompt whose frontmatter does not
// parse is dropped by pi at load time with no message in the session, so the
// prompt simply never appears. The authoring rule existed before this gate
// and was still missed, so the rule is enforced here rather than restated.
//
// Policy files (docs/**/*_policy.md) carry a description and a scope in their
// frontmatter too, per docs/policies/documentation_policy.md `### Document
// header format`. Nothing consumes their values at runtime, so the block's
// parse is the one thing a reader cannot check by eye; this gate is it.
//
// A file with no frontmatter block is skipped, not flagged. A prompt draft
// that opens on its title is a separate, tracked defect; only a block that
// parses badly is the silent failure this gate exists to catch.
//
// The file set is the manifest's instruction cells plus the project's own
// `.agents/` tree; see the ROOTS derivation below. The scan root is a test
// seam, while the declaration is always read from the module root, so a fixture
// tree is scanned against the real declaration.
//
// Exit codes: 0 = every block parsed, 1 = a block failed to parse or the gate
// could not run. The finding count is printed, never encoded in the exit code.

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { loadPiFrontmatter } from "./pi-frontmatter.mjs";
import { load_manifest, manifest_rows } from "../../src/build/container-interface.mjs";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const REPO_ROOT = process.env.FRONTMATTER_SCAN_ROOT
  ? resolve(process.env.FRONTMATTER_SCAN_ROOT)
  : MODULE_ROOT;

// The declaration is read from the module root, not the scan root, so a fixture
// tree is scanned against the real declaration. FRONTMATTER_MANIFEST_ROOT is the
// seam that points the read elsewhere, so the fail-closed branch is reachable.
const MANIFEST_ROOT = process.env.FRONTMATTER_MANIFEST_ROOT
  ? resolve(process.env.FRONTMATTER_MANIFEST_ROOT)
  : MODULE_ROOT;

// The instruction roots are declared once, in src/build/container-interface.json:
// a cell's `sources` are the repository folders that become prompt and skill
// roots at runtime. Deriving them here means a new instruction surface enters
// this gate with the declaration, not with a second edit that an author can
// forget. A manifest that is missing or does not parse is a finding, never an
// empty root set: a gate over no files would report clean.
const manifest = load_manifest(MANIFEST_ROOT);
if (manifest === undefined) {
  console.error(
    "Frontmatter gate: " + join(MANIFEST_ROOT, "src/build/container-interface.json") +
      " is missing or does not parse; cannot derive the instruction roots.",
  );
  process.exit(1);
}

/**
 * Roots holding a prompt or a skill. `.agents/skills` is the project's own
 * convention tree, which ships nowhere and so is declared by no cell. Its
 * sibling `.agents/prompts` is a declared cell, and it stays listed here so a
 * project whose manifest predates that cell is still scanned.
 */
const ROOTS = [
  // A draft is not a live prompt or skill, so .agents/drafts and
  // src/reasoning/agent/drafts are deliberately absent from the declaration.
  ...manifest_rows(manifest, "cells").flatMap((cell) => cell.sources ?? []),
  ".agents/skills",
  ".agents/prompts",
];

/** Root holding the policy files, and the name suffix that marks one. */
const POLICY_ROOT = "docs";
const POLICY_SUFFIX = "_policy.md";

/** Every markdown file under a root, or nothing when the root is absent. */
function collect(root, suffix = ".md") {
  const out = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) {
        walk(full);
      } else if (entry.endsWith(suffix)) {
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

// Pi's own parser, so the gate accepts exactly the files pi accepts.
const { parseFrontmatter } = await loadPiFrontmatter("Frontmatter gate");
// A cell source may contain another cell source -- the pi config home holds its
// own prompt and skill folders -- so the collected list is de-duplicated by
// path. Without the Set a file under a nested root is reported twice.
const files = [
  ...new Set([
    ...ROOTS.flatMap((root) => collect(join(REPO_ROOT, root))),
    ...collect(join(REPO_ROOT, POLICY_ROOT), POLICY_SUFFIX),
  ]),
];
const findings = [];

for (const file of files) {
  const text0 = readFileSync(file, "utf8");
  const block = frontmatterOf(text0);
  if (block === null) continue;
  try {
    parseFrontmatter(text0);
  } catch (error) {
    const rel = file.slice(REPO_ROOT.length + 1);
    const at = error.linePos ? error.linePos[0] : null;
    // The parser sees the block body, so its line numbers start at the second
    // line of the file; the offset is where the body began.
    const text = at ? text0.split("\n")[block.offset + at.line - 1] : undefined;
    findings.push({ rel, line: at ? block.offset + at.line : 0, text, first: String(error.message).split("\n")[0] });
  }
}

for (const f of findings) {
  if (f.kind === "reader" || f.kind === "flag") continue;
  console.log(f.rel + ":" + f.line + " frontmatter does not parse");
  console.log("  " + f.first);
  if (f.text) console.log("  offending line: " + f.text.trim().slice(0, 100));
}

// A skill hides itself from the model with `disable-model-invocation: true`.
// Pi's loader tests the value with `=== true`, so a string such as `yes` leaves
// the skill visible, the opposite of what the author wrote. The field is a
// boolean or it is a finding.
const NON_BOOLEAN_FLAG = "disable-model-invocation";
for (const file of files) {
  const text0 = readFileSync(file, "utf8");
  const block = frontmatterOf(text0);
  if (block === null) continue;
  let fm;
  try {
    fm = parseFrontmatter(text0).frontmatter;
  } catch {
    continue; // the parse finding above already covers this file
  }
  if (!fm || !(NON_BOOLEAN_FLAG in fm)) continue;
  const value = fm[NON_BOOLEAN_FLAG];
  if (typeof value !== "boolean") {
    findings.push({
      rel: file.slice(REPO_ROOT.length + 1),
      kind: "flag",
      first: NON_BOOLEAN_FLAG + " is " + JSON.stringify(value) + "; use true or false",
    });
  }
}

// A document that ships declares the reader it serves, because the ship set is a
// decision rather than a property of the folder a document happens to sit in.
// The shipping folders are the manifest's `docs/` rows. A document serving only
// the maintainer does not ship, so such a declaration inside a shipping folder
// is a finding: the folder set and the declaration disagree.
const READERS = new Set(["agent", "operator", "maintainer"]);
const shippedRoots =
  process.env.FRONTMATTER_SHIPPED_ROOTS !== undefined
    ? process.env.FRONTMATTER_SHIPPED_ROOTS.split(",")
        .map((s) => s.trim())
        .filter(Boolean)
    : [
        ...new Set(
          manifest_rows(manifest, "image")
            .map((row) => row.source)
            .filter((source) => typeof source === "string" && source.startsWith("docs/")),
        ),
      ];
const shippedFiles = shippedRoots.flatMap((root) => collect(join(REPO_ROOT, root)));
for (const file of shippedFiles) {
  const rel = file.slice(REPO_ROOT.length + 1);
  const text = readFileSync(file, "utf8");
  const block = frontmatterOf(text);
  if (block === null) {
    findings.push({ rel, kind: "reader", first: "no frontmatter; a shipping document declares its reader" });
    continue;
  }
  let declared;
  try {
    declared = parseFrontmatter(text).frontmatter;
  } catch {
    continue; // the parse finding above already covers this file
  }
  const value = declared ? declared.reader : undefined;
  const list = Array.isArray(value) ? value : typeof value === "string" ? [value] : [];
  if (!list.length) {
    findings.push({ rel, kind: "reader", first: "no reader declared; name agent, operator or maintainer" });
    continue;
  }
  const unknown = list.filter((reader) => !READERS.has(reader));
  if (unknown.length) {
    findings.push({ rel, kind: "reader", first: "unknown reader " + unknown.join(", ") + "; use agent, operator or maintainer" });
  }
  if (list.every((reader) => reader === "maintainer")) {
    findings.push({
      rel,
      kind: "reader",
      first: "declares the maintainer only, so it does not ship; move it out of the shipping folder or name an in-container reader",
    });
  }
}

for (const f of findings) {
  if (f.kind === "reader" || f.kind === "flag") {
    console.log(f.rel + " frontmatter: " + f.first);
  }
}

if (findings.length === 0) {
  console.log(
    "Frontmatter gate: clean across " + files.length + " prompt, skill and policy files, and " +
      shippedFiles.length + " shipping document(s) declare a reader",
  );
} else {
  console.error(
    "Blocking gate: " + findings.length + " frontmatter finding(s) across " + files.length +
      " prompt, skill and policy files and " + shippedFiles.length + " shipping document(s). " +
      "Quote any value holding a colon, a leading dash, or a trailing colon, and declare a reader on every shipping document.",
  );
}
process.exit(findings.length === 0 ? 0 : 1);
