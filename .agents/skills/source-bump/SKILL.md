---
name: source-bump
description: Bump a forked workflow artifact to a reviewed upstream revision. Use when the operator directs a source bump, asks to update a fork from upstream, asks to re-base a skill, runbook or prompt on a new upstream commit, or asks to review upstream changes against a local artifact.
---

# Source Bump

Updates one upstream-derived artifact to a reviewed upstream revision. The local artifact is authoritative; the tracking store records where it came from and which revision the next merge reviews. The CLI is the only writer of the store, and the merge is a discretionary judgement.

## The boundary

A bump runs only when the operator directs it. The store is pinned by default; a new upstream commit is not a reason to bump, and `source-bump check` is a validation command, not a lint gate.

The unit is one artifact edge, not the source. A source with two artifacts bumps one; the other keeps its base. The local file is the artifact: do not store a patch, generate a skill, or apply a two-way patch.

A home-grown artifact has no edge. Stop; there is nothing to bump.

## Commands

| Command | Run from this repository |
|---|---|
| `source-bump check` | `node scripts/source_bump.mjs check` |
| `source-bump diff` | `node scripts/source_bump.mjs diff --source <id> --local <path> --clone <clone>` |
| `source-bump prepare` | `node scripts/source_bump.mjs prepare --source <id> --local <path> --clone <clone> --revision <new>` |
| `source-bump record` | `node scripts/source_bump.mjs record --source <id> --local <path> --base <new>` |

The command names are the CLI's; the invocation adds the repository's script path. The CLI is the only writer of the store.

## Read first

| File | Why |
|---|---|
| The source file at `.agents/registry/sources/<source-id>.json` | The source facts, the edge, `origin` and `base`. |
| [`source_tracking.md`](../../../docs/development/source_tracking.md) | The schema and the CLI contract. |
| [`20261029` design record](../../../devlog/discussions/20261029-design-draft-skill_source_update.md) | The merge model and the intent that the diff cannot carry. |
| The local artifact; its `MAINTENANCE.md` for a skill, runbook or prompt | What the fork kept, rewrote, added and dropped, and why. |
| [`fork-and-strip.md`](../skill-scaffolder/patterns/fork-and-strip.md) | The creation counterpart; a bump re-adapts an existing fork. |

The store carries no design-doc path. Use the artifact's `MAINTENANCE.md` (a skill, runbook or prompt) and the source-bump design record as the intent; when a prompt has no record, ask the operator for its intent. If neither records why the fork exists, stop and ask the operator. Do not invent a design doc.

## Inputs

- The source id.
- The local artifact path.
- The new upstream revision, as a full 40-character commit.
- A local upstream clone. The CLI does not fetch.
- The operator's decision to take that revision.

If an input is missing, stop and ask. Do not infer a revision, a source id, or a local path.

## Procedure

1. **Find the edge.** Run `node scripts/source_bump.mjs check`, then open the source file and find the edge whose `local_path` is the artifact. If the edge is absent, stop. Done when the store is clean and the edge names `upstream_path`, `origin` and `base`.

2. **Read the intent.** Read the local artifact and the design record; for a skill, runbook or prompt, also its `MAINTENANCE.md`; when a prompt has none, ask the operator for the intent. Done when you can state what the fork added, rewrote and dropped, and which areas are likely to conflict.

3. **Review the local change.** Run `node scripts/source_bump.mjs diff --source <id> --local <path> --clone <clone>`. Read the `base -> local` diff. Done when every hunk is either an intended adaptation or understood as incidental.

4. **Prepare the three inputs.** Run `node scripts/source_bump.mjs prepare --source <id> --local <path> --clone <clone> --revision <new>`. The command verifies both commits and both paths, then prints `base`, `ours` and `theirs`; if it refuses, stop. Done when all three trees exist and the local artifact is still untouched.

5. **Merge each path.** For a skill or runbook, take the union of the paths in `base`, `ours` and `theirs`, and write each result to `<local>/<path>`. For a prompt, the path is `basename(<local>)` and the destination is `<local>`. When a path is present in all three trees, run `git merge-file -p <ws>/ours/<path> <ws>/base/<path> <ws>/theirs/<path> > <destination>`. A path only in `theirs` is added; a path only in `ours` stays; a path only in `base` is already absent locally. A path in `base` and `ours` but not `theirs` is deleted unless the local change must survive; a path in `base` and `theirs` but not `ours` stays deleted unless the upstream change conflicts with the deletion, in which case decide it by the intent. A path in `ours` and `theirs` but not `base` is a both-added file: keep the local content, review the upstream addition, and decide it by the intent; `git merge-file` has no base file for it. A conflict leaves markers and `git merge-file` exits 1. Done when every path is accounted for and no markers remain.

6. **Resolve by the intent.** Read the design record and, for a skill, runbook or prompt, the artifact's adaptation; when a prompt has none, use the operator's intent. Decide each conflict by what the fork means, not by accepting one side wholesale. Done when the local artifact reads as the re-adapted fork and the design doc can name what was kept, changed or rejected.

7. **Verify.** Run `bash scripts/lint.sh` and `bash scripts/run_tests.sh`, then the artifact's own checks. Update `MAINTENANCE.md` `## Adapted` if the adaptation changed, and update the design doc with what the merge changed. Done when the local artifact and its records are green.

8. **Move the base.** Run `node scripts/source_bump.mjs record --source <id> --local <path> --base <new>`, then `node scripts/source_bump.mjs check`. Done when the edge's base is the new revision, its origin is unchanged, and no other edge moved.

9. **Commit the bump.** Commit the local artifact, its maintenance and design records, and the source file. Use a `workflow:` subject that names the artifact and the short revision; the body states the source and the revision range. Done when the tree is clean and the commit holds the local artifact and the store, with no patch file and no generated skill.

## The three inputs

`base` is the stored upstream revision, `ours` is a copy of the local artifact, and `theirs` is the new upstream revision. The workspace is temporary. The local artifact stays the only editable copy; write the merged result there. Remove the workspace after the merge; it is not committed.

A file deleted upstream is a deletion only when the local side did not change it. A local change to a file upstream deleted is a conflict; decide it by the intent. A file the fork added is local-only and stays.

## The store

The source facts are immutable during a bump. A changed URL, license or copyright is a separate operator decision; the CLI refuses it. The `origin` stays at the first fork; `base` moves only after the merge is green. Do not edit the JSON by hand, even when the edit parses.

The shipped attribution is [`NOTICE`](../../../src/reasoning/agent/skills/NOTICE). The store is repository-only and does not ship. A license change updates the notice only after the operator decides it.

## Failure stops

- The operator did not direct the bump.
- The artifact has no source edge, or its source is empty.
- The clone has no base or no new revision, or the upstream path is absent at either.
- The store is not clean.
- The merge changes a source fact.
- The local artifact cannot be made green without an operator decision.

Stop on any of these and report the condition. Do not move `base` to make the store look current.
