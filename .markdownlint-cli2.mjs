// markdownlint-cli2 configuration for the agent-sandbox repository.
// Enables the subset of markdownlint rules that align with
// docs/operations/documentation_policy.md, plus two custom rules:
// doc-ascii (plain-ASCII prose) and doc-wrap (one paragraph per
// physical line) and record-links (link targets and heading fragments
// resolve). Both exempt the record trees declared below, under one key.
//
// Deliberately DISABLED (they contradict written policy):
//   MD013 line-length -- documentation_policy.md `### Line wrapping`
//       forbids breaking prose at a column limit
//   MD060 table-column-style -- the repo writes compact tables; MD060
//       pads cells to a uniform width and makes tables unreadable
//
// Suppression policy mirrors scripts/check_shell.sh: targeted context
// only, never a blanket disable in a source file.

// The record trees: closed records whose pointers and prose are read as
// history rather than as text to maintain. Declared once here and referenced by
// every rule that exempts them, so the list has one home and no rule grows its
// own copy. A tree leaves the list when its records are migrated.
//   devlog/handovers/    -- closed handovers, written before the current paths
//   devlog/discussions/  -- closed discussion records, pre-M1.5 restructure
//   docs/adr/archive/    -- superseded ADRs, kept for the decision history
export const recordTrees = ["devlog/handovers/", "devlog/discussions/", "docs/adr/archive/"];

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
    // record-links: enabled here, and enabled with the shared recordTrees list.
    // It was registered in customRules and enabled nowhere, and default:false
    // suppresses a rule that is not named, so it never ran: the gate reported
    // 800 files clean over an empty rule set. The list is passed because the
    // rule reads its carve-out from params.config, and a bare `true` would
    // exempt nothing and report every closed record.
    "record-links": { recordTrees },
    // doc-wrap: one paragraph per physical line, registered as of the
    // maintenance pass that found it enabled but never registered. The record
    // trees are exempt; legacyFiles names live files not yet reflowed, exempt
    // from the tree-wide run and enforced by scripts/check_doc_wrap_legacy.sh
    // on the commit that next touches them, so an entry ends when its file is
    // edited rather than never.
    "doc-wrap": {
      recordTrees,
      legacyFiles: [
        "docs/adr/agent_sandbox_two_container_separation.md",
        "docs/adr/command_flag_parsing.md",
        "docs/adr/container_host_correspondence_mechanism.md",
        "docs/adr/diff_packaging.md",
        "docs/adr/drift_state_coherence.md",
        "docs/adr/env_resolution.md",
        "docs/adr/harness_versioning.md",
        "docs/adr/interface_contract_compatibility.md",
        "docs/adr/policy_declarative_framing.md",
        "docs/adr/session_identifier.md",
        "docs/adr/single_source_model_recommendations.md",
        "docs/adr/task_queue_primitive.md",
        "docs/adr/task_type_taxonomy.md",
        "docs/architecture/execution_model.md",
        "docs/architecture/sandbox_lifecycle.md",
        "docs/architecture/security.md",
        "docs/architecture/tool_interface.md",
        "docs/concepts/context_resolution.md",
        "docs/concepts/sandbox_host_interface.md",
        "docs/concepts/sandbox_identity.md",
        "docs/concepts/terminology.md",
        "docs/development/interface-conventions.md",
        "docs/development/testing-conventions.md",
        "src/reasoning/agent/skills/caveman/SKILL.md",
        "src/reasoning/agent/skills/domain-model/ADR-FORMAT.md",
        "src/reasoning/agent/skills/improve-codebase-architecture/LANGUAGE.md",
        "src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md",
        "src/reasoning/providers/hermes/quickstart.md",
        "src/reasoning/providers/opencode/quickstart.md",
        "src/reasoning/providers/pi/onboard-readme.md",
        "tests/integration/README.md",
        "workflow/coding-agent/audits/bash-audit.skill.md",
        "workflow/coding-agent/audits/documentation-audit-comparison.md",
        "workflow/coding-agent/drafts/read-through-run.md",
        "workflow/coding-agent/drafts/sequential-work.md",
        "workflow/coding-agent/prompts/document.md",
        "workflow/coding-agent/prompts/gm.md",
        "workflow/knowledge-vault/README.md",
      ],
    },
  },
  customRules: [
    "./scripts/lint/doc-ascii.mjs",
    "./scripts/lint/doc-wrap.mjs",
    "./scripts/lint/record-links.mjs",
  ],
  globs: ["**/*.md"],
  ignores: ["**/node_modules/**"],
};