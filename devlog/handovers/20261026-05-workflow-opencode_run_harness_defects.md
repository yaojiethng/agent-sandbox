---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - Five traps in `opencode run` as a dispatch backend

## Objective

Record the five ways a `opencode run` loop fails while looking healthy, so the next harness that drives it does not spend a session rediscovering them. Each trap was found by running a hundred-and-seventeen-cell grid against the free model, and each one either exits silently, hangs to its wall cap, or returns an empty turn with a zero exit code.

## Scope

The invocation surface only: how the process is called, what it does with stdin, what its refusals look like on the wire, how a SQLite file shared by several processes behaves, and what `--variant high` costs. Not in scope: the model's judging quality, which the grid did not measure, and the seat contract, which `.agents/drafts/seat-contract-run.md` already carries.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every trap states the symptom it produces, the evidence that identifies it, and the correction | the `## Findings` table, five rows, each with a symptom and a correction | Agent [x] Operator [ ] |
| The instrument that made the failure visible is recorded, so the next reader can look at a run rather than a chat log | the session-store query in `## The instrument` | Agent [x] Operator [ ] |
| Each trap names where this repository must learn it | a `Home` column, naming a file or a draft | Agent [x] Operator [ ] |
| Nothing here rules on the model's output | a search for a fault count or a comparison | Agent [x] Operator [ ] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A dispatch closes the child's stdin | `opencode run` reads stdin, so a loop that feeds its plan through a redirect loses lines to the child and exits early with no error | this handover |
| A refusal is matched on every shape it arrives in | the free tier reports the same condition as a JSON body in one path and as an `AI_APICallError` string in another, and a detector that knows one shape hangs instead of stopping | this handover |
| A cell is repeated only on `database is locked` | it is the one condition that clears on its own; repeating a timeout multiplies the delay by the retry count and hides the failure | this handover |
| The free model runs `--variant medium`, never `high` | at `high` it spends the entire reasoning budget and returns no text, with a zero exit code | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `opencode run` inherits stdin, so a driver that feeds its work list through a file redirect loses the list to the child process: the read loop reaches end of file and the run ends after one cell with no message and a clean exit | defect | a grid shrinks from thirteen cells to one and reports success | `scripts/dispatch.sh`, which must close stdin on every dispatch |
| The free tier's refusal arrives in two shapes, `{"type":"FreeUsageLimitError"}` in the error stream and `AI_APICallError: Free usage limit reached` in the run log, and a detector that matches only the first keeps launching cells that will never answer | defect | every remaining cell burns its full wall cap, which reads as slowness rather than as exhaustion | the quota handling in any dispatch ladder, and the seat contract's availability axis |
| Several `opencode run` processes share one SQLite file at `~/.local/share/opencode/opencode.db`, and six at once produce `database is locked` on a cell that then exits non-zero | defect | one cell in six fails for no reason visible in its own brief, and its failure looks like the model's | the concurrency default of any runner driving this backend |
| A retry written as "repeat on a non-zero exit" repeats timeouts too, so a cell that hit its cap is tried three more times at the same wall cap | defect | a five-way block stalls for half an hour and the summary reports timeouts that were never diagnosed | any runner with a retry, which must key the retry to the one transient error |
| `--variant high` on `deepseek-v4.1-flash-free` returns an empty turn: `{"input":3144,"output":0,"reasoning":32000}` followed by `step-finish`, with no text and a zero exit code | defect | a cell counts as a success while carrying no fault list, so a comparison reads a silent zero as a real result | `.agents/model-recommendations.md` and any eval case that pins a free assignment |

## Completed

| File | Change |
|---|---|
| `devlog/handovers/20261026-05-workflow-opencode_run_harness_defects.md` | this handover: five traps, their evidence, and the store query that exposes a run's token counts |

## The instrument

A run's token counts are the only evidence that separates "the model answered nothing" from "the model was never asked". They survive the process, in the OpenCode store, and `node:sqlite` reads it without a client:

```js
const db = new DatabaseSync('/home/agentuser/.local/share/opencode/opencode.db', {readOnly: true});
// tables: session, message, part; each row carries a JSON `data` column
const rows = db.prepare('select id from message where session_id=? order by time_created').all(sessionId);
```

Each `message` row's `data` carries `role`, `modelID` and a `tokens` object; each `part` row carries a `type` of `text`, `reasoning`, `tool` or `step-finish`. An assistant message whose tokens read `output: 0` with a large `reasoning` count, followed by `step-finish` and no `text` part, is the empty turn. The session id is printed by the failing run's own log line, as `session.id=ses_...`.
