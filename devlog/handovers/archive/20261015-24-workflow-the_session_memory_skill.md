---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - The session-memory skill

## Objective

Bundle the steering memory as a pi-provider skill, so its tool and its instructions are one module and its paths are the caller's. The stopgap first landed the tool at `scripts/steer.mjs` and the instructions inside `push-task`, which put one body of knowledge in two places.

## Scope

The skill directory, the tool, the test, and the removal of the two files they replace.

Out of scope: wiring the prompts to the skill, which is the next unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill bundles the tool | `SKILL.md` and `session-memory.mjs` in one directory | Accepted |
| The tool's cases pass | `bash tests/test_session_memory.sh`, 11 cases | Accepted |
| The caller defines the paths | `--log`, `--block`, `--heading`; the tracker is one caller | Accepted |
| The block write is contained | the `render` case asserts the rest of the file is untouched | Accepted |
| The skill frontmatter parses | `bash scripts/lint.sh`, the frontmatter gate | Accepted |
| The replaced files are gone | `scripts/steer.mjs` and `tests/test_steer.sh` removed | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The name is `session-memory` | the memory is scoped to the session and dropped at its end; steering is its content, not its scope | [`SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/session-memory/SKILL.md) |
| The caller names the log and the block | the tracker is one caller, not the tool's assumption, so a second caller can place the memory elsewhere | the tool; this record |
| A reimplementation of OptMem's shape, not a derivation of `memo` | the shape is four mechanisms and the tree is for a million records; the code is written from the README, so crediting it as a fork would overstate the provenance | the tool header; this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The block lives in the tracker, so the tracker has two writers. They are sequential, because `push-task` invokes the tool, and the tool replaces only the region under its heading. | design boundary | the tool; `push-task` |
| The block write is the one place the tool edits a file it does not own, so `render` refuses without `--block` rather than guessing a path. | safety | the tool |

## Completed

| File | Change |
|---|---|
| [`SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/session-memory/SKILL.md) | new: the contract, the bounds, the model |
| [`session-memory.mjs`](../../src/reasoning/providers/pi/config/agent/skills/session-memory/session-memory.mjs) | new: `note`, `merge`, `wake`, `render`, `zoom`, `forget`, `diff`, `mark` |
| [`tests/test_session_memory.sh`](../../tests/test_session_memory.sh) | new: 11 cases, including `render` |
| `scripts/steer.mjs`, `tests/test_steer.sh` | removed: replaced by the skill's files |
| `$AGENT_HOME/agent/skills/session-memory/` | the skill installed |
