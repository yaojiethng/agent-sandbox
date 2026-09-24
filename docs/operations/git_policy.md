# Git Policy

Policy for commit messages and branch naming in agent-sandbox. Commit types are aligned with the iteration types defined in [`handover_policy.md`](handover_policy.md) so that the git log and iteration history tell the same story.

---

## Commit Message Format

```text
type: short description
```

Lower-case type prefix, colon, space, imperative summary. No scope field for now -- scope may be introduced later when component boundaries are clearer.

The short description completes the sentence "this commit will..." -- e.g. `feat: add snapshot validation gate`, not `feat: added snapshot validation gate`.

Body and footer are optional. Use a body when the "why" is not obvious from the summary. Use a footer for references (`Closes #12`, `See roadmap M2.1`).

The description summarises *why* and *what category* changed, not *what changed line by line*. The diff is visible in `git show`. No file paths or line numbers in the body -- that is the diff's job.

Every delivery commit (at iteration end) must use one of the types defined below. Intermediate commits -- wip checkpoints, corrections, test rollbacks, amends -- are not subject to this rule. Delivery commits without a valid prefix are rejected at review gate.

---

## Active Types

These types are adopted now. The commit type is decided from the nature of the change, independent of the handover type.

| Type | When to use |
|---|---|
| `feat` | New capability or behaviour |
| `fix` | Bug fix -- corrects broken behaviour |
| `refactor` | Code restructuring with no behaviour change; large sweeping cleanups |
| `docs` | Documentation-only changes -- descriptive prose, decision records, plans, reports |
| `chore` | Inert maintenance -- stale refs, index cleanup, linting, formatting |
| `workflow` | Policy changes, CI/CD rules, governance -- skill files under `src/reasoning/agent/` count as governance |
| `test` | Adding or updating tests or test infrastructure (runner, stubs, harness, `tests/libs/`) |
| `build` | Changes to Dockerfile, build scripts, image pipeline |

The commit type is chosen from the diff alone, not from the handover type. Both are evaluated at close: the commit type names what the change is; the handover type (set at scope time) names the deliverable. The two tables in `handover_policy.md` and here stay independent -- a documentation iteration that only touches an ADR is `docs` regardless, while any behaviour change's commit is `feat`, `fix`, or `refactor` according to the diff.

### Choosing between types

A commit that changes both code and documentation uses the type of the primary change. A snapshot pipeline implementation that also updates `execution_model.md` is `feat`, not `docs`. A documentation iteration that only touches markdown files is `docs` even if the content describes a new feature.

`refactor` vs `feat`: if the system behaves identically before and after, it is a refactor. If an operator or agent can do something they could not do before, it is a feat.

`chore` vs `workflow`: a chore is inert -- it does not change how work is done, only tidies what exists. A workflow commit changes the rules: a new policy, a CI/CD gate, a linter configuration, a branch protection change. If merging the commit would require other contributors to change their behaviour, it is `workflow`, not `chore`.

`chore` vs `docs`: if the change fixes stale links, updates an index, or cleans up formatting without changing the substance of what a document says, it is a chore. If the change updates the documented system reality, it is `docs`.

---

## Future Types

Parked until the project has a use case. Introduce them when the first commit would naturally use them -- not before.

| Type | Intended use | When to introduce |
|---|---|---|
| `perf` | Performance improvement with no behaviour change | When profiling or optimisation work begins |
| `revert` | Reverts a previous commit | When the first revert is needed |
| `ci` | CI/CD pipeline changes (distinct from `workflow` -- `ci` is pipeline plumbing, `workflow` is governance) | When CI/CD is introduced (M3+) |
| `style` | Code formatting, whitespace -- no logic change | When a formatter or linter is enforced |

---

## Branch Naming

```text
type/milestone_description
```

Type matches the commit type. Milestone is the sub-milestone ID with dots replaced by underscores. Description is lowercase and hyphen-separated. Underscore is reserved for the milestone separator -- do not use it in the description.

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

`main` is the only long-lived branch. All work happens on type-prefixed branches and merges via review. Branch protection rules are defined in [`standard_operating_procedures.md`](standard_operating_procedures.md#5-human--operational-protocols).

---

## Branching Strategy

### Simple case -- one branch per sub-milestone

Most sub-milestones fit in one to three sessions and produce a single branch. The branch is created at session start, receives commits across sessions, and merges to `main` when the sub-milestone is complete and reviewed.

```text
main ──────────────────────────────●── ...
        \                         /
         feat/m2_1-snapshot ─────
```

### Chunky sub-milestones -- integration branch

When a sub-milestone is too large or too varied for a single branch -- multiple functional areas, different commit types, or enough sessions that the branch becomes unwieldy -- use an integration branch.

The integration branch is named for the sub-milestone without a type prefix:

```text
milestone/m2_1
```

Session branches are created from the integration branch and merged back into it as each session or functional slice completes. The integration branch merges to `main` when the full sub-milestone is reviewed and approved.

```text
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

A session branch is merged or discarded when its work is complete. An integration branch is merged when the sub-milestone is complete. Stale branches with no activity for two milestones are deleted.

---

## Multi-File Commits

A single commit should be a coherent unit of change. Prefer fewer, meaningful commits over many granular ones. Guidelines:

- A policy restructuring iteration that touches six policy files is one `workflow` commit, not six.
- An implementation that adds a script and its tests is one `feat` commit, not separate `feat` + `test`.
- An iteration that produces both a feature and an unrelated chore fix is two commits -- do not bundle unrelated changes.

---

## Checkpointing

An iteration that ends with uncommitted work is a risk -- the handover records intent, but the filesystem is the only copy. Commit at iteration end even if the work is incomplete.

**Rules:**

- At iteration end, commit all work-in-progress on the active branch with a clear message: `wip: description of incomplete state`
- `wip` is not a commit type -- it is a prefix that signals the commit is not reviewable. The next iteration amends or follows up.
- Intermediate commits (wip, corrections, amends) are not subject to the type enforcement rule -- that rule applies only to the delivery commit at iteration end.
- Do not leave uncommitted changes across iteration boundaries -- this includes stashes. If work is incomplete at iteration end, commit with `wip:` prefix instead of stashing. The handover cannot reconstruct files; the commit can.
- On integration branches, session branches should be merged (not left dangling) before the session ends, even if the integration branch itself is not ready for `main`.

This is the git-level equivalent of the `autosave.diff` pattern in the execution model -- a checkpoint that preserves state without implying completeness.

---

## WIP Commits

`wip:` is an accepted commit prefix for intermediate checkpoints. A `wip:` commit is a checkpoint, not a deliverable. It is never reviewable and never reaches `main` as-is. Squash every `wip:` commit into the typed delivery commit at iteration end.

Use `wip:` when:

- The current task is a far-reaching refactor or audit-type change and you need checkpoints.
- The operator directs a wip commit.
- You propose a wip commit and the operator accepts.

The delivery commit at iteration end always carries a type prefix from the Active Types table, however many wip commits preceded it. wip commits are implementation detail; the delivery commit replaces them.

---

## Transient commits fold into the delivery commit

One delivery commit carries each iteration. Transient commits during the iteration fold into it. Three kinds exist:

- `wip:` checkpoints -- in-progress snapshot that is never reviewable; squash into the delivery commit at iteration end.
- Correction commits -- an amend or fixup that corrects a commit made earlier in the same iteration; fold into that commit via `git commit --fixup=<hash>` and `git rebase -i --autosquash`.
- The close edit -- the `Status: Closed` flip and the roadmap write-back; they belong in the delivery commit.

Each kind resolves to the single delivery commit; the delivery commit is the sole reviewable surface.

**Stuck procedure.** When the iteration's history already holds the work commit and the close edit is still outstanding, fold the edit into the work commit: set `Status: Closed`, apply the write-back, then amend (`git commit --amend`) or, for a non-HEAD delivery commit, `git commit --fixup=<hash>` plus `git rebase -i --autosquash`. The end state is one commit per iteration.

---

## Amending

Amending folds changes into their parent commit rather than creating follow-up commits. Valid use cases:

- **Squashing wip commits** -- wip checkpoints accumulated during an iteration are squashed into the delivery commit at iteration end.
- **Correcting a prior commit** -- when a handover, task list, or implementation needs a correction that belongs to the same logical unit as a commit already made *in this iteration*. The amendment bundles the fix with the commit where the work was done. A correction that targets a non-HEAD commit in the same iteration folds into it via interactive rebase.
- **Early iteration end** -- when the agent committed the delivery commit but the operator identifies a gap before the next iteration starts. The amendment is applied to the delivery commit rather than creating a separate correction commit.

**Boundary:** Amend only within the current iteration's commit chain. Do not amend commits from prior iterations -- those are part of the permanent reviewed record. If a prior iteration's commit needs fixing, file a new issue or create a new iteration.

---

## Recovery

Procedures for recovering from situations where normal discipline breaks down.

### Splitting interleaved changes

When a single file contains changes from multiple iterations that must be split into separate commits:

1. Save the full diff: `git diff > file.patch`
2. Reset to HEAD: `git checkout HEAD -- file`
3. For each commit, apply only the relevant hunks: `git apply file.patch` (then stage and commit)
4. Repeat for each remaining iteration's changes

If the file cannot be split by hunk boundaries (interleaved changes to the same logical section), consider splitting into two files or restructuring the changes so each iteration's work is disjoint.

## Merge Policy

### Session branch -> integration branch

**Squash merge.** Each session branch becomes a single commit on the integration branch. The squash message uses the appropriate commit type and summarises the session's contribution. Individual session commits are implementation detail -- the integration branch reads as a sequence of coherent steps.

### Session branch -> `main` (simple case)

**Squash merge.** Same rationale -- the branch collapses to one commit on `main`. If the branch has only one commit already, a fast-forward merge is acceptable.

### Integration branch -> `main`

**Merge commit.** Preserves the sub-milestone as a visible unit in `main`'s history. The merge commit message follows the format:

```text
feat: complete M2.1 — snapshot pipeline and diff workflow
```

Use the dominant commit type for the sub-milestone. If the sub-milestone is mixed (feat + docs + build), use `feat` if it delivers new capability, or `docs` if it is primarily documentation.

### Review gate

No branch merges to `main` without operator review and approval. This restates the system invariant: all repository mutation is operator-initiated. For integration branches, the operator may review incrementally (session branch merges) or as a whole (integration branch merge to `main`), but the final merge to `main` always requires explicit approval.

### Conflict resolution

The operator resolves conflicts. When two session branches on the same integration branch touch overlapping files, the second branch to merge resolves conflicts against the integration branch before merging. Conflicts on merge to `main` are resolved on the integration branch, not on `main`.

---

## Tagging

**Status:** Convention defined. Adopt when the first use case arises -- currently parked.

Tags mark major milestone boundaries on `main`. The tag is placed on the merge commit that completes the milestone.

**Format:**

```text
m1
m1.5
m2.1
```

Lower-case `m`, milestone number, dot-separated sub-milestone. No `v` prefix -- these are milestone markers, not version releases.

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
| [`handover_policy.md`](handover_policy.md) | Iteration types that map to commit types |
| [`standard_operating_procedures.md`](standard_operating_procedures.md#5-human--operational-protocols) | Human / Operational Protocols |
| [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) | Upstream specification this policy draws from |

---
