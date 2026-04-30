# RECOVERY — M2.3 Session A

**Date opened:** 2026-04-30
**Status:** Recovery in progress.
**Recovery vehicle:** claude.ai sessions (one session per step), operator drives host-side git operations.

This file is the working file for the operator and the orchestrator (the chat instance helping plan the recovery). It is **not** shared with the execution agents who run individual steps. Execution agents see only the tracking file for their current step, per the file access table below.

For the generalised process this recovery instantiates, see `recovery-protocol.md`.

---

## What is being recovered

The container running M2.3 Session A and its queued implementation sessions (A.1, A.2, A.3, A.4) was lost before the diff pipeline could run cleanly. Recovered:

- A flat `staged.diff` representing the net delta from baseline to the lost session's final state. Applied as one squashed commit on `recovery/<topic>`.
- Six closed handovers from the lost timeline (`20260429-03` through `20260429-09`, excluding `-08` which is the still-active Section B design open).
- An independent audit (`20260430-01-study-m2_3_audit.md`) of the recovered tree against the closed handovers.

Lost and unrecoverable:

- Per-commit granularity within each session.
- The agent's intermediate context that did not get persisted to the handover.

---

## Recovery flow

```
[squashed recovery branch]
        │
        ▼
  [1] Investigations    →  recovery-investigations.md
        │
        ▼
  [2] Pre-clean         →  recovery-pre-clean.md
        │
        ▼
  [3] Design step       →  recovery-design-step.md
        │
        ▼
  [4] Change A          →  recovery-change-a.md
        │   (A.1, A.4, A.2, A.3 — separate sessions)
        ▼
  [5] Change B          →  recovery-change-b.md
        │
        ▼
  [M2.3 complete; Trigger B can fire]
```

---

## Progress tracker

| Step | Status | Started | Closed | Notes |
|---|---|---|---|---|
| 1. Investigations | Done | 2026-04-30 | 2026-04-30 | Run twice — once against baseline, once against recovery tip. Both files retained as `recovery-investigations-baseline-state.md` and `recovery-investigations-recovered-state.md`. |
| 2. Pre-clean | Not started | | | Pre-clean file restructured 2026-04-30 to use port-or-re-fix framing per consolidated investigation findings. |
| 3. Design step | Not started | | | |
| 4. Change A — A.1 | Not started | | | |
| 4. Change A — A.4 | Not started | | | |
| 4. Change A — A.2 | Not started | | | Scope smaller than originally planned — routing already extracted in squashed tip. |
| 4. Change A — A.3 | Not started | | | |
| 5. Change B | Not started | | | |

Update at the close of each step. Status: `Not started` / `In progress` / `Blocked` / `Done`.

---

## Tracking files

The five tracking files are agent-facing. They live alongside this file but are loaded selectively per step. They are not subsumed into RECOVERY.md — they are the agent's working state, RECOVERY.md is the operator's coordination state.

| File | Purpose | Loaded for step |
|---|---|---|
| `recovery-investigations.md` | Code-verification questions and findings | Step 1; reference in step 3 |
| `recovery-pre-clean.md` | Audit drift remediation tasks | Step 2 |
| `recovery-design-step.md` | Design step scope and exit criteria | Step 3 |
| `recovery-change-a.md` | A.1 / A.4 / A.2 / A.3 reconstruction scope | Step 4 (selectively per A.x) |
| `recovery-change-b.md` | Section B settled scope, open questions, findings | Steps 3, 5 |

---

## File access matrix

What the agent sees at each step. This is the floor — operator may grant additional access in the session-open message if a specific need exists.

| Step | Tracking files | Historical context | Live tree | Specifically excluded |
|---|---|---|---|---|
| 1. Investigations | RECOVERY-protocol-only excerpt, recovery-investigations.md | Audit handover (`20260430-01`) only | Read-only | Lost handovers 03–09; `staged.diff` |
| 2. Pre-clean | + recovery-pre-clean.md | Audit handover | Read+write | Lost handovers; `staged.diff` |
| 3. Design step | + recovery-design-step.md, recovery-change-a.md, recovery-change-b.md, design doc | Audit handover; lost handovers 03/04/08 *on request only* | Read; write to docs and tracking files | Lost handovers 05/06/07/09 (their work has been absorbed) |
| 4. Change A (per A.x) | recovery-change-a.md, design step's handover | Corresponding lost handover *on request only* (e.g. handover 05 for A.1) | Read+write | Other lost handovers; `staged.diff` |
| 5. Change B | recovery-change-b.md, design step's handover | None by default | Read+write | Lost handovers; `staged.diff` |

**Never share with execution agents:**
- This file (RECOVERY.md)
- The squashed `staged.diff` (archaeology only, on explicit request)
- The full bundle of lost handovers as a default load

The principle: agents anchor on what they're given. Give them the recovery plan, not the lost session's narrative.

---

## Session-open templates

Operator copies the relevant template, fills in placeholders, sends as the session-open message before any task prompt.

### Step 1 — Investigations

```
Session open. Recovery step: investigations.

Uploaded:
  - recovery-investigations.md
  - 20260430-01-study-m2_3_audit.md
  - <relevant excerpt from recovery-protocol.md describing the agent's role>

Live tree access: read-only.

Focus: complete all Q-I-N questions in recovery-investigations.md. Do not modify
any files outside recovery-investigations.md. Do not propose code changes.

Aggression: low. Read, record, do not act.

Unexpected findings: surface as additional Q-I entries; do not act on them.
```

### Step 2 — Pre-clean

```
Session open. Recovery step: pre-clean.

Uploaded:
  - recovery-pre-clean.md
  - recovery-investigations.md (with findings filled in)
  - 20260430-01-study-m2_3_audit.md

Live tree access: read+write.

Focus: <P-1 group | P-2 group | P-3 group | all groups in order>. Land each
task as its own commit. Verify before and after each task per the verify
steps in recovery-pre-clean.md.

Aggression: medium. Defined task list; no expansion. If a task expands or
a new task surfaces, stop and surface to operator.

Unexpected findings: tier system per recovery-protocol.md. Tier 1 in scope;
tier 2+ surface to operator before acting.
```

### Step 3 — Design step

```
Session open. Recovery step: 20260430 design step.

Uploaded:
  - recovery-design-step.md
  - recovery-investigations.md (with findings)
  - recovery-pre-clean.md (post-step state)
  - recovery-change-a.md
  - recovery-change-b.md
  - docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md
  - 20260430-01-study-m2_3_audit.md

Live tree access: read; write to docs/ and recovery tracking files only.

Focus: complete objectives O-1 through O-6 in recovery-design-step.md.
Output: updated design doc, updated recovery tracking files, 20260430
design handover.

Aggression: medium-low. Decide on enumerated open questions only. New
questions get recorded, not answered.

Unexpected findings: tier system. Particularly likely to be tier 3 here —
record for future, do not absorb into current scope.
```

### Step 4 — Change A reconstruction (per A.x)

```
Session open. Recovery step: change A — <A.1 | A.4 | A.2 | A.3>.

Uploaded:
  - recovery-change-a.md (post-design-step scope, only the relevant § A.x section
    and cross-cutting notes)
  - 20260430-NN-design-recovery_consolidated.md (design step's handover)

Live tree access: read+write.

Focus: implement the A.x scope per recovery-change-a.md § A.x. Tests must
pass at the end of the commit.

Aggression: medium. Scoped change list; no expansion. Cross-step findings
get recorded in recovery-change-a.md, not acted on here.

Unexpected findings: tier system. Findings about other A.x sections are
tier 3 — record, do not absorb.
```

### Step 5 — Change B

```
Session open. Recovery step: change B — interactive flag.

Uploaded:
  - recovery-change-b.md (with all open questions resolved by design step)
  - 20260430-NN-design-recovery_consolidated.md
  - docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md

Live tree access: read+write.

Focus: implement Section B per recovery-change-b.md. Tests pass at the end
of each commit.

Aggression: medium. Same rules as Change A.

Unexpected findings: tier system. Findings about earlier steps are tier 4 —
recovery is mostly complete; do not re-open prior steps without operator
decision.
```

---

## Operator workflow per session

For each step:

1. **Open the session.** Use the template above. Fill placeholders. Send before any task prompt.
2. **Confirm scope.** Agent will read the tracking file and propose what it intends to do. Confirm or correct.
3. **During execution.** Watch for tier 2+ findings. Resolve as they arise — confirm expansion, defer to a separate task, or escalate to plan update.
4. **At session close.** Agent produces a handover and updates the relevant tracking file's findings/closed sections. Operator reviews against the step's exit criteria.
5. **Apply commits to host.** Operator drives `git` operations. The agent never touches host git history directly.
6. **Update RECOVERY.md.** Update progress tracker. Add any after-action review entries that emerged.
7. **Close the session.** Do not continue to the next step in the same session — open a fresh one.

---

## After-action review

This section accumulates findings about the *recovery process itself* and the *workflow that allowed the original failure*. Entries are added during recovery, not at the end. The section is not actioned until recovery is complete.

**Why workflow remediation is out of scope for the recovery itself:** a recovery has hard scope and a definable done state. Workflow improvements are open-ended. Mixing them re-creates the conditions that caused the original failure — context-window pressure, scope creep, agents folding new findings into in-flight work. The discipline that protects the recovery's done-state is also the discipline that defers workflow work to a separate, deliberate effort.

After recovery exits, this section becomes the input to a workflow remediation track. That track is run as a separate sequence of sessions (story → investigation → design → impl as appropriate), not as recovery follow-up.

### Findings about the recovery process

| Date | Step | Finding | Implication |
|---|---|---|---|
| 2026-04-30 | Step 1 (investigations) | The investigations file as written did not specify which tree to investigate (baseline vs recovery tip). The agent ran against whatever was checked out — which was baseline, not the recovery tip. A second session was needed against the recovery tip. | Future investigation files must explicitly state target tree. For recoveries with both baseline and recovery-tip available, run investigations against **both** by design — the delta is the most valuable signal. |
| 2026-04-30 | Step 1 (investigations) | The agent at the recovery-tip session classified the audit's wrongness as Tier 4 ("audit's central premise is wrong"). From its single-session perspective this was correct. From the orchestrator's perspective, with both investigations in hand, it was not surprising — the audit had been run against baseline, and the recovery-tip showed the lost session had fixed most of what the audit flagged. | The Tier system is local to a single session's view. An orchestrator reading multiple sessions' outputs may see the same finding as routine where the executing agent saw it as alarming. Tier classification should be re-evaluated at orchestrator level when consolidating across sessions. |
| 2026-04-30 | Step 1 → Step 2 transition | The original pre-clean plan assumed audit findings reflected the recovery tip's state. After the two-state investigation, it became clear that audit findings reflect *baseline* state and many were already resolved in the squashed tip. The pre-clean framing required restructuring from "fix all audit items" to "for each audit item, decide port-from-tip vs re-fix-from-baseline". | A pre-clean that follows an audit must explicitly classify each audit item as port / re-fix / no-action against the recovery tip. The default assumption that audit drift = pre-clean scope was wrong here. |
| 2026-04-30 | Step 1 (recovery-tip session) | The agent's session-close summary said "Pre-clean scope should shrink to the genuinely remaining items..." — implying the squashed tip's fixes should be inherited by rebasing rather than ported as discrete commits. This violated the recovery's stated goal of separating useful commits from the squash. The orchestrator did not catch this in initial framing back to the operator. | The orchestrator (this chat) must guard the recovery's commit-separation goal more actively. When an executing agent's framing drifts toward "blindly accept the squashed state", surface the drift explicitly rather than absorbing it into the next step's plan. |

### Findings about the original workflow that allowed the failure

| Date | Source step | Finding | Implication |
|---|---|---|---|
| 2026-04-30 | Step 1 baseline investigation | Audit findings claimed multiple migrations were incomplete (`SESSION_STATE`, `INIT_SHA` removal, test fixtures). The recovery-tip investigation showed these were actually completed in the lost session but the audit ran against baseline. The audit was not wrong — it was correctly identifying baseline drift — but its framing as "the migration is not implemented" rather than "baseline diverges from documented state" misled subsequent planning. | Audits that compare a static reference state (baseline) against documentation/handover claims must clearly label *what state is being compared to what*. An audit's discrepancy table is not the same as a remediation list — discrepancies may already be in flight in branches not under audit. |
| 2026-04-30 | Step 1 recovery-tip investigation | Test count diverged between audit (249) and recovery tip (242). Difference unexplained — possible test deletion or count correction during the lost session. Tests still all pass, so not a correctness issue, but indicates either undocumented test changes or audit error. | Test counts should be tracked across handovers as a coarse signal for unintended changes. A handover that closes with a different test count from the previous one's claim should call this out. |
| 2026-04-30 | Step 1 recovery-tip investigation | Routing extraction (handover 06's claim) actually landed in the squashed tip — the routers `resolve_source_for_draft` and `resolve_diff_for_apply` exist in `agent-sandbox.sh`. Earlier orchestrator analysis (based on baseline investigation) had concluded they did not exist. | When an investigation finding contradicts an earlier conclusion, the contradiction itself is a finding. The orchestrator should record both states and the resolution, not just overwrite the earlier analysis. (This is now done in this finding.) |
| 2026-04-30 | Step 1 baseline investigation | The functions named in `recovery-investigations.md` Q-I-1 (`write_uncommitted_diff`, `write_all_changes_diff`) did not exist at baseline; the actual functions were `diff_write_changes_diff` and `diff_generate`. The investigation file's question text was based on the lost session's *intended* function names, not the live tree's actual names. | Investigation question text should be grounded in the actual tree being investigated, not in the handovers' description of the work that produced or would produce that tree. Otherwise findings have to translate between two naming systems. |
| 2026-04-30 | Step 1 recovery-tip investigation | `agent-sandbox.sh` has no `main` guard despite containing testable functions (the routers). This is a structural defect that prevents direct unit testing. The lost session introduced the routers but did not make the file sourceable for tests, and no handover flagged this. | "Function exists" is not the same as "function is testable." Implementation handovers should explicitly verify testability — either tests landed alongside the function, or the function is structurally testable for future tests. Neither held here. |
| 2026-04-30 | Step 1 recovery-tip investigation | `roadmap.md` line 120 claims "Stale references to `changes.diff`, `staged.diff`, `BASELINE_SHA`, `diff_commit_pending`, and `apply_workspace.sh` removed from `docs/` and `libs/`" — but the recovery-tip investigation found 47 matches, including 2 in active/warm documents. The roadmap completion claim is false. | Completion claims in roadmaps must be verifiable by the same procedure the agent uses to "verify done." A claim "stale references removed" is testable by grep; the test should be run before the claim is recorded. |

### Patterns observed across multiple findings

When several findings point to the same underlying cause, record the pattern here. Patterns are the input to workflow remediation; individual findings are the evidence.

| Pattern | Supporting findings | Suggested remediation direction |
|---|---|---|
| **Completion claims without verification** | "audit not run during the lost session", "roadmap.md claim of stale references removed was false", "function exists but isn't testable", "SESSION_STATE migration claimed in handovers wasn't done" | A handover's "Completed this session" table requires evidence per row — a grep result, test name, or file diff. "I did the migration" is not a completion claim; "I did the migration, here's the test that asserts the new behaviour" is. |
| **State ambiguity in artifacts** | "investigations file didn't specify target tree", "audit didn't label what was compared to what", "investigation question text used intended-but-not-yet-existent function names" | Recovery and audit artifacts should explicitly declare the *as-of-state* they describe. A finding is "X is true at <branch>@<sha>"; without that anchor, findings translated across states get misinterpreted. |
| **Orchestrator drift toward executor framing** | "orchestrator initially framed pre-clean as inheriting fixes via rebase rather than porting commits", "orchestrator missed that 'audit was wrong' was Tier 4 only at agent level not at orchestrator level" | The orchestrator's job is to maintain the broader plan even when an executing agent's local framing is compelling. Periodic re-grounding against the original recovery goals (commit separation, audit-shaped commits, clean reconstruction) is a discipline the orchestrator owes the operator. |

---

## Decision log

Decisions about the recovery itself, separate from decisions within each step.

| Question | Decision | Rationale |
|---|---|---|
| Recover via in-sandbox tooling? | No | Tooling was being modified mid-session; cannot be trusted as recovery vehicle. |
| Preserve original commit granularity? | No (single squash, then logical re-split) | Original commits already mixed concerns. Logical clean reconstruction beats historical fidelity. |
| Run M2.3 Trigger B before recovery is done? | No | Section B is unstarted. M2.3 is not closed. |
| Run further investigations of the squashed diff? | No (archaeology only on demand) | The live tree is current state. The diff is historical. |
| Defer workflow improvements until after recovery? | Yes | Recovery has hard scope and definable done state. Workflow fixes are open-ended. See after-action review section. |
| Add helper extraction to pre-clean? | No (lands in A.1 per design step) | Extraction requires interface choices; choices belong in design, not cleanup. |
| Share RECOVERY.md with execution agents? | No | RECOVERY is operator+orchestrator coordination state. Tracking files are agent state. |

---

## Exit criteria

The recovery is complete when:

1. All steps in the progress tracker are `Done`.
2. `scripts/run_tests.sh` exits 0 on the post-recovery branch tip.
3. `roadmap.md` reflects M2.3 as fully complete.
4. M2.3 Trigger B has been run and the milestone is closed.
5. RECOVERY.md and the five tracking files are archived to a recovery folder in the repo (e.g. `docs/devlog/recovery/20260430/`).
6. The after-action review section is preserved in the archive (it is the input to subsequent workflow remediation).
7. The recovery branch has been merged or rebased into the line of development the project will continue on. (This is a host-side operation; no agent involvement required.)

After exit, RECOVERY.md becomes a historical document. The after-action review feeds a separate workflow remediation track.
