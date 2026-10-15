# Coding-Agent Project Bindings

**Current:** 2026-10-14

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | The procedure is fixed; only the values vary | a project cannot change what the loop does, only the values it reads |
| R2 | Every binding point is a declared value, never a procedure | the agent must not improvise a method (amended 2026-10-14: no `default` resolution; see the second decision) |
| R3 | A project must bind its mechanics; a required binding that is absent fails fast | superseded 2026-10-14: a project does not run on silent defaults |
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
| convention | a structure over a subset of content; a skill is provisioned for each |
| convention-skill | the project-owned skill that serves a convention |
| provision | a skill supplied for a convention; a missing provision degrades only its dependents |
| default convention-skill corpus | the workflow's shipped stubs, installed by the initializer; not a run-time default |
| maintenance surface | the fixed set of maintenance skills the prompts invoke, each stating an operation without naming a file |
| mechanics | the storage and format behind a maintenance surface; the bindable unit |
| maturity chain | rule -> skill -> gate -> binding; the direction a convention travels as it is made checkable |
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

The convention-skill corpus lands at handover `20261014-05`. It supersedes the interface, the project value file and the gate an earlier attempt in the same iteration produced: see the section below.

## 2026-10-14 -- The maintenance surface is fixed; the mechanics behind it are bound

**Decision:** The workflow's fixed unit is the **maintenance surface**: the maintenance skills the prompts invoke - `check-in`, `roadmap-maintenance`, `handover-maintenance`, `doc-maintenance` and `document`. Each states an operation - orient, update the task list, log and read a work unit, record a decision, publish knowledge - **without naming a file**. The **mechanics** behind a surface - the storage and the format, such as the roadmap file, the handover directory and the changelog - are the bindable unit. The workflow ships the default mechanics, and a project binds its own. This corrects the earlier reading in which a binding point was a path or a format value.

**Amends:** R2 becomes a declared value with no `default` resolution, and R3 is superseded: a project initializes its bindings, and a required binding that is absent fails fast. The workflow's own values still ship, as the values the initializer proposes rather than a run-time fallback.

**The maturity chain.** A convention matures along one chain, and each step moves discretion into something checkable:

| Stage | Form | Checkable by |
|---|---|---|
| rule | prose in a policy | nothing |
| skill | a `SKILL.md` the agent loads | a malformed file warns |
| gate | a deterministic script the skill bundles | an exit code |
| binding | a declared value the project supplies | the completeness gate |

The direction of travel is down the chain. **Coexistence is required:** a stage is not a migration, a mature workflow still carries unmigrated rules, and a consumer must accept any stage. The skill is the carrier - it packages prose in `SKILL.md`, judgement, a bundled `scripts/` file and data in `assets/` - and the contract and the gate sit beside it, workflow-owned.

**The seams kept open:** the surface states the operation while the mechanics hold the storage; inside a surface the checkable part extracts into a script while the skill keeps the judgement (`handover-maintenance` plus `scripts/check_handover_format.sh` is the one instance; `roadmap-maintenance` and `doc-maintenance` are judgement only); and a mechanics value is a parameter now and a deterministic implementation later, with the surface unchanged. For all three, the surface's contract is stated so a script could implement it, and the mechanics are declared as data rather than prose, so a script can read them.

**The skill specification's limits.** The Agent Skills specification (`agentskills.io/specification`, implemented by pi's `docs/skills.md`) carries all four stages, and a project's version can occupy `.agents/skills/`. It supplies none of the following, so the workflow supplies them:

1. **No typed inputs.** No field declares a required input. `metadata` is "a map from string keys to string values" that "clients can use this to store additional properties", so it can loosely declare a value, but it is untyped, unvalidated and string-to-string. The binding contract is ours.
2. **No enforcement.** "Most invalid fields produce warnings rather than stopping startup." A malformed skill is not a failure. The gate is ours.
3. **No non-agent execution.** A skill is model-loaded, and a bundled script runs only when something invokes it. The gate wiring is ours.
4. **No override.** "Name collisions keep the first discovered skill and produce a warning." Project-over-workflow replacement is not expressible. It is ours, or sidestepped.

`compatibility` is not a binding carrier: it is a free-text environment-requirements string, capped at 500 characters. For structured values, the specification's own carrier is a bundled `assets/` data file - "Data files (lookup tables, schemas)" - which holds our schema rather than a co-opted field.

**Edge cases / drivers:** The script layer is out of scope; only the seams are cut, so a script can slot in later. T5 (linear-style task tracking, an append-only changelog, handover rotation) and T6 (structured task logs) change the mechanics behind the surface, not the surface, which is why the surface must not name a file.

## 2026-10-14 -- The workflow ships convention-skills, and the seam is a handoff

**Decision:** The workflow ships a **default convention-skill corpus**, not a default convention corpus. A **convention** is a structure over a subset of content; the total list of conventions is the list of subsets a skill must be provisioned for, and a missing provision degrades only the workflows that depend on that subset. Each shipped convention-skill is a **stub** that states a skill is expected, that what was found is a stub, and a few open questions offered without direction. The `initialize` skill installs and updates the corpus into the project's `.agents/skills/`. A workflow step states its handoff to a convention-skill explicitly; when the skill is absent the handoff fails, and the agent reasons over it with the steering it has loaded. This supersedes the default-corpus decision above.

**Rationale:** The workflow imposes nothing on the project. It is a procedural layer, non-deterministic by nature; if it were deterministic it would be code. A run-time default would answer for a project that never chose, and a gate would police a project whose hooks the workflow does not control. A handoff states the need and the failure and leaves the reasoning to the agent.

**Rejected alternatives:**

- **A declared binding interface checked by a gate.** Superseded: a gate is a lint, and a lint over a project's bindings cannot run, because the workflow does not control the project's commit or lint hooks.
- **A project value file.** Superseded: the project's convention is a skill it owns, not a value it supplies, so the structure and the content live together.
- **A run-time default.** Superseded: a default answers for a project that never chose. The shipment is seed material, and its stub states a failure.

**Edge cases / drivers:** The convention list is the set of subjects that carry a maintenance surface: `task-list`, `work-log` (handovers and discussions), `decision-records`, `docs`, `git-discipline`, `testing` and `evals`, of which `evals` is optional. `iteration_policy` is the protocol, not a convention. A convention may cover more than one structure, and `work-log` carries two. The corpus lives in the `initialize` skill's `assets/` and ships with the skills cell, so no new layout surface is needed. The writing standard that governs all communicated text - chat, code comments, records and documents alike - is the `communication` standard, not a convention: it has no structure and no provision, and it lives in the project's always-loaded steering. Moving the conventions out of the shipped maintenance skills is deferred to the policy-form retirement.
