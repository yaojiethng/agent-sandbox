// markdownlint-cli2 configuration for the agent-sandbox repository.
// Enables the subset of markdownlint rules that align with
// docs/operations/documentation_policy.md, plus one custom rule
// (doc-ascii) that enforces the plain-ASCII prose rule.
//
// Deliberately DISABLED (they contradict written policy):
//   MD013 line-length -- documentation_policy.md `### Line wrapping`
//       forbids breaking prose at a column limit
//   MD060 table-column-style -- the repo writes compact tables; MD060
//       pads cells to a uniform width and makes tables unreadable
//
// Suppression policy mirrors scripts/check_shell.sh: targeted context
// only, never a blanket disable in a source file.

export default {
  config: {
    // start from an explicit empty baseline; enable rules individually
    default: false,

    // --- whitespace / structure ---
    "MD009": { br_spaces: 0 }, // trailing spaces
    "MD012": true,             // no multiple consecutive blank lines
    "MD022": { lines_above: 1, lines_below: 1 }, // blanks around headings
    "MD031": true,             // blanks around fenced code
    "MD032": true,             // blanks around lists
    "MD047": true,             // file ends with single newline

    // --- headings ---
    "MD024": { siblings_only: true }, // duplicates allowed under different parents
    "MD041": {
      // frontmatter name/description keys act as the title in prompt/skill files
      front_matter_title: "^\\s*(title|name|description)\\s*[:=]",
    }, // first line is a top-level heading

    // --- fenced code ---
    "MD040": true,             // fenced code blocks set a language
    "MD038": true,             // no spaces inside inline code

    // --- tables (coherence, not padding) ---
    "MD055": true,             // table pipe style
    "MD056": true,             // table column count
    "MD058": true,             // blanks around tables

    // custom rule, enabled by name (default:false suppresses it otherwise)
    "doc-ascii": true,
  },
  customRules: ["./scripts/lint/doc-ascii.mjs"],
  globs: ["**/*.md"],
  ignores: ["**/node_modules/**"],
};