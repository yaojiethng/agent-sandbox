# Task Type Taxonomy

**Current:** 2026-09-19

> This ADR records the design as it stands and is expected to evolve. A later
> change supersedes the current entry by adding a dated entry, per the ADR
> policy. It is not a locked contract.

## 2026-09-19 -- Handover type and commit type are decoupled

**Decision:** the handover type and the git commit type are two independent
vocabularies, set at different times and judged by different rules. The
handover type is set at scope confirmation and names the deliverable. The
commit type is set at close and names the landed diff. No cross-table mapping
couples the two policy documents.

Handover types split into an active set and a deprecated set. The active set
is `impl`, `discussion`, `plan`, `design`, `docs`, `workflow`, `chore`,
`audit`. The deprecated set is `story`, `study`, `spec`, retained so
historical handovers remain readable.

Commit types are `feat`, `fix`, `refactor`, `docs`, `chore`, `workflow`,
`test`, `build`. The commit type is decided from the diff alone, independent
of the handover type.

**Boundary rules.** `impl` is the catch-all handover for any behaviour work:
a new capability, a fix, or a restructure. The commit type disambiguates the
subclass (`feat` for new capability, `fix` for a correction, `refactor` for a
restructure). `impl` covers user-facing help and error strings; a help-text
pass is never a `workflow` commit. `workflow` is reserved for policy,
governance, AGENTS.md, and prompts. `chore` is the small administrative or
cosmetic case; a change that is not mostly administrative or cosmetic is
`refactor` or `audit`. `audit` is a compliance or review sweep that usually
produces a report or a non-content reordering sweep; code changes from a sweep
are `refactor`.

**Why the link was removed.** An earlier taxonomy version forced a one-to-one
"iteration type mapping" column onto the `git_policy` commit-type table
(`docs` -> `design`, `feat`/`fix`/`refactor` -> `impl`). That alignment
misclassified a user-facing help-text pass as `workflow`, because the two
single-word vocabularies did not carry the boundary. The failure mode was the
redundancy itself: a mapping column restating in a table what the "When to
use" rule states in prose drifts independently of its source. The decoupling
removes the coupling that produced the ambiguity. The commit type is judged
from the diff; the handover type is judged from the deliverable.

**Links.** The operational tables live in
[`docs/operations/handover_policy.md`](../operations/handover_policy.md)
(Types) and
[`docs/operations/git_policy.md`](../operations/git_policy.md) (Active Types).
This ADR records the principle; those tables record the current sets. The
AGENTS.md guard carries the single chore carveout: a chore commit may land
with no handover when the operator explicitly requires it.
