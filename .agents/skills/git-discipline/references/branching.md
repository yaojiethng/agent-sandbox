# Branching

## Naming

```text
type/milestone_description
```

| Part | Rule |
|---|---|
| `type` | the commit type of the work the branch carries |
| `milestone` | the sub-milestone ID with dots replaced by underscores |
| `description` | lowercase, hyphen-separated, and never an underscore: that character is the milestone separator |

Examples: `feat/m2_1-snapshot-pipeline`, `fix/m2_1-diff-baseline-sha`, `docs/m2_1-two-layer-model`, `workflow/m2_1-handover-policy-restructure`.

A change not tied to a sub-milestone omits the milestone, as in `workflow/git-policy` or `chore/readme-typos`.

## Protected branches

`main` is the only long-lived branch. All work happens on a type-prefixed branch and merges by review. The branch protection rules are in `docs/development/standard_operating_procedures.md#5-human--operational-protocols`.

## One branch per sub-milestone

Most sub-milestones fit in one to three sessions and produce a single branch. It is created at session start, receives commits across sessions, and merges to `main` when the sub-milestone is complete and reviewed.

```text
main ──────────────────────────────●── ...
        \                         /
         feat/m2_1-snapshot ─────
```

## The integration branch

When a sub-milestone is too large or too varied for one branch, it gets an integration branch named for the milestone with no type prefix, `milestone/m2_1`. Session branches are cut from it and merged back as each slice completes, and it merges to `main` when the whole sub-milestone is reviewed.

```text
main ──────────────────────────────────────────●── ...
        \                                      /
         milestone/m2_1 ──────●────────●──────
              \              /    \         /
               feat/m2_1-snapshot  feat/m2_1-diff
```

Use an integration branch when any of these hold:

- the sub-milestone spans more than three sessions
- it produces branches with different type prefixes, such as `feat` with `docs` and `build`
- intermediate merges to `main` would leave the system incomplete
- the operator wants to review the sub-milestone as one coherent unit

Otherwise the single-branch model is preferred.

## Lifecycle

A session branch is merged or discarded when its work is done. An integration branch is merged when the sub-milestone is complete. A stale branch with no activity across two milestones is deleted.

## Tagging

Tags mark milestone boundaries on `main`, placed on the merge commit that completes the milestone. The format is a lower-case `m`, the milestone number, and the dot-separated sub-milestone: `m1`, `m1.5`, `m2.1`. There is no `v` prefix, because these are milestone markers rather than version releases.

Tagging becomes worth doing when one of these applies: CI/CD triggers off milestone tags, a run is reproduced against a milestone state, two milestones are diffed, or the repository is shared with contributors who need stable reference points. Until then it is optional, because the changelog and the handover chain carry the same history in prose.
