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
//   - a link in a file that ships into the agent image resolves in the image's
//     path space, not the repository's. The prompt or the bundled document that
//     ships is read at its image path, so its link must reach a path that exists
//     there: a target that exists only in the repository is a finding. The pairs
//     come from `src/build/container-interface.mjs`, which reads the interface
//     manifest; an image path is checked by mapping it back to the repository
//     source that populates it.
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
import { fileURLToPath } from "node:url";

import { load_manifest, pairs } from "../../src/build/container-interface.mjs";

// Repository directory to image destination, trailing slash on both. The
// interface is declared once in `src/build/container-interface.json` and read
// here through `container-interface.mjs`, so a new `COPY` line reaches this
// rule with no edit to it: `scripts/check_container_layout.sh` holds the
// manifest equal to the dockerfiles. The provider config is declared twice on
// purpose -- the image copies it to `/opt/workflow/agent/config/`, and the
// entrypoint seeds `$AGENT_HOME/` from that template -- so a file beneath it
// has two valid destinations.
const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..");
const manifest = load_manifest(repoRoot) || {};
const imageMap = pairs(repoRoot).map((row) => [row.source, row.destination]);

if (imageMap.length === 0) {
  throw new Error(
    "record-links: src/build/container-interface.json declares no pair; a shipped file's links cannot be resolved",
  );
}

// A file that ships is read by an agent in a container, so its links resolve in
// the image's path space. That covers every instruction surface and every
// bundled document alike: a relative link between two bundled documents
// survives the move only because their two destinations keep the repository's
// shape. A file that does not ship is read in the repository and keeps the
// repository-space check, or its links to its own neighbours would demand that
// every record ship as well.
//
// The shipped set is the manifest's `image` rows, so a new `COPY` line reaches
// this rule with no edit to it.
// image_path_of REPO_RELATIVE -- the path the file has in the image, or empty
// when the file does not ship.
function image_path_of(repoPath) {
  for (const [source, destination] of imageMap) {
    if (repoPath.startsWith(source)) {
      return destination + repoPath.slice(source.length);
    }
  }
  return "";
}

// sources_of IMAGE_PATH -- every repository source that populates an image path.
// A directory can be populated from more than one source (the two prompt roots
// share a destination), so a path is valid when any source holds it.
function sources_of(imagePath) {
  return imageMap
    .filter(([, destination]) => imagePath.startsWith(destination))
    .map(([source, destination]) => source + imagePath.slice(destination.length));
}

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
      // A file that ships succeeds at its image path, so its links are resolved
      // there: absolute targets are image paths, relative targets are resolved
      // against the file's image directory, and both are checked by mapping the
      // image path back to the repository source that populates it. Every other
      // file keeps the repository-space check.
      const imageFile = image_path_of(name);
      const imageDir = imageFile === "" ? "" : dirname(imageFile);
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

          if (imageFile !== "" || pathPart.startsWith("/opt/")) {
            const imageTarget =
              pathPart === ""
                ? imageFile
                : pathPart.startsWith("/")
                  ? pathPart
                  : resolve(imageDir, pathPart);
            const source = sources_of(imageTarget).find((candidate) => existsSync(candidate));
            if (source === undefined) {
              onError({
                lineNumber: index + 1,
                detail: "link target does not exist in the image: " + target,
              });
              continue;
            }
            if (fragment !== "" && !anchors_of(source).includes(fragment)) {
              onError({
                lineNumber: index + 1,
                detail: "link fragment names no heading: " + target,
              });
            }
            continue;
          }

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