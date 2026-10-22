# Commit types

## The active types

| Type | When to use |
|---|---|
| `feat` | New capability or behaviour |
| `fix` | Bug fix, correcting broken behaviour |
| `refactor` | Code restructuring with no behaviour change; large sweeping cleanups |
| `docs` | Documentation-only changes: descriptive prose, decision records, reports |
| `plan` | Roadmap and milestone planning: scoping at any grain, task assignment, compaction, close and promotion bookkeeping |
| `chore` | Inert maintenance: stale refs, index cleanup, linting, formatting |
| `workflow` | Policy changes, CI/CD rules, governance. A skill file under `src/reasoning/agent/` counts as governance |
| `test` | Adding or updating tests or test infrastructure: runner, stubs, harness, `tests/libs/` |
| `build` | Changes to the Dockerfile, build scripts, or the image pipeline |

The type is read off the diff, not off the record. A documentation iteration that only touches an ADR is `docs`; any behaviour change is `feat`, `fix` or `refactor` according to the diff. Both are evaluated at close: the commit type names what the change is, and the record's type names the deliverable.

## Choosing between types

A commit that changes both code and documentation takes the type of the primary change. A pipeline implementation that also updates `execution_model.md` is `feat`, not `docs`.

- **`refactor` versus `feat`.** If the system behaves identically before and after, it is a refactor. If an operator or an agent can do something new, it is a feat.
- **`chore` versus `workflow`.** A chore is inert: it tidies what exists. A workflow commit changes the rules -- a policy, a gate, a linter configuration, a branch protection. If merging it would make another contributor behave differently, it is `workflow`.
- **`chore` versus `docs`.** Fixing a stale link, updating an index or cleaning formatting is a chore. Updating the documented system reality is `docs`.
- **`plan` versus `docs`.** A plan commit performs roadmap and milestone bookkeeping: scoping, assignment, compaction, close. A docs commit records the system or its decisions.

## Future types

Parked until the project has a use case. Introduce one when the first commit would naturally use it, not before.

| Type | Intended use | When to introduce |
|---|---|---|
| `perf` | Performance improvement with no behaviour change | when profiling or optimisation begins |
| `revert` | Reverts a previous commit | when the first revert is needed |
| `ci` | CI/CD pipeline changes, distinct from `workflow`: `ci` is pipeline plumbing | when CI/CD is introduced |
| `style` | Code formatting and whitespace, no logic change | when a formatter or linter is enforced |

## The scope field

Not adopted. Once component boundaries are stable enough to name consistently, a scope can be introduced as `type(scope): description`. Until then the short description carries enough context.
