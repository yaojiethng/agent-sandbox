---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Documentation
status: Closed
---

# Handover - Two shipped reference documents name whose tree they describe

## Objective

Classify each of the two shipped reference documents that describe this repository's tree, so a session in another project reads the mechanism rather than another project's folders.

## Scope

The roadmap row **Two shipped reference documents describe this project**, which closes M3.3.4.

Both documents ship, because the image mounts `docs/reference/`. Both name folders and files that exist only in a project's own tree. The row's two options were to move the project-scoped content or to name it as this project's, and it ends either way.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Each document is classified | `grep -n "describes this repository's tree" docs/reference/documentation_taxonomy.md` and `grep -n "names this repository's own tree" docs/reference/agent_workflow.md` each print one line | Agent [x] |
| The classification names the actual subjects, not a category | `grep -o "docs/development/[a-z_]*\.md\|devlog/[A-Za-z_]*\.md" docs/reference/agent_workflow.md \| sort -u` prints the four paths the classification covers | Agent [x] |
| Neither document claims reach for a folder it does not have | `bash scripts/check_reach.sh` prints `reach: clean across 5 mount point(s) and 4 folder(s)` | Agent [x] |
| Every gate passes | `bash scripts/lint.sh` prints `Lint: clean` | Agent [x] |
| The suite is unchanged | `bash scripts/run_tests.sh` prints `1284 passed, 0 failed` | Agent [x] |

## Decisions

Neither document moved. A move costs the two mounted copies and every citation that names them, and it buys nothing: the mechanism text and this repository's examples are read by the same reader, in the same session, and a document that states which parts are its own is usable in both places already. The statement is a paragraph against a move's diff.

The taxonomy needed a second statement, not a replacement. `## Reach` already said reach belongs to a root and no document declares its own; `## Folder taxonomy` was still listing five folders as though every tree held them. The two sections now say the same thing from two directions, which is what a reader arriving at either one needs.

`agent_workflow.md` is mechanism and its map names four project-scoped files. The classification names them by path rather than by folder, because the four are a smaller and truer set than `docs/development/` and `devlog/` taken whole: those two folders hold the mechanism's records too, and a reader told the whole folder is theirs would look for `AGENT_FEEDBACK.md` in the wrong tree.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `documentation_taxonomy.md` listed five folders with no statement of whose tree they are, so a mounted project read another project's folder names as its own | defect | `## Folder taxonomy` now names the two mounted folders and the three that belong to the reader's project | fixed in this unit |
| `agent_workflow.md`'s map names four project-scoped paths, and the row was written as though the whole document were in question | result | the classification is per subject rather than per document, which is what the reach axis makes possible | fixed in this unit |
| The reach gate cannot see this statement, because it reads only `## Reach` | gap | a later edit that names a new project-only path in the map passes lint. The row that would close it is a check over every shipped document's project path references, which the two shipped documents would satisfy and a third would not | recorded here; no row filed |
| M3.3.4's rows are closed and the milestone close is held by operator direction | process | the close is `/milestone-close`'s, and it does not open on this record | operator decision, stated in the same turn as the scope |

## Completed

| File | Change |
|---|---|
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | `## Folder taxonomy` states which folders the image mounts and which are the reader's own |
| [`docs/reference/agent_workflow.md`](../../docs/reference/agent_workflow.md) | the policy map's introduction names its four project-scoped subjects |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed as the last of M3.3.4 |
