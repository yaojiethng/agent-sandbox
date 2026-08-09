# Gotchas

A persistent record of recurring agent mistakes and code smells witnessed by the operator, chiefly via mid-turn steering. Recorded by the operator. Surfaced to the agent at session open as a primer. Fixed by the agent.

**Writer:** operator.
**Reader:** agent (session-open primer) and operator (pre-close review gate).

This file is tied into the session's Mid-session findings for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble — length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown
## [<A|G>] <date> — <short title>

state: open                        // open | mitigated | probation
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```

An entry is deleted when resolved. A resolved durable fix is recorded in the changelog and the roadmap, not in this file. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Open gotchas

This section holds the active gotcha backlog. The agent reads it at session open (Step 1) and avoids or re-checks the patterns during the session. A sweep applies a gotcha fix across recent code at sub-milestone cleanup. When gotchas accumulate, fold the recurring patterns into a skill so the loaded surface stays small.

### [G] 2026-08-09 — Policy-text changes need per-section approval even after task-list confirmation

state: open
scoped: none
legacy: none
mitigation: when a session directive names policy files (docs/operations/, AGENTS.md), treat a scope/AC gate confirmation as task-list approval only. Present each changed policy section and wait for operator approval before writing it. A gate confirmation is not policy-text approval.

### [G] 2026-08-09 — Set handover Status Closed before the final commit (close = the commit)

state: open
scoped: none
legacy: none
mitigation: the final commit must include the Closed handover. Set Status to `Closed`, then run `git add -A && git commit`. Do not commit then re-amend to add the Closed marker.

