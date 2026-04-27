---
description: Open a new session. Finds the latest handover, runs recovery and compaction checks, creates the new handover, then gates on scope and acceptance criteria before any work begins. Use at the start of every session. Accepts an optional argument describing the session type and focus — this takes priority over the Next session section of the prior handover.
argument-hint: "[workflow|impl|design|spec|plan|story|study|chore] <focus description>"
---

> $@

## Orient

Find and read the most recent handover:

```
ls docs/devlog/handovers/ | sort | tail -1
```

Then read `docs/devlog/roadmap.md`. No other files are needed at this stage.

---

## Recovery checks

**Trigger B check:** Compare the sub-milestone named in the prior handover's Next session section against the sub-milestone currently marked active in `roadmap.md`. If they differ, Trigger B has not run — run it now before proceeding. If they match, no action needed.

**Compaction check:** A task group is fully complete when every checkbox in it is checked. Scan the active sub-milestone task list in `roadmap.md`. If any group meets this condition, compact it — replace the group header and checklist with a single outcome sentence describing what the system can now do. If no groups are fully complete, note this and continue.

Report the outcome of both checks before proceeding.

---

## Session directive

Read the prior handover's Next session section before evaluating the directive.

| Session type | Shortform |
|---|---|
| Design | `design` |
| Spec | `spec` |
| Implementation | `impl` |
| Story | `story` |
| Investigation | `study` |
| Planning | `plan` |
| Workflow | `workflow` |
| Housekeeping | `chore` |

If the directive slot is empty:
- Follow handover policy. Derive session type and objective from Next session.

If the directive slot is non-empty:
- Identify the session type from the directive using the table above (explicit shortform, or implied by the language used). If the type cannot be determined, ask the operator to name it before continuing.
- **Step 1 — Compare session types.** Extract the session type implied by Next session. If the directive's type and Next session's type do not match, this session diverges — go to Diverges below.
- **Step 2 — Compare topics.** If types match, check whether the subject of the directive overlaps with the scoped task described in Next session (shared keywords, named files, or task references). If there is no recognisable overlap, ask the operator whether this session supersedes or adjusts prior work before continuing.
  - **Continues or adjusts prior work:** Reflect the directive as the session's focus and objective — it takes priority over the specific framing in Next session, but does not change the session type or supersede the work in progress.
  - **Diverges from prior work:** This session supersedes the prior implementation thread. Record a Context handover line in this session's Next session so the implementation thread can be resumed. Read [`handover_policy.md` — Session Types](docs/operations/handover_policy.md#session-types) for the supersede format — run `grep -n "## Session Types" docs/operations/handover_policy.md` then range-read that section.

---

## Create the handover

Before creating the handover, read the session open rules:

```
grep -n "### At session open" docs/operations/handover_policy.md
```

Range-read from that line through `### At scope confirmation`. Then create the handover per those rules. Set Status to `Active`.

---

## Gate 1 — What is being asked? (Step 2)

Both gates must be answered and confirmed before any work begins. They apply to every session regardless of type or size.

Derive the scope from the argument, the prior handover, and the roadmap. Read any additional files needed to make the scope concrete — what files will change, what will not change, and why. Then present:
- What is in scope this session and why
- What is explicitly deferred and why
- Any questions that must be resolved before work can begin

If scope cannot be confidently derived, ask the operator one question at a time until it can. Do not proceed with a best guess. Do not produce any file, code, or structural output until the operator confirms scope and sends an explicit release.

Stop here and wait for the release before continuing.

## Gate 2 — What does done look like? (Step 5)

Once Gate 1 is released, state what a successful output looks like. For each criterion, verify before presenting: can the operator run a command and observe a result without reading source code? If not, rewrite it. Criteria may be brief for simple sessions — one line is fine if it is specific. Every session that touches architecture must include: *"Architecture documents in scope describe the system as built."*

Wait for the operator to confirm. Once confirmed, update the handover — replace `Not yet defined.` with the confirmed criteria. The handover is the canonical location for AC; chat is not.

Implementation does not begin until both gates are confirmed.
