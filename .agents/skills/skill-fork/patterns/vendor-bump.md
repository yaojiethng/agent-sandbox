# Bump a vendored fork to a new upstream revision

Open this when the operator directs a bump. The move is to bring one artifact forward to a reviewed upstream revision without losing what the fork changed, then move the stored base so the next review starts from where this one ended.

## The boundary

This pattern is one carrier. An artifact a session loads from an installed package has no local copy and no merge; that bump is [`package-bump.md`](package-bump.md). One name has one route, so a name an installed package provides cannot also be vendored until the package excludes it.

A bump runs only when the operator directs it. The store is pinned by default; a new upstream commit is not a reason to bump.

The unit is one artifact edge, not the source. A source with two artifacts bumps one; the other keeps its base. The local file is the artifact: do not store a patch, generate a skill, or apply a two-way patch.

An artifact with no edge is one nobody bumps. Stop; there is nothing to bump. An edge exists because someone made it, and [`fork-and-strip.md`](fork-and-strip.md) is where they make it.

## Register an edge

A bump needs an edge, and the facts an edge holds are known when the artifact is vendored and nowhere later. The store is a directory of files, one per source, at `.agents/registry/sources/<source-id>.json`; an artifact is an edge in one of them.

```json
{
  "local_path": "src/reasoning/agent/skills/<skill>",
  "kind": "skill",
  "parent": null,
  "upstream_path": "skills/<group>/<skill>",
  "origin": "<40-character commit the fork was taken from>",
  "base": "<the same commit, until the first bump>",
  "record": {
    "kept": "what the fork kept",
    "rewritten": "what it changed, and why",
    "added": "what the local copy adds",
    "dropped": "what it leaves out"
  }
}
```

| Field | Holds |
|---|---|
| `local_path` | the local artifact: a directory for a skill or a runbook, a file for a prompt or an instruction |
| `kind` | `skill`, `runbook`, `prompt` or `instruction` |
| `parent` | the parent skill's path for a runbook, and `null` otherwise |
| `upstream_path` | the artifact's path in the upstream tree |
| `origin`, `base` | the revision the fork was taken from, and the revision the next merge starts from; the same commit until the first bump |
| `anchor` | a verbatim line of `local_path`, when the edge covers a passage rather than the whole file |
| `record` | the adaptation note: `name`, `source`, `kept`, `rewritten`, `added`, `dropped`, each one of them optional |

A source file adds `schema`, `id`, `url`, `license` and `copyright` above `artifacts`, and `reason` instead of `artifacts` when it holds no edge. Write the file by hand, then run `format` and `check`.

One artifact may carry several edges, one per source: a skill built from three upstream skills has three contributions to describe. Two edges in one source must not share a `local_path` and an `anchor`.

## Commands

| Command | Run from this repository |
|---|---|
| `source-bump check` | `node scripts/source_bump.mjs check` |
| `source-bump format` | `node scripts/source_bump.mjs format` |
| `source-bump diff` | `node scripts/source_bump.mjs diff --source <id> --local <path> --clone <clone>` |
| `source-bump prepare` | `node scripts/source_bump.mjs prepare --source <id> --local <path> --clone <clone> --revision <new>` |

The command names are the CLI's; the invocation adds the repository's script path. The store is written by hand and validated by `scripts/check_skill_sources.sh`, which runs on every commit; `check` prints the same findings and `format` writes the canonical form.

## Read first

| File | Why |
|---|---|
| The source file at `.agents/registry/sources/<source-id>.json` | The source facts, the edge, `origin` and `base`. |
| [`source_tracking.md`](../../../../docs/development/source_tracking.md) | The schema and the CLI contract. |
| [`20261029` design record](../../../../devlog/discussions/20261029-design-draft-skill_source_update.md) | The merge model and the intent that the diff cannot carry. |
| The edge's `record` | What the fork kept, rewrote, added and dropped, and why. |
| [`fork-and-strip.md`](fork-and-strip.md) | The creation counterpart; a bump re-adapts an existing fork. |

The store carries no design-doc path. Take the intent from the edge's `record` and the bump design record; when the record is silent and neither states why the fork exists, stop and ask the operator. Do not invent a design doc.

## Inputs

- The source id.
- The local artifact path.
- The new upstream revision, as a full 40-character commit.
- A local upstream clone. The CLI does not fetch.
- The operator's decision to take that revision.

If an input is missing, stop and ask. Do not infer a revision, a source id, or a local path.

## Procedure

1. **Find the edge.** Run `node scripts/source_bump.mjs check`, then open the source file and find the edge whose `local_path` is the artifact. If the edge is absent, stop. Done when the store is clean and the edge names `upstream_path`, `origin` and `base`.

2. **Read the intent.** Read the local artifact, the design record and the edge's `record`. Done when you can state what the fork added, rewrote and dropped, and which areas are likely to conflict.

3. **Review the local change.** Run `node scripts/source_bump.mjs diff --source <id> --local <path> --clone <clone>`. Read the `base -> local` diff. Done when every hunk is either an intended adaptation or understood as incidental.

4. **Prepare the three inputs.** Run `node scripts/source_bump.mjs prepare --source <id> --local <path> --clone <clone> --revision <new>`. The command verifies both commits and both paths, then prints `base`, `ours` and `theirs`; if it refuses, stop. Done when all three trees exist and the local artifact is still untouched.

5. **Merge each path.** For a skill or runbook, take the union of the paths in `base`, `ours` and `theirs`, and write each result to `<local>/<path>`. For a prompt or an instruction, the path is `basename(<local>)` and the destination is `<local>`; when the edge carries an `anchor`, the merge is confined to that passage and the rest of the file is left alone. When a path is present in all three trees, run `git merge-file -p <ws>/ours/<path> <ws>/base/<path> <ws>/theirs/<path> > <destination>`. A path only in `theirs` is added; a path only in `ours` stays; a path only in `base` is already absent locally. A path in `base` and `ours` but not `theirs` is deleted unless the local change must survive; a path in `base` and `theirs` but not `ours` stays deleted unless the upstream change conflicts with the deletion, in which case decide it by the intent. A path in `ours` and `theirs` but not `base` is a both-added file: keep the local content, review the upstream addition, and decide it by the intent; `git merge-file` has no base file for it. A conflict leaves markers and `git merge-file` exits 1. Done when every path is accounted for and no markers remain.

6. **Resolve by the intent.** Decide each conflict by what the fork means, not by accepting one side wholesale. Done when the local artifact reads as the re-adapted fork and the edge's `record` can name what was kept, changed or rejected.

7. **Verify.** Run `bash scripts/lint.sh` and `bash scripts/run_tests.sh`, then the artifact's own checks. Rewrite the edge's `record` if the adaptation changed, and update the design doc with what the merge changed. Done when the local artifact and its records are green.

8. **Move the base.** Set the edge's `base` to the new revision in its source file, leaving `origin` and every other edge alone, then run `node scripts/source_bump.mjs format` and `node scripts/source_bump.mjs check`. Done when the edge's base is the new revision, its origin is unchanged, no other edge moved, and the check is clean.

9. **Commit the bump.** Commit the local artifact, the source file and the design record. Use a `workflow:` subject that names the artifact and the short revision; the body states the source and the revision range. Done when the tree is clean and the commit holds the local artifact and the store, with no patch file and no generated skill.

## The three inputs

`base` is the stored upstream revision, `ours` is a copy of the local artifact, and `theirs` is the new upstream revision. The workspace is temporary. The local artifact stays the only editable copy; write the merged result there. Remove the workspace after the merge; it is not committed.

A file deleted upstream is a deletion only when the local side did not change it. A local change to a file upstream deleted is a conflict; decide it by the intent. A file the fork added is local-only and stays.

## The store

The source facts are immutable during a bump. A changed URL, license or copyright is a separate operator decision, and nothing derives it, so review is what catches one. The `origin` stays at the first fork; `base` moves only after the merge is green.

The shipped attribution is [`NOTICE`](../../../../src/reasoning/agent/skills/NOTICE). The store is repository-only and does not ship. A license change updates the notice only after the operator decides it.

## Failure stops

- The operator did not direct the bump.
- The artifact has no source edge, or its source is empty.
- The clone has no base or no new revision, or the upstream path is absent at either.
- The store is not clean.
- The merge changes a source fact.
- The local artifact cannot be made green without an operator decision.

Stop on any of these and report the condition. Do not move `base` to make the store look current.

## The test

Name the edge, the revision range and what the merge kept. If any is missing, the artifact was not bumped, it was overwritten.
