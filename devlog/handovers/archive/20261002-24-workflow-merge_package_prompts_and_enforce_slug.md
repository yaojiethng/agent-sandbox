---
date: 2026-10-02
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - Merge the two package prompts and enforce the bundle-summary slug

## Objective

One prompt exports the branch, whether the history was rewritten or not, and the script rejects a bundle summary that cannot produce a valid draft branch name.

## Scope

`src/reasoning/agent/prompts/package-branch.md` and `package-rebase.md`, the summary validation and branch-point reporting in `src/libs/package_branch.sh`, its tests, and the two `AGENTS.md` copies of the tool description. [CORRECTION -- 2026-10-02] Amended at the operator direction after the documentation review: the section entered scope in-session and was deleted. Out of scope at the scope gate, then amended: the `How to apply` section entered scope by operator direction once `make draft` printed both routes, and was deleted; see Decision 8. a `make dry-run` addition to the conditional verification field; any change to `draft.sh` slug handling, which stays as the second line of defence.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | A summary with a character outside `[a-z0-9_]` is rejected | `test_summary_rejects_spaces_and_capitals` | pass |
| 2 | A summary longer than 48 characters is rejected | `test_summary_rejects_overlong` | pass |
| 3 | A valid snake_case summary of 3 to 48 characters is accepted | `test_summary_accepts_valid_slug` | pass |
| 4 | The script reports when the branch point moved | `test_moved_baseline_is_reported_and_recorded` | pass |
| 5 | The bundle carries the machine-readable facts | `test_unmoved_baseline_records_no_movement` and the `.branch-point` assertions in the moved case | pass |
| 6 | `package-rebase.md` is gone and its content is in `package-branch.md` | `grep -rn package-rebase src/` returns nothing | pass |
| 7 | The description conveys the branch point and the bundle shape, without restating the body | the frontmatter names both, and carries no instruction the body owns | pass |
| 8 | The guide keeps the draft step and drops the file, `Changed files`, and `How to apply` | `grep -c "migration-guide\|How to apply" src/reasoning/agent/prompts/package-branch.md` returns 0 | pass |
| 9 | Suite and lint green | `bash scripts/run_tests.sh`: 1036 of 1036; lint clean across 5 gates | pass |

## Hot files

| File | Change |
|---|---|
| `src/libs/package_branch.sh` | summary validation; branch-point movement line; three-fact summary file |
| `tests/test_package_branch.sh` | rejection cases, acceptance case, movement line, summary facts |
| `src/reasoning/agent/prompts/package-branch.md` | absorbs the rebase baseline resolution and apply path; trimmed guide; relay rule; rewritten description |
| `src/reasoning/agent/prompts/package-rebase.md` | deleted |
| `~/.pi/agent/AGENTS.md`, `src/reasoning/providers/pi/config/agent/AGENTS.md` | tool description for `/package-branch` |
| `scripts/workflows/draft.sh` | `draft_print_confirm_hint` routes the confirm direction on `merge-base --is-ancestor` and names `make apply DIFF=<path>` |
| `docs/adr/diff_packaging.md` | the end-to-end export-to-merge flow and the deletion of `How to apply`, recorded as a decision |
| `docs/development/prompt-authoring-conventions.md` | `## A workflow document owns one step, and owns it whole`, and the seeded-document linking rule |
| `devlog/AGENT_FEEDBACK.md` | the finding that prompted the convention |
| `devlog/roadmap.md` | the closed row and the open dependency-convention row |

## Completed

The two package prompts are one, the summary is enforced, the movement is reported, the confirm hint routes itself, and the apply flow lives in the ADR.

## Decisions

1. **One prompt, and the baseline is always the branch point.** `package_branch.sh` already computes `git merge-base <init_sha> HEAD`; the rebase prompt re-derived it in prose. The merged prompt states the invariant and the script reports when it moved.
2. **The guide is drafted at the start and printed in chat at the end, not written as a file.** `migration-guide.md` has no consumer: `grep -rn "migration-guide"` across the repo returns only the prompt line that tells the agent to write it. The two facts it carried that survive are the change summary and the host-only check.
3. **`Changed files` is dropped; `MANIFEST.txt` owns it.** The section required the agent to reconcile a hand-written table against the manifest, which is the work worth deleting.
4. **`Verification` is conditional.** The suite and the gates are the container's own close evidence. The field appears only when a host-level check exists, and then names the target and what a pass looks like.
5. **The agent relays; it does not reprocess.** The script's output block is the whole report. The prompt says echo it verbatim, do not summarise or re-derive, because every fact in it is computed by the script and a paraphrase is where a wrong branch point survives.
6. **Slug rules: `^[a-z0-9]+(_[a-z0-9]+)*$`, 3 to 48 characters, rejected with the rule and two examples.** The value becomes `draft/<session>-<slug>-<hash>` in `draft.sh:341`, and git rejects spaces and colons in a ref. Reproduced: `fatal: 'draft/ad31ec-Rebased plan series: M3.1 split, with spaces-ad299e9' is not a valid branch name`. 48 keeps the ref inside git's 255-byte limit.
7. **The capability copy is a build artefact.** `src/capability/dockerfile:26` copies `src/libs/` to `/opt/sandbox/lib/`; the in-container file is byte-identical and root-owned. The validation lands in one source file.
8. **`How to apply` was deleted, not trimmed.** The operator reviewed a trim, then directed deletion once `make draft` printed both routes correctly. The section restated four commands three scripts print, and had drifted: it described only the fast-forward route. The end-to-end flow is recorded in `diff_packaging.md`.
9. **`make draft` routes its own hint on `merge-base --is-ancestor`.** Whether the source branch can fast-forward to the draft tip is a run-time fact only that step can test, so the decision moved out of the prompt and into the script. It also names `make apply DIFF=<path>` for recovery, beside the discard hint it already carried.
10. **The ownership rule is a scoping rule.** `prompt-authoring-conventions.md` states that a workflow document owns one step and owns it whole, and that a top-down flow belongs in a concept document or an ADR. Accuracy is not ownership: the failure is a document that is locally accurate and globally unreliable.

10. **`draft.sh` sanitisation is ruled out of scope, not carried here.** `draft.sh` does not sanitize `BRANCH_SUMMARY` before building the branch name; the validator is the first line and the operator owns the second.

13. **AC 7 was amended.** It read "the description states the branch-point invariant", which is a rule in the description. The rule now lives in the ADR and the prompt body; the description carries the branch point as one of the bundle contents, which conveys the fact without stating the rule.
14. **`worktree` names a git ref and `conditional branch` names control flow, in this ADR.** The 2026-10-02 entry used `branch` for both, inside one sentence.
15. **`Non-goals` was deleted, not trimmed, and its one live boundary moved to a `**Scope:**` line.** Three of the four bullets failed their own test: one duplicated a Step 3 paragraph, one was a justification filed as an exclusion, and one was a no-op instruction the agent already obeys. The surviving boundary is the one the agent cannot derive -- that summarising a change set is not authoring the records.

## Decisions pending

None.

## Findings

- **`make apply` is live; the ADR reads as if it is not.** `diff_packaging.md` lists `*Remove \`make apply\` (fold into \`draft\`)*` under **Rejected alternatives**, and the agent read the rejection as the removal. `scripts/workflows/apply.sh:130` and `scripts/templates/Makefile.template:373` both carry the target; it is recovery-only and takes an arbitrary diff path. Corrected by the operator during the review, and the recovery clause moved into the `make draft` hint for that reason.
- **An unquoted `${#VAR}` breaks the lib-contract gate's brace counter.** The counter stops at `#`, so `(( ${#SUMMARY} < 3 ))` opens a brace it never closes, and every later line reads as function body -- four spurious rule 3.1 findings across the file. The expansion is quoted. The gate has no case for this; it is a trap for any length comparison in a sourced library.
- **The route hint had no test seam.** The summary block sat inside `draft_run`, which the fixture harness does not exercise, so the routing could not be pinned without running the whole workflow. It is now `draft_print_confirm_hint`, a function the suite calls directly.
