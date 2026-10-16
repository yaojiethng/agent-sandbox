---
name: session-memory
description: Session-scoped memory that survives a pi /fork or /tree and is dropped at the session's end. Steering is its content. Use when a directive applies across the session's tasks, or when a returning traversal must read what it already carries.
---

# session-memory

Memory scoped to the session. It survives a divergence and dies with the session, so nothing here is durable.

## What it carries

Steering, mostly. A steering entry is a directive that applies beyond the node in hand and would change what a future task does. A filing rule, a constraint, a preference. One entry per occurrence.

The memory has two grains, one per file. The log records occurrences and is never edited. The view holds one line per directive.

## The tool

`session-memory.mjs` beside this skill, run with `node`. It owns the log, the view and the block.

| Command | Does |
|---|---|
| `note <text> [--home <path>] [--restates <n>]` | append an occurrence; a restatement takes `--restates` and adds no view line |
| `merge <lo> <hi> <text>` | compress a view range into one summary |
| `wake` | print the view |
| `render` | write the view into the block file under the heading |
| `zoom <lo>-<hi>` | print the log range |
| `forget <lo>-<hi>` | drop a summary and resurface the originals |
| `diff` | print the change since the mark |
| `mark` | set the mark |

Paths are the caller's.

| Flag | Means | Default |
|---|---|---|
| `--log <path>` | the append-only log | `<scratch>/SESSION_MEMORY_LOG.jsonl` |
| `--block <path>` | the file that carries the view block | none; `render` refuses without it |
| `--heading <text>` | the block's heading | `## Session memory` |

The scratch is the directory the project `AGENTS.md` Scope table declares.

## The bounds

The view is at most 16 lines by 240 characters, newest first. When `note` reports a merge due, merge the two ranges it names. A summary is a cache: drop a bad one with `forget` and it rebuilds from the log. The log is never pruned.

## The model

The shape is OptMem's, https://github.com/VictorTaelin/OptMem: an append-only log as storage, a bounded read, a merge on write, and a summary that is a rebuildable cache. This tool reimplements that shape for short-term memory, with the constants adjusted and the binary tree dropped, because the view is 16 lines rather than a million records.

## The read

A caller reads the view at a defined moment, not whenever. `pop-task` reports it on a return. A memory that is not read at the decision point is not a memory.

## Non-goals

- Durable memory. Nothing here outlives the session, so a durable directive goes to its own record and this holds a pointer.
- The tracker. This skill holds the memory; the tracker holds the traversal.
