# Finalized Workflow — Agent Feedback and Gotchas

**Status:** Settled (design complete; implementation pending next session)
**Date:** 2026-08-09
> This document is the finalized workflow to be implemented. It is the deliverable of the workflow exploration session `20260809-03`. It is the spec for the next implementation session. It is not the current system state.

---

## Purpose

The workflow gives the operator and the agent two persistent, devlog-hosted channels to record and resolve two classes of "boo-boos":

- **Agent Feedback** — friction points, poor stack design, poor operator prompting, and agent experience complaints. Recorded by the agent. Reviewed and addressed by the operator.
- **Gotchas** — recurring agent mistakes and code smells witnessed by the operator (chiefly via mid-turn steering). Recorded by the operator, surfaced to the working agent. Fixed by the agent.

The workflow ties both into the existing mid-session findings mechanism for **recording**, and into a pre-close review gate at sub-milestone cleanup for **reconciliation**.

---

## Definitions

| Term | Meaning |
|---|---|
| **Entry** | One recorded friction point or gotcha. It has a state, an attribute set, and a body. |
| **State** | `open`, `mitigated`, `probation`. Governs lifecycle. |
| **Attribute** | `scoped:<milestone>`, `legacy:`. Non-lifecycle metadata. |
| **Review/publish step** | Step at session close that routes mid-session findings to their destinations. Replaces the former mid-session findings triage gate. |
| **Pre-close review gate** | Step at sub-milestone close at which the agent surfaces open entries and the operator decides `dismiss`, `maintain`, or `escalate`. |
| **Sweep** | Agent action that applies a gotcha fix across recent code. Triggered at sub-milestone cleanup. |

---

## File locations and structure

`devlog/AGENT_FEEDBACK.md` and `devlog/GOTCHAS.md` are live files in `devlog/`.

Both are **flat**. There is no index layer. The preamble of each file must state:

> If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

Per-entry structure in both files:

```markdown
## [<A|G>] <date> — <short title>
state: open                        // open | mitigated | probation
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```

Entries are **deleted when resolved**. A resolved durable fix is recorded in the changelog and roadmap, not in these files. These files hold only the active backlog.

---

## The two files

### `devlog/AGENT_FEEDBACK.md`

- **Writer:** agent.
- **Purpose:** agent experience, friction, poor stack design, poor operator prompting, "this needs reinforcing".
- **Content classes:**
  - **To the agent itself:** friction the agent can mitigate (for example, a bash trap resolvable via a skill). Referenced for self-correction.
  - **To the operator:** friction requiring the operator to improve prompts, docs, or the stack.
- **Operator integration:** the agent surfaces open entries to the operator at the sub-milestone pre-close review gate. The operator reviews and addresses prompt/stack pain points. Ad-hoc spot-check is optional.
- **Migration:** subsume `devlog/discussions/20260809-story-active-bash_complaints.md` (8 entries) into a `## Bash` section of `AGENT_FEEDBACK.md`, converting each to the new per-entry format, then delete the source file and correct its backlinks (implemented session `20260809-04`).

### `devlog/GOTCHAS.md`

- **Writer:** operator.
- **Purpose:** recurring agent mistakes and code smells.
- **Source of entries:** chiefly mid-turn steering. When the operator says "did you forget X", the agent reacts, then lists it as a mid-session finding with an explicit note, then moves it into `GOTCHAS.md` at the review/publish step.
- **Agent integration:** at session open (Step 1), the agent reads open gotchas and avoids/re-checks those patterns during the session. This is a session-open primer. Sweep-and-fix happens at sub-milestone cleanup.
- **Durable housing:** when gotchas accumulate, fold the recurring patterns into a skill so the loaded surface stays small.

---

## Lifecycle of an entry

```
discover → record → review/publish → durable-fix scope → probation → cleanup
```

1. **Discover.** During a session, a friction point or gotcha is identified (by conversation, steering, or observation).
2. **Record.** The agent writes it to the handover's Mid-session findings section. The recording surface is the handover; the agent is the sole editor.
3. **Review/publish.** At session close, the review/publish step routes each entry:
   - Class A → `AGENT_FEEDBACK.md`
   - Class B → `GOTCHAS.md`
   - Class C (steering, scope, blockers, technical findings) → decisions, deferred items, roadmap, as already defined.
   - **Attribution is operator-owned.** The agent proposes a class; the operator confirms it. The agent never self-classifies its own boo-boo as not-its-fault.
4. **Durable-fix scope.** If a durable fix exists, the operator assigns it to a milestone and records it in the roadmap. An interim mitigation is noted on the entry so the agent can work around it now. A proposed solution is never self-implemented; the operator reviews it.
5. **Probation.** When the durable fix lands, the entry is tagged `probation`. It is re-checked at each sub-milestone cleanup and when the related feature space is next touched.
6. **Cleanup.** At sub-milestone cleanup, the operator decides:
   - **dismiss** — the fix held. Delete the entry.
   - **maintain** — the fix is not yet stress-tested. Extend probation.
   - **escalate** — the problem resurfaced. The prior fix failed. Re-scope with awareness of the prior fix; optionally retire the prior fix.

---

## The review/publish step

At session close, the review/publish step **replaces** the mid-session findings triage gate (iteration_policy — Steps 8–9). It performs the existing triage responsibilities plus routing to the two files.

The handover must be empty of findings or contain only findings with a `Triaged to:` annotation before close, as today.

---

## Pre-close review gate (sub-milestone cleanup)

At sub-milestone cleanup, the agent runs a review-gate checklist and surfaces to the operator:

- Open `AGENT_FEEDBACK.md` entries (operator prompt/stack pain points).
- Open `GOTCHAS.md` entries and any pending sweeps.
- Entries under `probation` for a `dismiss`/`maintain`/`escalate` decision.

This mirrors the minor-loop pre-close verification gate (Gate 3 style).

### Escalation placement

- **High blast radius / correctness:** the escalation **interrupts the milestone close**. The milestone is not finalized or tagged until the escalated work is cleared. Do not release known-broken code with a version tag. Attempt close again when cleared.
- **Low urgency, substantive new work:** filed as named task entries at the top of the next sub-milestone.
- **Retirement of a failed fix:** not a roadmap action in general. "add X / remove X" cancel on compaction; the work history stays in the handover. Retirement becomes a named roadmap task only when blast radius is non-trivial.

### "Interrupted close" framing

There is no dedicated "close-blocked" state. The sub-milestone simply stays `active` with the escalated tasks added, and close is deferred until they clear. Pre-close is the gate; close is deferred while pre-close has not passed.

---

## Milestone lifecycle reframe

The major loop is restated as:

```
active → pre-close → close → [post-close admin, only if broken]
```

- **Pre-close:** all substantive work. Compaction, changelog draft, escalation clear (the release-readiness check), and the review gate. The operator's release decision happens here.
- **Close:** ceremonial. No decisions. For now, a manual administrative checklist; the milestone is declared closed when the checklist completes. Human intervention is available on error.
- **M3:** close becomes a single administrative script (`make close-milestone`) that atomically bumps milestone state. Clean commit, no partial-close risk.
- **Post-close admin:** only genuine administrative work (index prune, link refresh). Heavy substantive work post-close is a lifecycle smell.

---

## Next session integration

- **GOTCHAS pointer** in `AGENTS.md` (agent-facing section): at session open, read open gotchas and avoid/re-check them; sweep at sub-milestone cleanup.
- **AGENT_FEEDBACK pointer** in `AGENTS.md` (adjacent to the Bash Friction Log): at sub-milestone pre-close review gate, surface open entries to the operator.
- Both files are pointed to from `AGENTS.md`, which loads every session. Integration is automatic on both sides.

---

## Language standard

New and changed policy language must be drafted in Simplified Technical English style (ASD-STE100):
- Objective and technical.
- Disambiguated from any conversational context.
- No dead prose, idiom, or unspecified pronouns.
- One concept per sentence; one word per concept.

**Backlog:** a doc-review sweep of the remaining docs, policies, and agent files to the same standard is recorded and deferred (too large for the implementation session).

---

## Scope of implementation (next session)

### Documentation changes
- **D1.** Create `devlog/AGENT_FEEDBACK.md`.
- **D2.** Create `devlog/GOTCHAS.md`.

### Subsume
- **T1.** Migrate `bash_complaints.md` (8 entries) into `AGENT_FEEDBACK.md` `## Bash` section; update AGENTS.md pointer and skill cross-references; flag source file for operator deletion.

### Policy changes
- **P1.** Expand Mid-session findings to a shared agent-managed stream; classify at review/publish. (`handover_policy.md`, `iteration_policy.md`)
- **P2.** Replace the mid-session findings triage gate with the review/publish step. (`iteration_policy.md`)
- **P3.** Add the pre-close review gate + dismiss/maintain/escalate probation at sub-milestone cleanup. (`milestone_policy.md`)
- **P4.** Trim the handover **Next session** section to context-only, and always push deferred tasks to the roadmap (coupled). (`handover_policy.md`, `roadmap_policy.md`)
    - **Roadmap-update timing rule (P4 companion):** when a session generates tasks, update the roadmap at end of session. State this behavior explicitly; do not leave roadmap-update timing implicit.
- **P5.** Add AGENTS.md pointers for the two files.
- **P6.** Restate the milestone lifecycle in the major loop (`active → pre-close → close`). (`milestone_policy.md`)

### M3 recording (record-only)
- **M3-1.** Add finding: sub-milestone containment.
- **M3-2.** Add subtask: close-script automation.
- **M3-3.** Re-word the existing "moving next-session seed into next-task subheader" task to reflect the immediate trim done and the roadmap-linear redesign remaining.
- **M3-4.** Re-word "converting the roadmap to linear-style task tracking" if required.

### ADR
- **None.** The agent-feedback/gotchas workflow is architectural in nature, but no significant design decision was made by this workflow (the substantive decision — how to structure the major/minor loop documentation and whether to split into `major_loop_policy`/`minor_loop_policy` — is deferred to M3). Per the operator, recorded as a docs mention in the respective workflow document; no ADR. The workflow itself is specified in this artifact and the operations policy docs.

### Close-order reconciliation (P2 companion)
- **P2 companion.** Reconcile the handover close-ordering contradiction: `iteration_policy.md` Steps 8–9 say commit then mark Closed; `handover_policy.md` requires a Closed handover with no uncommitted changes. This is a current friction point (recorded in the M2.6 roadmap item), carried into next session, and resolved when P2 edits the close flow. Preferred resolution: close = the commit itself — mark Closed, then the final commit includes the closed handover. No substantive action after close.

---

## M3 finding text (for `roadmap_future.md`)

> **Finding — Sub-milestone containment (recorded, not designed):** Milestones and sub-milestones are intended to be self-contained, but partial implementations from later milestones are frequently needed while the current milestone is incomplete. This suggests that how features are cut into sub-milestones, and how strictly they are sequenced, may be the wrong seam. The sub-milestone-as-container model is recognized as a candidate for re-examination, not as settled. Design and any restructuring is deferred to M3. The current deferred-items / sub-milestone task-list system is maintained until then.

Language rule: record findings concise and framing-only. Propose no solutions in the finding. Keep correct framing while the context is fresh.
