# agent-sandbox -- Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely -- this file is not a historical record. The changelog is.

---

## W1 -- Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone -- separate workflow for the Obsidian vault use case. Re-activate when the KV5 timeline demands it.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first (direct `sandbox/` mount, no MCP), then add MCP server as an enhancement. Unblocks KV5.

**Depends on:** the M2 two-layer foundation, closed in [`changelog.md`](changelog.md#m2---reasoningcapability-layer-separation).

The hermes provider was removed on 2026-11-07 rather than kept dormant: it was unused, its build path had drifted, and it was the only thing making the tier list depend on the provider. The integration task below is where it comes back, and it comes back when this milestone has a use for it.

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency -- see [`20260312-study-settled-mcp_server.md`](discussions/archive/20260312-study-settled-mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] **Integrate hermes as a provider** -- the source-built runtime returns as a provider on the harness's terms, so a session can run a workflow that needs its media and browser surface. It left on 2026-11-07 because nothing ran it and its build path had drifted; `<provider>-base` stayed in `build_agent` as its extension point, and the order test that covers that branch runs on a fixture provider until a real one returns. Trigger: this milestone needing a runtime the registry-package providers do not give, which is the surface the vault and MCP work would reach for. Nature of change: a provider directory with its two Dockerfiles and overlays, the manifest's rows, the live documents that name the provider set, and the pin rows the new inputs owe.
- [ ] Update `execution_model.md` -- document capability layer variants (general vs vault+MCP)

---

## W2 -- Communication Domain Taxonomy

**Status:** Not started. Scoped 2026-10-19.

**Objective:** A consolidated workflow section for the deep approach to the communication domain: a taxonomy of the reader's processing costs that slices the domain into principles, a controlled vocabulary of the domain terms, and a measured answer to whether those terms signal the domain to an agent. The output is one communication surface that owns the domain.

**Depends on:** M3.3.5, which owns the eval module the signalling experiment needs; and M3.3.4's principle cleanup, at minimum the removal of the duplicate declaration locations across `documentation_policy.md` `## Communication Standards`, `prompt-authoring-conventions.md`, and the `instruction-authoring` skill.

**Tasks:**

- [ ] Run the communication-domain taxonomy. Run brief: [`.agents/drafts/communication-domain-taxonomy-run.md`](../.agents/drafts/communication-domain-taxonomy-run.md).
- [ ] **Populate the leading words across the corpus.** `metadata: leitwort:` is declared on the principle skills and most words are blank; its definition half is closed, the population pass remains. M3.3.4 ran a pass that produced one word per skill, the operator rejected the set, and it was reverted, so `proximity` and `leverage` stand, each naming its own skill's subject, and `sediment` stands on `cut-what-carries-nothing`, adopted 2026-10-28 with the body anchored to it. What a leading word is, and which word leads, is `communication-principle-maximize-conceptual-leverage`; where it goes is `instruction-authoring`'s signposting pattern. The judging pass belongs with this sub-milestone's controlled vocabulary, where the territory is settled before a part of it is named. A gate over the field is unfiled, because presence is all a gate can read and no gate sees a thinking trace. Evidence: [`AGENT_FEEDBACK.md`](AGENT_FEEDBACK.md) **A vocabulary was chosen for flavour and reverted**.
  - [x] **The field's definition is stated** -- what the word is, that it sits at `metadata: leitwort:`, and that it is set only where the body already teaches it. Closed 2026-10-28: the definition is in `communication-principle-maximize-conceptual-leverage`, the placement owner names the field, and the feedback entry is mitigated. Filed out of order; W2 stays `Not started` until its dependencies land.

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
- [x] Bump cadence policy -- the operator decides when to bump, on new functionality needed, a critical fix, or a security vulnerability, with no automation. The bump edits the pinned version in `src/reasoning/providers/pi/base.dockerfile` and rebuilds.
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
