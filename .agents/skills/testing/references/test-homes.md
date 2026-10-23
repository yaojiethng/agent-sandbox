# Test homes

Open this when you choose between the unit suite, `tests/knowledge/` and `tests/integration/`. The placement judgement is in [`../SKILL.md`](../SKILL.md); this file holds each home, its prefixes, and what the runner does with it.

## The unit suite (`tests/test_*.sh`)

The suite `make test` runs. A test file is named for its subject and holds that subject's units ([`../patterns/structure.md`](../patterns/structure.md)). The runner globs `tests/test_*.sh` without recursion, so a nested file is not discovered. The suite contract is `failed 0`.

## `tests/knowledge/`

Behavioural knowledge about seams the harness cannot call. Every file is self-contained: it creates and cleans its own temporary directories and exits 0 on success, non-zero on failure. The runner never executes these; `scripts/check_test_smoke.sh` syntax-checks them with `bash -n`.

| Category | Prefix | Purpose |
|---|---|---|
| Knowledge test | `knowledge_*.sh` | Record what an unmodifiable seam does - git, docker, rsync, pi, an external library - and assert the assumption still holds. A one-off feasibility probe from an investigation is a knowledge test. Its assertions are not acceptance criteria for implementation work, and it must not probe our own maintained code that has an API; that belongs in the unit suite. |
| Diagnostic script | `diagnose_*.sh` | Verify the internal invariants of one production script or subsystem when a dry run or pre-flight check fails to isolate the cause. It runs in a container for troubleshooting, not as a regression test, and it may be named in an acceptance criterion as a regression guard for a recurring bug class. It is named for the production script it diagnoses. |
| Workflow test | `workflow_*.sh` | Validate a complete operator workflow against a mock repository - draft then confirm, draft then reject - asserting the resulting state, layout and exit codes. A multi-step operator workflow takes a workflow test over manual verification. |

## `tests/integration/`

End-to-end or environment-gated flows that cannot run deterministically in the unit harness: container or daemon requirements, chunky multi-process flows, metrics with no defined pass/fail. They are excluded from `make test` so the unit suite stays a deterministic `failed 0`. A flow whose seam becomes unit-testable is promoted, not kept here as a permanent home.

## Promoting a test

A seam that was untestable and becomes testable - a docker mock now asserting the exact command passed, a network call behind a stub - is promoted to `tests/test_*.sh` in the change that makes it callable. The knowledge or integration note is then deleted, not left beside the unit test as a second opinion.
