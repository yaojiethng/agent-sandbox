# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Refactor
**Status:** Closed

## Objective

Close the reconciliation's SF-9 concept-doc gaps in `documentation_taxonomy.md`: give the folder taxonomy a model home, show the check/lint stage in the record-lifecycle view, and convert the two restated obligations to links. Subsumes the SF-1 folder-purposes deferral.

## Scope

Targets the concept-doc gaps the reconciliation review (in handover `20260930-09`) named as SF-9, and recorded as deferred. It is the Docs-and-ADR consolidation group's first task.

## Carried forward

| Item | From handover |
|---|---|
| SF-9 (a): the concept doc has no folder-taxonomy section; the folder *purposes* model sits in `documentation_policy.md` `## Folder Structure` | `20260930-09` |
| SF-9 (b): the record-lifecycle view has no "gates and lint" stage, so the concept doc never shows what checks a record | `20260930-09` |
| SF-9 (c): two obligations are restated rather than linked -- "the only task list / future and TODO items land here" (roadmap row) and "The concept doc describes the model, not the implementation" | `20260930-09` |
| SF-1 half: descriptive folder *purposes* belong in the concept doc, not the policy | `20260930-09` |

## Acceptance criteria

- `documentation_taxonomy.md` gains a `## Folder taxonomy` section holding the folder model; the policy `## Folder Structure` trims its descriptive purposes and links to it.
- The record-lifecycle view shows a Check stage pointing to Tooling checks.
- The two restated obligations (roadmap "only task list"; "the concept doc describes the model") are converted to links.
- The audience-dispatch table routes the forbidden-content and tooling questions.
- Markdown lint clean.

## Hot files

| File | Why in scope |
|---|---|
| `docs/concepts/documentation_taxonomy.md` | the concept-doc gaps live here |
| `docs/operations/documentation_policy.md` | trims the folder-purpose model out of `## Folder Structure` (SF-1) and links to the concept doc |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The folder-taxonomy model lives in the concept doc; the policy keeps only the placement rule and links | resolves SF-1 / SF-9a and the policy's Rule-authority self-contradiction (descriptive folder purposes were model statements in policy) | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The concept doc did not hold the folder model (SF-9a), gap-2 = no check/lint stage (SF-9b), and restated two obligations instead of linking them (SF-9c) | scope gap | resolved this iteration - added the folder taxonomy, a Check lifecycle stage, link conversions, and dispatch routing |

## Completed

| File | Change |
|---|---|
| `docs/concepts/documentation_taxonomy.md` | added `## Folder taxonomy` (folder-to-purpose model incl. `devlog/`); added a Check stage to the Record lifecycle view; converted the roadmap "only task list" cell and the concept-describes-model sentence to links; extended the `Audience dispatch` table with the forbidden-content and tooling questions; repointed the folder-purpose pointer to the new section |
| `docs/operations/documentation_policy.md` | `## Folder Structure` trimmed to the placement rule + link to `documentation_taxonomy.md#folder-taxonomy` (descriptive purposes moved to the concept doc) |

## Deferred items

| Item | Reason | Where it goes next |
|---|---|---|
| Split `Records state, not session history` into a prohibition + settled-design guidance | deferred from `20260930-09`; the section's content is under review with the durable-record semantics | a dedicated follow-up in the consolidation group |

## What's Next

Docs-and-ADR-consolidation group: the loop-documentation structure decision and the `autonomous_agent_loop.md` concept offload.

**Conclusions:** SF-9 is closed - the concept doc now holds the folder taxonomy model (resolving the SF-1 policy self-contradiction), shows a Check stage in the lifecycle view, links instead of restating its two obligations, and dispatches the forbidden-content and tooling questions. The policy `Folder Structure` is trimmed to the placement rule. Lint clean.
