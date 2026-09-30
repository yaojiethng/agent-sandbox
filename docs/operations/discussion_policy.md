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

### Standalone policy docs

Policy files under `docs/operations/` are not discussion docs and do not follow this naming convention.

### Legacy docs

Existing docs with old-format names keep their names until substantively edited. On first edit, rename to this convention and update inbound links.

## Document types

### Stories (`story`)

See [`story_policy.md`](story_policy.md).

Defines the problem space. Created when a sub-milestone objective is understood but the approach is not.

### Studies (`study`)

See [`study_policy.md`](study_policy.md).

Evaluates a specific candidate approach. One study per candidate. Runs until a recommendation can be made and fed back to the parent story.

### Designs (`design`)

Opened during the iteration design phase -- see [`iteration_policy.md`](iteration_policy.md) when design is active. A design doc resolves trade-offs between options and recommends a decision.

#### Required sections

Design docs follow this section order:

| Section | Purpose |
|---|---|
| **Context** | What problem, what triggered the exploration |
| **Options Considered** | Alternatives with trade-offs; at least two |
| **Decision** | Recommended approach and why |
| **Consequences** | What this changes, enables, or forecloses |

#### Lifecycle

Design docs use the standard discussion statuses (draft, active, settled, superseded). When a design settles with an implementation decision, record the decision as an ADR per [`adr_policy.md`](adr_policy.md) and update the design doc's status to `settled`. The design doc remains as the exploration record; the ADR is the authoritative decision record.

### Reports (`report`)

Records a completed operation: what was attempted, what was produced, what was learned. Composed after the fact; never a working record. A report starts at draft and transitions directly to settled.

#### Required sections

| Section | Purpose |
|---|---|
| **Context** | what the operation was, why it ran, its scope and exclusions |
| **The brief** | what the operation set out to do, and the contract it ran against |
| **Compact log of actions** | what was done, phase by phase, with measured counts |
| **Mid-run adjustments** | the method changes made during the operation, each with why |
| **Findings summary** | the register link plus numbers computed from the data file, never asserted |
| **Resolution methods** | how the findings were handled, and the lanes they were split into |
| **Post-review learnings and process adjustments** | the reflection on the operation and the process changes that follow |
| **Final output artifacts** | the durable outputs the operation produced, each with its home |
| **Resolution status** | what is closed vs open, and the follow-ups by track |
| **Records this supersedes** | the documents the report replaces, their fate, and where each piece of their content now lives |
