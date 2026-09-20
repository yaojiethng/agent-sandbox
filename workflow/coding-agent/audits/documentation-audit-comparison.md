# Documentation Audit File Effectiveness -- Comparison Against the Autonomous Staleness Sweep

**Date:** 2026-09-11
**Purpose:** Input for compiling one comprehensive documentation audit prompt (the `gm.md` pattern: one canonical file per use case). This report compares two ways the same audit was done -- an autonomous grep-driven staleness sweep, and the existing documentation-audit files -- and states what each contributes. It is the M3 consolidation input for the documentation-audit use case.

## The experiment

The iteration ran a staleness sweep over `docs/architecture/` autonomously (no audit prompt loaded): grep for known stale terms (`rsync`, `docker cp`, `baseline.tar`, "fresh git init", "not yet implemented"), then verify each hit against the implementation (`scripts/prune.sh`, `scripts/start_agent.sh`, `src/capability/`, `scripts/workflows/draft.sh`) before editing.

The sweep work was then stashed, and a fresh `pi -p` subagent ran the `architecture-doc-reviewer.skill.md` prompt (staleness + consistency sections only) over the same pre-change tree. Findings from both passes were verified against the code and merged.

## Results

| Finding | Autonomous sweep found it | architecture-doc-reviewer found it | documentation-pass checklist covers it |
|---|---|---|---|
| `security.md` copy-mode `.git` claim false ("fresh git init" vs native `.git` copy) | yes (term grep) | yes (C1, with mechanism detail) | partial -- "future language" only, not factual staleness |
| `security.md` invariant names retired artefact (`staged.diff`) | no | yes (C2) | no |
| `tool_interface.md` "anonymous volume / destroyed on teardown" vs named persistent volume | no | yes (C3) | no |
| `tool_interface.md` capability contract describes the retired seed pipeline | no | yes (C4) | no |
| `tool_interface.md` duplicate `package-branch` sections, second one wrong | no | yes (C5) | yes -- duplication signs listed, but grep targets don't catch duplicate headings |
| Draft branch name pattern wrong in two documents | no | yes (C6) | no |
| `sandbox_lifecycle.md` stale library paths (`libs/`) | no | yes (C7) | no |
| Mount delivery status inconsistent between documents ("not yet implemented" vs "wired, not runnable") | yes (term grep) | yes (C8) | no |
| `security.md` invariant 2 contradicted by the provider-config mount | no | yes (C9) | no |
| `providers/<n>/` repo-path prefix wrong in four places | no | yes (I1) | no |
| `system_overview.md` links "authoritatively" to an invariant list that lacks the invariant | no | yes (I2) | yes -- "bridge/anchor" sign, closest match |
| `headless` speculative row in an architecture document | no (grep skipped it as intentional) | yes (I5, future-language rule) | yes -- "future language" sign |
| `security.md` overview names the wrong system (OpenCode) | no | yes (I6) | no |

Score: the autonomous sweep surfaced 3 of 13 findings. The audit prompt surfaced all 13, with mechanism-level corrections instead of term swaps.

## a. What the autonomous sweep lacked that the audit files supply

1. **Implementation cross-reference as a method, not a spot-check.** The sweep greps for known-stale terms; it cannot find stale claims about terms it does not know are stale (`staged.diff`, "anonymous volume", `libs/` paths). The reviewer's process -- extract every document claim, then check each against the code -- finds staleness independent of term choice.
2. **Cross-document consistency pass.** C5, C6, C8 are contradictions between documents, invisible to any per-file sweep.
3. **Internal-contradiction check.** C9 (an invariant the mount shape itself violates) requires reasoning about the document's own claims, not term matching.
4. **Terminology drift detection.** I1 (`providers/<n>/` after the repo restructure) is a whole class the term list cannot anticipate: any path or name that predates the last restructuring move.
5. **Future-language and speculative-content rules.** documentation-pass and the reviewer both flag "will/plan/reserved" rows (I5); the grep sweep has no equivalent unless the operator thinks to add it.
6. **Structured output with separated fix classes.** The reviewer separates documentation fixes from design questions and states consequences; raw sweep output does not, which pushes triage onto the operator.

## b. Effectiveness of each audit file

- **`architecture-doc-reviewer.skill.md` -- high effectiveness, not deployable as-is.** It found every finding and produced the most actionable output. But it is a Claude-format import: YAML frontmatter (`tools:`, `model: opus`), Claude tool names (Glob, WebFetch, TodoWrite), and `<example>` blocks. It cannot load as a pi skill. Its calibration sections (Simon Brown scope-honesty, Hickey complexity) are good review lenses but are scope the compiled prompt should make optional -- the staleness and consistency sections carry the whole practical load.
- **`documentation-pass.md` -- correct diagnosis, no procedure.** Its checklists name the right smell categories (future language, duplication, anchors, structural problems), and I2/I5 fall squarely in them. But it is a stub: it lists *signs*, not a *method*. An agent given only this file knows what wrong looks like but not how to search for it -- no implementation cross-reference step, no cross-document pass, no output contract. It is the correct skeleton for the compiled prompt's checklist section.
- **The two files overlap by one use case.** Both target "documentation describes something other than current reality." The compiled prompt should absorb the reviewer's method (sections 2 and 5 of its process, and its output format) and documentation-pass's diagnostic checklist, dropping the personality framing and Claude-specific machinery.

## Recommendation for the compiled prompt

One file, tentatively `documentation-audit.md` in this directory, pi-native:

1. **Authority:** `documentation_policy.md` wins on conflict; the prompt links, does not restate.
2. **Method (from the reviewer):** per-document claim extraction, then verify against implementation paths; then a cross-document consistency pass over names, paths, branch patterns, and mode-status claims; then the diagnostic checklist.
3. **Checklist (from documentation-pass):** future language, TODOs, duplication, anchor-only links, non-ASCII punctuation, hard-wrapped prose.
4. **Output contract (from the reviewer):** findings separated into critical / improvements / design questions, each with file, section, quoted claim, and correction.
5. **Scope parameter:** the invoker names the directory or document set; a milestone-completion sweep is the default trigger.

M3 drop candidates after compilation: `architecture-doc-reviewer.skill.md` (absorbed), `documentation-pass.md` (absorbed).
