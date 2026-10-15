---
name: task-list
description: agent-sandbox's task-list convention - the roadmap, the future roadmap and the changelog. Use when a workflow procedure reads or writes the task list.
---

# task-list

This project's task list is the roadmap and its two companions.

| Record | Path |
|---|---|
| The current sub-milestone and its pending tasks | `devlog/roadmap.md` |
| The sub-milestones planned but not active | `devlog/roadmap_future.md` |
| The completed sub-milestones, newest first | `devlog/changelog.md` |

The rule that governs them is [`roadmap_policy.md`](../../../docs/policies/roadmap_policy.md).

## The milestone identifier

The roadmap's `active-milestone` frontmatter and a handover's `milestone` field carry the same value: the milestone's identifier, a space-hyphen-space, then its name.

```text
<ID> - <Name>
```

The identifier is a dotted path (`M3.3.1`, `T12`) and the name is the one the milestone carries in the roadmap. If a handover's `milestone` field names a milestone the roadmap does not carry, the handover is unassigned.
