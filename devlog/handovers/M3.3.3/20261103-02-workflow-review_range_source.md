---
date: 2026-11-03
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the review surface is a reading path

## Objective

Place each fact a reviewer needs at the point it is needed, so a seat reaches a defensible range, a blocker test and a stop condition without asking, and reads no file it does not need.

## Scope

The roadmap row **The review surface is a reading path, designed from a failed run** under M3.3.3.

The evidence is one run: pi session `01a19317-5d19-746c-a613-7ac78f3fa343`, the thermonuclear review through `code-review`, 2026-10-31 17:52 to 2026-11-02 15:44. Starting point is the two-file edit this iteration opened with; the operator reframed the task at the pre-close gate after seeing that the duplicate was still a duplicate.

Out of scope, each with its reason: the vendored `thermo-nuclear-code-quality-review` runbook keeps its text, because a local edit would be an adaptation no store edge records; and the seat's model resolution and log mechanics stay in the translation table, because a caller never decides them.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The shell names the three readers and what each reads, and the runbook is off the caller's path | `sed -n '20,30p' workflow/coding-agent/skills/code-review/SKILL.md` | Agent [x] |
| The parameters are one section: the two facts no runbook can know, the runbook's `Accepts`, and the propose-then-confirm rule | `sed -n '32,45p' workflow/coding-agent/skills/code-review/SKILL.md`; `grep -c init_sha` = 1 there, 0 in the loop and the runbook | Agent [x] |
| A cold read of `/code-review thermonuclear-review` produces a proposal with each value's source and stops before a seat, and a value it cannot derive is a question | fresh `pi -p` on the current tree: derived the range from `.git/SESSION_STATE`, cited the record for each value, then asked which range and stopped | Agent [x] |
| The loop is a state machine: a record template, a two-field predicate and four transitions, with no second statement elsewhere | `sed -n '/## The loop/,/^## /p' workflow/coding-agent/skills/code-review/SKILL.md`; `ls .../code-review/references/loop.md` misses | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The reading path is three readers and three layers: the caller reads this file and the loop, the seat reads its brief and one runbook, the operator reads the proposal | The failed run's seats and its caller shared one context; separating them is what keeps the runbook and the mechanics out of the operator's way and the loop out of the seat's | the shell's `## The reading path`, this record |
| The parameters are proposed with their source and confirmed, and an underived value is asked rather than filled | The run's two operator turns were spent on a value the agent had decided for itself; a proposal with a named source is checkable, and a confirmation is the alignment | the shell's `## The parameters`, this record |
| The range default is the session's branch point, and it is marked as a proposal | The run proposed `085e20dd~1..HEAD` from the branch's size and was overruled; the session's own start is the base its changes are attributed to | the shell, this record |
| The loop is a state machine in the shell, not a rules file | Its only reader read the shell immediately before and after it, so the split earned nothing; and a loop an agent executes reliably needs written state, a two-field predicate and data termination, not prose | the shell's `## The loop`, this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The failed run: 15 rounds over two days, 13 context compactions, `BLOCK` in 9 messages and `ACCEPT` twice, from one review of one branch | measured | a loop with no consumer test does not converge; it exhausts context until someone stops it | the read path this iteration lands |
| Its first four minutes went to the base: `main..HEAD` measured at 418 commits and 1,624 files, `085e20dd~1..HEAD` proposed, then overruled by operator turn `[47]`; turn `[77]` spent on the ambiguity | measured | two operator turns for a fact the surface could state, on a run that then cost two days | the range rule, now stated once |
| The vendored `thermo-nuclear-code-quality-review` runbook is vendored from `cursor/plugins` and the source store carries no edge for it | defect | the artifact is an adaptation nobody recorded, so a bump has no base to diff | a roadmap row, filed: **The code-review runbook's vendored copy has no store edge** |
| The 2026-10-31 operator entry in \`devlog/AGENT_FEEDBACK.md\` reads \`open\`; the fix it asks for is this row's | record | the entry is the row's evidence and its state should follow the row | this iteration: moved to \`mitigated\` |
| I recorded that the runbooks were separately invocable and filed a row for the seam; the map shows 12 project, 31 provider and 10 agent-sandbox skills, none of them a runbook, because a nested runbook is not discovered | defect in this record | a record naming a fact the tree contradicts is worse than a missing one, and it cost a row | fixed in this iteration: the row is withdrawn and the entrypoint claim corrected |
| The records named the shell section by its first title after the section was split into the reading path and the parameters | record | a record naming a heading that does not exist is the carrier drift this repository gates elsewhere | fixed in this iteration; the cold read is what found it |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/SKILL.md` | new `## The parameters` stating the three caller facts and the stopping-rule pointer; the translation table's scope row points at it; the blocker-bar precedence line |
| `workflow/coding-agent/skills/code-review/SKILL.md` `## The loop` | the state record, the two-field predicate and the four transitions |
| `workflow/coding-agent/skills/code-review/references/loop.md` | deleted; its readers read the shell |
| `.agents/drafts/parallel-work.md`, `.agents/drafts/sequential-work.md` | repointed at `## The loop` |
| `devlog/roadmap.md` | the row's outcome, and the store-edge finding as an open row |
| `devlog/AGENT_FEEDBACK.md` | the 2026-10-31 `[O]` entry moves to `mitigated` |
| this record | four criteria accepted, four decisions, four findings |
