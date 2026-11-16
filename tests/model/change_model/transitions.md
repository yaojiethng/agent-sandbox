# Change model transitions

## The transitions

The transition table is the contract; the chart is its rendered view. `Lane` and `Actor` say who acts, `Mechanism` names the command or git operation, and `Manual` says whether an operator decision is part of the step. A blocked path is a transition that does not fire, recorded in `## The blocked paths`.

| Id | Lane | Actor | Event | Guard | From | To | Mechanism | Manual | Subject | Invariant | Test | Mutation |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| `T01` | agent | agent | prepare | the head is not an ancestor of the tip | `working` | `ready` | rebase onto the head | no | the prepare runbook | `PrepareResolvesEveryConflict` | `none: model check` | `none: model-only` |
| `T02` | agent | agent | history-cleanup | the series is not reviewable | `ready` | `ready` | `history-cleanup` | no | the history-cleanup skill | `SeriesIsReviewable` | `none: model check` | `none: model-only` |
| `T03` | agent | agent | export | the branch is prepared | `ready` | `ready` | the package step | no | the export step | `BundleCarriesTheBranchPoint` | `none: model check` | `none: model-only` |
| `T04` | host | operator | draft | a bundle is present and forkable | `ready` | `drafted` | `make draft` | no | `scripts/workflows/draft.sh` | `MergeableRequiresForkable` | `test_draft_forks_from_branch_point_not_head` | `252` |
| `T05` | host | operator | review | a draft is present | `drafted` | `drafted` | read the diff | yes | none: operator action | `ReviewBeforeAccept` | `none: operator action` | `none: operator action` |
| `T06` | host | operator | confirm | the draft is ready and at the queue head | `drafted` | `accepted` | `make confirm` | yes | `scripts/workflows/confirm.sh` | `AtomicAccept` | `test_confirm_script_entry_merges_draft` | `52` |
| `T07` | host | operator | reject | a draft is present | `drafted` | `ready` | `make reject` | yes | `scripts/workflows/reject.sh` | `RejectRestoresTheSource` | `test_reject_returns_to_source` | `259` |
| `T08` | host | operator | apply | a bundle is present and no draft is wanted | `ready` | `ready` | `make apply` | yes | `scripts/workflows/apply.sh` | `ApplyIsDirect` | `test_apply_run_single_file_diff_reports_one` | `none: model-only` |
| `T09` | host | another accept | the head advances | a confirm moved the head | `ready` | `working` | the trunk ref update | no | none: model-only | `ReadyReturnsToWorking` | `none: model check` | `none: model-only` |
| `T10` | host | operator | operator git | the operator runs git outside the verbs | `drafted` | `drafted` | raw git | yes | none: operator action | `OperatorGitRederivesTheState` | `none: operator action` | `none: operator action` |
| `T11` | host | operator | reject and redraft | the draft is inconsistent | `drafted` | `drafted` | `make reject` then `make draft` | yes | `scripts/workflows/reject.sh` | `MistakeHasARemediation` | `test_reject_returns_to_source` | `259` |
| `T12` | host | operator | delete | the trunk accepted the branch | `accepted` | `deleted` | `git branch -d` | yes | none: operator action | `AcceptedBranchIsDeleted` | `none: operator action` | `none: operator action` |
| `T13` | host | operator | abandon | the branch is stale and not ready | `working` | `deleted` | `git branch -D` | yes | none: operator action | `AbandonedBranchIsDeleted` | `none: operator action` | `none: operator action` |
| `T14` | host | operator | abandon | the branch is stale and ready | `ready` | `deleted` | `git branch -D` | yes | none: operator action | `AbandonedBranchIsDeleted` | `none: operator action` | `none: operator action` |
