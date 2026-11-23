# agent-sandbox -- Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely -- this file is not a historical record. The changelog is.

---

## W1 -- Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone -- separate workflow for the Obsidian vault use case. Re-activate when the KV5 timeline demands it.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate the sandbox-only configuration: the agent reads and edits the vault through the sandbox mount, and the diff is reviewed and applied. MCP is out of scope.

**Depends on:** the M2 two-layer foundation, closed in [`changelog.md`](changelog.md#m2---reasoningcapability-layer-separation).

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Validate KV5 end-to-end: agent modifies the vault through the sandbox mount, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` -- document capability layer variants (general vs vault)

---

## W2 -- Communication Domain Taxonomy

**Status:** Not started.

**Objective:** The communication domain settles on one principle taxonomy and one vocabulary, and learns whether that vocabulary changes what an agent writes.

**Scope:** The taxonomy is the intent family and the mechanism axis, recorded in [`principle_skill_shape.md`](../docs/adr/principle_skill_shape.md) and read from the corpus by `scripts/principle_inventory.mjs`. The vocabulary is each principle's `intent`, `mechanism` and `leitwort` fields, ratified at admission. What remains is the leading word on the principles that leave it blank, and whether the words earn their place in the instruction surface.

**Depends on:** M3.3.4 and M3.3.5, both closed in [`changelog.md`](changelog.md#m334---the-prose-standards-as-principles).

**Tasks:**

- [ ] **Decide the leading word on every principle that leaves `metadata.leitwort` blank** (`data`, `record`) -- each principle under the provider root takes the word its body already teaches, or a recorded deferral where none is evident. `communication-principle-maximize-conceptual-leverage` decides the word, and `scripts/check_principle_frontmatter.sh` holds the field's form. A word the body does not support is not declared.
- [ ] **Measure whether the domain vocabulary changes an agent's rewrite** (`record`) -- a case under `tests/eval/` grades one principle's rewrite blind under a control and a term-carrying treatment. The experiment declaration carries the metric set, and the operator sets the grader-reliability floor and the run count `n` when the eval is scoped. A run is evidence inside a stated band, not proof: the verdict reports the measured A/A band, the effect against the pre-registered decision rule, the grader's reliability and the validity threat the design leaves open, and a delta inside the band or an unattributable cell is not a win. A tie or a loss keeps the vocabulary out of the instruction surface. The eval skill's scope alignment may find that a read answers the claim, and that finding is the verdict.

---

## Multi-Agent Coordination

### M4 - Multi-Agent Coordination

Umbrella for the multi-agent milestones: coordinated dispatch of multiple task briefs across agents, the per-agent branch surface, and the metadata that feeds both. Metadata seeding is the parent milestone's first occupant, carried as `M4.1`. The name records the milestone's subject, and `### M5 - Multi-Agent Coordination (post-M4)` names what follows the M4 tracks.

---

### M4.1 -- Metadata Seeding

- [ ] Read the seeded metadata to guide task execution
- [ ] Respect the seeded allowed-file constraints
- [ ] Decide the regular mutation-run frequency (the M3.1 mutation tier is operator-triggered only until this row sets a cadence)
- [ ] Process the 2026-09-26 mutation-run survivors (62 rows with verdict `survived` in `tests/mutations/runs/20260926-184023-mutation_run.jsonl`): triage each survivor - re-run under the fixed-bite discipline or retire the row - and write the outcome back to the catalog. Dumped here by operator direction at the M3.1 close (2026-09-27), because the survivor set is the mutation tier's first real output and the tier's cadence and processing policy belong to M4.1

---

### M4.2 -- Agent-Assigned Branch Management

**Objective:** Each agent gets its own branch from a shared baseline. Branches serve as both the agent's working surface and the snapshot of its work for review and merge.

- [ ] Each agent gets its own branch from the same baseline
- [ ] The harness supports a named branch per agent; the mechanism is chosen when this milestone is planned, not named here
- [ ] Validate branch contents before merge
- [ ] Merge branch -> `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling -- decided against the branch surface as it ships, not against a closed milestone's outcome

---

### M4.3 -- Task Dispatch

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation -- `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model -- how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness
- [ ] **Whether greenfield documentation ever becomes dispatchable** -- it runs in the open context, where the operator is already describing the job, so a seat would need a brief for work a prompt already carries. The question waits on M3.3.5's case set, which is what would measure a dispatch. Filed at the M3.2.2 close from handover `20261028-20`; re-filed here from M3.3.5 on 2026-11-11.

**Deferred capability home:** the `pi-subagents` orchestration capabilities not needed by the task-queue primitive (background and detached execution, retained resume and steering, acceptance gates, watchdog, mission schedules, TUI fleet, external-CLI runners, recursion guard) are evaluated here against a future delegation use case, not grafted onto the operator-bottleneck task-queue. They are scope without a task row; the rows that split them out land before the implementation.

---

### M4.4 -- Constraint Enforcement

**Objective:** Enforce SOP constraints on agent dispatch and output. Partial enforcement may exist earlier from features built in prior milestones; this milestone brings it to a complete and auditable state.

- [ ] Implement automated SOP enforcement scripts covering agent lifecycle, output handling, and secrets
- [ ] Enforce allowed file and task constraints at dispatch time (builds on M4.1 metadata)
- [ ] Validate agent outputs against constraints before branch merge

---

### M4.5 -- Review & CI/CD Integration

**Objective:** Automate review of agent-produced changes and integrate with CI/CD pipelines.

- [ ] Configure PR / CI/CD checks on agent branches
- [ ] Automated validation of branch contents before merge
- [ ] Full structured audit trail per agent run, task, and commit

---

### M4.6 -- Background Work (parallel-work)

Multiple well-specified work tasks run once, in the background, with the operator releasing the plan once up front and not gating each unit. Each task is one unit run; the `work` family runs several at once, unattended, and collects the results for later merge. The work-unit and merge responsibilities from the dispatch prompts `.agents/drafts/parallel-work.md` and `.agents/drafts/sequential-work.md` (own worktree and branch per track, primary holds verification and merge) carry over.

**Source:** the retired T1 `parallel-auto` row, relocated here under the M4 umbrella and renamed with the `-work` family (M3.2.3).

- [ ] Build the background-work surface, reconstructed from the dispatch prompts as M3.2.3 ships them

### M4.7 -- The `/auto` Smart Dispatcher

`/auto` becomes a generalized dispatcher (Option A): given a roadmap task list (possibly out of order, subtasks each carrying an execution rank), it resolves the execution order, picks the dispatch shape per the work structure, and orchestrates. It parks any unit that genuinely needs operator input.

M4.7 derives its requirements from the surface shipped at its planning time. No requirement, criterion, or check in this milestone may rest on an M3 or M4 artifact that has not shipped. The 2026-10-01 semantics record records an M3 ownership decision and is not a specification for this milestone.

- [ ] Implement the `/auto` smart dispatcher

**Tentative workshape definition for autonomous dispatch units (persisted from the 2026-10-02 planning session; adapt on implementation).** One unit is roughly one fresh-context session: a narrow vertical slice through the layers the task touches, demoable or verifiable on its own rather than a horizontal layer cut. Sizing is a token-budget heuristic: estimate the work's tokens, and the unit budget is about a quarter of the context window -- 250k tokens against a 1M window -- with the total-work estimate divided by that budget naming the unit count. The durable destination the slice derives from is the roadmap row; this repo does not use specs and tickets, so a borrowed definition naming those adapts to the roadmap row and the handover scope instead. File-edit overlap is not the independence criterion: commits legitimately touch the same file (roadmap write-backs, fan-out subtasks), and a violation is work whose parts deliver no outcome of their own, not work that shares a file. `.agents/drafts/parallel-work.md` already carries a tracks-level independence test; whether the unit-level test cross-references it is the implementer's call at M4 time. Scope of this definition: the autonomous dispatch milestones (M4); M3 continues using the roadmap task list as the single unit of work, with the close self-check and the reviewer counterparty verifying that the iteration's confirmed scope lands as one unit in one commit.

### M4.8 -- `/goal` (Loose-Goal Decomposition)

`/goal` is the Option B capability, reworked from the removed and stale external extension: given a loose goal, it decomposes the goal into units itself and schedules every unit it can run, asking the operator only when a unit genuinely needs a decision. It is distinct from `/auto` (Option A), which takes a provided task decomposition and resolves its order and shape. `/goal` is the decomposition-and-schedule engine that runs autonomously until no non-operator-blocked unit remains.

- [ ] Rebuild `/goal` as a first-class prompt or extension

### M5 - Multi-Agent Coordination (post-M4)

**Objective:** the coordination surface that outlives the M4 tracks: agents talking to each other, and two agents holding one task at once. M4.3's dispatch model and M4.4's constraint enforcement are the prerequisites; M5 owns what runs after them land.

- [ ] Cross-agent message queue
- [ ] Coordination (parallel writes) on a complex task

---

## Standalone

### M7 - Security and Network Hardening (Policy Layer)

#### Dependency Security

Part of M7 -- supply-chain hardening for provider runtime dependencies.

- [x] Pi version pinned in the provider base Dockerfile; the pin moves with the `pi-bump` unit that owns it
- [x] Node base image pinned to specific version (`node:22.22.3-slim`)
- [x] Bump cadence policy -- the operator decides when to bump, on new functionality needed, a critical fix, or a security vulnerability, with no automation. The bump edits the pinned version in `src/reasoning/runtimes.dockerfile` and its registry lockfile, then rebuilds.
- [ ] **The base image is digest-capable and the apt set takes the strict pin form** -- the pin policy's R1 fixes the resolved artifact, and two classes cannot reach it on the current base: Debian's archive serves a per-file SHA256 that apt has no syntax to pin, so the apt set carries exact versions plus a recorded hash and a drift warning, and the class is a temporary relaxation rather than a settled form. This row is that relaxation's end. A base whose package set is content-addressed, as a Nix-based image is, makes the strict form reachable for every input, and the row owns the migration and the removal of the relaxation from the pin ADR. It is a large change to the image's foundation, so it is not M3.6.4's. Raised 2026-11-07 while settling the pin sweep.

---

### M9 -- Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 -- Structural Separation -- folder ownership, temperature classification, root document audience separation
- [ ] Level 2 -- Review Discipline -- PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 -- Temperature & Freeze Policy -- hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 -- Change Classification Matrix -- explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 -- Automated Enforcement -- CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents

---

## Deferred (Unplanned)

### The instruction modality has five homes (deferred)

**Status:** Deferred (not planned), raised 2026-11-18 while admitting the mood principle. The resolution is this task's scope and this entry states only the problem.

**The problem as it stands.** The five modalities, the MUST/SHOULD/MAY scale, the Kratzer derivation, the obligations a modality owes a writer, and the strength a stake sets are stated in five places: [`instruction_modality.md`](../docs/adr/instruction_modality.md), [`terminology.md`](../docs/reference/terminology.md#modality) for `## modality` and `## modal strength`, the `instruction-authoring` convention's `## What each modality owes the writer`, and [`principle-match-precision-to-stakes`](../src/reasoning/agent-runtime/pi/config/agent/skills/principle-match-precision-to-stakes/SKILL.md). A sixth statement was drafted in the mood principle and withdrawn, because the ADR rejects a keyword rule on a 12-of-20 reader agreement and rejects ranking the kinds by strength, and no reader can tell which of the five homes governs a sentence. Whether the vocabulary consolidates into one home, and which, is not decided here.

**Objective:** one home for the modal vocabulary, so a writer reads one statement of the scale and one statement of what each modality owes, and a principle cites rather than restates.

**Scope:** the five homes above, the sentences in each that state the scale, and the citations that point at them. The mood principle's rendering rule and the `must` case belong to this scope, and the mood principle states only the form rule until it lands.

### The eval's measurement infrastructure (deferred)

**Status:** Deferred (not planned), raised 2026-11-09 by the `/gm` A/B write-back `20261109-10`. It waits until the A/B pipeline is running; the current eval milestone files it as the dependency, not the work.

**Objective:** give the eval a measurement layer that can estimate the alignment grade's reliability and an effect's size, not only observe an outcome on four binary rules and one blind reading.

**Scope:** a richer automated score over the report and the transcript; a second independent grader with kappa for the alignment reading; and the analysis the score supports, including the run-to-run variance the A/A calibration establishes. A decision rule the automated reader evaluates gains a shape with this work; until then the rule stays the operator's prose, agreed per eval. It does not replace the calibration or A/B rows, which are current-infra work under M3.3.5. It also needs a read-cost measure in tokens: the tokens a read adds to the context against the read's effectiveness (a usable report, a located fact), not the read procedure. File opens, bytes and per-path counts are diagnostics only: a batched read that opens more files but spends fewer tokens and turns is the better read, and a census would rank it worse. The eval already records per-turn input and output tokens; what is missing is the normalisation to the outcome.

### The doc-maintenance eval restart (deferred)

**Status:** Deferred (not planned), re-filed from M3.3.5 on 2026-11-11. It is a second eval case, not the case that milestone's acceptance needs.

- [ ] **The doc-maintenance eval restart, on a subject the skill decides** -- the first round is spent: its third rule was satisfied by no configuration, the must-lose control included, so it measured the model, and the model then changed under it. The restart measures whether the review finds a claim a shipped document gets wrong, with the case, the rules and the contrast that must lose in [`20261014-design-draft-doc_maintenance_eval_restart.md`](../devlog/discussions/20261014-design-draft-doc_maintenance_eval_restart.md). Ends when a case separates its configurations; the harness generalisation it needed has landed. The first restart attempt did not separate its configurations, so the next attempt needs a defect the default review misses.

### A separating case for the current instruction-cleanup runbook (deferred)

**Status:** Deferred (not planned), re-filed from M3.3.5 on 2026-11-11. The old instruction-cleanup case measured a 168-line prompt and six carriers that no longer exist; its fixture and the census records it held were retired with them. The current runbook returns a cleaned surface and a ruling log, so a case must be built against that contract.

- [ ] **A separating case for the current instruction-cleanup runbook** -- build a case with a frozen carrier set and a must-lose contrast, graded against a ruling log rather than a fault list. The runbook's own doctrine says a fault list is a sample, so the expected output is the cleaned surface and the rulings, not an exhaustive fault enumeration. **Mechanism:** `code` plus `record`. **Depends on:** M3.3.5's close.

### Artifact Inventory and Reader Graph (indefinitely deferred)

**Status:** Indefinitely deferred, raised 2026-10-23 by handover `20261023-07`. Every requirement needed to start it is in this section; a session that picks it up should not have to re-derive the census it builds on.

**Objective:** One query that reports, for every artifact the repository stores, whether it is a copy of something the tree already holds and whether anything would notice if it went stale.

**Scope:** Two halves, one instrument. The first re-derives the inventory of stored artifacts using equality instead of shape, so a table that claims to list a directory is checked against that directory rather than guessed at. The second builds a reader index, so each artifact's classification comes from who consumes it rather than from what the file looks like. The judgement is [`principle-justify-materialization-cost`](../src/reasoning/agent-runtime/pi/config/agent/skills/principle-justify-materialization-cost/SKILL.md): every artifact is either derived at read time or protected by a mechanical verification gate, decided by reproducibility first, then auditability, then cost. The census that motivates this milestone is [`20261023-design-settled-derived_artifacts.md`](discussions/20261023-design-settled-derived_artifacts.md).

**Depends on:** nothing hard. The command-table gate under M3.3.3 in [`roadmap.md`](roadmap.md) shares the equality half's first test case and may land before it.

**What the census already established.** Re-gather none of this.

- No code in this repository writes a tracked file. Generators write to the host, to `.compose/`, to a run directory or to `$AGENT_HOME`. So no stored artifact here can be rebuilt, and `regenerate and diff` has nothing to run until something writes one.
- Nine artifacts carry a classification today, in the design record's table. The live problems among them: the chart's `## Commands` table asserts equality with the 17 prompt files and no gate holds it; `settings.json` carries the image's version pin as a literal that `base.dockerfile` also states; `tests/mutations/catalog.jsonl` holds 244 rows nobody can regenerate, 7 of which no longer match their subject.
- The instrument the census used was the wrong shape and is deliberately not preserved: it guessed at equality from a share of resolvable names, it could not see a duplicated literal, and its churn metric ranked an authored config first. Expect to write a new one rather than extend it.

#### The inventory, re-derived

- [ ] **Replace the shape detectors with set equality.** For each stored table or list, compare its first column to the directory or file set it appears to mirror and report exact match, subset or drift. Nature of change: a query run by hand, printing its table, with fixture cases for the five known artifacts.
- [ ] **Add the duplicate-literal detector.** Values that appear in two or more tracked files, filtered to identifiers, versions and counts; the settings version pin is its known case. Nature of change: the same query, one detector.
- [ ] **Classify every artifact with the four names of the principle** -- `Authored source`, `Gated copy`, `Derived on read`, `Dead weight` -- and record for each which detector found it and what would catch it going stale.
- [ ] **Keep the output unstored.** The report is printed and attached to a record as evidence; it is never committed as a table, because a stored inventory is the artifact class the milestone exists to find.

#### The reader graph

- [ ] **Build the index.** For each tracked path, every file that names it, split by kind: code that opens it, a prompt or skill that instructs a reader to it, a gate that scans it, a document that mentions it.
- [ ] **Add timing.** Whether that reader runs at build, at check, or at run time, since a copy that only a human document reader opens must be stored and gated, while a copy whose readers are programs can be computed by them.
- [ ] **Answer `Dead weight` mechanically.** A path with no reader at all is the classification that costs the most maintenance and the one no shape detector can reach.
- [ ] **Answer `Derived on read` mechanically.** A copy whose every reader can see the source is a candidate for deletion from disk.
- [ ] **Print what the graph cannot do.** It cannot see a copy: two artifacts with their own readers both look healthy while disagreeing, so drift stays with the equality detectors. The report should say so where it prints, not only in this entry.

#### Acceptance criteria

- [ ] The known artifacts reproduce from the new query: the chart's command table reports drift, the version literal reports duplicate, the mutation catalog reports its stale rows, and the loop table reports a clean subset of the protocol's scope.
- [ ] Every artifact in the census table keeps its classification, or carries a recorded reason it changed.

#### Not in scope

- The two equality gates that would hold these cases still. They are separate rows in [`roadmap.md`](roadmap.md): the chart's command table under M3.3.3, and the version literal against the dockerfile pin.
- The mutation corpus's future, which is its own row and a feature decision rather than a check.
- Any stored form of the graph or the inventory, for the reason the inventory's last row states.

---

### The Unit That Ships the Wiki (permanently deferred)

**Permanently deferred (M3.3.4, 2026-10-21).** `agent-sandbox.md` is a prompt whose body sends the reader to `/opt/sandbox/docs/`, so the wiki is real and its corpus is `docs/reference/` and `docs/policies/`. A unit named `agent-sandbox` would group that entry point with its corpus, but the entry point sits in `src/reasoning/agent/prompts/` beside the harness commands, and the default unit is that folder, `src/reasoning/agent/skills/` and the two document bundles together, so the split produces two module-shaped units where one was wanted. A module also earns its existence by being enableable, and this one would be enabled by every provider image always. The row was raised by the `20261021-02` iteration and deferred rather than decided, so the unit model stays unstated and the wiki's membership stays undecided.

### Skill Ingestion as a Workflow Module (indefinitely deferred)

**Status:** Indefinitely deferred, raised 2026-11-01 by handover `20261101-10`. Every requirement needed to start it is in this section; a session that picks it up should not have to re-derive why the move is expensive. The ruling it follows is in [`module_instruction_payload.md`](../docs/adr/module_instruction_payload.md), and the closed roadmap row is `Skill ingestion stays this repository's tool, not a shipped module`.

**Reopens when:** a second project vendors a skill of its own, or the project-declaration seam lands.

**Objective:** move the skill-ingestion pipeline into `workflow/<module>/`, so a project can enable ingestion or leave it off. It is repository-local today because two of its three members are project and harness state, and a module carries `prompts/` and `skills` only.

**Depends on:** M3.4.7 `Environment declaration seam`, and a way for a shipped module to register a lint gate.

**The prefactors, in the order they bind:**

- [ ] **The project declares where its registry lives** -- `source_bump.mjs` resolves its root to the repository it runs in and expects `.agents/registry/sources/`; M3.4.7 owns where a project declares a path like that. Ends when a project names its registry root in a declaration the CLI reads, and a fixture project's store sits somewhere other than that fixed path.
- [ ] **A shipped module can register a lint gate** -- `scripts/lint.sh` holds the gate list and a module's payload is its two folders, so a module cannot add a commit-time check. Ends when a gate shipped with a module runs under the umbrella, with a test that a failing module gate fails the umbrella and names its module.
- [ ] **The store's tooling has a transport** -- `scripts/skill_store.mjs` and `scripts/source_bump.mjs` are repository scripts, and their tests run against the tree. Ends when both resolve from one installed location in any project, and the suite runs against that copy.
- [ ] **The workflow layer enumerates modules from the manifest** -- `scripts/skill_layers.mjs` names the coding-agent module's skills folder literally, so a second module is invisible to the layer map, the collision gate and the reference gate. Ends when a second module appears in all three with no name added by hand.
- [ ] **The registry's owner is decided** -- whether `.agents/registry/sources/` is project data, each project owning its edges, or payload shipped with the module. Ends when one is chosen and the canonical-form gate reads the store from the place that choice names.
- [ ] **The module's membership is decided** -- whether the module means "vendor a skill" and carries `skill-fork` alone, or "do skill work" and carries the authoring side too, which needs the [merged instruction-writing surface](#merge-instruction-authoring-and-project-documentation-deferred-unscheduled) first; and whether `backlog-triage` leaves the coding-agent module. Ends when the payload is listed and no skill names a member of two modules.
- [ ] **The name is chosen** -- `skill-management` is a candidate and not a decision, and the name is owed by a module that exists. Ends when the directory exists under that name.
- [ ] **This repository migrates** -- its own skills move into the module and its provider config enables it. Ends when `.agents/skills/` holds no skill the module ships, and the layer map reports the module as the skills' source.

### Merge Instruction-Authoring and Project-Documentation (deferred, unscheduled)

**Status:** Deferred, unscheduled, raised 2026-11-04 while merging the boundary-violation rule into `principle-single-source-of-truth`. The two conventions overlap at the placement layer, but they have different scopes, readers and release rules. This task decides whether they should become one convention. It does not assume the merge.

**Reopens when:** the SSOT scoping merge lands and `instruction-authoring` points at `project-documentation/references/organization.md` for placement, or when the two conventions drift again.

**Objective:** decide whether one authoring convention should own both the documentation and the instruction surface, and if so, merge them without losing the distinct release rules.

**Scope:** the two conventions, their references, the placement rule, the readers and the release paths. [`project-documentation`](../.agents/skills/project-documentation/SKILL.md) governs `docs/`; [`instruction-authoring`](../.agents/skills/instruction-authoring/SKILL.md) governs prompts and skills. Diataxis covers both, per [`documentation_quadrants.md`](../docs/adr/documentation_quadrants.md), and the how-to mode is the instruction surface. A merge is justified only if the shared placement rule outweighs the cost of one convention carrying two purposes. If they stay separate, [`organization.md`](../.agents/skills/project-documentation/references/organization.md) is the single placement source and `instruction-authoring` points at it. Out of scope: the SSOT skill merge and the immediate cross-reference.

**Depends on:** the SSOT scoping merge, because it is the first test of whether `organization.md` can be the shared placement source.

**Acceptance criteria:** a recorded decision, merge or keep separate, with the rationale. If merge, one convention carries the placement rule and the two authoring branches, and no release rule is lost. If keep separate, `organization.md` is the single placement source and `instruction-authoring` points at it. Ends when no placement rule is stated twice.

### Trunk serialization when an agent manages the trunk (deferred, unscheduled)

**Status:** Deferred, unscheduled, raised 2026-11-14 by the design iteration `20261114-02`. Merge-back is the operator's manual host act today: the operator runs `make confirm` and `make apply`, one branch at a time. The runbooks that tried to automate it (`accept-fast-forward`, `merge-queue`, `prepare-rebase`) were retired on 2026-11-12 because they mirrored host verbs. Nonblocking while the operator holds the trunk; blocking when an agent accepts a branch without the operator.

**Reopens when:** an agent manages the trunk branch, accepting, serializing or applying branches on its own.

**Objective:** the trunk accepts one branch at a time as a property of the flow, so serialization is a scheduler rather than a rule the operator must remember while running a host verb. The method is the implementer's; the requirement is that two branches cannot be accepted into one trunk position at once.

**Scope:** the accept flow and the host verb set. Out of scope: the branch-preparation primitives, which landed as `prepare` and `history-cleanup`.

**Depends on:** the change model's accept transitions in [`change_pipeline.md`](../docs/reference/change_pipeline.md), which are landed. The requirement is a property of the flow, not of this document.

**Sources:** the merge queue as GitHub and Bors implement it, read for the queue's semantics rather than copied as a runbook. The citation record is the implementer's to add; the intent above does not depend on which one they choose.

**Ends when:** an accept flow serializes the trunk mechanically, or the operator's serialization obligation is stated with its tradeoff named, and the source is recorded.

### A size suggestion for one unit of work (deferred, unscheduled)

**Status:** Deferred, unscheduled, raised 2026-11-14 by the operator as an aside to `20261114-04`. The project has no working definition of "one unit of work" beyond "a coherent change". The review literature offers a numeric one: Google's small-CL guidance (a change reviewable in one sitting, on the order of 100 lines) and the SmartBear/Cisco 2006 rate (200-400 lines per review hour before defect detection falls). Both bound the diff, which is what they can measure; a message-length number is not derivable from them.

**Reopens when:** the delivery-commit rules or the change model need a size test, and the operator wants a suggestion rather than a gate.

**Objective:** the project states a size suggestion for a unit of work as advice a reviewer and an agent may apply, never a gate. A mass rename, a regenerated artifact or a lockfile exceeds any line count while remaining one unit, so a threshold that failed a commit would refuse the changes most obviously single. The method is the implementer's; the requirement is that the suggestion carries the two sources and the exception it cannot judge.
