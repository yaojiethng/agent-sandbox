---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Design
status: Closed
---

# Handover - skill ingestion is this repository's tool

## Objective

Settle whether skill ingestion becomes a shipped module, record the answer where the next reader of that question looks, and file the shipping work as a deferred task that carries every prefactor, so the roadmap row stops reserving a name and a shape the tree cannot deliver while the cost of paying for it later stays known.

## Scope

The roadmap row `Package skill ingestion as its own workflow`, which asks that fork-and-strip, the store edge and the backlog triage become one workflow a project can enable or leave off, under a name left open (`skill-management` was a candidate, not a decision).

**The ruling: ingestion stays this repository's tool.** It is not packaged as a module, no module name is chosen, and the three members remain where they are. What has to be written is the ruling and the reason, not a mechanism.

Three measurements settle it.

**Two of the three members belong to this repository, not to the workflow.** `.agents/skills/` holds 12 project skills, including `skill-fork` and `skill-scaffolder`; `workflow/coding-agent/skills/` holds 9 shipped ones, and neither of those two is among them. The store, `scripts/skill_store.mjs`, `scripts/source_bump.mjs` and `.agents/registry/sources/` are project and harness state. Only `backlog-triage.md` is already shipped, inside the existing module.

**A module cannot carry those members.** A module's payload is `prompts/` and `skills/`, stated in `docs/development/instruction-surface-conventions.md`, in its `workflow/<module>/` statement and in the ADR [`module_instruction_payload.md`](../../docs/adr/module_instruction_payload.md). A module is enabled by naming its directory as a package, so a project may omit it and get neither folder. The store is data in the project tree, the CLI and the gate are harness scripts, and the gate is registered in the `GATES` array of [`lint.sh`](../../scripts/lint.sh), which no module owns. A shipped module could not register a gate, and a project that omitted the module would still need the gate or lose the store's validity check.

**Shipping it needs a declaration surface that does not exist.** `source_bump.mjs` resolves its root to the repository it runs in, and the store sits at a fixed relative path in that tree. A shared tool has to be told where a project keeps its registry, which is the question [M3.4.2](../../devlog/roadmap.md) `Environment declaration seam` owns and which is `Not started`. Packaging ingestion is therefore not one iteration; it waits on that seam.

**And no consumer waits for it.** The only second project in the roadmap, `The vault project as the second-project portability proof`, is `Not started`. Building the packaging for it now is the shape [`principle-delegation-over-machinery`](../../src/reasoning/providers/pi/config/agent/skills/principle-delegation-over-machinery/SKILL.md) was landed to refuse: a mechanism whose two answers are both empty.

**The module keeps its real subject.** The sibling row `The four pstack skills are optional, not base` wants `teach`, `how`, `why` and `unslop` to arrive as an optional module, and that is what the form is for: a pack of skills someone else wrote, enabled or omitted by a package entry, carrying no tooling. The module loses the wrong tenant and keeps its purpose. That row is untouched here.

**The reopening condition is a task, not a clause.** A line in a closed row saying "reopen when a second project vendors a skill" holds no work and is read by nobody. So the shipping route is written in full under `## Deferred (Unplanned)` in [`roadmap_future.md`](../roadmap_future.md), which already carries the precedent: `Artifact Inventory and Reader Graph (indefinitely deferred)` states that every requirement needed to start it is in its section. That section owns the prefactors and the interfaces; this iteration's closed row and the ADR entry point at it.

Three rules keep the deferred section from rotting:

- **Names, never derived values.** No count, no line number, no other row's status. A deferred section that states "19 gates" or a file's line number is stale the next time either moves, and nothing checks this file: `roadmap-maintenance` audits it by judgement and is dispatched only on request.
- **Each prefactor is a row with a checkable end**, so picking the task up starts at a list rather than at a design.
- **The pointer lives where the question is asked.** A maintainer asking whether something can be a module reads `docs/adr/module_instruction_payload.md`, so the ADR entry names the deferred section. That covers the one risk the deferred file cannot cover itself: its trigger may land in a session that never opens it.

The ruling matches M3.3.3's own objective, which says the pipeline "adapts it to agent-sandbox" - the repository, not the workflow - and acceptance criterion 1, which names an operator working in this tree.

Two things follow that this iteration does not do. `skill-scaffolder` and `skill-fork` both stay project-layer, so the pipeline is repository-local end to end, and `Move the documentation-writing and skill-writing guidelines under skill-scaffolder` becomes the next task in the same direction. And the fork lifecycle's placement is already correct: `skill-fork` is a top-level project skill beside `skill-scaffolder`, not nested under it, so nothing about the ruling depends on that split being revisited.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The roadmap row closes as the ruling, not as a deletion: ingestion is repository-owned, and the row points at the deferred task that owns the shipping work | read the row in `devlog/roadmap.md`; `grep -n 'skill-management' devlog/roadmap.md` = `0` | accepted: the row closes as `Skill ingestion stays this repository's tool, not a shipped module`, and names no module name at all |
| The module boundary is recorded where a maintainer deciding what a module carries will read it, with the pointer to the deferred task | a dated entry in `docs/adr/module_instruction_payload.md` naming the three reasons and the pointer | accepted: `## 2026-11-01 -- Skill ingestion is harness-owned, and a module carries no tooling`, with three rejected alternatives, and `Current` moved to that date |
| The shipping work exists as a deferred task carrying its prefactors and the interfaces it would need, including a way for a shipped module to register a lint gate | `## Deferred (Unplanned)` in `devlog/roadmap_future.md` holds the section; read it for a prefactor row each with a checkable end | accepted: eight prefactor rows, from the project's registry declaration to this repository's own migration |
| The deferred section carries no derived value, so it does not rot as the tree moves | read the section: every fact is a name or a gap, with no count, no line number and no other roadmap row's status | accepted: `grep -nE '[0-9]+ (gate\|skill\|module)s?\b'` over the section returns nothing |
| The three members read as one workflow from the skill a reader already has open | one sentence in `.agents/skills/skill-fork/SKILL.md` naming fork, bump and triage as the pipeline | accepted: `## The pipeline it belongs to` names the three members and links the ruling |
| The sibling module row is unchanged and still names its subject | `git diff devlog/roadmap.md` shows no edit to `The four pstack skills are optional, not base` | accepted: `git diff --numstat` = 1 insertion, 1 deletion across the whole file |
| The suite and the lint gates are clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | accepted: clean across 19 gates; 1433 tests across 104 files, 0 failed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Ingestion is this repository's maintenance tool, not a shipped module | two of its three members are project state and harness code, and a module carries prompts and skills only | the roadmap row, and the ADR entry |
| No module name is chosen, and `skill-management` is not adopted | a name is owed by a thing that exists; the row's name question dies with the row | the roadmap row |
| The module keeps its own subject: optional skill packs, of which the pstack set is one | a pack of someone else's skills is exactly what the form carries, and it needs no tooling | the sibling row, unchanged |
| Packaging ingestion waits on the declaration seam (M3.4.2), not on a module mechanism | the store's location is project state, and no surface declares it yet | the ADR entry |
| The reopening condition is a deferred task, not a clause in a closed row | a clause holds no work and is read by nobody; the deferred section holds the prefactors, and the ADR holds the pointer because that is where the module question is asked | the roadmap row, the ADR entry and the deferred section |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Two of the row's three members are project-layer, and one of those is harness code a module cannot carry | finding | the row as written cannot be delivered by any module-shaped change | this record: the row closes as the ruling |
| The module form's payload is `prompts/` and `skills/`, and the gate that holds the store valid is registered in the harness's `GATES` array | finding | a project omitting the module would lose the store's only check, so packaging the tooling would break the thing it packages | the ADR entry |
| `scripts/skill_layers.mjs` names `workflow/coding-agent/skills` literally, so a second module would be invisible to the layer map and the collision gate | defect | the prefactor for any second module is a derived module list, and it belongs to whichever row lands one | fixed: it is the fourth prefactor in the deferred section, where a module list has to come from the manifest before any second module exists |
| My own cost estimate for the shipping route was wrong: I called it one medium iteration, and its real prefactor is M3.4.2 | defect | a scope proposal built on it would have failed at the first file | this record: corrected in Scope |
| The roadmap already owns the module's real subject in the pstack row | finding | the row being closed was holding a form that another row needs, so closing it removes no capability | the sibling row, unchanged |
| A deferred section is triggered by an event a session may never look for, and `roadmap-maintenance` reads `roadmap_future.md` only when dispatched | risk | the shipping work could sit unfound long after it became cheap | mitigated: the ADR entry points at it, and that is where a maintainer asks whether something can be a module |

## Completed

| File | One-line change |
|---|---|
| `devlog/handovers/20261101-10-design-skill_ingestion_scope.md` | this record |
| `devlog/roadmap.md` | the row closes as the ruling, its child stays open, and no module name survives |
| `devlog/roadmap_future.md` | `### Skill Ingestion as a Workflow Module (indefinitely deferred)`: eight prefactors, the reopening events and the dependency |
| `docs/adr/module_instruction_payload.md` | the 2026-11-01 entry: what a module carries, why the tooling cannot be a member, and the pointer |
| `.agents/skills/skill-fork/SKILL.md` | `## The pipeline it belongs to` names its three members |
