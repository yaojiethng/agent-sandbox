# The Policy Frontier, from the Corpus - Run

Filed 2026-10-24 for the roadmap's `M3.6.2` row **The policy frontier, from the corpus**, which replaces the row that counted requests per completed task. Read this brief with that row: the row is the task, this file is the method.

## Purpose

Answer one question with evidence already on disk: what does the dispatch policy this repository actually has cost, per delivered change set, in dollars, wall clock and requests. The question replaces a bakeoff that could not run, because two of its three candidates are not expressible in this tree and the third shipped as a route state.

## The premise, as one falsifiable sentence

A dispatch policy's cost is measurable from the session corpus alone -- every attempt's dollars and wall clock are recorded per message, and every delivered change set is a worktree with commits -- so the incumbent policy's frontier can be printed without building an instrument.

If the join from a session to a delivered change set does not hold, the premise fails and the run reports that instead of a table.

## What is already measured - do not re-derive

| Fact | Source |
|---|---|
| 706 sessions, 104 distinct cwds, 233 zero-cost and 473 paid, 48 provider/model pairs | `node scripts/cost_ledger.mjs --root /home/agentuser/.pi/agent/sessions` |
| transcript line types `session`, `model_change`, `thinking_level_change`, `message`; per message `usage.cost{input,output,cacheRead,cacheWrite,total}`, `model`, `timestamp`; `cwd` and `id` in the session header | a sample file under `~/.pi/agent/sessions/<cwd-key>/`, for example `--tmp-sAKVHv-repo--/2026-10-22T09-10-08-721Z_01a162df-fc51-7606-9a05-143a9bb5d94b.jsonl` |
| selection is first-fit over the role line, with cooling and a backoff curve; seats rotate over routable candidates | `src/libs/dispatch/machine.ts` `select()`, `src/libs/dispatch/seats.ts` |
| the walk itself is recorded nowhere; dispatch state is `/tmp/agent-sandbox/dispatch-state-<session>.json` and dies with the container | `src/libs/dispatch/state.ts`; `launch.ts` and `state.ts` write no role |
| no price exists at assignment time, and none may be added | `docs/reference/dispatch.md` `## Requirements` refuses catalogue validation |
| the three candidates were cheapest-first, free-first with paid fallback, capability-first | `.agents/drafts/cost-aware-dispatch-run.md` `## Phase 4` |
| the free tier's scarce resource is requests: one shared pool of 200 requests per IP per day, so a per-token price misranks a cheap model that needs many turns | the row this brief serves, in `devlog/roadmap.md` |

## The rulings - lines the run must not cross

1. **No price table, no catalogue validation.** Refused on two measured failures. A cost input may only come from a recorded `usage.cost`, which measures what happened instead of guessing a catalogue.
2. **No policy is implemented.** This run measures and decides. A cost-weighted selection is a later row, opened only if the frontier shows a gap worth paying for.
3. **No inferred role.** The transcript records the assignment, never the role, and two roles can share an assignment. A role column would be a derived value the record does not own.
4. **No derived total without its subset.** Every number names the corpus it came from and the command that printed it.
5. **The session store is read-only input.** Nothing writes to `~/.pi/agent/sessions`.
6. **A `$0.00` total is reported as free-or-unpriced**, never as free by default, unless the run establishes which.

## The phases

| Phase | The question | The deliverable | Depends on |
|---|---|---|---|
| P1 | Does `cwd` join a session to a worktree that produced commits? | the join key and its coverage, or the finding that it does not join. Worktrees under `/tmp` may be pruned; the branch name in the cwd key is then the fallback key | -- |
| P2 | What does the incumbent cost per delivered change set, by assignment? | the frontier table and the command that prints it, across dollars, wall clock and requests | P1 |
| P3 | What does each candidate need, and does that data exist? | the candidate/data table, with the free-first-equals-cheapest-first collapse stated in numbers, and the capability axis pointed at the `dead` state | P2 |
| P4 | What follows for the row? | the study record and the roadmap row's fate: a policy with its data, or a closure | P3 |

## The run shape

One reading pass over the corpus. Widest wave: one. No fan-out -- this is a read, not a dispatch. Review is two `_REVIEWER` seats over the record.

## The work units

One unit, per the iteration protocol's propose-no-split default:

| Unit | Commit type | Owned files | Handover |
|---|---|---|---|
| The frontier record and the row's fate | `docs` | a new study record under `devlog/discussions/`, `devlog/roadmap.md` | the iteration's own handover |

Fork, with the default taken: if P1 shows the join needs code, the unit splits and the `feat` unit for the join lands first, with its own test. The reversing word is "split it".

## The model assignment

`_IMPLEMENTER`, one seat for the run. `_REVIEWER`, two seats over the record. The roles resolve through `.agents/model-recommendations.md`; this brief names no model.

## The check that proves the result

A reviewer reruns the printed commands and gets the same table, picks two session ids out of it and confirms their dollars and wall clock by hand against the transcripts, and finds every number in the record's prose in a printed table. A number that cannot be reproduced is deleted rather than softened.

## Constraints and invariants

No price table; no policy implementation; no inferred role; no total without its subset; the session store is read-only.

## What would settle this brief

Three inferences keep it a draft:

- whether the corpus's cwds still exist as directories, since a pruned `/tmp` worktree breaks the join;
- whether `usage.cost` is populated for every runtime in the corpus -- it is populated in all 706 rows measured, all of them `pi`;
- whether enough sessions are dispatched rather than ad-hoc to make a delivered-change-set denominator meaningful, since 48 provider/model pairs appear against a five-role table.
