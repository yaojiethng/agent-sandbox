# Gotchas

A persistent record of recurring agent mistakes and code smells witnessed by the operator, chiefly via mid-turn steering. Recorded by the operator. Surfaced to the agent at session open as a primer. Fixed by the agent.

**Writer:** operator.
**Reader:** agent (session-open primer) and operator (pre-close review gate).

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble - length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown
## [<A|G>] <date> - <short title>

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

### [G] 2026-08-09 - Policy-text changes need per-section approval even after task-list confirmation

state: open
scoped: none
legacy: none
mitigation: when a session names policy files (`docs/operations/`, `AGENTS.md`), a released task-list gate confirms scope and acceptance criteria, not policy text. Content is confirmed; gates and policy text are released. Present each changed policy section verbatim in chat and wait for an explicit release before writing it.

### [G] 2026-08-09 - Session-relative finding numbers used outside their source session

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-03`): `documentation_policy.md` gained `### Numbering and cross-references` (a number is valid only in the conversation or document where it appears; outside the defining place, use the descriptive name or a link; persistent records do not take numbers from transient lists) and `AGENTS.md` gained the context-aware numbering + code-comment clauses. The known instances (design doc "Session 11b-11e" headings, "M2.7 item 8" code comments, handover_policy "item 13" example) were remediated in the same session. Monitor for resurfacing; when confirmed durable, delete and record in changelog/roadmap.

### [G] 2026-08-09 - Set handover Status Closed before the final commit (close = the commit)

state: mitigated
scoped: none
legacy: none
mitigation: the final commit must include the Closed handover. Set Status to `Closed`, then run `git add -A && git commit`. Do not commit then re-amend to add the Closed marker. Marked mitigated 2026-08-19 (P1): the durable policy fix landed in session `20260809-05` (P2)  --  `iteration_policy.md` Step 8 now reads "The close is the commit"  --  and practice held across the intervening sessions. Monitored through the next few closes; delete when confirmed durable.

### [H] 2026-08-12  --  Library functions must `return`, not `exit`

state: open
scoped: `src/libs/*.sh`, `src/build/*.sh` (sourced libraries, not standalone scripts)
legacy: not swept, fixed on contact
mitigation: library functions sourced by entrypoint scripts must use `return 1`,
not `exit 1`. All entrypoints run under `set -euo pipefail`, so a non-zero
return triggers script exit identically. Bare `exit` in a sourced function
is a latent bug if the function is ever called from a different context
(e.g. test harness, sub-shell, interactive use). Entrypoint scripts
(`scripts/*.sh`) may use `exit` legitimately. Canonical rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md) rule 3.1.

### [G] 2026-08-18 - Table-row append edits must keep the anchor row in newText

state: open
scoped: devlog markdown tables (handovers, design records, feedback/gotchas)
legacy: not swept, fixed on contact
mitigation: appending a row to a markdown table three times in one session replaced the
anchor row instead of appending (N5-record twice, D7 once  --  each time newText carried
only the new row, dropping the anchor). For any append, oldText must be the anchor row
AND newText must be that same anchor row followed by the new row(s). After a multi-row
table edit, re-grep the table"s row keys and confirm every prior row still exists before
continuing. Same family as the "did the write land?" reflex but distinct: that catches
un-applied edits, this catches overwrite-instead-of-append. Cross-reference: the
agent-side family record is AGENT_FEEDBACK ("did the write land?" reflex entry,
2026-08-09, with resurfacing instances).

### [G] 2026-08-23  --  Close-out propagation greps must sweep the full tests tree

state: open
scoped: M2.6 (any lib/production change with contract language)
legacy: none
mitigation: handover 20260823-09 changed `current_sig`"s contract but its close-out
residue grep covered only `src/`, `scripts/`, and the directly-edited test file  --  stale
"memoized" contract comments survived in `tests/test_trace_build.sh` and
`tests/test_session_inventory.sh` until the operator challenged propagation (fixed within
the same handover"s scope). Rule: the AC "no references to <old contract> remain" sweep is always
`grep -rn <term> scripts/ src/ tests/ docs/ Makefile`, never a file subset; test
comments asserting removed behavior are contract references and count as residue.

### [G] 2026-08-23 - Hollow iterations: content that should be amendments to an open handover

state: open
scoped: session workflow (any active session)
legacy: none
mitigation: operator-authored. During 20260823, two standalone handovers were cut for
content below the unit-of-work threshold: a two-line roadmap registration (-13, deleted)
and a fix iteration that should have amended the same-day ASCII-sweep iteration (renumbered
into -11). Rule: before opening a new handover, check whether the content amends, extends,
or completes work from an Open or same-session Closed handover -- if so, extend that
handover and let the delivery commit absorb it (squash per git policy). Minimum unit of
work for a new handover: implementation, investigation, or a substantive decision. Pure
record-keeping rides along with the next real unit of work.

### [G] 2026-08-31 - Roadmap open-item status can go stale against closed handovers

state: open
scoped: devlog/roadmap.md (M2.6 and later  --  any active milestone task list)
legacy: none
mitigation: several roadmap items were still `- [ ]` though the handover that resolved
them was already Closed (dry-run probe-check harness `20260828-03`, make resume volume
reuse / Bug D `20260828-04`, and the campaign-findings basket all-`[x]` sub-items). All
were cleared to `- [x]` with final-state summaries in `20260831-09` post-close corrections.
Rule: a roadmap task must be marked `- [x]` in the same iteration its resolving handover
closes -- the handover's Closed state is the trigger, not a later cleanup pass. At iteration
close, cross-check every `- [ ]` entry against its referenced/latest handover's Status; if
the handover is Closed (and its ACs met), flip the roadmap item and note it as a post-close
correction. Do not trust the checkbox to have been maintained; verify it against the
handover record.

### [G] 2026-09-01 - Editing or composing a doc whose own policy text forbids the pattern: verify the recipient file's rules first

state: open
scoped: M2.6
legacy: none
mitigation: when composing or editing a document, open the recipient file
and check its own formatting rules before writing prose. I manually column
wrapped two policy documents at ~80 characters; the very file being edited
(documentation_policy.md `### Line wrapping`) forbids exactly that -- prose is
written as single-flowing paragraphs, one paragraph per line, no manual wrap.
The compliance failure was visible from the file itself, so it should not have
required operator steering to catch.

Cross-reference: consolidated agent-side record is AGENT_FEEDBACK (hard-wrapped
instruction blocks entry, 2026-08-09; resurfaced 2026-09-01, probation lifted to open).

### [G] 2026-09-01 - Broad sweep launched before realigning a redesign task onto its true purpose

state: open
scoped: M2.6
legacy: none
mitigation: when a task is a redesign, confirm the objective and the unit of
work with the operator before starting exploration. I opened this iteration
fixated on the narrow ``partial-supersede status freshness`` framing and ran a
broad roadmap/deferred/gotchas/agent-feedback sweep; the operator steered that
the real objective was a redesign of what an ADR is (a living, component-scoped
rationale record), which subsumed the status problem as a symptom. A redesign
task should first establish purpose, then scope the exploration to it.
