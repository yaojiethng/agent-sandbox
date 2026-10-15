---
name: git-discipline
description: agent-sandbox's git-discipline convention - commit types, branch naming and the delivery commit.
---

# git-discipline

This project's git discipline:

| Subject | Structure |
|---|---|
| Commit types | `feat`, `fix`, `refactor`, `docs`, `plan`, `chore`, `workflow`, `test`, `build` |
| Branch names | `<type>/<milestone>-<slug>` |
| The delivery commit | one per work unit, carrying the work, the `Closed` handover and the roadmap write-back |
| Intermediate commits | `wip:` checkpoints that fold at the close |

The rule that governs them is [`git_policy.md`](../../../docs/policies/git_policy.md).
