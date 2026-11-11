---
date: 2026-11-09
milestone: M3.3.5
type: Implementation
status: Closed
---

# Handover - The `/gm` prompt states the current-milestone rule

## Objective

Land the S2 rule the operator accepted after the A/B: a cross-milestone recommendation in the check-in report must state a basis, or the recommendation is not aligned.

## Scope

The M3.3.5 row **The `/gm` prompt states the current-milestone rule, and a new ablation measures it**. The A/B (`20261109-09`) measured the rule in both cell orders: the rule led on alignment (6/8 and 7/8 against the control's 3/8 and 5/8 under the case's basis-inclusive rule; 4/8 and 5/8 against 3/8 and 2/8 under the narrow reading), and its token and wall-clock cost was lower in both orders. The operator accepted the edit. This iteration lands the tested text in `workflow/coding-agent/prompts/gm.md` and closes the row.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The rule is inserted in `## Close`, before the intent and no-intent branches. | `grep -c 'Recommend within the current milestone'` returns 1; the diff is one hunk of two lines | Agent [x] |
| The landed text is the text the A/B tested. | the rule line matches `fixture/configurations/current-milestone-rule/workflow/coding-agent/prompts/gm.md`; the other file differences are the fixture's frontmatter and the already-landed prefactor-tail deletion | Agent [x] |
| The harness suite and the lint gate stay green. | `tests/test_eval_harness.sh`: 40 passed; `scripts/lint.sh`: clean across 27 gates | Agent [x] |
| The S2 row is marked `[x]` with the landing recorded. | `devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The landed text is the tested overlay's rule line, verbatim | the A/B's evidence is about that text; an untested rewording would detach the edit from its measurement | this record; `workflow/coding-agent/prompts/gm.md` |
| The rule is inserted before the intent and no-intent branches | both closing forms recommend one task, so both need the basis rule | this record |
| No fixture or case change | the A/B overlay is the fixture's record; the repository prompt is the artifact the rule lands in | this record |

## Decisions pending

None.

## Findings

- The landed prompt composes the S2 rule with the `20261109-05` prefactor-tail deletion. The A/B measured the rule on the fixture baseline, which still carries that tail; the landed file is the two accepted edits together. The rule is independent of the tail, but the composition is the prompt a later run reads.
- The A/B's alignment lead depends on the case's basis-inclusive reading: a cross-milestone pick that states a recent/urgent basis is aligned. The narrow reading (only a recommendation under the current milestone) is 4/8 and 5/8 against 3/8 and 2/8; it still leads, but the first order's margin is one run.

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/prompts/gm.md` | Inserts the current-milestone basis rule in `## Close`. |
| `devlog/roadmap.md` | Marks the S2 row `[x]` and records the landing. |
| `devlog/handovers/M3.3.5/20261109-10-impl-current_milestone_rule.md` | This record. |
