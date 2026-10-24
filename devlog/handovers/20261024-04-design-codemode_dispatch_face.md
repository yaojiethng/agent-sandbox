---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Design
status: Closed
---

# Handover - The library's second face, answered no, and what the answer costs

## Objective

Answer the row's own question -- whether a caller inside pi can reach the dispatch library through codemode without a process boundary -- close the row on that answer, and carry what the answer says about an in-process face to the unit that will decide it.

## Scope

The measurement, the roadmap row, this record, and one addition to the scheduler row under `M3.6.6`. No artifact is built: the row was filed as a question, the answer is no, and the face it named cannot exist in this runtime.

## What the sandbox is

Measured in this session's codemode, which is QuickJS with a curated global set. Nothing in it reaches the host:

```text
typeof process: undefined      typeof require: undefined
typeof module: undefined       typeof importScripts: undefined
typeof fetch: undefined
import('node:fs')  ->  threw: could not load module 'node:fs'
require('node:fs') ->  threw: require is not defined
```

The globals are the language's own plus the harness's: `tools`, `text`, `image`, `store`, `load`, `models`, `searchTools`, `describeTool`, `exit`, `console`. No filesystem, no process, and no loader that can name a path.

So "codemode imports a repository module" is answered **no**, and not by preference: there is nothing to resolve a path against. The row's second question follows from the same measurement -- a seat run needs a worktree cut and a process spawned, and the sandbox has neither.

## What the second face would have been

The door already has one mechanism for reaching pi's process: a registered tool. The `task-queue` extension registers five, and they are this session's `taskq_*` tools, callable from codemode as `tools.taskq_status()`. A dispatch face would have taken that shape and imported the library in-process.

Three measurements decide what it would cost, and they are carried to the scheduler row under `M3.6.6` rather than lost with this row:

| Fact | Evidence |
|---|---|
| the library is already shipped where an extension can import it | `/opt/sandbox/lib/dispatch/` holds `classify.ts`, `cli.ts`, `launch.ts`, `machine.ts` and `seats.ts` |
| the extension is a copy in the image, not a mount | the installed `task-queue` is identical to the repository's copy and is not a separate mount |
| so a new extension needs a rebuild | the rebuild is blocked in this deployment, which is why handover `20261023-22` could prove a skill's content and not its loading |

What such a face buys is one process spawn and one JSON round trip per decision, against a subagent run that takes seconds to minutes. It changes no decision the library makes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row's first question is answered by measurement | the probe above, run in this session's codemode, and quoted in the record | Agent [x] Operator [ ] |
| The second question is answered as far as this deployment allows | the record states what a seat run needs -- a worktree and a process -- and that the sandbox has neither | Agent [x] Operator [ ] |
| The row's fate is recorded, and what survives it is routed | `grep -c "^- \[x\] \*\*The library is reachable from codemode\*\*" devlog/roadmap.md` prints 1, and `grep -c "the dispatch library is already where an extension can import it" devlog/roadmap.md` prints 1, on the scheduler row under `M3.6.6` | Agent [x] Operator [ ] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The row closes on the measurement rather than on an artifact | the mechanism it named cannot exist -- the sandbox has no filesystem, no process and no module loader -- so there is nothing to build where the row pointed | the roadmap row; this record's probe |
| D2 | The tool-face measurements are carried to the scheduler row under `M3.6.6` rather than dropped with the row | that unit already names "whether it is a harness tool" as an unknown, and these three facts answer part of it | the scheduler row's own text; this record |
| D3 | No dispatcher tool is built here | it buys one process and one JSON hop per decision, its loading cannot be proven until the image is rebuilt, and a face that subsists on its own measurements belongs to the unit that owns the boundary | this record; the scheduler row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| the codemode sandbox has no filesystem, no process and no resolvable path for an import | measurement | the row's stated mechanism cannot exist in this runtime, and a caller inside pi must shell out to the entrypoint or use a tool | the roadmap row, closed; the scheduler row under `M3.6.6` |
| the tool namespace is the one in-process door, and `taskq_*` is already one | measurement | an in-process dispatch face is a known shape with a shipped library behind it, not a new mechanism | the scheduler row under `M3.6.6` |
| extensions ship as an image copy, so a new one needs a rebuild and its loading cannot be proven here | measurement | a build today would prove a tool's body and tests, not that pi loads it | the scheduler row under `M3.6.6` |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the codemode row closed on the measured answer, and the three tool-face measurements added to the scheduler row under `M3.6.6` |
| this record | the probe, the answer to both questions, and the three measurements the scheduler unit needs |
