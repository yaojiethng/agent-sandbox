// markdownlint custom rule: one paragraph per physical line.
// Enforces docs/operations/documentation_policy.md `### Line wrapping`:
// prose is one paragraph per physical line, however long the line;
// hard breaks separate blocks only (paragraphs, headings, list items).
//
// Detection: markdown-it emits one `inline` token per text block
// (paragraph, list-item paragraph, blockquote paragraph). An inline
// token whose map spans more than one physical line is prose broken
// across lines -- a hard wrap. Fenced code (fence tokens), HTML
// blocks (html_block tokens), and table rows (inline cells span one
// line each) are exempt by construction, which matches the policy's
// fenced-code and table-row exemptions.
//
// Progressive scope, in two lists, both declared in .markdownlint-cli2.mjs.
// `recordTrees` is the shared exclusion list, the same one record-links reads
// under the same key: whole trees of closed records, whose prose is read as
// history rather than maintained. `legacyFiles` names individual live files not
// yet reflowed; those are exempt from the tree-wide run, and
// scripts/check_doc_wrap_legacy.sh fails the commit that next touches one, so a
// file's grandfathering lasts exactly until somebody edits it. One setting, one
// home: neither list is repeated here, and neither uses a per-file disable
// comment (documentation_policy.md `### Markdown lint gate`).

import { relative, resolve } from "node:path";

export default [
  {
    names: ["doc-wrap"],
    description: "Prose paragraphs must stay on one physical line",
    tags: ["prose", "format"],
    function: function rule(params, onError) {
      const opts = params.config && typeof params.config === "object"
        ? params.config
        : {};
      const legacy = Array.isArray(opts.legacyFiles) ? opts.legacyFiles : [];
      // A legacy file is exempt from the tree-wide run, and not exempt at all
      // once the commit touches it: DOC_WRAP_ENFORCE carries the changed files,
      // which scripts/check_doc_wrap_legacy.sh derives from the working tree.
      const enforced = (process.env.DOC_WRAP_ENFORCE ?? "")
        .split(",")
        .filter((entry) => entry.length > 0);
      const trees = Array.isArray(opts.recordTrees) ? opts.recordTrees : [];
      // markdownlint hands the rule the absolute path it resolved the glob to, so a
      // tree test compares against the path relative to the working directory.
      const fn = relative(process.cwd(), resolve(String(params.name || ""))).replace(/\\/g, "/");
      if (trees.some((root) => fn.startsWith(root))) {
        return;
      }
      if (legacy.some((pattern) => fn.endsWith(pattern)) && !enforced.includes(fn)) {
        return;
      }
      for (const token of params.tokens) {
        if (token.type !== "inline" || !token.map) {
          continue;
        }
        const lines = token.map[1] - token.map[0];
        if (lines <= 1) {
          continue;
        }
        onError({
          lineNumber: token.map[0] + 1,
          detail: "paragraph spans " + lines +
            " physical lines; keep one paragraph per physical line" +
            " (documentation_policy.md ### Line wrapping)",
        });
      }
    },
  },
];