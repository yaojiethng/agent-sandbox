---
description: Open a new session. Runs Steps 1, 1b, and 6 of the minor loop (iteration_policy.md) — finds the latest handover, runs recovery and compaction checks, creates the new handover, then answers two questions before any work begins: what is being asked, and what does done look like. Both must be confirmed by the operator before implementation starts. Use at the start of every session. Accepts an optional argument describing the session type and focus — this takes priority over the Next session section of the prior handover.
argument-hint: "[workflow|impl|design|spec|plan|story|study|chore] <focus description>"
---

Running Steps 1, 1b, and 6 of the [minor loop](docs/operations/iteration_policy.md).

**Orient:** Find and read the most recent handover (`ls docs/devlog/handovers/ | sort | tail -1`), then read `docs/devlog/roadmap.md`.

**Recovery checks (before creating the handover):** Run the Trigger B check and compaction check per the Step 1 entry condition in `iteration_policy.md`.

**Determine session focus:** $@ — if supplied, this takes priority over the Next session section of the prior handover. The prior handover's Next session is still useful context but is not the directive. If nothing was supplied, derive session type and objective from the prior handover's Next session section. Session types and their shortforms are defined in `handover_policy.md` — Session Types.

**Create the handover** per `handover_policy.md`. Set Status to `Active`.

---

Two questions must be answered and confirmed before any work begins. Both gates apply to every session regardless of type or size.

**Gate 1 — What is being asked? (Step 1b)**

Derive the scope from the argument, the prior handover, and the roadmap. Read any files needed to make the scope concrete — what files will change, what will not change, and why. Then present:
- What is in scope this session and why
- What is explicitly deferred and why
- Any questions that must be resolved before work can begin

If scope cannot be confidently derived, ask the operator one question at a time until it can. Do not proceed with a best guess. Do not produce any file, code, or structural output until the operator confirms scope and sends an explicit release.

Stop here and wait for the release before continuing.

**Gate 2 — What does done look like? (Step 6)**

Once Gate 1 is released, state what a successful output looks like. For each criterion, verify before presenting: can the operator run a command and observe a result without reading source code? If not, rewrite it. Criteria may be brief for simple sessions — one line is fine if it is specific. Every session that touches architecture must include: *"Architecture documents in scope describe the system as built."*

Wait for the operator to confirm. Once confirmed, update the handover — replace `Not yet defined.` with the confirmed criteria. The handover is the canonical location for AC; chat is not.

Implementation does not begin until both gates are confirmed.
