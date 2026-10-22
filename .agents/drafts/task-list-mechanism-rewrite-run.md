# Task List Mechanism Rewrite - Run

**Status:** draft

**Scope:** the run directive for the task list mechanism study. It states the premise to attack, the falsifiable done predicate, the phase ledger, the parallel shape of each phase, the model for each seat, and the limits the run must respect. It carries no implementation detail for the mechanism itself; the mechanism is what the run decides.

**Origin:** the operator's rewrite request (2026-10-15), the eight requirements R1 to R8 in the churn study, and the two T5 rows that own the subject. This brief is a draft under `.agents/drafts/`, so no live dispatch path reaches it until the operator promotes it.

**Vocabulary:** the system is the Task List Mechanism. A task is the record of work that will need to be done, and a task list is the collection of tasks. Work item is the wider term for a task once it is picked up and expands through scoping, design or planning. The two name different subdomains and are not synonyms.

## Purpose

The operator runs two development threads and the roadmap permits one. A task has no identity, so every rename propagates into prose. Every semantic rule about the record is a review duty rather than a gate. The churn study measured all three and derived requirements, and no design exists.

This run produces two things. First, a proposal for the new task list mechanism, checked against the primary sources rather than against a digest of them. Second, a utility committed to the repository that implements the storage and the migration, with tests.

The reader of the proposal is the operator, who needs two milestones to advance at once without a shared write target. The next agent that inherits the mechanism must be able to read one generated view and answer what is in flight, what is blocked, and what is next.

## The premise to attack

Write this premise down before any design work, and confirm or kill it from the evidence.

The premise is that prose is the state store. The roadmap holds machine state and human text in the same characters, so a state change is a text edit, and text edits serialize on the file.

Three facts support it. The `active-milestone` field in [`roadmap.md`](../../devlog/roadmap.md) is a scalar, and the project's `task-list` convention defines it as naming the milestone work is scoped to. Three runbooks write that one field. The churn study found 197 references to a roadmap row by position, and a row has no identity other than its prose. Twelve invariant families are rule-only, so an unmet invariant is a review duty.

If the census in Phase 1 shows that milestone serialization is not the dominant cost, say so and rescope the run to the cost that is dominant. The premise is the thing under test, not the conclusion.

## The done predicate

The run is done when every item below is true and its evidence is a command a reviewer reruns.

1. The committed utility implements the storage and the migration, and its tests pass under `make test`.
2. Two sessions advance two milestones at once for N rounds, with zero lost updates and zero record conflicts. The value of N is fixed before the run and printed in the report.
3. The count of commits touching `devlog/roadmap.md` falls, or the file becomes generated and no hand edit touches it. The baseline is 333 of 897 commits, measured 2026-10-15.
4. A fresh-context agent with no access to the policies reads only the generated view and answers three questions correctly. The questions are what is in flight, what is blocked, and what is next.
5. Every invariant the census found rule-only is either gated or named as judgement-only with the reason.
6. The migration is idempotent. A second run and a mid-run crash both converge to the same end state.
7. A foreign-format project migrates end to end from a fixture, or the report states that no foreign format exists and names what it checked.

A verdict on each item is VERIFIED, NOT VERIFIED, or INCONCLUSIVE. Inconclusive is not a pass.

## Phase ledger

Phases 0, 2, 4, 5 and 7 write artifacts. Phases 1, 3 and 6 are read-mostly and return reports. The shape column names the parallel form.

| Phase | Question | Deliverable | Shape |
|---|---|---|---|
| 0 | what is the schema every later phase emits into | the frozen snapshot, the record schema, the baseline capture | serial |
| 1 | what does the current mechanism actually cost | five census reports | swarm, five slices |
| 2 | what is a task, and what it becomes when it expands | the entity, the state machine, the event schema | arena, two candidates |
| 3 | what do the prior designs contribute | five source digests in one fixed shape | swarm, five slices |
| 4 | which store survives the real corpus | three prototypes, one base, one grafted result | arena, three candidates |
| 5 | how does the old record become the new one | the converter, the fixture, the dry-run diff | serial design, swarm build |
| 6 | is the claim true | six verification lanes | swarm, six lanes |
| 7 | what do we propose | the design proposal, the ADR, the roadmap write-back | serial, writer plus reviewer |

### Phase 0, scaffold

Cut one snapshot with `git archive` and hand every worker the same bytes. Fix the record schema once, in the preamble, before any dispatch. Capture the baseline before any change, so every later measurement reads as old value against new value. The baseline is the commit count in the done predicate, the current `make lint` output, and the current `make test` count.

No phase runs before the schema is frozen. The schema is the contract every worker writes into, and a schema agreed late makes the deliverables incomparable.

### Phase 1, the census

Five slices over disjoint evidence sets. No slice reads another slice's files.

| Slice | Evidence | Question |
|---|---|---|
| A | the 434 session JSONL files under `~/.pi/agent/sessions/--home-agentuser-sandbox--/` | how often was an operator turn blocked because the work sat in a non-active milestone |
| B | `git log -p --follow devlog/roadmap.md` | what shape is each roadmap edit, and what does that stream say the model must carry |
| C | the three record policies, the seven loop prompts, the two maintenance skills | which invariant families are gated and which are rule-only |
| D | every code path and prompt that reads or writes task state | which shared write target does each actor touch |
| E | the tree and the docs, for a foreign roadmap or handover format | does a second format exist in this repository, and if not, what does the fixture need |

Slice A carries the number that prices the whole rewrite, so it gets the tightest brief and the strongest verification. A first pass with `jq` over the transcripts emitted 4 usable operator lines against 6425 user-role records, measured 2026-10-15, so the extraction is unbuilt and the slice owns building it.

Slice D is the one that finds the undisclosed bottlenecks. It must answer whether the handover format serializes, whether the review gate forces one item at a time, whether `active-milestone` appears as a scalar anywhere else such as branch naming or the session-diff pipeline, and what else in the harness assumes a single writer. Name what it checked and what it did not.

### Phase 2, the domain model

One artifact, produced twice, compared on a rubric. The rubric is fixed in Phase 0 and the candidates never see it.

| Criterion | What it grades |
|---|---|
| identity | survives a rename, a reorder and a file move |
| illegal states | contradictory states are unrepresentable rather than checked |
| one home per fact | other surfaces derive from the item rather than restate it |
| append-only history | a closed item keeps its text and gains a successor |
| offline testability | a check runs with no network and no paid dependency |

Candidates are two, on different model families. A cross-judge on a third family scores criterion by criterion. The parent picks the base, grafts what the loser did better, and records what it rejected.

### Phase 3, the primary sources

Read at source, never from a summary. Five slices, one fixed digest shape each.

| Slice | Source |
|---|---|
| F | OpenAI's Symphony spec |
| G | the Linear data model and API documentation |
| H | the GitHub Issues GraphQL schema and Projects v2 documentation |
| I | the task queue primitive, its ADR and its source |
| J | the read-through register and the metadata-seeding note, as the repository's own proto-tracker |

Each digest names the source's entities, its identity scheme, its state set, its ordering model, what it cannot express, its cost, and what it contributes to the model. Slice I and slice J exist because the repository already holds a work-item engine and a labelled record set, and a design that ignores them rebuilds solved work.

The paid constraint is settled here. Linear is a paid dependency the harness cannot test offline. GitHub Issues and Projects carry no licence cost and live where the repository already lives. The study proposes the constraint it takes, and if it takes a paid dependency it says why the free option failed.

### Phase 4, the store bakeoff

Three candidate stores, each run against the Phase 1 corpus, compared side by side. Candidates are named here as the directions to cover, not as the answer.

1. A git-native append-only event log with a generated view.
2. A per-milestone directory with one file per task and a derived index.
3. A wrapper over a hosted tracker with a read-only local mirror.

Each candidate reports the concurrency test result, the review load it removes, the migration cost, the offline testability, and the dependency cost. The parent picks the base and grafts. When all three converge, that convergence is the finding and no graft is needed. When they diverge, the rubric was under-specified and the phase reruns rather than averages the divergence.

### Phase 5, the migration

Design first, then build. The design is the hard part, because the new mechanism must land in a repository still governed by the old one, and a foreign project has a different format again.

| Unit | Owns | Writes |
|---|---|---|
| M1 | the converter contract and the legacy deletion date | the design note |
| M2 | the converter for this repository | the script and its test |
| M3 | the fixture project and its converter | the fixture tree and its test |
| M4 | the idempotence and crash-recovery harness | the test |
| M5 | the dry-run diff against the current `roadmap.md` | the rendered view and the enumerated diff |

M1 depends on Phase 4 and runs alone. M2, M3 and M4 are disjoint and run at once. M5 runs on the merged result.

The converter parses the old format at a boundary and never trusts it. It is idempotent: a second run and a mid-run crash both converge. The legacy format gets a deletion date, not a compatibility layer that survives.

### Phase 6, the verification lanes

Six lanes, each one task, each returning PASS, ISSUES or BLOCKED with evidence.

| Lane | Claim it tests |
|---|---|
| V1 | two sessions advance two milestones with no lost update |
| V2 | the roadmap commit count fell, or the file is generated |
| V3 | a fresh-context agent reads the view and answers three questions |
| V4 | the fixture project migrates and stays green |
| V5 | every rule-only invariant is gated or named |
| V6 | the existing suite and gate are green |

V1 runs real concurrent writers, not a simulation, and runs N rounds. The brief states that finishing before N rounds is a failure. V3 runs on a model with no access to this repository's policies.

One suite runs at a time. V4 and V6 both run the suite, so they serialize even though they fan out. State that as a scheduler rule in the briefs, not as a footnote.

### Phase 7, the proposal

One design record at `devlog/discussions/` in the `design` section order from [`work-log`](../../.agents/skills/work-log/assets/design.md), one ADR, and the roadmap write-back. The writer is the strongest prose seat. A different family reviews it.

## The dispatch plan

### The transport

`taskq` is the transport for every phase that writes. One `taskq_fork` per unit cuts its own worktree and branch, so no two workers share a write target. The join is one pool `taskq_join` over the task ids, and every task is audited in its worktree before its bring-back. Phase 1, Phase 3 and Phase 6 write reports only, so their bring-back is the empty set and the reports are the deliverable.

### The waves

| Wave | Tasks at once | Depends on |
|---|---|---|
| W0 | 1 | nothing |
| W1 | 5 census slices and 5 source slices, in parallel | W0 |
| W2 | 2 model candidates, then 1 cross-judge | W1 |
| W3 | 3 store designs, then 3 store prototypes, then 1 cross-judge | W2 |
| W4 | 2 migration designs, then 3 migration builders | W3 |
| W5 | 6 verification lanes | W4 |
| W6 | 1 writer, then 1 reviewer | W5 |

Phases 1 and 3 are independent, so W1 runs ten workers at once. That is the widest wave and the ceiling on this run's parallelism. W2 and W3 are single-artifact competitions and cap at three. W5 fans to six but serializes on the suite.

### Swarm or arena, by phase

Swarm for coverage. Every slice must return, so there is no selection rule. That is Phase 1, Phase 3, Phase 5's build units and Phase 6.

Arena for one artifact produced several times and compared. There is a rubric, a cross-judge, a base and a graft. That is Phase 2, Phase 4 and the design half of Phase 5.

Never both on one unit. An arena inside a swarm slice averages divergent designs and destroys the comparison it was built for. The two shapes are not alternatives to choose between for the run. Each phase takes the one its question requires.

### The model assignment

Read the role from `$AGENT_HOME/model-recommendations.md` and pass the provider, the model and the thinking level explicitly on every dispatch. A role with no value falls back to the pi startup default, which is not the model this run wants.

| Seat | Model | Why this seat |
|---|---|---|
| `_ORCHESTRATOR` | `opencode-go/step-5-preview-free` at high | the schema, the partitions, the joins and the synthesis need one million tokens of context and good prose |
| `_IMPLEMENTER`, mechanical | `opencode-go/cat-jam-free` at medium | fast and accurate on bounded code, and there are many small units |
| `_IMPLEMENTER`, extraction | `opencode-go/cat-jam-free` at high | the census scripts are code with an exact output shape |
| `_REVIEWER` | `deepseek/deepseek-v4-pro` at high | a second family, so agreement is signal rather than a shared bias |
| arena candidates | `opencode-go/step-5-preview-free` and `deepseek/deepseek-v4-pro` for a prose artifact, `opencode-go/cat-jam-free` for a code artifact | one family per candidate, so the comparison is not three flavours of one model |
| arena cross-judge | the family not used by the base candidate | the judge must not share the base's blind spot |
| Phase 7 writer | `opencode-go/step-5-preview-free` at high | it writes well and the record is prose |
| Phase 7 reviewer | `deepseek/deepseek-v4-pro` at high | independent read of the proposal |

The reviewer seats sit on the deepseek family because the openrouter key is expired. Measured 2026-10-15: `openrouter/z-ai/glm-5.3-flash` answers `401 API key expired`, so the `_ADVISOR` line in the live recommendations file is dead and the cross-judge must come from deepseek or opencode-go. Replace the key or move that line, before the arena runs.

The two free models have opposite failure modes and the briefs must answer each. Step 5 is slow and retries, so it never holds a deadline alone and it runs behind the retry policy already in the pi config. Cat Jam terminates early, so every brief it receives names a done predicate, a minimum unit count, and a self-check the worker must print before it stops. A Cat Jam worker that returns `done` with no printed self-check is audited as not-usable and re-queued.

The `_IMPLEMENTER`, `_REVIEWER` and `_ORCHESTRATOR` role lines are uninitialized in the live file, read 2026-10-15. Phase 0 populates them before any dispatch, using the values above.

## The worker brief template

Every brief carries the same preamble and its own ownership assignment. The preamble is written once in Phase 0 and not renegotiated per worker.

```text
Task: <one outcome, one sentence>
Owns: <the exact file set this worker may write>
Reads: <the files and commands it may read>
May not write: <every path outside the owned set, and the shared tree>
Deliverable: <one file, one schema, named exactly>
Self-check: <the command the worker runs and prints before it stops>
Done predicate: <the observable that is true only when the task is complete>
Do not stop before <N> <units>. Finishing early with an unrun self-check is a failure.
Report: <the report path, and the one-line summary>
```

The record schema is fixed in the preamble. A worker that invents a field is re-queued rather than accommodated, because two schemas make the deliverables incomparable.

## The limits

The repository suite is one shared resource and runs one at a time. The full verification wave therefore costs the sum of the suites, not the maximum of them.

The opencode-go quota meters the metered model family, not the provider. Measured 2026-10-15: `opencode-go/deepseek-v4-flash`, `opencode-go/deepseek-v4-pro` and `opencode-go/deepseek-v4.1-flash` each answer `429 GoUsageLimitError` in about a second, while `opencode-go/step-5-preview-free` and `opencode-go/cat-jam-free` both answer normally. So the wave is not blocked by the spent quota, and the cap applies only if a seat moves onto a metered model. What no key reaches is the app's own free tier: `opencode/deepseek-v4.1-flash-free` answers `403 FreeTierError`, `OpenCode's free tier can only be used from within OpenCode`, and opencode-go carries no `-free` id for that model. The remaining cap risk is the two free seats meeting a request-rate limit at ten concurrent workers, which no probe here measured.

Disk is a third limit. Ten worktrees of this repository is the cost of W1. Check free space before W1 and prune at each bring-back.

## Invariants

- The live shared tree is neither an input nor an output of a worker. The frozen snapshot is both.
- One file has one owner among concurrent workers.
- One suite runs at a time.
- A worker never edits the record schema, the rubric or the brief it runs under.
- The generated view is derived and never hand-edited.
- A claim about the mechanism carries a command or a measurement in the same sentence.

## What would settle this brief

This brief stays a draft until the run records these.

- The operator-blocked count from slice A, so the rewrite's price stops being an inference.
- Whether the ten-way wave completed, and how many workers a rate cap re-queued.
- Whether the arena produced a base worth grafting, or three candidates converged.
- Whether the concurrency test found a lost update, and at which round.
- Whether the dry-run diff was empty or enumerated, and what it enumerated.
