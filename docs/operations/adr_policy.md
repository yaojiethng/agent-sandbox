# ADR Policy

Governs files in `docs/adr/`.

## Naming

Format:

```
YYYYMMDD-adr-{status}-{description}.md
```

Type is always `adr` (enforced — no other type occurs in this directory).
Same character rules as `discussion_policy.md`: hyphens as delimiters,
underscores as word separators, charset `[a-z0-9][a-z0-9._-]*`.

### Statuses

| Status | Meaning | Valid next states |
|---|---|---|
| `settled` | Decision made and recorded | `superseded` |
| `superseded` | Replaced by a newer ADR | — |

## When an ADR is required

An ADR is required when a design decision results in implemented code.
Written during the session that implements the decision. The ADR is created
before the session closes.

An ADR is not required for:
- Rejected decisions (recorded in the discussion doc as status `rejected`)
- Routine implementation choices with no design trade-offs
- Decisions already captured by an existing ADR

## Content

ADR documents follow this section order:

- **Summary** — one line below the title
- **Context** — what problem, what triggered the decision
- **Options Considered** — alternatives with trade-offs
- **Decision** — what was chosen and why
- **Consequences** — what this changes, what it enables, what it forecloses
- **Supersedes** — links to superseded docs, with section anchor if partial

## Supersede protocol

When a new ADR supersedes an existing one:

1. The old ADR gets one edit — a `> **Superseded by:** [link](#section)` blockquote at the top, immediately after the title line.
2. The new ADR lists what it supersedes in its Supersedes section:
   - Full document: `[20260611-story-superseded-agent_git_surface.md](../../devlog/discussions/20260611-story-superseded-agent_git_surface.md)`
   - Partial: `[20260416-study-superseded-git_worktrees.md](../../devlog/discussions/20260416-study-superseded-git_worktrees.md#finding-1-core-incompatibility-project_dir-is-never-mounted)`
3. After the edit, the old ADR is frozen — no further changes.
