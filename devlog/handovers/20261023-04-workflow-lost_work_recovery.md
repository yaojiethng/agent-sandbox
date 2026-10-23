---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The lost-work recovery

## Objective

Give the classification of lost work one home, where each class names the runbook that recovers it and the one class no runbook covers keeps the draft's procedure.

## Scope

Continues **Give the lost-work recovery a home, or retire the draft**, a child of **Retire the policy form** under M3.3.2. The draft it names, `src/reasoning/agent/drafts/recovery.skill.md`, has two halves: a reconstruction procedure, and a verification audit. Four of the git runbooks already own the recovery of work that exists as commits; none owns work that does not exist at all.

The operator's steering for this iteration: the artifact names the classes of lost work first and dispatches to the runbook that recovers each, keeping the draft's own procedure for the class that has no runbook.

The operator settled the home as the `git-discipline` reference and ruled the artifact's domain mismatch out of this iteration: recovery spans session records and handovers, so its placement under a git convention is expedient. That finding is filed as the roadmap row **Recovery is not git work** under M3.3.3, and the two other orphans in `src/reasoning/agent/drafts/` are left alone.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| A1 | Every class of lost work names the runbook that recovers it, or the rebuild section when none does | each named file exists; exactly one class points at the rebuild | Agent [x] |
| A2 | Each dispatch agrees with that runbook's own mandate | the five mandates read against their rows; the merge/rebase split stated as its own section because both replay | Agent [x] |
| A3 | The absent class keeps the draft's procedure | one iteration per commit, a handover per rebuilt commit, the suite between commits | Agent [x] |
| A4 | The verification half cites the gate that enforces each check, and keeps only what no gate holds | every check names a gate or a command; the one check no gate decides is called out | Agent [x] |
| A5 | The draft is deleted and no live document asserts its path | `grep -rn recovery.skill.md`: archived handovers, one closed handover, the audit report's row, this record | Agent [x] |
| A6 | A reader choosing an instrument finds the artifact from the convention | `git-discipline`'s `## Runbooks` carries the row and the link resolves | Agent [x] |
| A7 | Gates clean | `lint.sh`, `run_tests.sh`, `check_handover_format.sh` | Agent [x] |
| A8 | The row closes with the record | roadmap write-back and this record on one commit | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The artifact lands at `.agents/skills/git-discipline/references/recovery.md`, not as a shipped skill | five of the six classes dispatch to a runbook this convention already lists, and `references/` is where its detail lives; a skill would be a second front door for git practice | scope gate, and the `## Runbooks` row in the source |
| The artifact opens with the class table, and the rebuild follows it | the operator's steering: name the classes first, then dispatch to the runbook that exists for each; the draft treated every loss as absent | the reference's `## The classes` |
| Replay and port get a section of their own | the two rows that both move existing commits are the pair a reader chooses wrongly, and the cost of the wrong choice is the work lost twice | the reference's `## Replay or port` |
| The verification half cites gates rather than restating their bash | four of the draft's seven checks are enforced by `check_handover_format.sh` and `lint.sh`, so a restated command is a copy that drifts | the reference's `## Verify the rebuild` |

## Decisions pending

None. The operator chose the reference under `git-discipline`, and directed that the artifact's domain mismatch be filed as its own row rather than resolved here.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The draft treated every loss as absent, where four of the five recoverable classes are a replay of commits that exist; its own procedure would rebuild work `/merge` or `/rebase` recovers in one run | Defect in the draft | The expensive instrument was the only one named, for every class but the one that needs it | Fixed by the class table, which names the class before the instrument |
| The draft's verification audit restated four checks that `check_handover_format.sh` and `lint.sh` already decide | Defect in the draft | A copied command drifts from the gate, and the copy is the one a reader trusts | Fixed: the audit cites each gate beside its row |
| Recovery is not git work: its rebuild, verification and gap sections concern session records and handovers, so its placement under `git-discipline` is expedient rather than semantic | Gap in the home | A reader looking for the rebuild opens a git convention, or does not find it | Filed as the roadmap row **Recovery is not git work**, under M3.3.3 |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/git-discipline/references/recovery.md`](../../.agents/skills/git-discipline/references/recovery.md) | new: six classes of lost work, the replay-or-port split, the rebuild procedure, the gate-backed verification, three known gaps |
| [`.agents/skills/git-discipline/SKILL.md`](../../.agents/skills/git-discipline/SKILL.md) | one row in `## Runbooks` routing a missing-work decision to the reference |
| `src/reasoning/agent/drafts/recovery.skill.md` | deleted |
| [`.agents/audits/surface-area-report.md`](../../.agents/audits/surface-area-report.md) | its row for the draft reads `Moved` and names the new path |
| [`devlog/roadmap.md`](../roadmap.md) | the row closes; **Recovery is not git work** is filed under M3.3.3 |
| this record | `Status: Closed`, criteria, decisions, findings, completed |
