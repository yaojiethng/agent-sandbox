# Handover 20260902-02 — docs add test-quality-campaign prompt template

**Milestone:** none (workflow artifact)
**Type:** docs
**Status:** Closed
**Date:** 2026-09-02

## Objective

Write a reusable campaign prompt at `workflow/coding-agent/test-quality-campaign.md` that combines the two source prompts (test-writing self-reflection; long-running test-quality campaign), grounds them in the testing policy edits landed in `20260902-01`, and targets the operator's stated goal: autonomous, token-aggressive audit with on-the-spot test fixes, producing a final report + one delivery commit, then submit for review.

## Completed

| Task | Evidence |
|---|---|
| Scope confirmed (audit + autonomous fixes; report + commit, then submit) | chat |
| First draft written | `workflow/coding-agent/test-quality-campaign.md` |
| Tone adjusted to STE100 (ASCII, ` - ` headings, no em-dashes) | `workflow/coding-agent/test-quality-campaign.md` |
| Run-wrapper template written | `workflow/coding-agent/test-quality-campaign-run.md` |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Campaign both diagnoses and rewrites tests on the spot | operator: "let's go with 2" |
| D2 | Deliverable is a final report + a single delivery commit, then stop and submit both for review | operator: "create a report + commit, then submit for review" |
| D3 | Reflection (prompt 1) becomes Phase 1, a judgment gate the execution grind is forbidden to skip | same discipline as Anti-Pattern 6: judge meaning before asserting strings |
| D4 | "Coverage" reframed as invariant/branch coverage, not a numeric line-coverage percentage | repo harness has no line-coverage tool |
| D5 | Policy files are the authority; this prompt references, does not restate, them | `documentation_policy.md` |
| D6 | Campaign state lives in the output mount (`$OUTPUT_DIR/test-campaign-<ts>-$$`), not the repo; the commit carries only the test changes | original prompt 2 hygiene: "write everything to the output mount"; sample run `test-campaign-20260821-165041-258` confirms the pattern |
| D7 | The campaign prompt links to policy docs and does not restate them | `documentation_policy.md`: "Duplicate content is a defect" + "A rule that exists only in a skill file or prompt template is not authoritative" |
| D8 | Subagent presents uncommitted changes + report as a proposal; the main agent + operator work it through the normal iteration and commit at close. No branches, no fixed accept/reject procedure | operator: "part of the work is already done as a proposal that we work through" + "i dont want to impose an exact procedure here other than our regular iteration workflow" |

## Findings

None.

## Deferred

- None.
