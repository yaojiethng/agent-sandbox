---
date: 2026-10-20
milestone: M3.3.4 - The prose standards as principles
type: Documentation
status: Closed
---

# Handover - The prose cut phase

## Objective

Cut the tracked Markdown corpus outside `devlog/` by applying the filed communication principles, and measure the result rather than assert it.

## Scope

The five units the operator directed in the same turn: a measurement harness, dead-document verdicts, prose compression, restatement collapse, and stale-text removal. The phase ran on operator direction with no roadmap row; the row was written at close and rides this commit.

Three blocks were ruled out of scope with a reason each. `docs/adr/` (33 files, 284,256 characters) stays frozen, because `documentation_policy.md` `### Post-close document corrections` forbids changing a closed record without operator direction, and rewriting an ADR for length is not a correction. `.agents/drafts/` (20 files, 2,606 lines) holds unreviewed working documents whose arguments belong to their authors. The enumerated rule documents, chiefly `docs/development/bash-coding-conventions.md`, carry numbered rules that other files cite by number, so merging a bullet breaks a citation.

The measurement harness was deleted at close on the operator's direction, so the phase adds no surface of its own.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The corpus is measured at the parent commit and at close by one rerunnable command | `scripts/measure_prose.mjs --at HEAD --compare`, before the harness deletion | accepted: 20,515 to 19,872 lines, 1,585,233 to 1,570,026 characters |
| A cut removes content that carries nothing, not evidence | per-file rate table, with the identifier set diffed before and after on the two rewritten files whose facts were dense | accepted: `execution_model.md` lost 8 backtick identifiers, 2 of them genuine facts, restored before the file was signed off |
| Repetition is found at the paraphrase level, not only verbatim | `measure_prose.mjs --restatements`, 4-word shingles, 0.3 Jaccard floor | accepted: 9,931 verbatim characters (0.6%) against 85,898 restated characters on the smaller sides |
| The link changes resolve where the citing file runs | `bash scripts/lint.sh`, which fails a link from a shipped file to a non-shipped one | accepted: 2 link edits failed the gate and were reverted to code spans |
| Removing the separators leaves every frontmatter block intact | byte comparison of all 123 frontmatter blocks against the parent commit | accepted: 0 structural changes, 0 content differences |
| The gates stay green at close | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | accepted: 10 gates clean in 7s, 1250 tests passed in 111s |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Exclude `devlog/` from the measured surface | It is the record dump, not the maintenance surface, and its growth is a separate question | this handover |
| Do not rewrite ADRs | A closed record's content does not change without operator direction | `documentation_policy.md` `### Post-close document corrections` |
| Delete the harness at close | It was scaffolding for one phase, and keeping it would add 360 lines to a phase that removes them | this handover |
| Remove the 298 bare `---` separators | They carry no content, and the removal takes 572 lines with their blank neighbours | this handover |
| Carry the norm ledger by matching rewritten lines to their old classification | The ledger keys a row by the line's SHA-1, so a rewrite orphans the row | `scripts/lint/norm-ownership.tsv`, `scripts/lint/norm-judgements.tsv` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does `docs/adr/` get a compression pass | 284,256 characters, 18% of the corpus | direct a pass, or leave the records frozen |
| Do the drafts get compressed | 2,606 lines in `.agents/drafts/` | compress, or leave them to their authors |
| Do the numbered rule documents get restructured | the largest line counts in `docs/development/` | renumber the citations and merge, or leave the numbering |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Verbatim repetition is 0.6% of the corpus, and paraphrase-level restatement is about 5%. The text-matching dedup pass was dropped after the census | measurement | routed the phase's repetition crop onto the norm ledger and the shingle detector | this handover |
| A test helper that changed directory inside a command substitution kept the shell in the real repository, so its `git add -A` committed this working tree into four `base` commits | defect | the branch was reset to the parent commit, the fixture files were deleted, and a guard now refuses a write from inside the real repository | `devlog/AGENT_FEEDBACK.md`, entry `2026-10-20` |
| The instrument counted a bare `---` as a prose paragraph, so `proseLines` fell by 308 when the separators went | instrument | the drop is a correction of the measure, not prose that was cut | this handover |
| Compression averages 4.2% across the nine files over 15,000 characters, and 11.9% on the file carrying the most narration | measurement | sets the realistic rate for any later pass | this handover |

## Completed

| File | Change |
|---|---|
| `docs/reference/execution_model.md` | history, forecasts and restated facts removed; 277 to 264 lines, -11.9% characters |
| `docs/policies/documentation_policy.md` | the linking rule stated four times collapsed to one home, terminology merged, 12 ledger rows merged or dropped; -8.6% characters |
| `docs/reference/sandbox_lifecycle.md` | the `make resume LIST=1` column contract replaced by a pointer at `tool_interface.md`; -7.5% characters |
| `docs/reference/tool_interface.md` | resume, dry-run and build notes tightened; -4.3% characters |
| `docs/reference/sandbox_host_interface.md` | `## Model Gaps` removed as history, duplicated `make confirm` detail replaced by a pointer; -3.4% characters |
| `workflow/coding-agent/prompts/wrapup.md` | routing sentence and the root-cause rule tightened; -3.4% characters |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` | the `store 469` incident narrative and a forecast removed; -0.7% characters |
| `docs/development/prompt-authoring-conventions.md` | YAML frontmatter rules and the skill-name rule tightened; ledger reclassified |
| `docs/reference/agent_workflow.md` | auto-discovery rationale and the feedback-record status tightened |
| `AGENTS.md` | the dispatch failure rule now points at the provider layer's home instead of restating it |
| `docs/policies/git_policy.md` | one forecast removed from the summary rule and the parked-status line tightened |
| `docs/policies/iteration_policy.md` | the duplicate attribution sentence removed |
| `docs/development/contributors.md` | the stale `task-queue` milestone line replaced with a roadmap pointer |
| `docs/reference/project_onboarding_guide.md` | future tense corrected to present |
| `workflow/knowledge-vault/onboarding.md` | the M1.5 migration note removed, the migration having closed |
| `workflow/knowledge-vault/README.md` | the M2.1 hot-task block removed, two milestones stale |
| 19 prompts and skills under `workflow/coding-agent/` | the `## Project conventions` list compressed from one bullet per convention to one comma list, with the duplicated instruction paragraph cut to two sentences |
| 3 skills under `workflow/coding-agent/skills/` | the `initialize` corpus contract and two scope statements replaced by pointers |
| 44 files across `docs/`, `workflow/`, `src/`, `.agents/` | 298 bare `---` separators removed with their blank neighbours, 572 lines |
| `scripts/lint/norm-ownership.tsv`, `scripts/lint/norm-judgements.tsv` | regenerated for the two rewritten files, carried by similarity match, clean at 136 rows |
