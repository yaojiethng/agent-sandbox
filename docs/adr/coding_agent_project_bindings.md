# Coding-Agent Project Bindings

**Current:** 2026-10-14

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | The procedure is fixed; only the values vary | a project cannot change what the loop does, only the values it reads |
| R2 | Every binding point is a value or `default`, never a procedure | the agent must not improvise a method |
| R3 | A project that binds nothing still runs | the workflow ships a default form for every point |
| R4 | A mechanism and a convention do not share a form | a rule that says how and a rule that says what are separate |
| R5 | Project knowledge survives the work ledger | pruning the ledger must not lose project context |

## 2026-10-14 -- The workflow declares a project binding surface

**Decision:** The coding-agent workflow defines a binding surface: a set of named project inputs. The procedure stays fixed and a project supplies values. Every policy splits into a mechanism, which becomes a core procedure, and a convention, which becomes a project binding; the policy document as a form is retired. Records fall into three persistence classes - work ledger (operational, prunable), project knowledge (durable, bundled), and rules. `git` is an available tool rather than a module or a binding, and the workflow is git-native. The work ledger is a mandatory capability with a modular form, because the core loop's unit boundary is the ledger's record boundary.

**Rationale:** The policy corpus mixed a mechanism, which already existed as a skill or a prompt, with a convention, which a project legitimately chooses. Duplicating the mechanism as policy prose was the weight the structure carried. Splitting the two lets the procedure stay fixed, keeps the run deterministic, and lets a host project keep its own record layout and formats. A live host project demonstrates the need: it derived its own policies from the shipped procedures and runs a sparser handover format and a single roadmap.

**Rejected alternatives:**

- **A fixed workflow with a host fork.** Rejected on execution: each host forks the workflow, so the workflow has no single maintained form and an upstream fix reaches no host.
- **A delivery-swap abstraction.** Rejected on intent: the core loop's operations - land a commit, read branch and status, create or switch a branch - are git-shaped, so the interface would be git's interface under another name. A non-git delivery is a re-architecture, not a variation, and designing for it now buys nothing.
- **A unified layer scheme across the system's subdomains.** Rejected on intent: the container architecture, the document dependency order, the instruction roots and the image build are on different axes. A unified numbering would have to invent the ordering relationship between them, would displace the load-bearing container meaning of "layer", and would couple four independent designs to a naming problem.

**Edge cases / drivers:** The binding mechanism and its completeness gate are deferred; the default form stands until they land, and a host project's own form stands unchanged. The workflow must not assume the full ledger is present, so distillation precedes pruning and an ADR cites its own reasoning rather than a record that may be gone. The protocol document names the ledger and its paths, so those references resolve through the binding mechanism rather than hardcoding `devlog/`.

### Reserved terminology

This ADR reserves the terms this principle introduces, and the senses of **layer** it replaces. The reservation is to be carried into [`docs/reference/terminology.md`](../../docs/reference/terminology.md).

| Term | Reserved meaning |
|---|---|
| protocol | the fixed loop sequence, gates, mandatory writes and record kinds |
| convention | a project binding value |
| default corpus | the workflow's own values, used when a project binds nothing |
| ownership split | the protocol / convention / default-corpus division |
| binding point, binding set, binding value | the declared input, a unit's set, and the supplied value |
| module | a coherent unit with its own binding set; the form, not the capability |
| standard | a practice with no procedure and no binding, read by judgement |
| host tooling | agent-sandbox-only payload with no binding set |
| persistence class | work ledger, project knowledge, or rules |

| Sense of "layer" | Reserved replacement |
|---|---|
| container architecture | keep "layer" - the canonical sense |
| implementation stack | "tier" |
| `AGENTS.md` scope | name the file - the provider or project `AGENTS.md` |
| instruction roots | "surface" or "root" |
| record dependency | "class" or "order" |
| agent nesting | "depth" |
| Docker build | keep - Docker's own term |

### In development

This principle governs the M3.3.1 structural moves, and it stays under development until they land. The exploration record is [`20261014-design-draft-coding_agent_binding_surface.md`](../../devlog/discussions/20261014-design-draft-coding_agent_binding_surface.md). Remove that link when the moves complete, which closes this record.
