# Closed Record Corrections

**Current:** 2026-09-27

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | State consistency | a closed record ends closed, whatever path the correction took |
| R2 | The marker | no closed record's content changes without its type's marker |
| R3 | The successor entry | a record that tracks state gains the entry that carries the correction |
| R4 | Propagation | a correction inherits the record set of the unit it corrects |
| R5 | Operator direction | the agent proposes a correction; it applies one only at the operator's direction |
| R6 | The fold | corrected content rides the unit's own commit, folded, so the history reads as if it had always been that way |

## 2026-09-27 -- A closed record is corrected by marker and successor, not by edit

**Decision:** A closed record's content does not change. It gains the marker its type carries, and a record that tracks state also gains a successor entry. The mechanic follows what the record is for: a record that states what is true is corrected in place under a `[CORRECTION]` tag, and a record that tracks open and closed tasks keeps its closed row, gains a `[SUPERSEDED]` or `[REMOVED]` marker, and gains the successor entry that carries the correction. Corrections apply at the operator's direction; the agent may propose one and may not apply one unasked. A correction propagates across every record its unit touched, and its content rides the unit's own commit, folded. Two mechanics for two kinds of record, one principle.

**Rationale:** The rule this replaces could not say whether a closed record's defect was fixable. Its trigger was a list introduced by "reasons include", and its prohibition was flat, so the operator and the agent read the same case in opposite directions: the operator counted a missed omission as a correctable error, the agent read it as forbidden new information and routed it into a new handover. Neither broke the rule, and a rule that admits both readings decides nothing. Three observations fixed the shape. A `DONE`-headed roadmap section held three open boxes, and the only sanctioned repair was a new iteration to flip three checkboxes. The rule's severity distorted behaviour rather than only obstructing it: a row whose scope was partly met got a clause annotated and its box left open, so a landed fact and a stale box coexisted in the task list. And the corrections a developer actually resents are `fix:` commits stacking on a one-line change, which the rule could not touch because it governed records rather than history.

The developer's own interest settled the mechanism. History that lists every detour is harder to read than history that reads as if the work were done correctly first time, and the detour is not lost because the handover carries it. That splits the record from the commit cleanly: commits fold, records accumulate. It also follows from the amendment existing at all -- a correction is a second change to the same logical unit, which is what amending means, and a rule that forbids it forces the detour it exists to prevent.

Two mechanics follow from what a record is. A record that states a claim is corrected by rewriting the claim, because a reader who skims will act on a stale sentence and a record carrying both a claim and its refutation has stopped being readable. A record that tracks state is corrected by addition, because a completed task stays completed and a correction is work falling across the state seam -- it is a new task, so it is a new row. The operator's correction that the changelog is the roadmap's archived half, kept apart for length, is what makes the second mechanic apply there too: the milestone anchor already presupposed a body of closed work with a successor.

**Rejected alternatives:**

- *An illustrative trigger list plus a flat prohibition on new information* (the replaced rule) -- execution failure. The intent was right, a correction should be available at the operator's direction, and the wording is what produced two readings of one case.
- *"Glaring errors that compromise completion" as the qualifying test* -- intent failure. It moved the threshold without deciding anything: it asks whether a defect is obvious, which is a judgement the agent and the operator can still answer differently. The operator rejected a test for a judgement call in favour of a principle plus a list of qualifying situations.
- *Conceptual scoping as the test* -- intent failure, though it improved on the alternatives by asking a question the record answers rather than one the agent's memory answers. Still a judgement, so it did not survive.
- *One mechanic for every record type* -- intent failure. A state record cannot be corrected by rewriting its closed row without destroying the state it exists to hold, and the roadmap's own section already forbade rewriting.
- *Splitting the roadmap and changelog into separate sections with different mechanics* -- intent failure. The premise was false: the changelog is the roadmap's archived half, not a different kind of document. The milestone-anchored marker already encoded that.
- *Keeping the rule that the Status field never changes* -- intent failure. It constrained the mechanism rather than the end state, and forced a rewrite-in-place where reopening the record and closing it again was both simpler and a better record.
- *A milestone-anchored marker only* -- intent failure. A correction landing inside an open milestone had no form, and that is the common case: three records were corrected mid-milestone in the session that produced this decision.
- *Dropping the rule from the provider `AGENTS.md` without landing the lifecycle statement first* -- execution failure, avoided by ordering. `AGENTS.md` is the only place the bar is stated coarsely and the file that seeds the host, so removing it alone would have left no statement of it anywhere.

**Edge cases / drivers:** A correction inside an open milestone has no closed boundary to point at, so the anchor names the current milestone and the iteration is the fallback for work belonging to no milestone. A correction that cannot be finished returns the record to the state it carried before, because a reopen cycle abandoned mid-way is the one way this rule could leave a record inconsistent. A large adjustment, such as reopening a closed milestone to list rows closed on scope they did not cover, goes through the reopen path. A fold that needs an interactive rebase with several conflict edits is reported as a smell and stops, because past that size the instrument is a port rather than a correction. A correction that turns out to need its own handover is a new iteration, not a large correction. A correction crossing a unit boundary has no owner under R4, because the rule inherits one unit's record set and a spanning correction has none; this case is unsolved. Ordering for two markers on one row is specified for handovers and not yet for roadmap rows.
