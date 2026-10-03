# Documentation Taxonomy

This document is the index and view of the documentation ecosystem. It states no obligations and defines no rules; every rule it names links to the policy document that canonically owns it. Read it to learn what documents exist, what each is for, how a record changes over time, and which document governs a question.

## What documents exist

| Document | What it is | Durability | Governed by |
|---|---|---|---|
| Policy document (`docs/**/*_policy.md`) | rules for how the harness runs: workflows, handovers, iterations, roadmaps, documentation | durable | per-file; the rules of rule-hood are in [`policy_declarative_framing`](../adr/policy_declarative_framing.md) |
| ADR (`docs/adr/`) | the rationale behind a standing principle: the chosen option, the rejected alternatives, the reasons | durable | [`adr_policy.md`](../operations/adr_policy.md) |
| Concept document (`docs/concepts/`) | a conceptual model: abstract state transitions, cross-component interactions, principles no single component owns | durable | [`documentation_policy.md`](../operations/documentation_policy.md) -- Concept document obligations |
| Architecture document (`docs/architecture/`) | implementation design and decisions | durable | [`documentation_policy.md`](../operations/documentation_policy.md); the freeze rule is in [`system_overview.md`](../architecture/system_overview.md) |
| `readme.md` | entry point for humans and agents: system invariants, architecture layer model, documentation guide path | durable | -- |
| `AGENTS.md` | provider notes, collaboration protocol, role, read discipline, output format rules | durable | -- |
| Roadmap (`devlog/roadmap.md`) | active planning; future and TODO items land here | durable | [`roadmap_policy.md`](../operations/roadmap_policy.md) |
| Changelog (`devlog/changelog.md`) | the roadmap's archived half; a length boundary, not a correction | durable | [`roadmap_policy.md`](../operations/roadmap_policy.md) |
| Handover (`devlog/handovers/`) | one session's record of the work done | transient | [`handover_policy.md`](../operations/handover_policy.md) |
| Discussion record (`devlog/discussions/`) | one session's evidence for a decision, as one of four types: story (problem framing), study (feasibility), design (decision exploration), report (post-action record) | reference-durable: kept as a reference for the course of the implementation it describes, then subsumable | [`discussion_policy.md`](../operations/discussion_policy.md) |

The policy set is every `docs/**/*_policy.md` file, in any folder. `docs/operations/` also holds guides and procedures that state no rules.

## Folder taxonomy

A document lives in exactly one `docs/` folder or in `devlog/`. Each folder holds one concern:

| Folder | Holds |
|---|---|
| `architecture/` | implementation design and decisions |
| `concepts/` | conceptual models: abstract state transitions, multi-component interactions, principles of interaction. The *what* at the conceptual level. |
| `operations/` | how to run the system: the policy rules, plus the onboarding guides and the SOPs |
| `development/` | contributor workflow and development conventions |
| `adr/` | the rationale behind standing principles, interface shapes, and contracts; superseded or awaiting-review ADRs live in `adr/archive/` |
| `devlog/` | the session-facing records: the roadmap, the changelog, handovers, and discussion documents |

The placement rule (each document in exactly one category) is in [`documentation_policy.md`](../operations/documentation_policy.md) -- Folder Structure.

## Durability

A document is durable when it is kept and maintained as a reference after the session that produced it. Maintained documents are durable. A discussion record is reference-durable: it stays as a reference for future work units for the course of the implementation it describes, then becomes subsumable and may be cleaned up or subsumed. A handover decays; a tmp file or chat record is never kept. The durable home of the approaches considered and the knowledge tests is the ADR. Rules that depend on the durable/transient line link here for the classification.

## Record lifecycle view

A record moves through stages. Each stage is a readable summary; the rule that governs it lives in the policy it names.

- **Place.** Pick the folder category before drafting. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Folder placement.
- **Author.** A record-layer document starts with a confirmed skeleton. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Skeleton first for record-layer documents.
- **Format.** Every `docs/` document opens with the same header block. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Document header format.
- **Maintain.** A durable record states the current state, not the session that produced it. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Records state, not session history.
- **Check.** A record must satisfy the document lint gate to close. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Tooling checks.
- **Correct after close.** A closed record's content does not change; it gains its type's marker. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Post-close document corrections.
- **Reference a missing document.** A missing document is an error unless its link carries `[REMOVED]`. Rule: [`documentation_policy.md`](../operations/documentation_policy.md) -- Missing documents.

## Promotion topology

Documents promote along a path, and each step is an obligation with one policy home.

- **Discussion to ADR.** A discussion doc settles into an ADR when the change stabilizes a principle whose consequences reach beyond the change. Rule: [`adr_policy.md`](../operations/adr_policy.md) -- When an ADR begins.
- **Concept to ADR.** The concept document is the parent; the ADR is the explainer that records why the model was chosen. Rule: [`adr_policy.md`](../operations/adr_policy.md) -- Relationship to other records.
- **Concept to architecture.** The concept states the model; the architecture document carries the implementation design. What a concept document describes is in [`documentation_policy.md`](../operations/documentation_policy.md) -- Concept document obligations.

## Boundary

Skill files, prompt templates, tmp files, and chat records are not maintained documents. A handover is a transient session record, not a maintained document. The rule that governs what counts as authoritative is in [`documentation_policy.md`](../operations/documentation_policy.md) -- Rule authority. The rules that govern a handover are in [`handover_policy.md`](../operations/handover_policy.md).

## Audience dispatch

| Reader question | Open |
|---|---|
| "I am new here -- what documents exist and which do I need?" | this document |
| "What is a concept document against an ADR or a discussion?" | Promotion topology |
| "Where does this file go?" | Folder taxonomy (this document); the placement rule is in [`documentation_policy.md`](../operations/documentation_policy.md) -- Folder Structure |
| "Is this statement a rule or a description? Where is the canonical home of a rule?" | [`documentation_policy.md`](../operations/documentation_policy.md) -- Rule authority |
| "How do I write the prose?" | [`documentation_policy.md`](../operations/documentation_policy.md) -- Communication Standards |
| "What content is forbidden in an architecture document?" | [`documentation_policy.md`](../operations/documentation_policy.md) -- Prohibited content |
| "What does the lint check? What must a record satisfy?" | [`documentation_policy.md`](../operations/documentation_policy.md) -- Tooling checks |
| "How do I correct a closed record?" | [`documentation_policy.md`](../operations/documentation_policy.md) -- Post-close document corrections |
