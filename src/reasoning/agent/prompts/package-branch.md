---
description: Export this branch's committed work as a bundle the operator applies to the host worktree. The bundle takes the form of a directory holding numbered per-commit diffs with a sibling commit message each, an uncommitted diff, an all-changes diff, the changed files, and the branch point the export was taken at. Use when the agent has committed work to export ("package my branch", "export my commits", "prepare a commit series for review"), when the operator asks for a full re-export of the iteration's committed work, or after a history rewrite -- rebase, fold, amend. Packaging does not affect iteration status; do not edit any iteration file while packaging.
trigger: /package-branch
---
> $@

# Package the branch for export

**Scope:** Exports the branch and prints the operator reply. It does not author the iteration records, and it does not run the host review workflow.

Export the commits that differ from the branch point, so the operator can review the series and apply it to the host branch. This prompt covers both a linear history and a rewritten one: the branch point is computed the same way in each case, and the script reports the difference. Run it when the iteration rewrote history with a rebase, a fold, or an amend, as well as on an ordinary branch. This task is independent of iteration open housekeeping -- do not read the handover or roadmap first. Run the script, relay its output, then print the draft.

## Purpose

The operator reviews work as a commit series and applies it on the host, not as a patch of a tree. This prompt produces that series. What leaves the container is a set of artefacts; what reaches the operator is a bundle path, the branch point, and a short account of the change.

## When to use

Run this prompt when the iteration has committed work to export, or when the operator asks for an export.

- **Not uncommitted work.** `uncommitted.diff` ships inside the bundle for completeness; the reviewable unit is the commit series.
- **Not a single file or a partial range.** The export covers every commit since the branch point. `--baseline` narrows it only when the host has moved past the recorded `init_sha`.

## Step 1 -- Choose the summary and draft the reply

`--bundle-summary` names the bundle directory and, through `BRANCH_SUMMARY`, the draft branch `draft/<session>-<summary>-<hash>`. Git refuses a ref holding a space or a colon, so the shape is enforced: **3 to 48 characters, lowercase snake_case**, matched by `^[a-z0-9]+(_[a-z0-9]+)*$`. A prose phrase is rejected at the script.

Derive the summary from the commit subjects since the branch point. Never reuse a previous export's summary.

| Good | Bad |
|---|---|
| `merge_package_prompts` | `Rebased plan series: M3.1 split` -- spaces, capitals, punctuation |
| `enforce_summary_slug` | `changes`, `misc`, `snapshot` -- too vague to name a change set |

State the proposed summary, then draft the three fields of Step 3. Draft them now while the commits are in view; the script does not read them and Step 3 only prints them.

## Step 2 -- Run the script and relay its output

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --bundle-summary=<summary>
```

The script resolves the branch point itself as `git merge-base <init_sha> HEAD` from `~/sandbox/.git/SESSION_STATE`. Without a rebase that equals `init_sha`; after one it is the branch point, which is the commit the host still holds. Pass `--baseline=<sha>` only when the host has diverged from the recorded `init_sha`, for example when the operator advanced the host branch mid-session.

**Echo the script's output block verbatim.** Do not summarise it, do not re-derive the branch point, do not rewrite the command, and do not add a command of your own. Every value in it was computed by the script from the repository; a paraphrase can carry a wrong branch point to the operator. When the block reports that the branch point moved, repeat that fact in Step 3 in one sentence.

**To diff against an explicit baseline:**

```bash
bash /opt/sandbox/lib/package_branch.sh --to=$HOME/workspace/output --baseline=<sha> --bundle-summary=<summary>
```

On the host, invoke via `agent-sandbox package-branch --sandbox=<path> [--bundle-summary=<slug>] [--baseline=<sha>]`, or `make package-branch [BUNDLE_SUMMARY=<slug>] [BASELINE=<sha>]`. In a `make draft` invocation the branch point is `BRANCH_FROM=<sha>`, never `--branch-from=<sha>`.

The script produces one numbered `.diff` per commit since the branch point, with the subject embedded in the filename, a sibling `.msg` carrying the full commit message, and the three supporting artefacts:

```text
<to>/bundles/<EXPORT_TIME>-<BUNDLE_SUMMARY>-<SESSION_ID>/
  patches/
    0001-<sha>-<subject>.diff     --  per-commit diff (index lines stripped)
    0001-<sha>-<subject>.msg      --  full original commit message
    ...
  uncommitted.diff
  all-changes.diff
  changed-files/
    MANIFEST.txt
  .branch-point
```

The `.msg` files are consumed by `make draft` to recreate commits with their original messages. Each `.diff` is a unified diff with index lines stripped, suitable for sequential `git apply`. The numbered order runs from the branch point to `HEAD`. `.branch-point` records `BUNDLE`, `BRANCH_POINT`, `BASELINE_MOVED`, and `RECORDED_INIT_SHA`, so a host tool reads the facts without parsing this conversation.

`changed-files/MANIFEST.txt` is the changed-file list. There is no separate changed-files section in the reply; the manifest is authoritative and retyping it invites drift.

## Step 3 -- Print the reply

Print the script's output block first, then the three fields drafted in Step 1. Keep them short.

- **What changed and why.** The problem the change set solves and how it solves it. Motivation, not a file list. One sentence for any large deletion.
- **API breaking changes.** Changes to signatures, environment variables, file paths, or flags that a caller must update. Write `None.` when there are none.
- **Verification.** Only when a check exists that only the operator can run -- a `make dry-run` on a capability change, a manual install, anything needing a real host checkout. Name the exact target and what a pass looks like. The container's own suite and gates are already evidenced at the close; restating them tells the operator nothing they cannot run. Write `None.` when no host-only check exists.

When the branch point moved, one sentence names the movement and its consequence:

> The branch point moved from `init_sha` to `<sha>`, so this series replaces history on the host rather than extending it.

The operator directions for drafting, reviewing, confirming, and recovering are not printed here. `package_branch.sh`, `make draft`, and `make confirm` each print the next hop at the moment it is taken. Repeating them in this prompt would be a second copy that goes stale. The sequence across the three, and why each step prints its own, is decided in the `diff_packaging` ADR; a prompt names it in plain text because a prompt runs in the container, where the ADR tree is not seeded.
