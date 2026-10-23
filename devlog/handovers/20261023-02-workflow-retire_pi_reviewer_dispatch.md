---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Retire `pi-reviewer-dispatch`

## Objective

Give the review dispatch one mechanism with one owner and delete the skill that wrapped it: the runner moves to the provider config as a script beside the `AGENTS.md` section that instructs a dispatch, takes its pair from the `_REVIEWER` role line instead of pinning two, and the skill's contract moves into that section. Ends with `pi-reviewer-dispatch` absent from the tree and the agent home, no model literal in the runner, and the ported test green.

## Scope

The roadmap row **Retire `pi-reviewer-dispatch` into its mechanism owner**, a sub-row of **Retire the policy form** under M3.3.2. It belongs there because Handover `20261023-01` created it: the advisor retirement took the brief half of that skill and left its mechanism, so the row is the retirement's own follow-through. It was first filed under M3.2.2 and moved here at the operator's direction, because that sub-milestone opens later and finished work cannot sit under a sub-milestone that has not started.

The skill holds two things. Its brief half -- the read-only frame, the handling of a returned report, agreement between the pair as the signal -- is already in `skill-scaffolder`'s review runbook. Its mechanism half is the runner script, the three refusals, the log shape and the model read-back, and it has no second home. This iteration moves that half to `src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh`, which the container provisions to `$AGENT_HOME/agent/bin/review-dispatch.sh`, and then deletes the skill directory, its seeded copy and its test.

The pair is the defect this move removes. The script pins `opencode-go/deepseek-v4.1-flash` and `deepseek/deepseek-flash`; its own `SKILL.md` states `openrouter` with `z-ai/glm-5.3-flash` and `opencode-go` with `step-5-preview-free`; the provider `AGENTS.md` and the skill's own contract both say every review seat takes its pair from the `_REVIEWER` line, which names `deepseek/deepseek-flash` at `high`. Three statements, and the script follows none of them. The runner takes the pair as an argument, so the call site resolves the role and the runner carries no model at all.

Out of scope: the seat contract, `.agents/drafts/seat-contract-run.md`, which replaces the resolver, the adapters and the role table and will rewrite this runner from above; the instruction-surface gate in `.agents/drafts/close-the-model-bypass-run.md`, which stays that run's work; `opencode-dispatch`, which keeps its script inside its skill directory because it dispatches a worker with a worktree rather than a read-only reviewer; and M3.2.2's review-surface consolidation, which may merge the runbook this runner serves.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill is gone from the tree and the agent home | `test ! -e src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch` and `test ! -e /home/agentuser/.pi/agent/skills/pi-reviewer-dispatch` exit 0 | Agent [x] |
| The mechanism has one executable owner | `src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh` exists, and `bash scripts/check_shell.sh` reports 0 warnings across 194 files | Agent [x] |
| The runner carries no pair | `grep -En 'deepseek\|openrouter\|opencode-go\|z-ai\|step-5'` on the runner prints nothing, and `tests/test_review_dispatch.sh` holds that as a case | Agent [x] |
| The shipped section names the runner and no longer names the skill, in both copies | `grep -c 'pi-reviewer-dispatch'` is 0 and `grep -c 'review-dispatch.sh'` is 2 in the repo copy; `diff` of the repo copy against `$AGENT_HOME/agent/AGENTS.md` is empty | Agent [x] |
| The reviewer contract survives somewhere shipped | the section carries read-only, one brief passed verbatim, its own session and log, report shape, the model read back in step 3 and the worker-fan-out non-goal; pair agreement is the runbook's step 3 | Agent [x] |
| The ported test holds the gates | `bash tests/test_review_dispatch.sh` passes 9 cases: the four refusals, the malformed pair, the three result checks and the no-literal assertion; `bash scripts/run_tests.sh` reports 1272 passed, 0 failed | Agent [x] |
| No carrier of the deleted path is left outside history | `grep -rn 'pi-reviewer-dispatch' src workflow tests scripts .agents/drafts --include=*.md --include=*.sh` returns only the dated carrier list in `close-the-model-bypass-run.md`, which states of itself that it ages | Agent [x] |
| The roadmap row closes with its landing note | the row reads `[x]` naming the runner path and Handover `20261023-02` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The runner moves to `config/agent/bin/review-dispatch.sh`, provisioned to `$AGENT_HOME/agent/bin/` | The instruction that owns the mechanism is `## Running Review Subagents` in the same config tree, and the entrypoint provisions that tree whole, so instruction and runner travel together and the invocation path changes by one segment | this record |
| The runner takes `<brief> <scratch> <pair> <level>` and resolves nothing | A runner that reads the role table is a second resolver beside `src/libs/dispatch.sh`, and a runner that hard-codes a pair is the bypass. The call site resolves `_REVIEWER`; the runner runs two seats of what it is given | this record |
| The reviewer contract moves into `## Running Review Subagents`, not the runbook | The section is shipped and therefore reachable from `/document` and `/iter`; the runbook is project-only, so a shipped prompt cannot name it | this record |
| The test is ported rather than deleted | The refusals are gates, and the run's history has one empty log read as "nothing to report"; a suite that stops holding them turns every one into an instruction an actor must remember | this record |
| The shipped `AGENTS.md` is edited in two copies, the repo source and `$AGENT_HOME/agent/AGENTS.md` | The running agent reads the installed copy, so an edit to one alone leaves the live instruction and the shipped one divergent | this record; the project `AGENTS.md` |
| The section takes the minimum edit, not a restructure | Another session owns that section's shape for the dispatch work, so this unit changes the opener, adds the contract paragraph, replaces step 2 with the runner invocation and states the fan-out non-goal, and leaves every other paragraph verbatim. The rules the skill alone held are kept because deleting the skill removes their only copy | this record |
| The row files under M3.3.2, not M3.2.2 where Handover `20261023-01` opened it | M3.2.2 has not started, and its sequencing line puts it after the M3.3.2 retirement; a closed row under an unopened sub-milestone is filed out of order. M3.3.2 owns the retirement this row follows through | this record; the roadmap row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The linking gate flagged a dead target: the seat-contract draft linked the deleted `SKILL.md` | Defect | The gate fails on a carrier of this unit's deletion | Fixed here: the record link retargets the runner, and two sentences that asserted the pinned pairs in the present tense now name the handovers that removed them |
| The bypass draft's carrier list still prints the deleted script path | Stale measurement | A reader could treat the row as a live caller | Left as is: the list is a measurement the document dates to 2026-10-18 and instructs the reader to re-derive, so a stale row is its designed state rather than a pointer |
| The section the contract moved into is being restructured by the dispatch session | Coordination | This unit's contract paragraph may be rewritten by that session | Reported, not resolved: the text is placed to survive that rewrite, and the dispatch session owns the section's shape |
| The M3.6.1 closed row lists the skill in the set an unfiltered cell handed a worker | Stale example | A reader could take the list for the current emitted set | Not a carrier: the sentence is the bug's evidence, and the same row records that the provider filter landed |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh` | new runner: pair and level as arguments, refuses a malformed pair, an empty brief, an unwritable scratch directory and a dirty tree, fails a seat that logs nothing or binds another model, one log per seat |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | `## Running Review Subagents` names the runner, carries the reviewer contract and the fan-out non-goal; step 2 is the runner invocation |
| `/home/agentuser/.pi/agent/AGENTS.md` | the same text, installed copy |
| `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/{SKILL.md,dispatch.sh}` | deleted |
| `/home/agentuser/.pi/agent/skills/pi-reviewer-dispatch/` | the seeded copy, deleted |
| `tests/test_review_dispatch.sh` | new, 9 cases ported from the old test plus the malformed pair and the no-literal assertion |
| `tests/test_pi_reviewer_dispatch.sh` | deleted |
| `src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh` | the header's contrast now names the review runner |
| `.agents/drafts/seat-contract-run.md` | the dead record link and two present-tense claims about the pinned pairs |
| `devlog/roadmap.md` | the row closed with its landing note |
| this record | `Status: Closed`, criteria and completed set |
