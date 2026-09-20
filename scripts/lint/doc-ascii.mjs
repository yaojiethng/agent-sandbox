// markdownlint custom rule: non-ASCII prose ban.
// Enforces docs/operations/documentation_policy.md `### Character set`:
// documents use plain ASCII punctuation. Flags em-dash (U+2014),
// en-dash (U+2013), section sign (U+00A7), pilcrow (U+00B6), and any
// other non-ASCII code point.
//
// Box-drawing characters (U+2500-U+257F, the documentation_policy
// exception for ASCII-art diagrams) are excluded because markdownlint
// never emits text tokens for fenced code blocks; the tokenizer already
// leaves diagram content untouched. No explicit exception is needed.
//
// ESM form: `.markdownlint-cli2.mjs` imports this as a custom rule.

export default [
  {
    names: ["doc-ascii"],
    description: "Non-ASCII characters are banned in prose",
    tags: ["ascii"],
    function: function rule(params, onError) {
      for (const token of params.tokens) {
        if (token.type === "text" || token.type === "inline") {
          const m = token.content.match(/[^\x00-\x7F]/);
          if (m) {
            const cp = m[0].codePointAt(0);
            const hex = ("0000" + cp.toString(16).toUpperCase()).slice(-4);
            const label = m[0] === "\u2014" || m[0] === "\u2013"
              ? "dash"
              : m[0] === "\u00A7"
                ? "section sign"
                : m[0] === "\u00B6"
                  ? "pilcrow"
                  : "non-ASCII character";
            onError({
              lineNumber: token.lineNumber,
              detail: label + " U+" + hex + " is banned; write ASCII only",
            });
          }
        }
      }
    },
  },
];