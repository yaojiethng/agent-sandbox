---
date: 2026-10-30
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - The bash maintenance backlog triage

## Objective

Close the bash backlog entries the roadmap names, so the redundant `set -e` guards have a pattern and the circular-sourcing rule stays in `p-27` rather than in an active feedback entry.

## Scope

Continues the parent row **Package skill ingestion as its own workflow** in M3.3.3, from handover `20261030-03`. The working row is **Skill-maintenance backlog triage**.

In scope: one bash pattern entry for the three `set -e` forms the 2026-09-25 entry records; the retirement of that entry and the 2026-08-09 circular-sourcing entry; and the roadmap write-back. The three code lines already landed in `9325cb70`, and the circular source graph is already one-way, so this unit records the rules and retires the entries rather than re-fixing the code.

Out of scope: the source-cycle lint gate, which M3.1.2 owns by operator direction; the ADR, which is withdrawn because `p-27` already states the rule; the 2026-09-19 shellcheck-prose and 2026-10-26 mechanism entries, which already name their patterns; the other M3.3.3 rows; a new bash skill; and the milestone changelog.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The bash pattern set gains `p-62`, one past the highest `p-61`, stating the three `set -e` forms: `exit $?`, a `cmd \|\| exit 1` guard, and a default the consumer re-applies; it says the line is a code row, no unit can pin it, and a terminal `exit` that stops a second path stays. | `rg -n '^## p-62'` in the pattern set; read the entry; the id list tail shows `p-60`, `p-61`, `p-62`. | Agent [x] |
| The 2026-08-09 circular-sourcing and 2026-09-25 `set -e` feedback entries are gone, and the other Bash entries remain. | `rg -n 'Circular sourcing between\|A guard that errexit already provides' devlog/AGENT_FEEDBACK.md` returns no output; the shellcheck-prose and mechanism headings remain. | Agent [x] |
| The roadmap row is `[x]` with handover `20261030-04`, names the three `set -e` instances rather than three entries, and records that the source-cycle gate is M3.1.2. | `rg -n 'Skill-maintenance backlog triage' devlog/roadmap.md`; read the row. | Agent [x] |
| Every decision recorded in the handover is realized: `p-62` exists, `p-27` and no ADR carry the circular rule, and the two feedback entries are removed. | Read `## Decisions`; check each destination. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The three `set -e` forms land as one pattern entry, p-62, in `failure-handling.md`; `shell-options.md`'s p-18 keeps the errexit-suspension variant. | One entry is one form, and the form decides what a guard's status means; p-18 already owns when `-e` is in force. | `failure-handling.md` |
| The circular-sourcing rule stays in `p-27` and takes no ADR; the source-cycle lint gate is M3.1.2. | `p-27` already states the one-way graph and the leaf-library extraction; the missing enforcement is a gate, which M3.1.2 owns, so a separate ADR would repeat the pattern without adding a guard. | `sourcing.md` and the M3.1.2 roadmap group |
| The two feedback entries are dropped rather than kept on probation. | Their fixes have been durable since 2026-08-09 and 2026-09-26, and the pattern and the fixed source graph now carry their rules; the feedback file holds the active backlog. | `AGENT_FEEDBACK.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row names three `set -e` "entries"; the record holds one 2026-09-25 entry with three instances, and the three code lines are already gone in `9325cb70`. | Reconciliation | The unit adds the pattern and drops the one entry; the roadmap wording is corrected to "instances". | `roadmap.md` |
| The circular-sourcing entry is already `mitigated`; `p-27` states the rule, and the source-cycle lint gate is the missing enforcement. | Reconciliation | The entry is dropped; the gate stays in M3.1.2. | `roadmap.md` |
| The Bash section also holds the 2026-09-19 shellcheck-prose and 2026-10-26 mechanism entries, both mitigated and both with a pattern. | Scope | They are outside this row and stay in place. | this handover, out of scope |
| The ADR proposed at the scope gate is withdrawn on operator direction: the rule is a pattern plus a lint rule, and M3.1.2 already owns the gate. | Scope | No ADR is written; the handover's ADR decision and pending question are removed. | this handover, decisions |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/failure-handling.md` | Added `p-62`, the three redundant `set -e` forms and the code-row verdict. |
| `devlog/AGENT_FEEDBACK.md` | Removed the 2026-08-09 circular-sourcing and 2026-09-25 `set -e` entries. |
| `devlog/roadmap.md` | Marked the triage row `[x]`, named the three instances, and recorded that the cycle gate belongs to M3.1.2. |
| `devlog/handovers/20261030-04-workflow-bash_backlog_triage.md` | Closed this handover. |
