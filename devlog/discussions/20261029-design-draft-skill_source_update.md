---
date: 2026-10-29
type: Design
status: active
---

# Design - The source update merge model

**Status:** active

## Context

The skill tree holds local forks that are edited in place and shipped from the tree. The source catalog records a source revision and local file hashes, and each adapted skill carries a maintenance record. That shape makes a local edit look like drift from a stored state, and it has no place for a flat prompt or a runbook nested under another skill.

The local file is the version that ships, the version a reader opens, and the version the maintainer edits. A patch is not stored and a build step does not produce the skill. The source pin exists to find the original, to show what changed, and to give a merging agent the upstream range it needs.

The question this record answers is what must be stored to re-adapt a fork when upstream changes, and what the merging agent needs when the change is discretionary rather than a mechanical diff.

## Terms

| Term | Meaning |
|---|---|
| `upstream` | The repository a local artifact was forked from. |
| `origin` | The upstream revision the artifact was first forked from. It is a reference, not the merge base. |
| `base` | The upstream revision the next diff and merge treat as the common ancestor. It moves after each upstream review. |
| `local` | The current file in this repository. It is authoritative and is edited directly. |
| `L` | The local file after forking at `origin`, before any upstream merge. |
| `L'` | The local file after merging upstream `B`. It is `L` plus what came from `B`. |
| `L''` | The local file after merging upstream `C`. |
| `diff` | The generated comparison `base -> local`. It is not stored. |
| `three-way merge` | A merge with three inputs: `base`, `ours` (the local file), and `theirs` (the new upstream file). |
| `design doc` | The human record of intent, rejected options, cross-links and known conflicts. It is not a lock. |

The model is per local artifact. A skill directory is one artifact; a runbook is its own artifact with a parent; a prompt is its own flat artifact. Two artifacts from one source can have different bases, as `writing-for-agents` already does.

## The merge model

A fork starts at an upstream revision.

```text
upstream:  A ---------> B ---------> C

local:     A
            \
             L          (your changes on top of A)
```

At the fork, `origin` and `base` are both `A`. The diff `A -> L` is the local change.

To merge `B`, the three inputs are `base` `A`, `ours` `L`, and `theirs` `B`.

```text
          B            (theirs, new upstream)
         /
A ------
         \
          L            (ours, current local)

base = A
merge(base A, ours L, theirs B) -> L'
```

The result is `L'`. It carries the `B` changes plus the local changes. The base then moves to `B`.

```text
A ---------> B ---------> C
              \
               L'        (B plus your changes)

origin = A
base   = B
diff   = B -> L'         (local changes only)
```

The diff is now recomputed against `B`. The upstream changes from `A` to `B` are common history and are not part of the local diff.

Leaving the base at `A` is the failure this model prevents.

```text
A ---------> B ---------> C
 \            \
  \            L'        (contains B, but base is still A)
   base A
```

The diff `A -> L'` now includes the upstream changes from `A` to `B` as if they were local edits. A later merge with `C` sees those `B` changes on the local side, not in the common ancestor. They can be replayed or conflict a second time. The fix is to move the base to the revision that was reviewed.

The next merge uses `base` `B`, `ours` `L'`, and `theirs` `C`.

```text
A ---------> B ---------> C
              \            \
               L'           L''    (C plus your changes)

base = B
merge(base B, ours L', theirs C) -> L''
base = C after the merge
```

A rejected upstream change is recorded by the local file, not by a separate rejection list.

```text
base = B
local L' = B with one B change reverted
diff(B, L') shows the revert as a local change
next merge with C: B is common, the revert is ours
```

The next merge does not offer the rejected `B` change again unless `C` changes the same area. If `C` does change it, the conflict is the correct place to decide again.

## Options Considered

### Store a patch queue

A patch series would make the adaptation explicit and replayable. It also makes the patch a second source of truth, forces a build from upstream plus patches, and breaks the rule that the local file is the editable, shipped version. It is rejected for this repository because the local file is the artifact, not a build output.

### Install upstream as the shipped package

Pi can install a git package pinned to a commit, and resource filters can load none of its skills. A package can therefore be a source cache. It cannot be the shipped copy once the local skill has agent-sandbox cross-links, provider mechanics removed, or prose changes that upstream does not have. The local fork remains the artifact.

### Store the base, generate the diff, and keep a design doc

This keeps the local file authoritative, stores only the source reference and the merge base, and derives the diff on demand. The design doc gives the merging agent the intent that the diff cannot carry. This is the recommended model.

## Decision

| # | Decision | Rationale |
|---|---|---|
| D1 | The local file is authoritative and is edited in place. | It is the file that ships and loads; a patch build would make it derived. |
| D2 | Store `origin` for reference and `base` for the merge. `base` moves to the reviewed upstream revision after each upstream merge. | The original fork point is not the common ancestor after the first upstream update. |
| D3 | Generate the diff `base -> local`. Never store the patch. | The diff is derivable from the two trees; storing it makes a second source of truth. |
| D4 | Merge with `base`, `ours` local, and `theirs` new upstream. | A two-way patch application cannot resolve discretionary changes. |
| D5 | Keep one design doc for the intent, rejected options, cross-links and known conflicts. | The diff says what changed; the design doc says why and what must survive. |
| D6 | Do not store local hashes. Recompute them from the tree. | A local hash is derived data and goes stale on every edit. |
| D7 | Add a `source-bump` procedure and CLI that use this model. Do not reuse `/rebase` literally. | `/rebase` replays branch commits and handovers; this merge replays a local artifact against an upstream range. Its intent-first rule is the part to carry. |
| D8 | The tracking file is written only by the `source-bump` CLI. The merge agent writes the local artifact and the design doc. | Deterministic state should not be transcribed by an agent, and the CLI can validate every write. |
| D9 | The CLI prepares the merge inputs and records the result. It does not resolve conflicts. | The merge is a discretionary judgement; the CLI owns the facts around it. |
| D10 | The store is one JSON file per source at `.agents/registry/sources/<source-id>.json`; it holds source facts and artifact edges, no hashes, patch or prose, and `origin` and `base` are per edge. | One source can be worked independently, and one source can feed artifacts at different bases. |
| D11 | A bump runs only when the operator directs it, and the store stays pinned by default. `source-bump check` is a validation command, not a lint gate. | This matches `pi-bump`; the upstream review is discretionary, and an automatic gate would turn a pin into a drift alarm. |

## The tracking store

The store is one JSON file per source at `.agents/registry/sources/<source-id>.json`. The filename is the source id. A source file is independent, so a fan-out can work one source without touching another; the one-file-per-source shape costs nothing today and leaves that fan-out open.

A source file holds the source facts and the artifact edges. The source facts are `schema`, `id`, `url`, `license` and `copyright`. An empty source carries `artifacts: []` and a `reason`; it carries no status field. An artifact edge carries `local_path`, `kind`, `parent`, `upstream_path`, `origin` and `base`. A skill and a runbook are directories with a `SKILL.md`; a prompt is a file; a runbook names its parent.

The store holds upstream-derived artifacts with a known revision. A home-grown artifact has no upstream edge, so it is absent. The base is per artifact because one source can feed artifacts at different revisions; `writing-for-agents` already sits at a different revision from its siblings.

The live store now holds the three sources and five edges. The source catalog is retired; the five forked records name the store and the shipped `NOTICE`. The exact schema, path rules and command behavior are in [`source_tracking.md`](../../docs/development/source_tracking.md).

This unit implements `add`, `record` and `check`. `diff` and `prepare` are planned; the CLI does not fetch and does not merge. `check` is a validation command, not a lint gate: a bump runs only when the operator directs it, and the store stays pinned by default.

## The CLI and the agent

The CLI and the agent have different writers and different failures.

| Actor | Owns | Does not own |
|---|---|---|
| `source-bump` CLI | the tracking file, source and base facts, artifact paths, license, validation, merge workspace preparation, generated diff | conflict resolution, local prose, design rationale |
| merge agent | the local artifact, conflict resolution, the design doc's rationale and update notes | the tracking file |
| operator | scope, license and attribution decisions, acceptance | routine record writes |

The tracking file is not the design doc. The tracking file holds only the source, base, path, kind, parent and license facts. The design doc holds the intent, rejected options, cross-links and known conflict areas. Putting the design prose in the tracking file would repeat the structured and unstructured mixing this model is meant to remove.

A manual edit to the tracking file is a defect even when it parses. The CLI's `check` validates the same facts, and the write path is atomic so a failed update leaves the old file in place.

| Command | Effect | Writes the tracking file |
|---|---|---|
| `source-bump add` | Create a source, create an empty source, or add a source edge for a local artifact. | yes |
| `source-bump diff` | Print `base -> local` for review. Planned; not implemented. | no |
| `source-bump prepare` | Resolve the stored base and the new revision, and create a temporary merge workspace with the three inputs. Planned; not implemented. | no |
| `source-bump record` | After the merge, set `base` to the new revision, validate, and write. | yes |
| `source-bump check` | Validate paths, sources, bases, kinds, parents and source facts. | no |

`add` takes the source facts only when it creates the source. An existing source refuses a changed `url`, `license` or `copyright`; changing source facts is a separate decision. `add --empty` creates an empty source and requires its reason. The `record` command moves only `base`; it does not change `origin` or the source facts.

The CLI does not fetch by default. `prepare` takes a local upstream clone or a git URL with an explicit network permission. That keeps `check` deterministic and offline; it is a validation command, not a lint gate. A bump runs only when the operator directs it, and the store stays pinned by default.

## How the future source-bump skill uses this

The procedure is the subject of the open roadmap row [the source bump is a pattern](../roadmap.md). The pattern is planned at `skill-scaffolder/patterns/source-bump.md`, beside the existing [fork-and-strip pattern](../../.agents/skills/skill-scaffolder/patterns/fork-and-strip.md). This record is the reference for the merge model; the pattern owns the steps and the CLI owns the tracking file.

| # | Step | Output |
|---|---|---|
| 1 | Read the local artifact and its design doc. | The intent and the known conflict areas. |
| 2 | Run `source-bump prepare` for the stored base and the new upstream revision. | A merge workspace with `base`, `ours` and `theirs`, or the upstream range. |
| 3 | Run `source-bump diff` or inspect the workspace. | The local change, for review and for the merge. |
| 4 | Three-way merge `base`, `ours` local, `theirs` new upstream. | A merged local file, with conflicts where both sides changed the same area. |
| 5 | Resolve conflicts by the design doc's intent, not by accepting one side wholesale. | The re-adapted local file. |
| 6 | Run the repository gates and the artifact's own checks. | A green local artifact. |
| 7 | Run `source-bump record` with the new base, and update the design doc with what was rejected or changed. | The next merge's common ancestor and context. |
| 8 | Commit the local artifact, the tracking file and the design doc. | No patch file and no generated skill. |

A source cache is needed for steps 2 and 3. A git clone or a filtered git package gives the commit range; a tarball does not. The package is a reference cache, not the shipped skill.

## Consequences

The durable record per artifact is small: local path, kind, parent for a runbook, source URL, upstream path, `origin`, `base`, and the source license. The design doc is the only human-maintained prose. The patch, local hashes, upstream hashes, source tree and per-file hash table are all derived or fetched. The CLI is the only writer of the tracking file; the agent is the only writer of the local artifact and the design doc.

A round-trip check can regenerate `base -> local`, apply it to `base`, and compare the result with the local file. That proves the diff is derivable and the pair is coherent. It does not prove the base is the latest reviewed revision. The `source-bump record` command owns that move, and a stale base is a review failure rather than a gate failure.

The license and copyright ship with the forks in `NOTICE` at the agent skills root. The store is repository-only, so the notice is the image's copy; the design doc is not a substitute for attribution.

## Settled and open

The design settles these.

- **Scope.** The subject is upstream-derived artifacts with a known revision. A home-grown artifact is absent; an empty source carries a reason. The migration applies the scope to the live tree.
- **Base granularity.** One base per artifact. A partial file update is represented as a local diff against that base, with the design doc naming the rejected change.
- **Tracking file shape.** One JSON file per source at `.agents/registry/sources/<source-id>.json`, no hashes, patch or prose; the CLI is the only writer. The exact schema is in [`source_tracking.md`](../../docs/development/source_tracking.md).
- **Gate strictness.** `source-bump check` is a validation command, not a lint gate. A bump runs only when the operator directs it, and the store stays pinned by default.
- **Attribution.** Settled: `src/reasoning/agent/skills/NOTICE` lists the source URL, license and copyright and ships under the existing skills `COPY`.

These questions remain open.

- **Source cache.** A pinned git clone, a filtered pi package, or network-only access to the commit. The clone is the only option that gives `git range-diff` without extra work.
- **Design doc shape.** One document per source or one per artifact, with prose only. It is not the tracking file.
