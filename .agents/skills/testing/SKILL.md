---
name: testing
description: agent-sandbox's testing convention - the suite and the lint umbrella.
---

# testing

This project's testing convention:

| Subject | Structure |
|---|---|
| The suite | `scripts/run_tests.sh`, globbing `tests/test_*.sh` |
| The lint umbrella | `scripts/lint.sh` |
| Test files | `tests/test_<subject>.sh` |

The rule that governs them is [`testing_policy.md`](../../../docs/development/testing_policy.md).
