# Branching

## Naming

```text
type/milestone_description
```

| Part | Rule |
|---|---|
| `type` | the commit type of the work the branch carries |
| `milestone` | the milestone or sub-milestone ID with dots replaced by underscores |
| `description` | lowercase, hyphen-separated, and never an underscore: that character is the milestone separator |

Examples: `feat/m2_1-snapshot-pipeline`, `fix/m2_1-diff-baseline-sha`, `docs/m2_1-two-layer-model`, `workflow/m2_1-handover-policy-restructure`.

A change not tied to a milestone omits the milestone, as in `workflow/git-policy` or `chore/readme-typos`.

## The branch tree

The milestone tree is fractal: a milestone holds sub-milestones, and a sub-milestone holds delivery branches. The branch tree mirrors it. `main` is the root long-lived branch; every milestone node may carry a long-lived branch, a **track**, cut from its parent's track; a delivery branch is the leaf.

```text
main
  \-- feat/m3-orchestration                 track for M3
        \-- feat/m3_5-task-list             track for M3.5
              \-- feat/m3_5_4-branch-tree   delivery branch
```

A node whose work needs no separate long-lived branch is collapsed into its parent's track. The current M3.5.4 is collapsed into the M3 track. The collapse is a topology choice, not a second model: when a node does carry a track, it follows the same lifecycle as every other track.

## The track

A track is the long-lived branch at a milestone node. It is the workspace that node's work happens on, and it is the integration branch for the node's children.

- Cut from the parent's track when the node opens.
- Accepts its children by fast-forward.
- Merges into the parent when the node closes.
- Deleted after the merge.

The track's lifetime is the node's lifetime. It carries the type prefix of the work it predominantly carries.

## The trunk is a role

At every node the parent branch is the trunk for its children. The trunk accepts or refuses; it never authors and never resolves a conflict. The child owns its rebase and its own merge-back.

`main` carries the host branch-protection rules in `docs/development/standard_operating_procedures.md#5-human--operational-protocols`. Every track carries the accept rule: it only fast-forwards.

## The prepare obligation

A branch is ready for its trunk when the trunk's head is an ancestor of its tip. When the trunk moves, the branch is `not-ready`; it re-prepares before it can be accepted. This holds at every level: a delivery branch re-prepares onto its track, and a track re-prepares onto its parent.

The queue is a view over the ready set and never holds a `not-ready` branch. A branch left out of the queue re-prepares and re-enters.

## Lifecycle

A delivery branch is deleted when its trunk accepts it. A track is deleted when its node merges into its parent. A stale branch with no activity across two milestones is deleted.

## Tagging

Tags mark milestone boundaries on `main`, placed on the merge commit that completes the milestone. The format is a lower-case `m`, the milestone number, and the dot-separated sub-milestone: `m1`, `m1.5`, `m2.1`. There is no `v` prefix, because these are milestone markers rather than version releases.

Tagging becomes worth doing when one of these applies: CI/CD triggers off milestone tags, a run is reproduced against a milestone state, two milestones are diffed, or the repository is shared with contributors who need stable reference points. Until then it is optional, because the changelog and the handover chain carry the same history in prose.
