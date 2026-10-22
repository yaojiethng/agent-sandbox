---
reader: [agent]
---

# Documentation Taxonomy

This document is the index and view of the documentation ecosystem. It states no obligations and defines no rules; every rule it names links to the policy document that canonically owns it. Read it to learn what documents exist, what each is for, how a record changes over time, and which document governs a question.

## What documents exist

| Document | What it is | Durability | Identification | Governed by |
|---|---|---|---|---|
| Policy document (`docs/**/*_policy.md`) | rules for how the harness runs: workflows, handovers, iterations, roadmaps, documentation | durable | sections numbered | per-file; the rules of rule-hood are in `docs/adr/policy_declarative_framing.md` |
| ADR (`docs/adr/`) | the rationale behind a standing principle: the chosen option, the rejected alternatives, the reasons | durable | sections numbered; decisions `D` | [`adr_policy.md`](../policies/adr_policy.md) |
| Concept document (`docs/reference/`) | a conceptual model: abstract state transitions, cross-component interactions, principles no single component owns | durable | sections numbered where the document navigates by number | [`documentation_policy.md`](../policies/documentation_policy.md) -- Concept document obligations |
| Architecture document (`docs/reference/`) | implementation design and decisions | durable | sections numbered where the document navigates by number | [`documentation_policy.md`](../policies/documentation_policy.md); the freeze rule is in [`system_overview.md`](../reference/system_overview.md) |
| `readme.md` | entry point for humans and agents: system invariants, architecture layer model, documentation guide path | durable | no unit numbers | -- |
| `AGENTS.md` | provider notes, collaboration protocol, role, read discipline, output format rules | durable | no unit numbers | -- |
| Roadmap (`devlog/roadmap.md`) | active planning; future and TODO items land here | durable | identity `M` and `T` codes; no renumbering | the project's `task-list` convention |
| Changelog (`devlog/changelog.md`) | the roadmap's archived half; a length boundary, not a correction | durable | append-only; no unit numbers | the project's `task-list` convention |
| Handover (`devlog/handovers/`) | one session's record of the work done | transient | identity `YYYYMMDD-NN`; `F`, `Q`, `D` units | the project's `.agents/skills/work-log/SKILL.md` convention |
| Discussion record (`devlog/discussions/`) | one session's evidence for a decision, as one of four types: story (problem framing), study (feasibility), design (decision exploration), report (post-action record) | reference-durable: kept as a reference for the course of the implementation it describes, then subsumable | identity date, type, slug; `F`, `Q` units | [`discussion_policy.md`](../policies/discussion_policy.md) |

The scheme each class uses belongs to the project's numbering convention, where the project states one; the column above names the scheme and states no rule. The judgement behind a numbered list is `communication-principle-one-addressing-axis` at `$AGENT_HOME/agent/skills/communication-principle-one-addressing-axis/SKILL.md`.

The policy set is every `docs/**/*_policy.md` file, in any folder. The other folders hold no rules.

## Folder taxonomy

A document lives in exactly one `docs/` folder or in `devlog/`. Each folder holds one concern:

| Folder | Holds |
|---|---|
| `reference/` | the harness as built: contracts, states and sequences, the interface index, and the glossary |
| `policies/` | the policy rules the agent obeys |
| `development/` | contributor workflow, development conventions, and the procedures for changing the harness |
| `adr/` | the rationale behind standing principles, interface shapes, and contracts; superseded or awaiting-review ADRs live in `adr/archive/` |
| `devlog/` | the session-facing records: the roadmap, the changelog, handovers, and discussion documents |

The table describes this repository's tree. `reference/` and `policies/` reach every session because the image mounts them; `adr/`, `development/` and `devlog/` are this project's, so a session in a provisioned project reads that project's own. `## Reach` states the axis and `scripts/check_reach.sh` holds it to the manifest.

The placement rule (each document in exactly one category) is in [`documentation_policy.md`](../policies/documentation_policy.md) -- Folder Structure.

## Durability

A document is durable when it is kept and maintained as a reference after the session that produced it. Maintained documents are durable. A discussion record is reference-durable: it stays as a reference for future work units for the course of the implementation it describes, then becomes subsumable and may be cleaned up or subsumed. A handover decays; a tmp file or chat record is never kept. The durable source of truth of the approaches considered and the knowledge tests is the ADR. Rules that depend on the durable/transient line link here for the classification.

## Reach

Reach is who reads a document: every session, or the sessions that hold this repository's tree. Reach belongs to the root that carries the document, so every file under that root inherits one value and no document declares its own.

How a document arrives in front of that reader is a second fact, delivery, and the two do not move together. An image-mounted root and a root the project's own setup fills reach the same reader by different routes.

| Delivered by | The roots it carries | Reach |
|---|---|---|
| the image, as a module payload | the roots the manifest mounts at `/opt/sandbox/`, `/opt/workflow/agent/skills/`, `/opt/workflow/agent/prompts/` and `/opt/workflow/agent/modules/` | every session |
| the image, as a provider's config | the roots the manifest mounts at `/opt/workflow/agent/config/` | every session |
| the project's own setup | `workflow/coding-agent/skills/initialize/assets/conventions/`, copied into `.agents/skills/<name>/` | every session, once the project has run `initialize` |
| nothing | the repository-only folders, `docs/adr/`, `docs/development/`, `devlog/`, and the tree itself | a session with the repository tree present |

Which root the manifest mounts where is the manifest's, in `src/build/container-interface.json`, and this document copies no list of roots. `scripts/check_reach.sh` holds the two together: every mount the manifest carries is one this table's routes cover, every mount point here carries something, a folder stated repository-only is reached by no manifest path, and a delivered folder exists in the tree.

Enablement is a property of a module and not a reach value.

A pointer states reach in two values, `every session` and `this project`, because the first three routes reach every session and every reading of them happens inside a provisioned project.

## Record lifecycle view

A record moves through stages. Each stage is a readable summary; the rule that governs it lives in the policy it names.

- **Place.** Pick the folder category before drafting. Rule: [`documentation_policy.md`](../policies/documentation_policy.md) -- Folder placement.
- **Author.** A record-layer document starts with a confirmed skeleton. Rule: [`documentation_policy.md`](../policies/documentation_policy.md) -- Skeleton first for record-layer documents.
- **Format.** Every `docs/` document opens with the same header block. Rule: [`documentation_policy.md`](../policies/documentation_policy.md) -- Document header format.
- **Maintain.** A durable record is written for its reader, not for the session that produced it. Judgement: `communication-principle-write-for-the-reader` at `$AGENT_HOME/agent/skills/communication-principle-write-for-the-reader/SKILL.md`. Procedure: [`documentation_policy.md`](../policies/documentation_policy.md) -- Subject, not the session.
- **Check.** A record must satisfy the document lint gate to close. Rule: [`documentation_policy.md`](../policies/documentation_policy.md) -- Tooling checks.
- **Correct after close.** A closed record's content does not change; it gains its type's marker. Rule: [`documentation_policy.md`](../policies/documentation_policy.md) -- Post-close document corrections.
- **Reference a missing document.** A missing document is an error unless its link carries `[REMOVED]`. Rule: [`documentation_policy.md`](../policies/documentation_policy.md) -- Missing documents.

## Promotion topology

Documents promote along a path, and each step is an obligation whose source of truth is a policy.

- **Discussion to ADR.** A discussion doc settles into an ADR when the change stabilizes a principle whose consequences reach beyond the change. Rule: [`adr_policy.md`](../policies/adr_policy.md) -- When an ADR begins.
- **Concept to ADR.** The concept document is the parent; the ADR is the explainer that records why the model was chosen. Rule: [`adr_policy.md`](../policies/adr_policy.md) -- Relationship to other records.
- **Concept to architecture.** The concept states the model; the architecture document carries the implementation design. What a concept document describes is in [`documentation_policy.md`](../policies/documentation_policy.md) -- Concept document obligations.

## Boundary

Skill files, prompt templates, tmp files, and chat records are not maintained documents. A handover is a transient session record, not a maintained document. The rule that governs what counts as authoritative is in [`documentation_policy.md`](../policies/documentation_policy.md) -- Rule authority. The rules that govern a handover are in the project's `work-log` convention (`.agents/skills/work-log/SKILL.md`).

Everything under a project's `.agents/` is project-scoped: that project's sessions read it and no other project's session does. A document read more widely names a path there only where a mechanism that ships guarantees the path exists, so a shipped document names the convention a project may state rather than the one it has.

## Audience dispatch

| Reader question | Open |
|---|---|
| "I am new here -- what documents exist and which do I need?" | this document |
| "What is a concept document against an ADR or a discussion?" | Promotion topology |
| "Where does this file go?" | Folder taxonomy (this document); the placement rule is in [`documentation_policy.md`](../policies/documentation_policy.md) -- Folder Structure |
| "Is this statement a rule or a description? Where is the source of truth of a rule?" | [`documentation_policy.md`](../policies/documentation_policy.md) -- Rule authority |
| "How do I write the prose?" | [`documentation_policy.md`](../policies/documentation_policy.md) -- Communication Standards |
| "What content is forbidden in an architecture document?" | [`documentation_policy.md`](../policies/documentation_policy.md) -- Prohibited content |
| "What does the lint check? What must a record satisfy?" | [`documentation_policy.md`](../policies/documentation_policy.md) -- Tooling checks |
| "How do I correct a closed record?" | [`documentation_policy.md`](../policies/documentation_policy.md) -- Post-close document corrections |
