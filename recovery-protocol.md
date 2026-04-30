# Recovery Protocol

A north-star process for recovering from the loss of an in-flight implementation session — where the agent's working state, intermediate commits, and partial scope are gone, but some artifacts survive (a flat diff of net changes, handovers from completed sub-sessions, a known baseline commit).

This document describes the *shape* of recovery work, not any specific recovery. Examples illustrate principles. When applying this protocol to a specific recovery, produce a working file (conventionally `RECOVERY.md`) that instantiates each phase concretely.

---

## Why recovery is its own kind of work

A lost session is not just "the work is gone." Three properties make recovery different from normal session work:

1. **The artifacts you have describe intent, not landed state.** Handovers say what was decided and what files were changed. They do not say what currently *is* in the tree, because between handover-write time and loss time the tree may have moved further. The flat diff says what landed at the end, but flattens the shape of how it got there.

2. **The tooling you depend on may itself be part of what was lost.** If the lost session was modifying the diff pipeline, the build system, or the test harness, those tools cannot be trusted as the recovery vehicle — they are part of the unknown. Recovery happens *outside* the tools that are normally used.

3. **The temptation to faithfully reproduce is wrong.** The lost session almost certainly had its own bugs, scope leaks, and partial work. A faithful reproduction carries those forward. Recovery is the moment to choose logical cleanliness over historical fidelity.

These properties mean: do not start by recovering. Start by establishing what you have.

---

## Phase 0 — Establish a checkpoint

Before anything else, freeze a known state. Three artifacts must exist before recovery work begins:

**A baseline commit.** The point in history before the lost session began. This is the "if all else fails, we revert to here" anchor. Tag it explicitly. Do not work on `main` directly.

**A snapshot of recoverable state.** This is whatever survived the loss. Typically a flat diff (`staged.diff` or equivalent) representing the lost session's net delta. Apply it to the baseline as a single squashed commit on a `recovery/<topic>` branch. The squashed commit is the canonical artifact going forward — the original diff file can be discarded or kept as backup, but it is not the recovery's source of truth. The branch tip is.

**An inventory of session artifacts.** All handovers, all design documents, all in-context decisions that were persisted somewhere outside the lost agent's context. Collect them in one place. Do not yet read them for content — just confirm they exist and are accessible.

The checkpoint is "you cannot lose more than this." Everything that follows is reversible.

---

## Phase 1 — Audit before you recover

Audit means: an *independent* review of what is actually in the recovered tree, against what the artifacts claim. This is not the recovery; this is the input to scoping the recovery.

Three principles for the audit:

**The agent that runs the audit must not be the agent that ran the lost session.** Different context. Different priors. The audit's value is in not assuming the artifacts are correct.

**The audit's output is a discrepancy list, not a fix list.** Each finding is a claim-vs-actual pair. Whether to fix it (and how) is a separate decision made later. Bundling audit and remediation is how scope creep starts.

**The audit must be exhaustive in its scope but bounded in its depth.** It checks everything claimed by the handovers; it does not invent new claims to check. "What else might be wrong?" is a legitimate question for a different exercise.

A good audit finding has four components: the claim (what handover said happened), the actual state (what the tree shows), the classification (not implemented / partially implemented / incorrectly implemented / stale reference), and the location (file and line). Without all four, the finding cannot be acted on cleanly.

---

## Phase 2 — Distinguish recoverable from non-recoverable

Some things are gone forever. Acknowledge them explicitly so they don't haunt the recovery as ghost goals.

**Per-commit granularity is gone if you only have a flat diff.** The lost session's individual commits, with their boundaries and messages, cannot be reconstructed accurately. You can construct *new* commit boundaries based on logical groupings (typically per-handover or per-functional-unit), but these are not recoveries — they are reconstructions.

**The agent's working context is gone.** Anything that was reasoned about in the agent's context window but never persisted to a handover, a design doc, or code is lost. If a decision was made and recorded only in chat, it is gone.

**Tools modified mid-session are in indeterminate state.** If the lost session was modifying the build, the test harness, or the diff pipeline, those tools' current state is the result of partial modifications that may or may not be coherent. Treat them with the same skepticism as code: verify before relying.

**What *is* recoverable:**

- The net delta (the flat diff applied to baseline).
- The narrative of what was meant (the handovers).
- Anything persisted to disk before loss.

The recovery's job is to take these three and produce a clean, coherent tree state with new commit boundaries that match the *logical* shape of the work — not the historical shape.

---

## Phase 3 — Plan the recovery

Recovery is structured as a sequence of steps, each a separate session, each with its own scope. The principle: separate concerns that the lost session conflated.

The lost session likely conflated several things: design and implementation; one feature's work and another's; bug fixes and feature work; documentation and code. The recovery undoes that conflation by giving each concern its own step.

A typical recovery shape:

1. **Investigations** — read-only verification of current tree state. Confirm or refute audit findings. No modifications.
2. **Pre-clean** — land audit-identified drift fixes. Strictly hygiene; nothing that requires design choices. The tree at the end of pre-clean is the baseline that subsequent work lands on.
3. **Design step** — make any design decisions that the lost session made (or failed to make) but that the recovery hasn't yet locked in. Output: a consolidated design document and updated scope for subsequent steps.
4. **Reconstruction steps** — implement the lost work as new clean commits, scoped per the design step. Each commit has logical scope, not historical scope.
5. **Continuation steps** — any work that the lost session was about to do but hadn't started. Same shape as normal session work, but informed by the consolidated design.

Not every recovery has all five phases. A recovery from a small loss might be just investigations + reconstruction. A recovery from a complex loss might subdivide reconstruction further. The shape is a starting point, not a template.

The principle gating phase scope: would I do this even if there were no recovery happening? If yes, it might fit in pre-clean. If no, it belongs in design or reconstruction. This prevents pre-clean from becoming a dumping ground.

---

## Phase 4 — Execute, one step at a time

Each step is a separate session. The session is opened, the agent does the step's work, the session is closed. The next step starts fresh.

Three disciplines per step:

**Scope is enumerated before execution.** The step's working document lists concrete tasks. The agent does what is enumerated; nothing else. Findings that suggest expansion are surfaced, not acted on.

**Aggression scales with step type.** Investigations are read-only. Pre-clean is bounded modification per task. Design is decisions on enumerated questions only. Reconstruction is implementation per the design's scope. Continuation is normal session work.

**Verification is at every commit.** Tree must be green at each commit boundary. Tests pass. Handovers reflect reality. If a step would leave the tree red, that is a tier-4 finding (see below) and the step does not close.

Sessions are short. The operator is in the loop continuously. This is a feature: the lost session likely failed in part because too much was delegated across too long a session. Recovery is the corrective.

---

## Unexpected findings — the tier system

During execution, the agent will encounter things the recovery plan didn't anticipate. The discipline is: classify before acting.

### Tier 1 — Trivial deviation

The recovery plan was approximately right; a minor correction is needed. The agent's domain, clearly in scope, clearly small.

*Example:* the audit cited line 134, the relevant content is at line 137.

**Action:** record the correction, proceed.

**Heuristic:** if you have to think for more than a few seconds about whether it's tier 1, it isn't.

### Tier 2 — In-scope expansion

The finding is in the same logical scope as the current task but bigger than anticipated.

*Example:* the task lists four files to update, a fifth file has the same pattern that the audit didn't catch.

**Action:** surface to the operator before acting. Operator decides: expand the task, defer to a separate task, or ignore.

**Rule:** never expand silently. The lost session likely failed in part because agents folded findings into in-flight work.

### Tier 3 — Cross-step finding

Something the current step shouldn't fix but a different step should. Recording is required; acting is forbidden.

*Example:* during pre-clean, the agent notices something that affects how reconstruction will need to be scoped.

**Action:** record in the appropriate downstream step's working document. Do not act. Complete the current step's enumerated work.

**Rule:** the section to record into is determined by where the action will eventually happen, not where the finding was made.

### Tier 4 — Recovery-altering finding

The finding changes the recovery plan itself. The current step cannot continue without operator decision.

*Example:* an investigation reveals a constraint that makes the planned reconstruction approach infeasible.

**Action:** stop. Surface to operator with a clear description of the constraint. Do not produce commits until the operator updates the recovery plan.

**Rule:** if uncertain between tier 3 and tier 4, treat as tier 4. The cost of stopping unnecessarily is small. The cost of proceeding incorrectly is the recovery itself.

### Common misclassifications

The most common errors are:

- **Tier 2 misclassified as tier 1.** "It's small, I'll just fix it." Then the agent makes a decision the operator should have made.
- **Tier 4 misclassified as tier 2 or 3.** The agent surfaces the finding but keeps working. The operator gets a finding embedded in a partial commit.

Two checks before acting:

1. *Was this enumerated in the current step's working document?* If not, it's tier 2 minimum.
2. *Does this change my understanding of what the next step should do?* If yes, it's tier 3 minimum.

Combined: if not enumerated *and* changes the next step, it's tier 3 at minimum, possibly tier 4.

---

## File access discipline

The agent at each step sees the working files for that step plus the *minimum* historical context needed. Never the full historical bundle.

Two principles:

**Default-deny on lost-timeline artifacts.** Handovers, prior agent contexts, and the squashed diff are reference material. They contain narrative the agent will treat as authoritative — but the recovery plan is authoritative. Load them on specific request when content is genuinely needed.

**The live tree is the source of truth for current state.** Not the squashed diff, not the handovers' "Files changed" tables, not memory. If the agent needs to know what the code looks like, the agent reads the code.

The principle behind both: agents have a strong tendency to anchor on whatever they're given. Giving them the lost session's narrative makes them try to reproduce it. Giving them the live tree makes them work with what is.

---

## The role split: operator and agent

Recovery is a two-role activity. The split matters.

**The operator drives the recovery.** Opens each session. Confirms scope before execution. Resolves tier 2 expansions. Resolves tier 4 findings by updating the plan. Closes each step. Drives host-side git operations — applying commits, rebasing, branch management. The agent never operates on host git history directly.

**The agent executes within scope.** Reads the working file for the current step. Surfaces findings at the appropriate tier. Does not expand, does not improvise, does not reason across steps.

**There may be a third role: the orchestrator.** A separate session (or human) that holds the broader recovery plan, drafts the working files, and is not the same agent that executes any individual step. The orchestrator's value is in *not* having the execution context. It can think about scope and discipline without being pulled toward "I'm in the middle of doing this; surely I can just fix one more thing."

Where an orchestrator is used, it is not given access to the execution agent's working files in their working state — it sees the plan and the step-close handovers, not the agent's mid-step state. This separation prevents the orchestrator from drifting into execution and the executor from drifting into planning.

---

## What recovery is not

**Recovery is not workflow improvement.** A recovery has hard scope and a definable done state: the lost work is reconstructed and the project continues. Workflow improvements — better tooling, tighter session discipline, improved handover quality — are open-ended and have no natural stopping point. Mixing them re-creates the conditions that caused the original failure.

The discipline: record workflow findings during the recovery, address them in a separate after-action review *after* the recovery exits. The recovery's working file should have an after-action section for accumulating these findings; the section is not actioned until recovery is complete.

**Recovery is not exhaustive correctness verification.** The audit is bounded — it checks what was claimed. It does not, and should not, attempt a full correctness review of the tree. If the recovery exits with the audit's findings resolved and the reconstruction logically clean, that is enough. Broader correctness work is the next session's problem, not the recovery's.

**Recovery is not redesign.** Decisions the lost session made and persisted (in handovers, design docs, or commits that survived) are inputs to the recovery, not subjects for re-litigation. The exception is decisions that the recovery's own audit reveals to be inconsistent or incomplete — those go to the design step. Otherwise: implement what was decided.

---

## Exit

The recovery exits when:

1. All planned steps are complete and their handovers are closed.
2. The tree is green: tests pass, no broken builds, no incoherent intermediate states.
3. The reconstruction reflects the logical shape of the lost work — not necessarily the historical shape.
4. Outstanding workflow findings are recorded in the after-action review section, not in the project's main backlog.
5. The recovery's working files are archived (typically into a recovery folder in the repo) so future operators can read what happened.

After exit, the recovery's working file becomes a historical record. The after-action review section becomes the input to a separate, deliberate workflow improvement effort.
