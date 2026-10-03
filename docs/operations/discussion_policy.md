# Discussion Policy

Governs files in `devlog/discussions/`. For ADRs, see `adr_policy.md`.

## Naming

Format:

```text
YYYYMMDD-{type}-{status}-{description}.md
```

Hyphens as section delimiters. Underscores as word separators in the description. Description character set: `[a-z0-9][a-z0-9._-]*` (lowercase letters, digits, period, underscore, hyphen). No emoji, no unicode, no spaces.

### Types

| Code | When to use |
|---|---|
| `story` | Problem framing -- what does the operator need? |
| `study` | Feasibility -- can we do X? |
| `design` | Decision exploration -- should we, and how? |
| `report` | Post-action record -- what an operation did, what it produced, what the operator and the agent learned from it |

`investigation` was an earlier name for `study` and is retired; the type code is `study`.

### Statuses

A report starts at draft, is reviewed, and transitions directly to settled; it never passes through active. A report that is rejected is deleted or archived at the operator's direction.

| Status | Meaning | Valid next states |
|---|---|---|
| `draft` | First write, not yet reviewed | `active`, `rejected` |
| `active` | Under discussion or investigation | `settled`, `rejected` |
| `settled` | Discussion closed, decision reached | `superseded`, `archived` |
| `superseded` | Replaced by a newer doc | `archived` |
| `rejected` | Decided against | `archived` |
| `archived` | Terminal -- no active references | -- |

This table is the single status vocabulary for all four discussion types, in the file name and in the `**Status:**` line. The type sections below define section order only.

### Standalone policy docs

Policy files under `docs/operations/` are not discussion docs and do not follow this naming convention.

### Legacy docs

Existing docs with old-format names keep their names until substantively edited. On first edit, rename to this convention and update inbound links.

## Document types

Each type has one section order. The skeleton is the template; the angle-bracket line under each heading states what that section holds.

### Stories (`story`)

Frames a problem before an approach is chosen. Open one when the sub-milestone objective is clear but the approach is not. A story closes into a roadmap row.

Section order:

```markdown
# <Title>
**Status:** <draft | active | settled | superseded>

## Context
<the use case and why it matters; 2-4 sentences>

## Pain Points
<the concrete problems being investigated; what is broken or missing>

## Constraints
<non-negotiable requirements any solution must satisfy; omit when none>

## Open Questions
<unresolved questions blocking progress; updated as they resolve>

## Study Findings
<what the studies found; one summary link per study; omit when no studies>

## Resolution
<at closure: the decision, where the work went, and why>
```

A story graduates when the pain point is understood, all resolvable questions are answered, the approach is agreed with rationale, and the tasks name a file and a nature of change. Write the roadmap row first, then set the status to `settled`. Tasks are not copied back into the story.

### Studies (`study`)

Evaluates one candidate approach for a parent story. Open one per candidate when a story has two or more candidates to compare. A study closes into a recommendation.

Section order:

```markdown
# <Title>
**Status:** <draft | active | settled | superseded>

## Direction and parent story
<which direction this study belongs to; link to the parent story>

## Required reading
<prerequisite documents; links only, no prose>

## Summary
<what this candidate is and how it works; 2-4 sentences>

## Findings
<what was discovered; iterative subsections>

## Open Questions
<unresolved questions blocking a recommendation>

## Constraints
<non-negotiable requirements this candidate must satisfy>

## Next Steps
<immediate actions; replaced by Resolution at closure>

## Resolution
<at closure: adopt, reject or defer; the rationale; where the decision was recorded>
```

The agent does not delete study documents. A closed study feeds a summary link back into its parent story's Study Findings section.

### Designs (`design`)

Resolves trade-offs between options and recommends a decision. Opened during the iteration design phase.

Section order:

```markdown
# <Title>
**Status:** <draft | active | settled | superseded>

## Context
<what problem; what triggered the exploration>

## Options Considered
<alternatives with trade-offs; at least two>

## Decision
<the recommended approach and why>

## Consequences
<what this changes, enables, or forecloses>
```

When a design settles with an implementation decision, record the decision as an ADR per [`adr_policy.md`](adr_policy.md) and set the design's status to `settled`. The design doc remains the exploration record; the ADR is the authoritative decision record.

### Reports (`report`)

Records a completed operation: what was attempted, what was produced, what was learned. Composed after the fact, never a working record. A report starts at `draft` and moves directly to `settled`.

Section order:

```markdown
# <Title>
**Status:** <draft | settled>

## Context
<what the operation was, why it ran, its scope and exclusions>

## The brief
<what the operation set out to do, and the contract it ran against>

## Compact log of actions
<what was done, phase by phase, with measured counts>

## Mid-run adjustments
<the method changes made during the operation, each with why>

## Findings summary
<the register link plus numbers computed from the data file, never asserted>

## Resolution methods
<how the findings were handled, and the lanes they were split into>

## Post-review learnings and process adjustments
<the reflection on the operation and the process changes that follow>

## Final output artifacts
<the durable outputs the operation produced, each with its home>

## Resolution status
<what is closed vs open, and the follow-ups by track>

## Records this supersedes
<the documents the report replaces, their fate, and where each piece of their content now lives>
```
