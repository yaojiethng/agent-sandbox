# Retiring the policy form

**Status:** settled

## Context

Eight policy documents hold the workflow's rules, about 1770 lines. Each carries three kinds of content at once:

- A **mechanism** - how the work is done. It already exists as a procedure: `handover-maintenance`, `roadmap-maintenance`, `doc-maintenance`, `document`, `merge`, `rebase`, `record-correction`.
- A **convention** - the project's structure: where a record lives, its format, its vocabulary. It belongs in the project's convention-skill under `.agents/skills/`.
- A **remainder** - what is neither: the rules themselves.

Duplicating the mechanism as policy prose is the weight. The roadmap row is **Retire the policy form**; this document settles where each policy's content lands.

## Options Considered

- **Assign each section to mechanism, convention, or protocol.** A section often carries two of the three at once, so the assignment forces an artificial choice.
- **Subtract.** Strip the mechanism and the convention from the document, then read what is left. The remainder needs no assignment; it is what the subtraction leaves. This is the operator's method and it is adopted.

## Decision

For each policy, subtract the mechanism (owned by the procedure that already runs it) and the convention (owned by the project's convention-skill); the remainder is the rule.

| Policy | Mechanism -> procedure | Convention -> convention-skill | Remainder (the rule) |
|---|---|---|---|
| `handover_policy` | `handover-maintenance`, `iter`/`wrapup`: Lifecycle, Corrections to Closed Handovers | File Naming Standard, Types, Format, The Format Window, Canonical Null Markers | Purpose, Brevity |
| `roadmap_policy` | `roadmap-maintenance`, `milestone-close`: Roadmap maintenance, Milestone Promotion | Structure and Filing Rules, Milestone States, Changelog Format | When the Roadmap Is Touched (the timing invariant), One record |
| `adr_policy` | `document`: When an ADR begins, Liveness and evolution, Statuses, Archive | the ADR structure template, Naming, the archive path | Relationship to other records, Unit of record, Content |
| `discussion_policy` | `document`: the four document types and their section orders, the drafting flow | Naming, the type codes, the statuses, the section templates | Standalone policy docs, Legacy docs |
| `git_policy` | `merge`/`rebase`/`record-correction`, `wrapup`: Checkpointing, WIP Commits, Transient commits fold, Amending, Recovery, Merge Policy | Commit Message Format, Active Types, Future Types, Branch Naming, Branching Strategy, Tagging, Scope Field | one delivery commit per unit, the review gate, never rewrite published history |
| `documentation_policy` | `doc-maintenance`: Record maintenance, Tooling checks, Post-close corrections | Folder Structure, Format, Drafting, Document Types | Communication Standards, Rule authority, Prohibited content |
| `testing_policy` | `testing` procedure: Shared Fixtures, Test Placement, Running the Test Suite, Keeping Tests Current | the paths `tests/`, `tests/libs/`, `tests/knowledge/`, the runner | Core Principles |
| `iteration_policy` | `iter`/`wrapup`/`sidequest`/`plan`/`document`/`milestone-start`/`milestone-close`: The autonomous agent loop, the canonical procedures | the ledger and path references, File Tracking | Principles, Iteration Invariants, Sidequests, Loop workflow prompts |

**The fates.** The remainder decides the fate, on one rule: a rule that a procedure enforces is stated where it is enforced; a rule that binds the procedures to each other is a protocol and keeps a document.

- **`iteration_policy` keeps a document**, its protocol half: the Principles and the Iteration Invariants bind every runbook, so no single procedure can hold them. It is no longer a policy; it is the runbooks' contract.
- **`documentation_policy`'s Communication Standards keep a document**, the `communication` standard: they govern every text, so no one procedure holds them. The rest dissolves.
- **The other six dissolve.** Their remainder is a rule a procedure enforces, so it is stated there.

**The order.** One slice per policy, each its own iteration, ordered so the pattern is set on the most self-contained document and the protocol moves last: `handover_policy`, `roadmap_policy`, `adr_policy`, `discussion_policy`, `git_policy`, `documentation_policy`, `testing_policy`, `iteration_policy`.

## Consequences

The policy form ends. Eight documents become two: the iteration protocol and the `communication` standard. Their content is distributed to the procedures that run it and to the project's convention-skills, so nothing ships twice.

Each slice must leave the repository working: `Drop the policy bundle` (the `COPY docs/policies/` line in the three provider dockerfiles) lands after the last policy leaves, because a prompt reads a policy where it ships.

The map is at section grain. A section that turns out to straddle the line is resolved by the same subtraction in the slice that moves it, and the resolution is recorded there.
