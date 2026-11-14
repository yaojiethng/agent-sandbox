---
description: a personal prompt (macro) for thermonuclear-review.
---

/code-review run a thermonuclear-review (one pass only) using the model priority defined in Pi's settings.json enabledModels, thinking level: max, without any pre-seeded "[prior round: | investigate {x} issues]" list.

scope: All the commits in the current working branch. If you have prior review-pass artifacts, delete them before starting the new run.
