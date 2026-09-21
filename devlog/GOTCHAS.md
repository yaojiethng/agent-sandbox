# Gotchas

A persistent record of recurring agent mistakes and code smells witnessed by the operator, chiefly via mid-turn steering. Recorded by the operator. Surfaced to the agent at session open as a primer. Fixed by the agent.

**Writer:** operator.
**Reader:** agent (session-open primer) and operator (pre-close review gate).

Entries are point-in-time records. Reconcile an entry against the current tree before acting on it. If the tree has outgrown an entry, mark it probation; if the entry is superseded  --  its lesson already carried by another entry or record  --  it jumps to probation as well. Either way, follow the normal procedure: wait to see whether it resurfaces; drop it if it does not.

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble - length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown

## [<A|G>] <date> - <short title>

state: open                        // open | probation | mitigated
                                   // probation = durable fix applied, or the tree has
                                   // outgrown the entry; kept for monitoring, dropped on no resurfacing
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```

An entry is dropped when monitoring confirms the fix durable  --  a probation entry is kept for monitoring and dropped when it does not resurface. A durable fix is also recorded in the changelog and the roadmap. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Open gotchas

This section holds the active gotcha backlog. The agent reads it at session open (Step 1) and avoids or re-checks the patterns during the session. A sweep applies a gotcha fix across recent code at sub-milestone cleanup. When gotchas accumulate, fold the recurring patterns into a skill so the loaded surface stays small.

### [G] 2026-08-09 - Set handover Status Closed before the final commit (close = the commit)

state: mitigated
scoped: none
legacy: none
mitigation: the final commit must include the Closed handover. Set Status to `Closed`, then run `git add -A && git commit`. Do not commit then re-amend to add the Closed marker. Marked mitigated 2026-08-19 (P1): the durable policy fix landed in session `20260809-05` (P2)  --  `iteration_policy.md` Step 8 now reads "The close is the commit"  --  and practice held across the intervening sessions. Monitored through the next few closes; delete when confirmed durable.

### [H] 2026-08-12  --  Library functions must `return`, not `exit`

state: open
scoped: M3 T3 -- sourced-lib / library lint rules
legacy: not swept, fixed on contact
mitigation: library functions sourced by entrypoint scripts must use `return 1`,
not `exit 1`. All entrypoints run under `set -euo pipefail`, so a non-zero
return triggers script exit identically. Bare `exit` in a sourced function
is a latent bug if the function is ever called from a different context
(e.g. test harness, sub-shell, interactive use). Entrypoint scripts
(`scripts/*.sh`) may use `exit` legitimately. Canonical rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md) rule 3.1.

### [G] 2026-09-18 - Mechanical-edit one-liners must carry a match-count guard and a timeout

state: open
scoped: M3 T3 -- tool timeout / run-budget on the bash tool, tests, and lint
legacy: none
mitigation: a perl one-liner intended to count matches in a test file was
written with the `/g` modifier against a full-file slurp; it matched nothing,
but the loop structure ran forever, emitting a line count that grew into the
hundreds of millions before the run was aborted and the log killed. The
deeper fix: a mechanical transform that prints only a summary at the end is
invisible while it spins. Always (1) bound the tool with `timeout`, (2) have
the transform emit a match/replacement count to stderr BEFORE any output, and
(3) diff against the input to verify the change before committing. A
long-running transform with no stderr progress is the signal to inspect the
loop, not to wait. The standing order to run every script through `timeout`
is withdrawn: a blanket timeout on a simple script maxes out the wait every
run. Move to a test harness with per-test timeouts.
