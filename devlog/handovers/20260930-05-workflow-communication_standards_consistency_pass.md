# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Apply the `## Communication Standards` section's own rules to itself, fix its internal inconsistency, and verify the AGENTS shadow does not carry the same verbosity.

## Scope

Full concision and internal-consistency pass on the `## Communication Standards` section of `documentation_policy.md`, with the operator's five `### Link sparingly` edits as the anchor. Verify the provider-layer shadow and repo-root Output Format for the same verbosity. Independent of a new roadmap row: follow-on to the closed task "Writing-conventions section extraction or subsume" (landed 2026-09-30).

## Carried forward

None.

## Acceptance criteria

1. `## Communication Standards` holds to its own rules: STE100, plain ASCII, one paragraph per physical line, no idioms or metaphors, no internal contradiction. Accepted.
2. `### Link sparingly` drops the framing, binds transient vs durable documents, and does not contradict the Character set or Link anchors subsections. Accepted.
3. The literal-reader test and instruction-not-prohibition rule are preserved intact, de-tangled from best-practice phrasing. Accepted.
4. The provider AGENTS shadow needs no verbosity rewrite. Accepted (verified: the shadow is a tight bullet list).
5. Lint gate clean. Accepted.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | the `## Communication Standards` section under the pass |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | shadow; verified, not rewritten |
| [`AGENTS.md`](../../AGENTS.md) | repo-root Output Format; verified, not rewritten |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| STE phrasing rules go above the evaluation tests | the two tests evaluate prose; the phrasing rules prevent tripping them, so they lead | `documentation_policy.md` STE subsection |
| Literal-reader and delete test are kept as pure tests; rephrase best practices move into the phrasing rules | the old paragraph tangled a test with its remedies, which duplicated the phrasing bullets | STE subsection |
| Two renderings of the allowed-form rule combine into one bullet | "state the allowed form, do not state only what to avoid" is one instruction | STE subsection |
| Transient/durable documents kept as the pair; chat-numbers clause dropped from Link sparingly | Numbering owns chat-number references; one term, one meaning | Link sparingly subsection |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The section carried the framing verbosity it forbids (raised 2026-09-30; operator) | steering | current iteration - cut across all subsections |
| The old Link sparingly contradicted itself on inline code and used a weak term ("maintained tier") | contradiction | current iteration - fixed with the transient/durable pair |
| glm-5.3-flash (high) advisor review caught two new self-contradictions in the first rewrite (inline-code absolute, dropped qualifier) and four lost rules; all applied, verdict converged to ready-to-ship | contradiction | current iteration - advisory |

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | rewrote `## Communication Standards`: phrasing rules above the delete and literal-reader tests; split the defined-noun bullet into three; combined the allowed-form bullets into one; rehomed link-next rule; replaced "maintained tier" with transient/durable documents; restored canonical-owner and box-drawing scope; purged idioms and metaphors |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | verified tight; no rewrite |
| `AGENTS.md` | verified tight; no rewrite |

## Deferred items

None.

## What's Next

Next sub-milestone: M3.2.2 - Audit and Review Workflow Cleanup.

No sub-milestone completed this iteration; no roadmap maintenance needed (follow-on to the closed writing-conventions task).

The advisor left one open terminology observation: `transient documents` / `durable documents` (links) sits beside `transient list` / `persistent record` (numbering) as near-synonym pairs. Lower-priority; reconcile if a numbering pass ever opens.
