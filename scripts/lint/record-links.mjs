// markdownlint custom rule: link targets and heading fragments resolve.
// A Markdown link is a claim that a document exists and says what the citing
// line says it says. Nothing in the tree checks either claim, so a reorganisation
// that moves a file or renames a heading leaves a broken pointer behind, and the
// record layer is where those pointers decide what an agent reads next.
//
// What the rule checks, per inline link:
//   - a relative target exists. A directory counts: several documents point at a
//     tree (a provider directory, a lib directory) rather than at a file.
//   - a fragment names a heading in the target. The fragment rule is the one
//     every forge applies and the one this repository's links now follow:
//     lowercase, drop every character that is not a letter, digit, space, hyphen
//     or underscore, then one hyphen per space. So "M4.6 -- Background Work
//     (parallel-work)" yields "m46----background-work-parallel-work", and a
//     heading carrying a suffix carries that suffix in its fragment.
//
// What it skips: external targets (http, https, mailto, tel), links inside
// fenced code blocks, and whatever the config exempts.
//
// The exempt trees are configuration, not code: the rule reads `recordTrees`
// from its config entry, and exempts nothing when the key is absent. The list is
// declared once in `.markdownlint-cli2.mjs` and shared with doc-wrap under the
// same key, so one setting has one home and no rule grows its own copy.
//
// ESM form: `.markdownlint-cli2.mjs` imports this as a custom rule.

import { existsSync, readFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";

// anchor_of HEADING -- the fragment a link uses to reach a heading.
function anchor_of(heading) {
  return heading
    .toLowerCase()
    .replace(/[^a-z0-9 _-]/g, "")
    .replace(/ /g, "-");
}

// anchors_of FILE -- every fragment the file's headings yield. An unreadable
// file yields nothing, which makes every link into it a finding rather than a
// silent pass.
function anchors_of(file) {
  let text = "";
  try {
    text = readFileSync(file, "utf8");
  } catch {
    return [];
  }
  const out = [];
  for (const line of text.split("\n")) {
    if (!/^#+[ \t]/.test(line)) {
      continue;
    }
    out.push(anchor_of(line.replace(/^#+[ \t]*/, "").replace(/[ \t]*#*$/, "")));
  }
  return out;
}

export default [
  {
    names: ["record-links"],
    description: "Link targets exist and fragments name a heading",
    tags: ["links"],
    function: function rule(params, onError) {
      const recordTrees = params.config.recordTrees ?? [];
      // markdownlint-cli2 hands the rule the path its glob produced, which may be
      // relative or absolute depending on the invocation, so the carve-out test
      // compares against the path relative to the working directory.
      const name = relative(process.cwd(), resolve(params.name)).replace(/\\/g, "/");
      if (recordTrees.some((root) => name.startsWith(root))) {
        return;
      }
      const dir = dirname(params.name);
      let inFence = false;

      params.lines.forEach((line, index) => {
        if (/^[ \t]*(```|~~~)/.test(line)) {
          inFence = !inFence;
          return;
        }
        if (inFence) {
          return;
        }
        for (const match of line.matchAll(/\]\(([^)\s]+)\)/g)) {
          const target = match[1].replace(/^</, "").replace(/>$/, "");
          if (/^(https?:|mailto:|tel:|data:)/.test(target)) {
            continue;
          }
          const hashAt = target.indexOf("#");
          const pathPart = hashAt === -1 ? target : target.slice(0, hashAt);
          const fragment = hashAt === -1 ? "" : target.slice(hashAt + 1);
          const targetFile = pathPart === "" ? params.name : resolve(dir, pathPart);

          if (!existsSync(targetFile)) {
            onError({
              lineNumber: index + 1,
              detail: "link target does not exist: " + target,
            });
            continue;
          }
          if (fragment !== "" && !anchors_of(targetFile).includes(fragment)) {
            onError({
              lineNumber: index + 1,
              detail: "link fragment names no heading: " + target,
            });
          }
        }
      });
    },
  },
];