# Container Execution Model

**Current:** 2026-11-12

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One diff source of truth | the diff pipeline reads exactly one filesystem, whatever the environment |
| R2 | One owner per plane | each ownership slice has exactly one owner, named in the model |
| R3 | Reserved vocabulary | `layer` names the container architecture and nothing else |
| R4 | Stabilization order | a plane stabilizes before the next, within a sub-domain; a sub-domain stabilizes before the next |
| R5 | A bidirectional declaration | what a project declares to the harness, and what the harness may write into a project, are both stated |

## 2026-11-12 -- One owner at a time, and the declaration crosses in both directions

**Decision:** A plane has exactly one owner at every point of a move. The environment declaration is **harness-owned today**, and M3.4 moves it to the project, so the model names the harness rather than a contested target. The fifth plane is the **verification plane**: a plane is named by its concern, and `surface` no longer names an ownership slice, so `surface` stays inside the workflow vocabulary, where instruction roots and the maintenance surface carry it. The environment declaration's access contract is the **declaration interface**. `seam` and `interface` are unreserved: both are ordinary with a qualifier, as `unit` is, and neither names a plane. The declaration is bidirectional per R5: a project declares its environment to the harness, and the harness writes into a project only what that declaration or the session guarantee permits.

**Rationale:** R2 required exactly one owner while `system_overview.md` described the environment declaration as "contested; the project is the target owner". Contested is the transition the milestone performs, not an owner, so the authority document stated something R2 forbids. Naming the harness keeps the model true at every point, and it gives the milestone a mechanical close check: the owner cell is the evidence, so M3.4.7 cannot close without it changing. `surface` carried three senses - instruction root (`coding_agent_project_bindings.md`), the maintenance surface of the workflow prompts, and the ownership slice - and the third is the one that leaves. The bidirectional half is measured, not argued: the capability entrypoint installs a pre-commit hook into every project's `.git/hooks`, and the seeder writes the harness's git identity and config keys into every project's `.git/config`, while the model stated only the project-to-harness direction. The measurement is the record `20261112-design-open-m3_4_project_harness_contract_and_prefactors.md`.

**Rejected alternatives:**

- *Contested, with the project as target owner.* Rejected on execution. It leaves the model forbidding what the architecture document states, which is the defect rather than its fix, and it gives the milestone no close check.
- *Keep `surface` for the ownership slice and define its senses.* Rejected on intent. Three senses under one word is what the reserved-terms table in `coding_agent_project_bindings.md` was written to prevent, and a glossary entry records the collision instead of resolving it.
- *Project-to-harness only, as the milestone previously stated.* Rejected on execution. The measured table in the record falsifies it.

**Edge cases / drivers:**

- The declaration's element list is not settled, so the trust classification of each element is open and the record holds it. A declaration carrying build steps and hooks is code, not configuration, so a classification that treats the whole declaration as configuration would satisfy R5 in prose and not in effect.
- The bidirectional rule is about writing into a project's tree and its git state. It does not reach the session volume, the diff pipeline or the session record, which are the session guarantee's and stay harness-owned.
- Historical records are not retro-renamed: `verification surface`, `declaration seam` and `declaration surface` stay in closed handovers and discussions. The 2026-10-15 entry below also keeps `verification surface`, because an entry records what was decided then; this entry supersedes the name, and the live plane list is this one and [`system_overview.md`](../reference/system_overview.md)'s.

## 2026-10-15 -- Sub-domains and planes, with a reserved vocabulary

**Decision:** The system is described by a domain model. The domain is **agentic engineering**. It divides into **sub-domains** by execution extent: infrastructure, single-agent execution, multi-agent orchestration. Each sub-domain divides into **planes** by environment ownership: host substrate, session guarantee, environment declaration, project data and caches, verification surface. A plane owns one concern and has exactly one owner, the operator, the harness, or the project. The vocabulary is reserved in [`terminology.md`](../reference/terminology.md): `layer` for the container architecture, `domain` for the problem field, `sub-domain` for an execution-extent division, `plane` for an ownership slice. This supersedes the three-layer implementation stack in [`system_overview.md`](../reference/system_overview.md).

**Rationale:** The prior model answered one question, how many agents execute, and the earlier `layer` wording was already flagged by the T8 row `A controlled vocabulary for layer` as carrying seven senses. The prior freeze column named M1.5 and M2, both closed, so it described a plan from three milestones ago. It had no axis for M3 or for the environment contract, which is why every environment-ownership concern had to be filed into the two lowest layers and would have unfrozen them wholesale. The domain and plane model localizes the change: the environment declaration is one plane, and the current work moves it to project ownership without touching the session guarantee. Measured term collisions decided the vocabulary. `tier` carries 37 uses, split between the Docker build tiers (`src/reasoning/base.dockerfile:3`, `scripts/build.sh`) and the `model-failover` dispatch tiers (`router.ts:8`), and its common meaning is a physical or deployment separation. `boundary` carries 99 uses, with the trust boundary load-bearing. `scope` carries 355 uses as the task-specification extent, and `context` 197 as the agent context. `plane` carries zero.

**Rejected alternatives:**

- *`tier` for execution extent.* Rejected on execution. It collides with two live senses in the tree and would make `tier 3` mean either the provider image or multi-agent execution depending on the file.
- *`boundary` for execution extent.* Rejected on intent. A boundary names a line, not an extent, and `trust boundary` is load-bearing in the same documents.
- *`scope` or `context`.* Rejected on intent. Both are already reserved, for the task-specification extent and the agent context respectively.
- *Keep the three-layer implementation stack.* Rejected on intent. It is too shallow to localize the change it guides, and a whole-layer freeze forces unrelated planes to move together.
- *A unified numbering across every axis.* Rejected on intent, consistent with [`coding_agent_project_bindings.md`](coding_agent_project_bindings.md). The axes lie on different questions, and a unified number would invent the ordering between them.

**Edge cases / drivers:**

- The DDD sense of `domain` is load-bearing. The harness is a problem within the domain of agentic engineering, and the sub-domains are bounded contexts of it that overlap at the edges rather than nesting cleanly.
- The session guarantee plane is topology-conditional. It nests under single-agent execution today; multi-agent orchestration will force its re-cut, because the guarantee becomes per-agent. It is not invariant across sub-domains, and the only truly invariant plane is the host substrate.
- The freeze status is scoped to a plane, never to a file, and never to a whole sub-domain once a plane inside it changes.
- The `active-milestone` scalar cannot represent two concurrent sub-domains. That is a task-list-mechanism defect owned by M3.5, not this model.
