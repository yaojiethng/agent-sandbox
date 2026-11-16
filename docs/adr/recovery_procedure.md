# Recovery procedure

**Current:** 2026-11-16

## Requirements

| Id | Requirement | Demanded by |
|---|---|---|
| R1 | Recovery starts on a reason to believe directed work was lost. A session that is merely open is resumed, not recovered. | session 2026-09-12 |
| R2 | State the record's claim -- the unit, the range, the files, the commit -- before searching. | sessions 2026-09-22, 2026-09-30 |
| R3 | Capture a recovery point before any destructive git or filesystem operation. | feedback 2026-08-10; session 2026-11-14 |
| R4 | Search the evidence in the stated order, and name every source searched. | sessions 2026-05-26, 2026-08-12, 2026-09-29 |
| R5 | Classify only from evidence; `absent` only after the search finds nothing. | sessions 2026-07-30, 2026-09-22 |
| R6 | Retrieve from the object store or an artifact before rebuilding. | sessions 2026-05-26, 2026-08-12 |
| R7 | Verify the restored tree against the claim, and correct a record that overclaimed. | handovers `20260503-07`, `20260512-07`; session 2026-09-30 |
| R8 | Record what was lost, what survived, the evidence source and the repair. | handover `20260512-07`; session 2026-09-29 |
| R9 | Keep the evidence locations in a runtime and delivery-mode layer, apart from the sequence. | sessions 2026-07-22, 2026-08-12, 2026-09-29 |
| R10 | The host draft repair is `T11`; correction, `history-cleanup` and `prepare` are redirects. | [`change_pipeline.md`](change_pipeline.md); roadmap M3.7.2 |
| R11 | Surface destructive or ambiguous choices; reconstruction is a choice the operator sees. | sessions 2026-09-12, 2026-09-22 |

## 2026-11-16 -- Recovery is derived from the evidence

**Decision.** The requirements above govern the recovery procedure. The skill leads with the intent to recover lost work and a six-step triage: claim, preserve, search, decide, restore, record. `partial` and `absent` remain the two classes; the evidence state selects retrieval or rebuild within `absent`. The evidence locations are a separate reference by runtime and delivery mode: pi's session JSONL, the task-queue worktrees and branches, the bundle and output channel, host checkpoints, and copy versus mount delivery. The host draft repair is `T11`. The duplicate `git-discipline/references/recovery.md` is retired; the skill, its runbooks and the locator are the one source.

**Evidence.** The requirements pass read the pi session transcripts under `~/.pi/agent/sessions/` and the handover record for recovery-shaped moments. The recurring failures: the agent rebuilt before checking the reflog (2026-05-26, "it should all be in reflog, why panic?"); it could not find work the operator located in the output channel or bundle (2026-08-12); it rebuilt artifacts that the session log held after a teardown (2026-09-29); it declared work lost before confirming it (2026-09-22, "confirm the changes are indeed lost; could you recreate instead?"); it conflated a stopped session with a lost one (2026-09-12); and uncommitted work was destroyed by `git restore` and `git checkout` (feedback 2026-08-10, recurrence 2026-11-14). The lost-timeline rebuild and its audit are handovers `20260503-07` and `20260512-07`; the audit's own gap, that the session record was the only complete record of the edits, is R9's driver.

**Rejected alternatives.**

- **A model home with a transition table and a classifier.** Intent failure: the requirements do not need a formal model, and building one before them puts machinery ahead of the evidence. The transition sequence is the triage in the skill.
- **Keep the duplicate reference as the model's home.** Intent failure: one subject has one source. The prompt now points at the skill and its locator.
- **A third "unreachable" class.** Intent failure: the evidence state already distinguishes retrieval from rebuild, so a third class would add a word without changing the action.
- **Treat the host draft repair as a recovery class.** Intent failure: nothing was lost. The draft is the host flow's object, and `T11` already owns it.

**Edge cases / drivers.**

- **Resume.** A non-closed session resumes; recovery is proposed only when there is a reason to believe progress was lost.
- **The record overclaims.** Where the claim has no evidence, the repair includes correcting the record, not only restoring the work.
- **Evidence in an artifact.** A bundle or output-channel diff can hold what the repository does not; the locator names it, and the repair applies it rather than rebuilding.
- **A runtime without a transcript.** The general sequence stands; the locator states the runtime has no session log rather than assuming one.
- **Mount delivery.** The `.git` is the host worktree and the harness installs no hook; the locator says so, and the repair does not assume the volume's copies.
