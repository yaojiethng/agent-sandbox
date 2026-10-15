# The coding-agent workflow's binding surface

**Status:** settled

## Context

The coding-agent workflow ships as one module, `workflow/coding-agent/`, and runs against projects other than agent-sandbox. Its prompts and skills hardcode agent-sandbox's record layout: `devlog/roadmap.md`, `devlog/handovers/`, `docs/policies/`. A host project with a different layout or a different record format must either adapt the workflow or break against it, and nothing declares which parts a project must supply.

The policy corpus is where the problem is sharpest, and it is two things wearing one form. Half of each policy is a **mechanism** - how to write a handover, how to maintain a roadmap, how to use git correctly. The other half is a **convention** - the format, the paths, the commit vocabulary this project chose. The mechanism already exists as a skill or a prompt; the policy document duplicates it as prose. That duplication is why the structure reads as heavy.

This exploration was opened by the M3.3.1 design row, `Decide where the policy content lives, and what the repository copy becomes`. It widened when the operator named the goal: a portable workflow that fits a host project's rules rather than imposing its own.

## Options Considered

**A fixed workflow, host adapts.** The status quo. The workflow ships one structure and a host project copies and edits it. Rejected: this is what the live host project did, and it means every host forks the workflow, so the workflow has no single maintained form and an upstream fix reaches no host.

**A delivery-swap abstraction.** Abstract change delivery behind an interface so a project can swap git for another mechanism. Rejected as prohibitively expensive. The core loop's operations - land a commit, read branch and status, create or switch a branch - are git-shaped, so the interface would be git's interface with another name. A non-git delivery (live sync, database transactions) is a different class and a re-architecture, not a variation.

**A declared binding surface.** The workflow defines the values it needs; a project supplies them. Adopted. The procedure stays fixed and only the values vary, so the run stays deterministic.

## Decision

### Vocabulary

| Term | Meaning |
|---|---|
| **Core loop** | the irreducible procedure every project runs; not a module, because it cannot be left off |
| **Procedure** | the ordered steps a run executes; fixed, workflow-owned |
| **Binding point** | one named project input the procedure reads; variable |
| **Binding set** | every point one unit needs; this is the unit's boundary |
| **Maintenance surface** | the fixed unit: a maintenance skill the prompts invoke, stating an operation without naming a file |
| **Mechanics** | the storage and format behind a maintenance surface; the bindable unit |
| **Binding value** | what a project supplies at a point: a path, a document reference, or a vocabulary |
| **Default corpus** | the workflow's own binding values, which the initializer proposes for a project; no run-time fallback |
| **Module** | a coherent unit with its own binding set; the form, not the capability |
| **Standard** | a practice with no procedure and no binding, read and applied by judgement |
| **Host tooling** | agent-sandbox-only payload; no binding set, may hardcode |
| **Provenance** | home-spun or ingested; orthogonal to the above |

The term **policy** is retired, as a word and as a form. It named both a mechanism and a convention, which is the conflation this design removes.

### The ownership split

| Part | Nature | Owner |
|---|---|---|
| Protocol | the loop sequence, the gates, the mandatory writes, the record kinds | core, fixed |
| Convention | the values the protocol reads | project, a binding |
| Default corpus | the values used when a project binds nothing | the workflow |

The rule that places a thing: a change that alters what the loop does is protocol; a change that alters only where or under which convention is a binding.

### Modules

| Unit | Members | Binding inputs |
|---|---|---|
| **Core loop** | `iter`, `wrapup`, `milestone-start`, `milestone-close`, `plan`, `sidequest`; the two gates; the record kinds | the work-ledger interface, the commit vocabulary, the host interface |
| **Work ledger** (mandatory, modular form) | `roadmap-maintenance`, `backlog-triage`, `check-in`/`gm`; `devlog/` | ledger root, task list, unit log, changelog, feedback, discussions |
| **Project knowledge** (project concern) | ADRs, reference documents, `document`, `doc-maintenance` | decision-record and documentation directories and formats |
| **Eval** (optional) | `eval`, `package-eval-snapshot` | eval root, case format, role model |
| **Skill ingestion** (optional) | fork-and-strip, maintenance record, backlog triage | upstream source, adaptation record |
| **Host tooling** | `agent-sandbox.md`, `pi-agent.md`, `pi-bump`, `setup-pre-commit`, onboarding | none |

Project management is a mandatory capability of the core loop; the form it takes is modular. The loop's unit boundary is the ledger's record boundary, so the coupling is by design, not a seam to cut: the core loop binds the ledger rather than owning the records.

`git` is not a module and not a binding. It is an **available tool**, like bash or node. The workflow is git-native, and it may invoke git directly.

### Persistence classes

| Class | Value | Records | Fate |
|---|---|---|---|
| **Work ledger** | operational | roadmap, handovers, discussions, feedback, changelog | prunable; full history may leave the working tree |
| **Project knowledge** | durable | ADRs, reference documents | bundled with the project; not pruned |
| **Rules** | governing | protocol and conventions | not records |

The class follows the process stage, not a guess at write time. Exploration is a ledger record; a settled decision is a knowledge record; elevation is the transition. Whether a problem warrants a design and an ADR is judgement made during the work, not a gate, and the workflow permits elevation without requiring it. Once written, an ADR is knowledge.

### The policy split

Each policy splits along its mechanism and its convention:

| Policy | Mechanism (fixed) | Mechanics (bound, behind the surface) |
|---|---|---|
| `iteration_policy` | the loop sequence and the gates | its references to the ledger and its paths |
| `handover_policy` | `handover-maintenance` | the work-log storage, identity and format |
| `roadmap_policy` | `roadmap-maintenance` | the task-list storage and format |
| `discussion_policy` | `document` | the discussion storage and the type format |
| `adr_policy` | `document` | the decision-record storage and the living format |
| `documentation_policy` | `doc-maintenance` | the documentation tree and taxonomy |
| `git_policy` | `merge`, `rebase`, `record-correction` | the delivery mechanics: the commit vocabulary and branch scheme |

The mechanism lives in the procedure that runs. The convention shrinks to a binding value with a workflow default. The policy document as a form disappears.

### The fixed surface and the bound mechanics

The fixed unit is the **maintenance surface** - the maintenance skills the prompts invoke. The bound unit is the **mechanics** behind a surface: its storage and its format. The surface states the operation; the mechanics name the file. The earlier path points are the default mechanics' parameters, not top-level binding points.

| Maintenance surface (fixed) | Default mechanics (adjustable) |
|---|---|
| `check-in` | the ledger paths it reads for orientation |
| `roadmap-maintenance` | the task-list storage and format |
| `handover-maintenance` | the work-log storage, identity and format |
| `doc-maintenance` | the documentation tree |
| `document` | the decision-record and discussion storage and format |

The core-loop mechanics no maintenance surface owns: **verification** (the project's check command), **delivery** (the commit vocabulary and branch scheme), and the **host interface** (how the tree enters and how changes leave). Two optional module sets sit beside them: **eval** and **skill ingestion**. Every mechanics value is declared, never improvised, and a required value that is absent fails fast.

### Pruning

The workflow must not assume the full ledger is present. Distillation precedes pruning: history is removed only after its durable content is extracted into knowledge. Knowledge is self-contained: an ADR cites its own reasoning, not a discussion or handover that may no longer exist. This extends the archive boundary the checks already apply - they read the live folder alone - to knowledge records.

## Consequences

- The M3.3.1 task list is superseded. Its seven per-policy move rows assume the policy corpus survives as documents; under the split there is no corpus to move. The move rows become: retire each policy's mechanism into its maintenance surface, and place its mechanics in the default surface.
- The default mechanics need a home. They are declared data, not a document set, so the destination is a default-convention surface in the module rather than a `policies/` folder, and an initializer proposes their values for a project.
- No run-time default remains. A required binding that is absent fails fast; the workflow's own values are what the initializer proposes, not a fallback.
- The maturity chain `rule -> skill -> gate -> binding` governs the surface's evolution, and every stage coexists. The surface's contract is stated so a script could implement it, and the mechanics are declared as data so a script can read them.
- The binding mechanism is deferred. This design fixes the seam; the mechanism that resolves a binding, and the gate that checks a binding is complete, is a later row.
- The protocol document's references must resolve through the binding. `iteration_policy` states the protocol, but it names the ledger and its paths; those references become mechanics, so the protocol document no longer hardcodes `devlog/`.
- The two named blockers dissolve. `defer.md`, `ADR-FORMAT.md` and the provider `AGENTS.md` table read the bound mechanics, so none has to move or stop linking.
- `record-correction` is unwired: it is referenced only by the roadmap and called by no prompt. It is a mechanism with no entry point, and the split gives it one or retires it.
