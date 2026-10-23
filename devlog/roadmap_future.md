# agent-sandbox -- Future Milestones

Detail sections for milestones not yet active. Kept separate from [`roadmap.md`](roadmap.md) to keep the active milestone document focused and fast to read.

**Promotion rule:** when a milestone becomes active, move its section from here into `roadmap.md` under `## Upcoming Milestones`. Update the summary table row in `roadmap.md` to point to the local anchor. Remove from this file.

**Re-scoping note:** milestone definitions here are planning targets, not commitments. They are expected to evolve as implementation matures and earlier milestones reveal new constraints. Rewrite sections freely -- this file is not a historical record. The changelog is.

---

## W1 -- Vault Capability Layer Prototype

**Status:** Deferred. Not a mainline milestone -- separate workflow for the Obsidian vault use case. Re-activate when the KV5 timeline demands it.

**Objective:** Extend the capability layer for the Obsidian vault use case. Validate sandbox-only first (direct `sandbox/` mount, no MCP), then add MCP server as an enhancement. Unblocks KV5.

**Depends on:** the M2 two-layer foundation, closed in [`changelog.md`](changelog.md#m2---reasoningcapability-layer-separation).

**Hermes python base refactor (non-urgent):** The shared `python-harness` base was designed but never built. Hermes currently builds independently from `python:3.11-slim` rather than inheriting from the harness. If W1 can be implemented without Hermes, consider removing Hermes support entirely rather than maintaining a dormant provider.

**Tasks:**

- [ ] Validate vault workflow with sandbox-only configuration: agent accesses vault files directly via `sandbox/`, diff reviewed and applied to vault repo
- [ ] Evaluate MCP server candidates; select one (criteria: licence, maintenance, path traversal protections, binary file handling, no Obsidian runtime dependency -- see [`20260312-study-settled-mcp_server.md`](discussions/archive/20260312-study-settled-mcp_server.md) candidates table)
- [ ] Build vault capability layer image: extends base capability layer image, adds selected MCP server
- [ ] Configure OpenCode to connect to MCP server; validate it routes vault operations through MCP tools when server is present
- [ ] Validate binary file handling (vault attachments) under selected MCP server
- [ ] Validate KV5 end-to-end: agent modifies vault via MCP tools, diff reviewed, applied to vault repo
- [ ] Update `execution_model.md` -- document capability layer variants (general vs vault+MCP)

---

## W2 -- Communication Domain Taxonomy

**Status:** Not started. Scoped 2026-10-19.

**Objective:** A consolidated workflow section for the deep approach to the communication domain: a taxonomy of the reader's processing costs that slices the domain into principles, a controlled vocabulary of the domain terms, and a measured answer to whether those terms signal the domain to an agent. The output is one communication surface that owns the domain.

**Depends on:** the eval module, so the signalling experiment can run; and M3.3.4's principle cleanup, at minimum the removal of the duplicate declaration locations across `documentation_policy.md` `## Communication Standards`, `prompt-authoring-conventions.md`, and the `skill-scaffolder` skill.

**Tasks:**

- [ ] Run the communication-domain taxonomy. Run brief: [`.agents/drafts/communication-domain-taxonomy-run.md`](../.agents/drafts/communication-domain-taxonomy-run.md).
- [ ] **Populate the leading words across the corpus.** `metadata: leitwort:` is declared on the principle skills and the words are blank. M3.3.4 ran a pass that produced one word per skill, the operator rejected the set, and it was reverted, so `proximity` and `leverage` stand, each naming its own skill's subject. What a leading word is, and which word leads, is `communication-principle-maximize-conceptual-leverage`; where it goes is `principle-skill-signposting`. The judging pass belongs with this sub-milestone's controlled vocabulary, where the territory is settled before a part of it is named. A gate over the field is unfiled, because presence is all a gate can read and no gate sees a thinking trace. Evidence: [`AGENT_FEEDBACK.md`](AGENT_FEEDBACK.md) **A vocabulary was chosen for flavour and reverted**.

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
- [ ] `apply_workspace.sh --branch=<n>` supports named branches per agent
- [ ] Validate branch contents before merge
- [ ] Merge branch -> `main`
- [ ] Evaluate whether to adopt existing checkpoint branch logic (`workflow/knowledge-vault/scripts/`) as the harness-level branch management mechanism, or design purpose-built tooling -- decision depends on M2.4 checkpoint branch pattern outcome

---

### M4.3 -- Task Dispatch

**Objective:** Extend the execution model to support coordinated dispatch of multiple task briefs across agents. Design precedes implementation -- `execution_model.md` must be updated before any code changes.

- [ ] Design multi-task coordination model -- how multiple task briefs are dispatched, sequenced, and tracked across agents
- [ ] Update `execution_model.md` to reflect dispatch model before implementation begins
- [ ] Implement dispatch mechanism in harness

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

- [ ] Build the background-work surface on `.agents/drafts/parallel-work.md`

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

- [ ] Introduce `.config/workflow.yaml`
  - [ ] Configure network access
  - [ ] Configure resource limits (`--memory`, `--cpus`)
  - [ ] Define allowed directories and workflow rules
- [ ] Enforce policy configuration in container startup
  - [ ] Add automated isolation validation checks
- [ ] Implement `safe` mode: `--network=none` enforcement
  - [ ] Evaluate `--network=none` mode for non-AI execution
- [ ] Implement `restricted` mode: Restrict outbound network access
  - [ ] Introduce outbound proxy or domain filtering to required AI endpoints

#### Dependency Security

Part of M7 -- supply-chain hardening for provider runtime dependencies.

- [x] Pi version pinned in the provider base Dockerfile; the pin moves with the `pi-bump` unit that owns it
- [x] Node base image pinned to specific version (`node:22.22.3-slim`)
- [ ] Consider lockfile for `npm install -g` dependencies (transitive dependency locking)
- [x] Bump cadence policy -- the operator decides when to bump, on new functionality needed, a critical fix, or a security vulnerability, with no automation. The bump edits the pinned version in `src/reasoning/providers/pi/base.dockerfile` and rebuilds.

---

### M9 -- Governance Hardening

Progressive enforcement maturity for the documentation and architecture governance model. Each level builds on the previous.

- [x] Level 1 -- Structural Separation -- folder ownership, temperature classification, root document audience separation
- [ ] Level 2 -- Review Discipline -- PR template with required "does this change system behaviour?" checkbox
- [ ] Level 3 -- Temperature & Freeze Policy -- hot/cold system and doc-status layer freeze formalised as enforced convention, not just policy
- [ ] Level 4 -- Change Classification Matrix -- explicit categories (invariant / design / additive / corrective) with per-class review requirements; gives the PR gate question resolution beyond binary yes/no
- [ ] Level 5 -- Automated Enforcement -- CI/tooling enforcement of freeze policy and agent write restrictions on cold and frozen documents

---

## Harness Packaging and Versioning (Standalone)

**Objective:** Self-contain the agent-sandbox binary at install time and introduce semantic versioning to detect and communicate staleness. This is the prerequisite for harness-sig (runtime drift detection).

**Problem:** `make install` writes an `agent-sandbox` CLI script that sources scripts/libs/templates from the repo checkout at runtime. After `git pull`, the installed binary silently executes changed code. No mechanism signals the operator to reinstall.

**Solution path -- two complementary changes:**

1. **Self-contained binary.** `make install` packages all scripts, libs, and templates into the binary itself (shar archive or similar). The installed binary has zero runtime dependency on the repo checkout. This eliminates the entire class of host-side drift problems.

2. **Semantic versioning.** A `VERSION` file in the repo root, bumped on meaningful changes. The installed binary writes its version to `~/.config/agent-sandbox/.version` at install time. At `make start`, the harness compares installed version against repo version and warns on mismatch.

   Bump policy:
   - **Patch** (0.x.1): lib/script bugfixes, behaviour-preserving internal changes
   - **Minor** (0.1.x): new features, new flags, new Makefile targets
   - **Major** (1.0): breaking CLI changes, install contract changes, deployment model changes

**Depends on:** M2.7 completion (container-sig, build pipeline cleanup). Not part of any current milestone.

**Preconditions for design:**

- Self-contained binary mechanism selected (shar archive vs compiled language vs proper package manager)
- Version bump policy agreed and documented
- Dogfood vs non-dogfood usage split understood (determines where the comparison target lives)

**Design reference:** [`devlog/discussions/archive/20260522-study-superseded-harness_sig_requirements.md`](./discussions/archive/20260522-study-superseded-harness_sig_requirements.md)

---

## Deferred (Unplanned)

### Artifact Inventory and Reader Graph (indefinitely deferred)

**Status:** Indefinitely deferred, raised 2026-10-23 by handover `20261023-07`. Every requirement needed to start it is in this section; a session that picks it up should not have to re-derive the census it builds on.

**Objective:** One query that reports, for every artifact the repository stores, whether it is a copy of something the tree already holds and whether anything would notice if it went stale.

**Scope:** Two halves, one instrument. The first re-derives the inventory of stored artifacts using equality instead of shape, so a table that claims to list a directory is checked against that directory rather than guessed at. The second builds a reader index, so each artifact's classification comes from who consumes it rather than from what the file looks like. The judgement is [`principle-guard-derived-state`](../src/reasoning/providers/pi/config/agent/skills/principle-guard-derived-state/SKILL.md): every artifact is either derived at read time or protected by a mechanical verification gate, decided by reproducibility first, then auditability, then cost. The census that motivates this milestone is [`20261023-design-settled-derived_artifacts.md`](discussions/20261023-design-settled-derived_artifacts.md).

**Depends on:** nothing hard. The cited-command check row under M3.3.2 in [`roadmap.md`](roadmap.md) shares the equality half's first test case and may land before it.

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

- The two equality gates that would hold these cases still. They are separate rows in [`roadmap.md`](roadmap.md): the cited-command check, and the version literal against the dockerfile pin.
- The mutation corpus's future, which is its own row and a feature decision rather than a check.
- Any stored form of the graph or the inventory, for the reason the inventory's last row states.

---

### Doc Language Cleanup -- STE-Clean Sweep

**Deferred (workflow session `20260809-03`).** Bring the remaining docs, policies, and agent files to the Simple Technical English (ASD-STE100) standard: objective and technical, disambiguated from conversational context, no dead prose, one concept per sentence. New and changed policy is already drafted to this standard (see the agent-feedback/gotchas finalized-workflow artifact); the sweep applies it to the existing body of docs/policies/agent files. Large scope; deferred here.

### Copy-Model Seeding -- Host-Side Volume Seed (M2.6.5 follow-up, complete)

The volume is seeded host-side before the sandbox container starts, so the entrypoint mounts no snapshot directory: the compose template carries no `SNAPSHOT_DIR` mount, the `baseline.tar` preflight gate is removed with the mount, and the `snapshot_dir` environment and session-state writes are retired repo-wide. Model: [`docs/reference/copy_delivery.md`](../docs/reference/copy_delivery.md); design record [`20260730-design-settled-mount_model.md`](./discussions/archive/20260730-design-settled-mount_model.md). Handovers `20260818-02` (the copy-in decision) and `20260901-14` (the implementation). The entrypoint branch inversion (`if ! -d .git` then init, else resume bookkeeping) belongs to the M2.6.6 delivery scope and is not filed here.

### M2.6.7 -- Interface Contract Compatibility (complete)

One version constant, one image label, one warn-only preflight check, and a hard stop on a container-to-container mismatch; a missing record key still warns, which is the upgrade path. Interface concept doc `docs/reference/sandbox_host_interface.md`, lifecycle architecture doc `docs/reference/sandbox_lifecycle.md`, ADR `docs/adr/interface_contract_compatibility.md`. Handovers `20260919-03` (design), `20260919-04` (implementation) and `20260919-05` (documentation); design record [`20260919-design-settled-interface_contract_compatibility.md`](./discussions/archive/20260919-design-settled-interface_contract_compatibility.md). The `container-sig` mechanism this sub-milestone superseded was retired at `20260919-08`.

### The Unit That Ships the Wiki (permanently deferred)

**Permanently deferred (M3.3.4, 2026-10-21).** `agent-sandbox.md` is a prompt whose body sends the reader to `/opt/sandbox/docs/`, so the wiki is real and its corpus is `docs/reference/` and `docs/policies/`. A unit named `agent-sandbox` would group that entry point with its corpus, but the entry point sits in `src/reasoning/agent/prompts/` beside the harness commands, and the default unit is that folder, `src/reasoning/agent/skills/` and the two document bundles together, so the split produces two module-shaped units where one was wanted. A module also earns its existence by being enableable, and this one would be enabled by every provider image always. The row was raised by the `20261021-02` iteration and deferred rather than decided, so the unit model stays unstated and the wiki's membership stays undecided.

### Environment-Change Persistence -- Install Layers Across Runs (Not in scope, current model)

**Deferred / not-in-scope (design walk `20260818-02`, persistence-model decision).** The current model (copy and bind-mount) does not persist environment changes across runs: apt installs, `pi update --self`, `pi install` live in the per-run container writable layer, torn down at every run end (per-run writable-layer parity). Persisting them is explicitly NOT in scope for the current model -- containers are per-run; persistence is delivered exclusively by mounted sources. It would be nice to have. Candidate, parked, if per-run install cost proves punishing: a persisted install-cache volume fed per run (durable-by-designation), not a second writable layer.
