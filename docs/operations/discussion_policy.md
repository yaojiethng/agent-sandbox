# Discussion Policy

Governs files in `devlog/discussions/`. For ADRs, see `adr_policy.md`.

## Naming

Format:

```
YYYYMMDD-{type}-{status}-{description}.md
```

Hyphens as section delimiters. Underscores as word separators in the description. Description character set: `[a-z0-9][a-z0-9._-]*` (lowercase letters, digits, period, underscore, hyphen). No emoji, no unicode, no spaces.

### Types

| Code | When to use |
|---|---|
| `story` | Problem framing — what does the operator need? |
| `study` | Feasibility — can we do X? |
| `design` | Decision exploration — should we, and how? |

### Statuses

| Status | Meaning | Valid next states |
|---|---|---|
| `draft` | First write, not yet reviewed | `active`, `rejected` |
| `active` | Under discussion or investigation | `settled`, `rejected` |
| `settled` | Discussion closed, decision reached | `superseded`, `archived` |
| `superseded` | Replaced by a newer doc | `archived` |
| `rejected` | Decided against | `archived` |
| `archived` | Terminal — no active references | — |

### Standalone policy docs

Policy files under `docs/operations/` are not discussion docs and do not follow this naming convention.

### Legacy docs

Existing docs with old-format names keep their names until substantively edited. On first edit, rename to this convention and update inbound links.

## Document types

### Stories (`story`)
See [`story_policy.md`](story_policy.md).

Defines the problem space. Created during the major loop when a sub-milestone objective is understood but the approach is not.

### Studies (`study`)
See [`study_policy.md`](study_policy.md).

Evaluates a specific candidate approach. One study per candidate. Runs until a recommendation can be made and fed back to the parent story.

### Designs (`design`)

Opened during the minor loop Step 3 (Design) — see [`iteration_policy.md`](iteration_policy.md) when design is active. A design doc resolves trade-offs between options and recommends a decision.

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
