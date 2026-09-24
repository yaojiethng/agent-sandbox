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
// Progressive scope: the rule may name legacy files in its config
// (legacyFiles). Prose in those files is not flagged while the files
// await the conversion chore; the chore removes entries as it
// reflows, and the enable step drops the option entirely. The
// exemption is config-driven, never a per-file disable comment
// (documentation_policy.md `### Markdown lint gate`).

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
      const fn = String(params.name || "").replace(/\\/g, "/");
      if (legacy.some((pattern) => fn.endsWith(pattern))) {
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