---
name: evals
description: agent-sandbox's evals convention - the eval skill and the snapshot command.
---

# evals

This project's evals convention:

| Subject | Structure |
|---|---|
| The eval harness | `workflow/coding-agent/skills/eval/SKILL.md` |
| The snapshot command | `src/libs/package_eval_snapshot.sh` |
| The snapshot export | `<to>/evals/<export-time>-<summary>-<session-id>/` |

The convention is optional: a project that runs no evals leaves it unprovisioned.
