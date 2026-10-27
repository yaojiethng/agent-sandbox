# Closed Record Corrections

**Current:** 2026-10-19

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | State consistency | a closed record ends closed, whatever path the correction took |
| R2 | The marker | no closed record's content changes without its type's marker |
| R3 | The successor entry | a record that tracks state gains the entry that carries the correction |
| R4 | Propagation | a correction inherits the record set of the unit it corrects |
| R5 | Operator direction | the agent folds a correction to its own commit while that session is live, and applies one only at the operator's direction after it has ended |
| R6 | The fold | corrected content rides the unit's own commit, folded, so the history reads as if it had always been that way |

## 2026-10-19 -- The minimal-corrections principle is assessed against R1 to R6

**Decision:** R1, R2, R3, R4, R5 and R6 all survive the assessment; none is retired. The principle governs what a correction *contains*. R2 and R3 govern the *form* a closed record takes when its content changes, and that form adds no second statement of the correction. R1 is the end-state invariant, R4 the propagation set, R5 the direction (settled on 2026-10-18), and R6 the fold, which is the principle's own mechanic. On a claim record the correction is the rewritten claim under a one-line `[CORRECTION]` tag; the tag names that the record changed and carries no account of the deviation. On a state record the closed row keeps its `[SUPERSEDED]` or `[REMOVED]` marker and the successor entry *is* the correction, because a completed task stays completed and the correction is new work.

**Rationale:** The principle's table pairs "a `[CORRECTION]` paragraph in a record" with "the corrected claim", so its subject is a narrative paragraph, not a one-line state marker. A tag that says only that the record changed adds no account beside the claim; it is the closed record's audit trail, and the git history and the handover carry the reason. R3 likewise is not an artifact beside the correction: a state record cannot be corrected by rewriting its closed row without destroying the state it exists to hold, so the successor entry is the correction's only form. The sharpest case, the `[CORRECTION -- 2026-09-28]` tag on the 2026-09-27 entry of this record, is kept for the same reason: it marks that the entry's edge-case sentence was superseded, and the replacement is the 2026-09-28 entry itself. Retiring R2 or R3 would require rewriting the `record-correction` procedure's `## Correcting a record`, `task-list` `## Corrections to a closed entry`, `handover-maintenance` Step 8 and `record-correction`, and would leave a closed state record either rewritable or untraceable.

**Rejected alternatives:**

- *Retire R2's marker and R3's successor entry as artifacts beside the claim* -- intent failure. It reads a state marker as commentary. It would also make a closed roadmap row editable in place, which the record exists to prevent.
- *Retire the `[CORRECTION]` tag on claim-type records and keep only the fold* -- execution failure. The tag is the only signal that a closed claim changed after the fact; the git history records the edit but not that the record was closed when it changed.
- *Supersede this ADR* -- intent failure. Six requirements survive with reasons, so no successor is needed.

**Edge cases / drivers:** A correction that changes only the commit and no record produces no marker, because no record changed. A correction to a record that is still open carries no tag, because the record is not closed. The tag on this record's 2026-09-27 entry stays; it is the form R2 requires, and the 2026-09-28 entry that supersedes it is the successor entry R3 requires for the edge-case sentence.

## 2026-10-18 -- The content judgement leaves, and the operator's direction narrows to a closed session

**Decision:** The judgement about what a correction may contain leaves this record for `principle-minimal-corrections`, and the `git-discipline` convention's fold rules decide only where a correction lands. R5 governs the landing once the session that made the commit has ended. While that session is live and the commit is the agent's own, the agent folds the correction without asking, whichever actor raised the defect. R1, R2, R3, R4 and R6 are unchanged here; the assessment the roadmap row asked for is the 2026-10-19 entry of this record, which keeps all six with a reason and supersedes nothing.

**Rationale:** R5 named one direction for two decisions. A content instruction then read as a landing instruction, and a correction that should have folded into `582af1eb` landed as `f82d1a0d` twenty minutes later, with its own handover and its own record. Naming the two decisions separately is what closes the case that the single clause could not separate.

**Rejected alternatives:**

- *A pointer to the principle only* -- execution failure. R5 keeps stating that the agent applies a correction only at the operator's direction, which the Amending section no longer holds, so two records disagree in the tree.
- *Defer both the pointer and the R5 narrowing to the assessment row* -- execution failure, for longer. The contradiction is in the tree already, and the assessment is scoped to decide what survives, not to detect that something changed.

**Edge cases / drivers:** A correction raised after the session that made the commit has ended stays with the operator, and the Amending section's case 2 says so. A correction to a commit that is not the agent's own is untouched by this entry. R2's marker is the sharpest question the assessment faces, because a marker is an artifact standing beside the corrected claim.

---

[CORRECTION -- 2026-10-26: the decision closed by naming the assessment as an open roadmap row. The row was closed in ed796fc1, which appended the outcome to it, and removed from the roadmap when M3.3.4 closed in b8e5fc99, so the sentence pointed at nothing; it now names the entry that holds the assessment. The 2026-10-18 heading is restored, because ed796fc1 overwrote it when the assessment was inserted above this entry.]

## 2026-09-28 -- The fold target is the unit whose scope the fix fits

**Decision:** A fix that lands after its unit's delivery folds into the unit whose target scope it fits. In scope of the current unit, the fix is that unit's regular work: it rides the unit's commit, and its handover carries it as a regular entry. Out of scope, the fix folds into the latest relevant commit (the prior unit), and the prior unit's handover gains the record. The realization point selects the mechanics, never the target. In flight, an out-of-scope fix is stashed apart from the unit's working set, landed as a patch on the relevant commit, and squashed in by rebase. After delivery, it folds via `git commit --fixup=<hash>` plus `git rebase -i --autosquash`, which rewrites the target and re-applies the later commits on top. A closed record's change carries its type's marker per R2.

**Rationale:** R4 and R6 presupposed one target unit. When a fix could attach to either of two units, the rule had no selector, and the 2026-09-27 entry recorded the case as unsolved. The selector is scope: a unit's scope is fixed when the iteration starts, so "does the fix fit the current unit's scope" is a yes-or-no question, not a judgement. Keying the target to the corrected content would fold into an arbitrary past commit; keying it to the realization point alone would pollute a unit's regular work with out-of-scope changes.

**Rejected alternatives:**

- *Key the target to the corrected content* -- execution failure. The fold target becomes arbitrary past history; the latest-relevant-commit rule keeps the rebase short and the record reachable.
- *Always fold into the realization point's current unit* -- intent failure. B's scope statement then stops matching B's content.
- *A later iteration owns the spanning correction across both units' records, or one correction per unit* (the T1 row's former options) -- intent failure. Both presuppose the correction is an object; there is one fix, one target, chosen by scope.

**Edge cases / drivers:** Realized during the unit and in scope: regular work, no correction machinery. Realized in flight and out of scope: patch is stashed apart and squashed into the relevant commit. Realized after delivery and out of scope: fixup and autosquash, later commits re-applied; the amended handover carries the R2 marker. The 2026-09-27 edge case "a correction crossing a unit boundary has no owner under R4" is resolved by this entry.

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

**Edge cases / drivers:** A correction inside an open milestone has no closed boundary to point at, so the anchor names the current milestone and the iteration is the fallback for work belonging to no milestone. A correction that cannot be finished returns the record to the state it carried before, because a reopen cycle abandoned mid-way is the one way this rule could leave a record inconsistent. A large adjustment, such as reopening a closed milestone to list rows closed on scope they did not cover, goes through the reopen path. A fold that needs an interactive rebase with several conflict edits is reported as a smell and stops, because past that size the instrument is a port rather than a correction. A correction that turns out to need its own handover is a new iteration, not a large correction. A correction crossing a unit boundary has no owner under R4, because the rule inherits one unit's record set and a spanning correction has none. [CORRECTION -- 2026-09-28] resolved by the unit-whose-scope entry above: the fold target is decided by scope, not by content. Ordering for two markers on one row is specified for handovers and not yet for roadmap rows.
