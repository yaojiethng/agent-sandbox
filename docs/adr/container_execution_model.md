# Container Execution Model

**Current:** 2026-10-15

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One diff source of truth | the diff pipeline reads exactly one filesystem, whatever the environment |
| R2 | One owner per plane | each ownership slice has exactly one owner, named in the model |
| R3 | Reserved vocabulary | `layer` names the container architecture and nothing else |
| R4 | Stabilization order | a plane stabilizes before the next, within a sub-domain; a sub-domain stabilizes before the next |

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
