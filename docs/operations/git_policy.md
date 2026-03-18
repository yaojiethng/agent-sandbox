# Git Policy

**Status:** Stub. Adopted types and branch naming are active. Scope field and future types are parked until usage patterns stabilise.

Policy for commit messages and branch naming in agent-sandbox. Commit types are aligned with the session types defined in [`handover_policy.md`](handover_policy.md) so that the git log and session history tell the same story.

---

## Commit Message Format

```
type: short description
```

Lower-case type prefix, colon, space, imperative summary. No scope field for now — scope may be introduced later when component boundaries are clearer.

The short description completes the sentence "this commit will..." — e.g. `feat: add snapshot validation gate`, not `feat: added snapshot validation gate`.

Body and footer are optional. Use a body when the "why" is not obvious from the summary. Use a footer for references (`Closes #12`, `See roadmap M2.1`).

---

## Active Types

These types are adopted now. Each maps to one or more session types from `handover_policy.md`.

| Type | When to use | Session type mapping |
|---|---|---|
| `feat` | New capability or behaviour | Implementation (`impl`) |
| `fix` | Bug fix — corrects broken behaviour | Implementation (`impl`) |
| `refactor` | Code restructuring with no behaviour change | Implementation (`impl`), Housekeeping (`chore`) |
| `docs` | Documentation-only changes | Design (`design`), Spec (`spec`), Story (`story`), Investigation (`study`), Planning (`plan`) |
| `chore` | Inert maintenance — stale refs, index cleanup, linting, formatting | Housekeeping (`chore`) |
| `workflow` | Changes that affect how other branches work — policy changes, CI/CD rules, branch restrictions, linter config, governance | Workflow (`workflow`) |
| `test` | Adding or updating tests only | Implementation (`impl`) |
| `build` | Changes to Dockerfile, build scripts, image pipeline | Implementation (`impl`) |

### Choosing between types

A commit that changes both code and documentation uses the type of the primary change. A snapshot pipeline implementation that also updates `execution_model.md` is `feat`, not `docs`. A documentation session that only touches markdown files is `docs` even if the content describes a new feature.

`refactor` vs `feat`: if the system behaves identically before and after, it is a refactor. If an operator or agent can do something they could not do before, it is a feat.

`chore` vs `workflow`: a chore is inert — it does not change how work is done, only tidies what exists. A workflow commit changes the rules: a new policy, a CI/CD gate, a linter configuration, a branch protection change. If merging the commit would require other contributors to change their behaviour, it is `workflow`, not `chore`.

`chore` vs `docs`: if the change fixes stale links, updates an index, or cleans up formatting without changing the substance of what a document says, it is a chore. If the change updates the documented system reality, it is `docs`.

---

## Future Types

Parked until the project has a use case. Introduce them when the first commit would naturally use them — not before.

| Type | Intended use | When to introduce |
|---|---|---|
| `perf` | Performance improvement with no behaviour change | When profiling or optimisation work begins |
| `revert` | Reverts a previous commit | When the first revert is needed |
| `ci` | CI/CD pipeline changes (distinct from `workflow` — `ci` is pipeline plumbing, `workflow` is governance) | When CI/CD is introduced (M3+) |
| `style` | Code formatting, whitespace — no logic change | When a formatter or linter is enforced |

---

## Branch Naming

```
type/milestone_description
```

Type matches the commit type. Milestone is the sub-milestone ID with dots replaced by underscores. Description is lowercase and hyphen-separated. Underscore is reserved for the milestone separator — do not use it in the description.

Examples:
- `feat/m2_1-snapshot-pipeline`
- `fix/m2_1-diff-baseline-sha`
- `docs/m2_1-two-layer-model`
- `chore/m2_1-stale-refs-cleanup`
- `workflow/m2_1-handover-policy-restructure`
- `build/m2_1-capability-layer-dockerfile`

When a change is not tied to a specific sub-milestone (e.g. a cross-cutting policy change), omit the milestone:
- `workflow/git-policy`
- `chore/readme-typos`

### Protected branches

`main` is the only long-lived branch. All work happens on type-prefixed branches and merges via review. Branch protection rules are defined in [`standard_operating_procedures.md`](standard_operating_procedures.md) — Human / Operational Protocols.

---

## Branching Strategy

### Simple case — one branch per sub-milestone

Most sub-milestones fit in one to three sessions and produce a single branch. The branch is created at session start, receives commits across sessions, and merges to `main` when the sub-milestone is complete and reviewed.

```
main ──────────────────────────────●── ...
        \                         /
         feat/m2_1-snapshot ─────
```

### Chunky sub-milestones — integration branch

When a sub-milestone is too large or too varied for a single branch — multiple functional areas, different commit types, or enough sessions that the branch becomes unwieldy — use an integration branch.

The integration branch is named for the sub-milestone without a type prefix:

```
milestone/m2_1
```

Session branches are created from the integration branch and merged back into it as each session or functional slice completes. The integration branch merges to `main` when the full sub-milestone is reviewed and approved.

```
main ──────────────────────────────────────────●── ...
        \                                      /
         milestone/m2_1 ──────●────────●──────
              \              /    \         /
               feat/m2_1-snapshot  feat/m2_1-diff
```

### When to use an integration branch

Use an integration branch when any of these apply:
- The sub-milestone spans more than three sessions
- The sub-milestone produces branches with different type prefixes (e.g. `feat` + `docs` + `build`)
- Intermediate merges to `main` would leave the system in an incomplete state
- The operator wants to review the sub-milestone as a single coherent unit

If none of these apply, the simple single-branch model is preferred.

### Branch lifecycle

A session branch is merged or discarded when its session work is complete. An integration branch is merged when the sub-milestone is complete. Stale branches with no activity for two milestones are deleted.

---

## Multi-File Commits

A single commit should be a coherent unit of change. Prefer fewer, meaningful commits over many granular ones. Guidelines:

- A policy restructuring session that touches six policy files is one `workflow` commit, not six.
- An implementation that adds a script and its tests is one `feat` commit, not separate `feat` + `test`.
- A session that produces both a feature and an unrelated chore fix is two commits — do not bundle unrelated changes.

---

## Checkpointing

A session that ends with uncommitted work is a risk — the handover records intent, but the filesystem is the only copy. Commit at session end even if the work is incomplete.

**Rules:**
- At session close, commit all work-in-progress on the active branch with a clear message: `wip: description of incomplete state`
- `wip` is not a commit type — it is a prefix that signals the commit is not reviewable. The next session amends or follows up.
- Do not leave uncommitted changes across session boundaries. The handover cannot reconstruct files; the commit can.
- On integration branches, session branches should be merged (not left dangling) before the session ends, even if the integration branch itself is not ready for `main`.

This is the git-level equivalent of the `autosave.diff` pattern in the execution model — a checkpoint that preserves state without implying completeness.

---

## Merge Policy

### Session branch → integration branch

**Squash merge.** Each session branch becomes a single commit on the integration branch. The squash message uses the appropriate commit type and summarises the session's contribution. Individual session commits are implementation detail — the integration branch reads as a sequence of coherent steps.

### Session branch → `main` (simple case)

**Squash merge.** Same rationale — the branch collapses to one commit on `main`. If the branch has only one commit already, a fast-forward merge is acceptable.

### Integration branch → `main`

**Merge commit.** Preserves the sub-milestone as a visible unit in `main`'s history. The merge commit message follows the format:

```
feat: complete M2.1 — snapshot pipeline and diff workflow
```

Use the dominant commit type for the sub-milestone. If the sub-milestone is mixed (feat + docs + build), use `feat` if it delivers new capability, or `docs` if it is primarily documentation.

### Review gate

No branch merges to `main` without operator review and approval. This restates the system invariant: all repository mutation is operator-initiated. For integration branches, the operator may review incrementally (session branch merges) or as a whole (integration branch merge to `main`), but the final merge to `main` always requires explicit approval.

### Conflict resolution

The operator resolves conflicts. When two session branches on the same integration branch touch overlapping files, the second branch to merge resolves conflicts against the integration branch before merging. Conflicts on merge to `main` are resolved on the integration branch, not on `main`.

---

## Tagging

**Status:** Convention defined. Adopt when the first use case arises — currently parked.

Tags mark major milestone boundaries on `main`. The tag is placed on the merge commit that completes the milestone.

**Format:**
```
m1
m1.5
m2.1
```

Lower-case `m`, milestone number, dot-separated sub-milestone. No `v` prefix — these are milestone markers, not version releases.

**When tagging becomes active:**
- CI/CD triggers off milestone tags (M3+)
- Reproducing a run against a specific milestone state (`git checkout m2.1`)
- Diffing between milestones (`git log m1.5..m2.1`)
- Sharing the repo with contributors who need stable reference points

Until one of these applies, tagging is optional. The changelog and handover chain provide the same historical record in prose form.

---

## Scope Field

Not adopted. When component boundaries are stable enough to name consistently (e.g. `snapshot`, `diff`, `mcp`, `entrypoint`), scope can be introduced as `type(scope): description`. Until then, the short description carries enough context.

---

## References

| Document | Purpose |
|---|---|
| [`handover_policy.md`](handover_policy.md) | Session types that map to commit types |
| [`contributors.md`](contributors.md) | General contribution rules and branch protection |
| [`standard_operating_procedures.md`](standard_operating_procedures.md) | Human / Operational Protocols |
| [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) | Upstream specification this policy draws from |
