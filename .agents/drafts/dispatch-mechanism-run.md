# Dispatch Mechanism

**Status:** draft

> $ARGUMENTS

## The problem

Dispatch has no document. Its behaviour is asserted across 40 live carriers -- the seam, a front door with no caller, two skill-local launchers, two `AGENTS.md` layers, three skills, a skeleton, three reference documents, two ADRs and thirteen drafts -- and no carrier claims the whole. The carriers also disagree on the *words*: one thing is called a backend, a runtime and a provider; `provider/model` is called a pair while it carries three components; `opencode` is a company, a model-id prefix, a runtime value and a directory name; and "table" names four different files.

The disagreement is live, not theoretical, and three instances are measured:

- Two role tables exist and disagree on grammar and values. The seam silently prefers the committed one, so editing `$AGENT_HOME/model-recommendations.md` changes nothing while that file states it is authoritative.
- The runtime map is correct, and its only defect is that the word beside it was `backend`. `opencode-go` is the OpenCode Go gateway, which pi serves, so `dispatch_backend opencode-go` printing `pi` is right; `tests/test_dispatch.sh` asserts it and `knowledge_model_refresh_real_load.sh:77` runs `pi --provider opencode-go`. Only `opencode` itself is CLI-only. A prefix's name decides nothing, which is the rule this run writes down.
- `dispatch_roles` reports a role named `Format` with model `` `_ROLE: ``, because the header line matches the role pattern.

Every extension of dispatch lands on top of that. The model catalog, the dispatch-rule surface and the router each assume one data unit read one way; if the carriers disagree about what the unit even is, each extension inherits a different answer.

**The premise under test.** The collisions are vocabulary-deep, not design-deep: once the terms are fixed, one machine describes both runtimes and both dispatch skills, and the 40 carriers reduce to one document plus links.

**What its falsification would mean.** If the machine needs a distinct state for each dispatch site -- the seam, `opencode-dispatch`, the front door, an inline site -- then dispatch genuinely is several mechanisms, not one badly named one. The outcome is then a document per mechanism, and the milestone's routing rows are scoped per mechanism. That outcome is a success, not a failure.

## What is already measured

Do not re-derive these. Each carries the command that produced it.

| Fact | Command | Result |
|---|---|---|
| Live carriers state dispatch behaviour | `grep -rln "dispatch_role_model\|model-recommendations\|_IMPLEMENTER\|dispatch_backend\|opencode-dispatch\|pi -p" --include=*.md --include=*.sh --include=*.mjs --include=*.json --include=*.ts . \| grep -v '^./devlog'` | 40 files |
| "backend" as a word | `grep -rn backend --include=*.md --include=*.sh --include=*.mjs --include=*.ts --include=*.json . \| grep -v '^./devlog' \| wc -l` | 73 occurrences in 14 files (7 are drafts) |
| Commits naming dispatch | `git log --oneline --all -i --grep=dispatch \| wc -l` | 94 of 1081 |
| Churn sits in the test, not the code | `git log --follow --numstat -- tests/test_dispatch.sh` | 38 commits, +1821/-1593, 228 lines now |
| The implementation is small and young | same, `src/libs/dispatch.sh` | 5 commits, +251/-7, 244 lines now |
| Two role tables, disagreeing | read `$AGENT_HOME/model-recommendations.md` and `.agents/model-recommendations.md` | different grammar; home holds `opencode/deepseek-v4.1-flash-free` for two roles, committed holds `deepseek/deepseek-flash` for four |
| The seam's preference is silent | `src/libs/dispatch.sh:38-45` | committed copy wins; no notice when both exist and differ |
| The runtime map is one declared list | `source src/libs/dispatch.sh; dispatch_runtime opencode-go` | prints `pi`, correctly: the Go gateway is pi-served |
| The header line parses as an entry | `source src/libs/dispatch.sh; dispatch_roles` | first line is `Format \`_ROLE: pi` |
| Only the first entry of a role line is read | `src/libs/dispatch.sh:89` `value="${value%%;*}"` | recorded fallbacks never route on the seam path |
| Both backends the home table names are dead | recorded 2026-10-18, not re-derived | `opencode/*` -> `403 FreeTierError`; `opencode-go/*` -> `403 permission_error` |
| A failover outcome has never been recorded | recorded in the design record, not re-derived here | 0 `model-failover/outcome` entries across 592 sessions |
| No dispatch term is reserved | `grep -n "^## " docs/reference/terminology.md` | holds `session`, `iteration`, `staleness` only |

## The vocabulary

Fixed by the operator on 2026-10-22. The document's first section carries this table, extended and defined.

| Term | One meaning | Replaces |
|---|---|---|
| **role** | the tag a brief is dispatched under, `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`, `_ORCHESTRATOR` | "seat" |
| **role table** | the one file mapping a role to a value; `.agents/model-recommendations.md` | "recommendations", "table" for any other file |
| **assignment** | what a role resolves to: a model id, a runtime, a thinking level | "pair", "recommendation", "entry" |
| **provider** | the namespace a model id belongs to, `deepseek`, `opencode`, `opencode-go` | "provider" for the launcher |
| **model id** | `<provider>/<model>` as a CLI expects it | "model" for a family, "pair" |
| **runtime** | the executable that runs a worker: `pi` or `opencode` | "backend", "provider" for the launcher |
| **launch site** | a place that starts a worker: the seam, a skill script, an inline line | "caller", "consumer", "carrier" |
| **carrier** | a file that states dispatch behaviour in prose | "site", "surface" |
| **outcome** | what a request ended in: success, transient, quota, capability, timeout | "result", "class" |
| **verdict** | the seam's failure report: recoverable flag, scope, the provider's sentence | "outcome" |
| **the walk** | the throwaway pass that tests the document's claims against the tree | "census", "crawl", "sweep" |

`opencode` is a lookup string. It names a model-id prefix (`opencode/`, `opencode-go/`), a path on disk, or a runtime value, and never a decision. Three visual forms keep it visible: `opencode/` for a prefix, `opencode run` for the executable, `opencode` for the runtime value. No instruction uses the bare noun.

The runtime is never an agent's decision. A role resolves to an assignment; the seam prints the runtime. That is what makes the runtime data rather than an inference.

## The rulings

- **No extension.** No router, no model catalog, no dispatch-rule surface, no new launch site, no change to how a model is chosen. The document names the defects those rows inherit and stops.
- **The instruction-carrier gate is not this run's.** [`close-the-model-bypass-run.md`](close-the-model-bypass-run.md) owns the claim that no agent-facing instruction names a provider or a model. This brief reads that scope and does not duplicate it.
- **The design records are hypotheses, not facts.** [`20261015-design-settled-cost_aware_dispatch.md`](../../devlog/discussions/20261015-design-settled-cost_aware_dispatch.md) says of its own run directive that parts are superseded. A claim is re-derived from the tree or the store, or it is labelled `recorded, not re-derived`.
- **The document lands where it ships.** `docs/reference/dispatch.md`, because that tree is mounted into all three images (`src/build/container-interface.json` cells at lines 46, 66, 86) and the provider layer already describes it as "contracts, states and sequences". The decision history stays in `devlog/discussions/`.
- **The walk leaves no artifact in the tree.** Its script, raw output and log go to `$HOME/workspace/output/dispatch-walk-<date>/`. Nothing it produces is committed except what it changes in the document.
- **The claims are not a document.** The [`docs`](../skills/docs/SKILL.md) convention keeps a reference document current with the implementation, so an unwalked claim stays out of it: the claims file lives with the instrument and the tree gains only what survived.
- **The words are their own deliverable.** The same convention's [reserved terms](../skills/docs/SKILL.md#what-a-document-may-contain) puts every reserved term in `docs/reference/terminology.md` and forbids a local redefinition, so the vocabulary lands there first and the behaviour document links it. The `linking` lint gate fixes the order: a fragment naming no heading does not resolve.
- **The document states; code follows.** A rename the document implies lands in the same run only where it is mechanical and covered by a test.
- **Deferred, not absorbed.** `src/reasoning/providers/` -> `agent-runtime` belongs to M3.6.4's container refactor; `src/reasoning/agent/` -> `agent-context` belongs to the deferred context track. This run names both and touches neither.
- **A role carries preferences, not seats.** Approved 2026-10-22: a role line holds an ordered list of distinct assignments. A request names the number of distinct models it needs, so a single-seat brief takes one entry and a two-seat review takes two, from the head of the same list in order; a seat whose attempt fails advances to the next entry no other seat holds. Heterogeneity is therefore a count, not a second list and not a second role. A fallback is the next entry the table holds; a default is a value the table does not hold. Fewer distinct entries than the request needs fails with a verdict naming the shortage, and no seat is filled by duplicating a model.
- **A fixed run is not a dispatch.** A launcher that takes its assignments from its caller instead of resolving them, as the review runner does for reproducible review, is outside the mechanism: it reads no table, so nothing it runs can drift with a table edit. Its input belongs in its own contract, stated in one place. The document names it as outside dispatch and states why, and the request for several distinct models belongs to dispatch, not to that script.
- **One implementation is refused as a premise.** The subject is four launch sites and their readers, not "the implementation", which would be the 244-line file that barely changed.

## The phases

| Phase | Question | Deliverable | Waits on |
|---|---|---|---|
| P1 The claims | What does dispatch do, stated as requirements, states, transitions and control-flow steps? | `claims.md` beside the instrument: every assertion with the carrier that makes it and the command that decides it | -- |
| P2 The walk | Which claims does the tree and the store contradict, and which do they confirm? | one mark per claim: confirmed, corrected, cut, with the command that decided it | P1 |
| P3 The machine | What survives as the behaviour of record? | the state machine, the control flow, the invariants, the failure vocabulary, the supersession table | P2 |

The carrier collapse is not a phase. It edits files, so it is a unit `/scope` formulates from the walked document, not work inside this run.

## The run shape

P1 and P2 alternate at one grain per claim: a claim is written, then walked, so a wrong model is caught before the next section is drafted on top of it. P2 fans out three ways and is the widest wave: the code and carrier reading, the record reading (12 handovers, 16 `AGENT_FEEDBACK` entries, the roadmap rows), and the behavioural reading through the existing ledger parser over the session store. P3 is single-threaded.

## The work units

| Unit | Commit type | Owned files | Handover |
|---|---|---|---|
| U1 The words | `docs` | `docs/reference/terminology.md` | yes |
| U1b The behaviour | `docs` | `docs/reference/dispatch.md` | yes |
| U2 The runtime map becomes data, and the word `backend` goes | `refactor` | `src/libs/dispatch.sh`, `scripts/dispatch.sh`, `tests/test_dispatch.sh`, `scripts/cost_ledger.mjs`, `tests/test_cost_ledger.sh`, `docs/adr/opencode_dispatch_backend.md` | yes |
| U3 The carriers collapse | `docs` | both `AGENTS.md` layers, `opencode-dispatch/SKILL.md`, `setup-model-recommendations/SKILL.md`, `config/agent/bin/review-dispatch.sh`, `docs/reference/{agent_workflow,execution_model,provider_lifecycle}.md`, `docs/adr/single_source_model_recommendations.md`, `devlog/roadmap.md` (M3.6.5's title and summary row) | yes |

U1 carries the reserved terms -- `role`, `role table`, `role line`, `assignment`, `provider`, `runtime`, `launch site`, `outcome` -- each with the identity, scope and relationships its entries require, and `backend`, `pair` and `seat`-as-a-synonym-for-role noted as deprecated tokens in the entry that replaces them. `role line` is added to the seven: once a role resolves to a list, one word cannot name both the list and the element in force.

U1b carries the requirement set, the state machine, the control flow, the launch-site table, the invariants, the failure vocabulary with its measured `unknown` rate, and the supersession table naming where each earlier record's content now lives. It links `terminology.md` on first mention and defines no term.

U2 makes the provider-to-runtime map one declared list rather than a value buried in a function, so a new prefix is a data edit; renames `dispatch_backend` to `dispatch_runtime` across code, tests and the ADR; and retitles ADR `opencode_dispatch_backend.md` to match. Its central change is the chain: the library returns a role's ordered list instead of truncating at the first `;`, and the walk along that list is driven by the outcome, which is where `opencode-dispatch`'s candidate loop moves. It also fixes the measured parsing defects it touches, the header line entering the role walk and the entrypoint's stale table path, each with the case that fails today.

U3 is the propagation: no runtime carrier restates what the document owns, the ADR's R8 and its "operator-owned and gitignored" line are corrected, and M3.6.5 is retitled to `OpenCode as a first-class runtime` with its summary row and anchor following. It carries the split's instruction half: a `dispatch` skill that turns a prose intent into a `scripts/dispatch.sh` invocation and reads back what ran, replacing `opencode-dispatch`, whose launcher retires into the entrypoint and whose `SKILL.md` restates flags the entrypoint owns.

U2 and U3 are hypotheses until the walk closes. `/scope` runs after P3 and formulates them from the walked document, each unit evidenced by the claims it retires.

## The model assignment

Every role resolves from `.agents/model-recommendations.md`: `deepseek/deepseek-flash`, `_IMPLEMENTER` and `_REVIEWER` at `high`, `_ADVISOR` at `high`, `_ORCHESTRATOR` at `low`.

| Seat | Role | Why |
|---|---|---|
| The P2 walk readers | `_IMPLEMENTER` x3 | one brief each, disjoint source families, no shared file |
| The drafting | `_ORCHESTRATOR` | the document is written by the seat that holds all three readings |
| The blind reading | `_REVIEWER` | one run: there is one model, so a second seat is a second run of the same model |

Known dead seats: `opencode/*` and `opencode-go/*` (measured 2026-10-18). The operator's home table names `opencode/deepseek-v4.1-flash-free` for two roles, which is one of the findings rather than a seat this run can take.

## Verification

| Check | Artifact |
|---|---|
| The document states behaviour, not findings | it has no findings section; every claim is a requirement, a state, a transition or a control-flow step |
| The claims were walked | `$HOME/workspace/output/dispatch-walk-<date>/walk.jsonl` holds one record per claim with its deciding command, and the document's margin matches it |
| The runtime map is one declared list | a fixture overrides `DISPATCH_OPENCODE_PROVIDERS` and the prefix routes to `opencode` with no code change |
| The two parsing defects are proven, not asserted | `dispatch_roles` prints four roles and no `Format`; `dispatch_role_assignments` returns a role's list in order and refuses a malformed entry; both cases existed and failed before the fix |
| The two-table defect is decided | either one table remains, or a dispatch that finds two prints which it obeyed |
| The carriers carry no restatement | `grep` for the model rule returns the document and the role table only |
| The vocabulary is applied | `grep -rn backend` over live code and docs returns only the superseded ADR's historical title |
| A second reader reaches the same model | the `_REVIEWER` seat, given the document's vocabulary table alone, predicts the runtime for three prefixes and the assignment for two roles |
| Both gates stay green | `bash scripts/lint.sh`, `bash scripts/run-tests.sh` |

## Constraints and invariants

- The source set is named, not globbed: the 40 carriers, the 12 handovers, the 16 feedback entries, the roadmap's dispatch rows, the four launch sites, and the session store.
- No claim without the command that decides it. No claim stated as fact when the store cannot confirm it; such a claim is labelled `recorded, not re-derived`.
- The document does not restate what the role table already is; it states what a role resolves to and links the table.
- Nothing in this run edits the home table, adds a launch site, or changes which model a role resolves to.
- A rename lands only where a test covers it.

## What would settle this brief

| Fork | Default taken | The word that reverses it |
|---|---|---|
| One document, or one per launch site | one, with the falsifier stated above | `per mechanism` |
| The runtime is derived from declared data, or stated per role | derived; the table stays readable and the seam prints it | `state it` |
| The two-table defect is reported or fixed | fixed in U2 by removing the silent preference -- a dispatch reads one table and says which | `report it` |
| Supersession reaches the two live records, or all seven | the two live ones; the five archived stay history | `all seven` |
| The five archived design records are moved, or left in place | left; they are already outside every agent's context | `archive them` |

## Records this depends on

- [`close-the-model-bypass-run.md`](close-the-model-bypass-run.md) -- the neighbouring run; owns the instruction-carrier gate.
- [`cost-aware-dispatch-run.md`](cost-aware-dispatch-run.md) -- a source of measured facts, not the plan; its own design supersedes parts of it.
- [`20261015-design-settled-cost_aware_dispatch.md`](../../devlog/discussions/20261015-design-settled-cost_aware_dispatch.md) -- the router boundary and failure taxonomy the document absorbs.
- [`20261016-design-settled-dispatch_ownership.md`](../../devlog/discussions/20261016-design-settled-dispatch_ownership.md) -- why dispatch is three layers, and the lean the document must settle.
- [`coding_agent_project_bindings.md`](../../docs/adr/coding_agent_project_bindings.md) -- the reserved-terminology device this vocabulary follows.
- [`single_source_model_recommendations.md`](../../docs/adr/single_source_model_recommendations.md) -- R1 to R9, two of which the tree now contradicts.
- `devlog/roadmap.md` M3.6.3 -- the ten rows whose blind spots the document replaces.
