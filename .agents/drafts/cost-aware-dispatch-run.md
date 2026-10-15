# Cost-Aware Dispatch and the OpenCode Runner - Run

**Status:** draft

**Scope:** the run directive for the cost-aware dispatch work: the instruction transport into an OpenCode runtime, the runner seam between two backends, the cost ledger, the dispatch-policy axis, and the provider decision. It carries the measured facts the run must not re-derive, the ruling it must not cross, the phase ledger, the parallel shape and the done predicate.

**Origin:** the operator's scoping request (2026-10-15), the measured evidence in the T7 row `Expose a capacity signal to the agent`, and the T2 telemetry rows. This brief is a draft under `.agents/drafts/`, so no live dispatch path reaches it until the operator promotes it.

---

## Purpose

Model cost is recorded and unread. The harness pays for every dispatch and cannot say what a skill costs, which model it should have used, or which free model it could have reached. A free model inventory exists that the harness cannot see at all.

This run produces three things. First, an instruction transport, so an OpenCode runtime reads the same skills and instructions pi reads. Second, a cost ledger, so a dispatch's price and its wall clock are one readable record. Third, a dispatch policy, so the choice of model is a rule that can change without a code change.

The reader of the ledger is the operator, who is paying. The reader of the dispatch policy is the next agent, who must be able to say which model it chose and why.

## What is already measured - do not re-derive

Every line below was measured on 2026-10-15. Treat each as a given and cite it rather than re-running it.

| Fact | Evidence |
|---|---|
| The package is `opencode-ai`, not `@opencode/cli` | `npm view` returns nothing for the latter, 1.19.0 for the former |
| Headless mode is `opencode run -m <provider>/<model> "<prompt>"` | `opencode run` answered `ok` in 5 seconds, rc=0 |
| The app-gated free tier is reachable from the CLI, with no spoofing | `opencode run -m opencode/deepseek-v4.1-flash-free` answered, where pi answers `403 FreeTierError` |
| Cost and tokens return per step | `--format json` emits `step-finish` with `tokens{total,input,output,reasoning,cache{write,read}}` and `cost` |
| The free inventory is larger than pi can see | `opencode models` lists 498 models, 10 free on `opencode`, 3 on `opencode-go`, about 12 free on `openrouter` |
| OpenCode reads `AGENTS.md` and `SKILL.md` | a throwaway tree's `AGENTS.md` codeword and `.agents/skills/probe-skill/SKILL.md` value were both returned |
| The config seam is `opencode.json` plus `OPENCODE_CONFIG` | config docs name both, with an `instructions` key and `command` entries carrying `template`, `agent` and `subtask` |
| pi already records per-message cost | one session JSONL carries 87 `usage` objects with a four-component `cost`; `models-store.json` carries a per-model price with zeros for the free ones |
| pi already surfaces a session total | the footer and `/session`, per pi's own docs |
| The metered family, not the provider, carries the quota | `opencode-go/deepseek-*` answers `429 GoUsageLimitError`, while `opencode-go/step-5-preview-free` and `opencode-go/cat-jam-free` answer normally |

One sentence is a documentation defect. `src/reasoning/providers/opencode/provider.dockerfile` states that OpenCode "has no config transport that could load a prompt or a skill". That is a statement about the harness's missing work, not about OpenCode. Reword it to say so.

## The line that must not be crossed

Do not spoof request attribution. Do not pose as the OpenCode app from pi, forge a header, or otherwise defeat the free-tier gate's client check. The operator's ruling is explicit: the consequence of being caught is irreversible and not worth the access.

The sanctioned route to a free model is the real OpenCode CLI, invoked as a subagent. A dispatch rule that would require misrepresenting the client is rejected, not softened.

## Phase 1, the instruction transport

Build the config that makes the harness's instruction surfaces reachable inside an OpenCode runtime. This is the work the Dockerfile comment says is missing.

Decide and record which roots carry: the provider `AGENTS.md`, the project `AGENTS.md`, the prompt root, the skill roots, the module package directory. Prefer pointing at the surfaces already declared in [`container-interface.json`](../../src/build/container-interface.json) rather than adding a second declaration. `OPENCODE_CONFIG` is the seam for a harness-chosen path.

Prove it by running one real repository skill through OpenCode and keeping the transcript. Then reword the Dockerfile sentence.

## Phase 2, the runner seam

One command builder with two backends, `pi -p` and `opencode run`, plus the flag mapping that differs between them. The model flag takes `provider/model` on one backend and a provider plus a model on the other. The thinking level and the JSON output format differ too. A brief names a role and not a runtime.

Thirty-five files launch a subagent with `pi -p` or `pi --provider`, measured by grep. Prove the seam on the [`parallel-work.md`](parallel-work.md) launch site, then state the propagation count and decide in writing whether to sweep all thirty-five or to keep the seam inside one lib. A split surface that is not written down is the failure this phase exists to prevent.

Session handling is part of the seam. pi has `--session`; OpenCode has `--session`, `--continue` and `--fork`. State how a segment resumes on each backend.

## Phase 3, the cost ledger

One committed script producing one record per dispatch: backend, provider, model, thinking level, wall clock, tokens by class, cost, and the brief's identity. It reads two sources with two shapes, pi's session JSONL and OpenCode's JSON event stream, and normalises them into one record.

Its second output is one brief on two models side by side, cost beside wall clock. A free model that doubles the wall clock is not free, and only the paired number shows it.

This is the T2 telemetry instrument and the T7 capacity signal, not a third thing. Read the T2 rows and the T7 row, and state which this satisfies and which it leaves open.

## Phase 4, the dispatch policy

[`model-failover`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md) already routes on health: `routes.json` chains, two route states, `eligible` and `cooling`, transitions T1 to T6, and a `limited` failure class with a one-hour cooldown. Extend that machine rather than building a parallel dispatcher. Add a cost or quota axis and whatever state it needs, with a case and a mutation row like the existing ones.

The failover README's discipline applies. State the measured behaviour the design rests on, then the configuration surface, the algorithm, the state model and the invariants.

Then bake off two or three policies on the same brief and the same commit: cheapest-first, free-first with paid fallback, capability-first. Measure cost, wall clock and re-queue count. Name the winner and what it beats.

Cost is not the only axis. A free model that retries, terminates early, or writes badly has a cost the price table does not show. The policy must be able to reject a model for capability, and the reason must be recorded rather than hard-coded.

## Phase 5, unify or do not

Decide in writing whether opencode stops being a base-level provider. If it does, `src/reasoning/providers/opencode/` goes, `opencode-ai` lands in the pi image, and the manifest and the layout gate follow. If it does not, state the reason.

Either way the merged image serves the same skill, prompt and `AGENTS.md` surfaces pi serves, verified by running one real skill on the OpenCode runtime and keeping the transcript.

## Phase 6, flexibility over time

Free models appear and disappear, prices move, and quota resets. The dispatch rules change without a code change, the way `routes.json` already does. State where a rule lives, who edits it, how a rule change is tested, and how a stale rule is detected. An unverifiable rule is not a rule.

The inventory above is a snapshot of one day, and it will not hold for long.

## The run shape

Phase 1 is the prerequisite: no other phase can dispatch to OpenCode until the transport exists.

| Wave | Units at once | Depends on |
|---|---|---|
| W0 | 1, the transport | nothing |
| W1 | 3, the runner seam, the cost ledger, the dispatch-rule surface | W0 |
| W2 | 3, the policy candidates, measured on one brief and one commit | W1 |
| W3 | 2, the provider decision, the policy bakeoff write-up | W2 |
| W4 | 4 verification lanes | W3 |

The shape is a **swarm** for W1 and W4, because every unit must return and there is no selection rule. It is an **arena** for W2, because the policy candidates are the same artifact produced three times and one has to win. Do not run an arena inside a swarm slice.

Phases 1 through 6 are sequential, so the parallelism is inside each phase rather than across them. That is the honest ceiling here, and it is lower than the task-list run's. W1 is the widest wave at three.

## The model assignment

| Seat | Model | Why this seat |
|---|---|---|
| the transport and the seam | `opencode-go/cat-jam-free` at high | bounded code with an exact shape, and it is the fastest seat available |
| the cost ledger | `opencode-go/cat-jam-free` at high | a parser over two known record shapes |
| the policy design | `opencode-go/step-5-preview-free` at high | judgment over a state machine, and it writes the record |
| the policy bakeoff candidates | three, from the working set | one family per candidate, so the comparison is not three flavours of one model |
| the write-up and the ADR | `opencode-go/step-5-preview-free` at high | the record is prose |
| the reviewer | `deepseek/deepseek-v4-pro` at high | a second family, and the openrouter key is expired |

Read the role from `$AGENT_HOME/model-recommendations.md` and pass the provider, the model and the thinking level explicitly. A role with no value falls back to the pi startup default, which is not the seat this run wants.

Do not dispatch a worker to a metered opencode-go model. The `deepseek-*` family on that provider answers `429 GoUsageLimitError` and costs a re-queue for nothing.

## Verification

1. The transport proof: one real repository skill loaded and executed by OpenCode, with the transcript.
2. The ledger's paid-versus-free table for one brief on one commit, cost beside wall clock.
3. A `make`-reachable cost command with a test.
4. The failover ledger's new axis and state, with a case and a mutation row, and the totality check green.
5. The provider layout gate green after the Phase 5 decision.
6. A second reader: a fresh-context agent given only the ledger and the dispatch rules, asked which model to send a named skill to and why.
7. The propagation count for the runner seam, with every untouched site named.

A verdict is VERIFIED, NOT VERIFIED, or INCONCLUSIVE. Inconclusive is not a pass.

## Constraints

- No attribution spoofing, ever. See the ruling above.
- No paid dependency is added. A paid fallback is allowed only where the operator has already configured one.
- Everything except live dispatch and the model catalog runs offline.
- Every cost claim carries the command or the file that produced it.
- Wall clock is reported beside every cost figure.

## Invariants

- A brief names a role, never a runtime.
- The generated cost record is derived and never hand-edited.
- A dispatch rule is data, and a rule change is tested.
- The transport points at the declared instruction surfaces, and does not declare a second set.

## What would settle this brief

This brief stays a draft until the run records these.

- Whether the transport carried a real skill end to end, and which skill.
- The propagation count for the runner seam, and which sites were left.
- The measured paid-versus-free delta on one real brief, cost and wall clock.
- Whether the policy bakeoff separated its candidates or converged.
- Whether the free inventory held for the length of the run.
