---
date: 2026-10-16
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - Activate M3.3.4 and split the rule doctrine

## Objective

Activate M3.3.4 as the next milestone, take the judgement half of the rule-authority doctrine into its scope, and file M3.2.2's blurb-only work as rows so both milestones name their own subject.

## Scope

`devlog/roadmap.md` only: the frontmatter, the Milestone Summary table, the M3.3 intro, the M3.3.2 opening row and its `Retire documentation_policy` slice, the M3.3.4 section, the M3.2.2 section, and two stale facts in M3.5.

The milestone-start audit proposed a wider re-bucketing of the remaining M3.2, M3.3 and M3.5 rows. The operator took the narrower decision: start M3.3.4, which was already shaped, and let it clarify its siblings. The re-bucketing is filed as a pending decision, not an obstacle.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M3.3.4 is active | frontmatter `active-milestone` names it, and its summary row reads `In progress` | Agent [x] |
| The judgement half of the doctrine moved | the M3.3.4 row names `## Rule authority`, the two authoring bars and the pi advisor prompt; the M3.3.2 row names only the policy-map echoes | Agent [x] |
| The policy slice names both outgoing halves | `Retire documentation_policy` carries `## Rule authority` and `## Communication Standards` as M3.3.4's | Agent [x] |
| The dependency inverts and is stated once | M3.3.4 reads `Depends on: nothing`; the M3.3 intro states the activation order | Agent [x] |
| M3.2.2 files its own work | six new rows carry the consolidation, the three framing fixes, the mutation step, the assertion-audit retirement, the standing passes and the consistency pass | Agent [x] |
| M3.2.2 names its dependency | `Depends on: M3.3.4` | Agent [x] |
| No row states a fact the tree falsifies | the two policy paths in M3.5's parallel-milestone row and the summary-table list in the M3.5 premise no longer name retired files or completed rows | Agent [x] |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.3.4 starts, not M3.2.2 | it is already shaped, so it needs no supersession and no retitle; and the principle corpus is the bar the payload consolidation applies, so the consolidation is cheap only after it | the M3.2.2 `Depends on` line |
| The split criterion is the milestone's first intellectual job | judgement becomes a principle, structure stays a gated convention. One criterion resolves both source documents and settles the doctrine question too | the M3.3.4 scope paragraph |
| The authority doctrine splits by carrier, not by row | its judgement half blocks a principle from being its own home; its mechanics half is policy-map bookkeeping that retires with the form. One row reaching both bins could never meet its own end condition | the M3.3.4 and M3.3.2 rows |
| `## Rule authority` moves to M3.3.4 | it is the doctrine's canonic home, and leaving it behind ships a corpus that contradicts the project's own rule | the M3.3.4 doctrine row |
| The exemplar is proven before it is copied | one principle has shipped and nothing records that it changes a draft; 20 copies would multiply an unverified template | the M3.3.4 `Settle the split criterion` row |
| M3.2.2's blurb becomes rows | a milestone whose core work exists only as prose reads `In progress` while holding no work | the M3.2.2 section |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Whether the remaining M3.2, M3.3 and M3.5 rows are re-bucketed along functional buckets | the record's shape only; no work is blocked | adopt the six-bucket shape; keep the present milestones and re-file individual rows; leave it until each milestone activates |

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| Two of the doctrine row's four carrier paths were stale: `agent_workflow.md` moved to `docs/reference/`, and `doc-advisor-policy.md` moved to the pi prompt root | record defect | a slice worked from the row's text would have edited two files that do not exist there | corrected in the same row, and the row now names sections rather than line numbers |
| M3.2 has no section and no summary row, so M3.2.1, M3.2.2 and M3.2.3 hang under a parent that does not exist | record defect | the nesting is unreadable and M3.2 can carry no Not-in-scope section | raised at the milestone audit; not fixed, because re-parenting is a milestone-shape decision |
| M3.3.2 read `Not started` while its section carried two completed slices, and M3.3.4 read `Not started` while it carried one | record defect | the summary table contradicts the sections it names | corrected to `In progress` for both |
| The M3.5 premise listed five rows as `In progress`, one of which reads `Complete` | record defect | a reader checking the claim finds it false | the list is replaced by the claim it actually supports: several rows read `In progress` |
| Activating M3.3.4 while M3.6 keeps open rows adds one more instance of the scalar-versus-table concurrency the M3.5 premise names | known cost | the record cannot express the state it is in | recorded here; M3.5's parallel-milestone row is the fix |
| The two source documents carry structure rows that cannot become principles, and no row previously named them | scope gap | a plan written from the old rows would have tried to file gated structure as ungated judgement | M3.3.4's Not in scope, and its split-criterion row |

## Completed

| File | One-line change summary |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | `active-milestone` set to M3.3.4; the M3.3.4 section gained its acceptance criteria, the doctrine-retirement row, the split-criterion row and the structure exclusion; the M3.3.2 doctrine row narrowed to the policy map and its `documentation_policy` slice given both outgoing halves; M3.2.2 gained an objective, a dependency and six rows; two stale M3.5 facts corrected |
