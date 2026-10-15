---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - the frontmatter gate derives its roots

## Objective

Make the frontmatter gate cover every skill and prompt root by deriving them from the container interface declaration, and repair the convention-skill whose malformed frontmatter the hand-listed scope had missed.

## Scope

The `devlog/roadmap.md` row under M3.3.1, `The frontmatter gate derives its roots from the declaration`. This iteration owns the gate `scripts/lint/frontmatter.mjs`, its test `tests/test_lint_umbrella.sh`, and the `.agents/skills/task-list/SKILL.md` repair the widened scan made findable.

One adjacent item is ruled out of scope. Three `.agents/audits/*.skill.md` files carry the same unquoted colon-space defect, but they are audit reference material under a folder that is not an instruction root, not `SKILL.md` files a provider loads, so the derivation does not scan them.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate derives the prompt and skill roots from the declaration | `grep -n 'manifest_rows(manifest, "cells")' scripts/lint/frontmatter.mjs` returns the derivation | Agent [x] |
| A declared cell source that is not hand-listed is scanned | `test_frontmatter_gate_covers_every_declared_instruction_root` reads the manifest, plants a malformed block per source, and asserts each is found | Agent [x] |
| A missing or unparseable declaration fails the gate | `FRONTMATTER_MANIFEST_ROOT=<empty dir> bash scripts/check_frontmatter.sh` exits 1 and names the file | Agent [x] |
| A block reached through a nested source is reported once | the gate reports 74 files; `new Set(...)` in `scripts/lint/frontmatter.mjs` holds the de-duplication | Agent [x] |
| The convention-skill whose frontmatter was malformed parses | `bash scripts/check_frontmatter.sh` reports clean, having scanned `.agents/skills/task-list/SKILL.md` | Agent [x] |
| The gate suite is clean | `bash scripts/lint.sh` reports clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The instruction roots derive from the `cells` rows, not a second list | the container interface already declares each instruction surface's source folder; a hand-listed copy drifted and missed `.agents/skills`, the tree pi loads, so the declaration is the one source | this record |
| `.agents/skills` and `.agents/prompts` stay appended to the derived set | they are the project's own convention tree, which ships nowhere and so no cell declares, and the workflow still checks them | this record |
| The declaration read is a seam separate from the scan root | a fixture tree is scanned against the real declaration, and `FRONTMATTER_MANIFEST_ROOT` reaches the fail-closed branch | this record |
| A missing declaration is a finding, not an empty root set | a gate over no files reports clean; the derivation cannot run without the declaration | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The gate hand-listed its scan roots and missed `.agents/skills`, the project convention-skill tree pi loads, so a malformed `description` cost that skill silently while the gate reported clean. The defect is the enumeration, not the one file. Triaged to: `devlog/roadmap.md` row `The frontmatter gate derives its roots from the declaration` and `devlog/AGENT_FEEDBACK.md` entry `[A] 2026-10-15`. | obstacle | current iteration |
| The broken block was an unquoted value holding a colon-space (`changelog: their shape`), which YAML reads as a nested mapping. The authoring rule already states it; the widened gate now reaches the file that broke it. Triaged to: the same roadmap row. | technical | current iteration |
| Three `.agents/audits/*.skill.md` files carry the same unquoted colon-space defect. They are reference material under a non-instruction root, not live skills. Triaged to: out of scope, one sentence in Scope. | technical | out of scope |

## Completed

| File | Change |
|---|---|
| [`scripts/lint/frontmatter.mjs`](../../scripts/lint/frontmatter.mjs) | derives the instruction roots from the interface `cells`, appends the project convention roots, de-duplicates a file reached through a nested source, and fails closed on a missing declaration |
| [`tests/test_lint_umbrella.sh`](../../tests/test_lint_umbrella.sh) | a case per declared root driven by the manifest, plus the fail-closed case |
| [`.agents/skills/task-list/SKILL.md`](../../.agents/skills/task-list/SKILL.md) | the `description` value is quoted, so the block parses |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | new M3.3.1 row, marked `[x]` |
| [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) | new entry for a gate that hand-lists its subject set |
| [`devlog/handovers/20261015-04-workflow-frontmatter_gate_derived_roots.md`](20261015-04-workflow-frontmatter_gate_derived_roots.md) | this record |
