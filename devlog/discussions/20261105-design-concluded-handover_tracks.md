# Handover tracks and the record read seam

**Status:** concluded

## Context

M3.3.3 closed, and the next milestones are scoped well enough to run in parallel. The record model is what blocks them: three serializers deny concurrency even though the git machinery (worktrees, `/merge`, the task queue) already supports it.

1. `active-milestone` is one scalar, so one milestone is allowed to move.
2. A handover's `NN` is a per-day global counter (`max + 1`), so two tracks on one day collide at merge.
3. The shared part of the roadmap -- frontmatter, summary table, changelog -- assumes one writer.

The record already disagrees with itself: the summary table lists several milestones `In progress` while the scalar names one. M3.5 names this as its premise.

This stopgap is pulled forward from T5 into M3.5.1, the work-log layer of M3.5. M3.5.2 is the task-list mechanism and M3.5.3 is the unified layer; M3.5.3's parallel-milestone rule and the T5 record-storage rewrite consume this work, so the stopgap is designed to be deleted.

### What is confirmed

1. **A folder is a milestone.** `devlog/handovers/<milestone>/` holds that milestone's records. Every record in a folder belongs to it. There is no separate track ledger for identity.
2. **The `NN` is an identity, not a position.** It stays globally unique because 1,142 bare references resolve by it (`scripts/lint/numbering.mjs` matches a basename and requires exactly one). It comes from a block reserved per track at opening, not from `max + 1` over the day.
3. **Order is git.** Delete "the record with the highest date and index is the latest." The latest is the tip on the track, or a git query. The merge replay is where parallel lines become one; that replay is the order.
4. **The shared roadmap part has one writer.** That writer is a role -- whoever is merging -- not a folder. If the merge work needs a record, it is an ordinary handover in the milestone being merged.
5. **`archive/` is frozen.** It is not a track. Nothing enters, no open roadmap row names a file there, and orientation never reads it. T5 deletes the exception later.
6. **The unit rule stays.** One iteration, one commit, one handover. It is reviewability and bisectability, not order. It is what makes a merged history legible.

### The smell family

The "procedures that read latest or the scalar" list is one instance of a broader class:

> **A skill or gate re-derives state that `work-log` owns, or restates the record layout that one declaration should own.**

The instances found so far:

| Id | Instance | Carrier |
|---|---|---|
| A1 | latest handover computed with `ls \| sort \| tail -1` | `iter.md:19`, `plan.md:25` |
| A2 | active handover found with `grep -l "Status: Active"` | `commit.md:55` |
| A3 | "most recent handover" read from the flat folder | `milestone-start.md:20`, `milestone-close.md:20` |
| A4 | active milestone read from the scalar | `check-in/SKILL.md`, `backlog-triage.md`, `milestone-start.md`, `milestone-close.md` |
| A5 | order and "`Active` only on the most recent" derived from the filename | `handover-maintenance/runbooks/chain.md` steps 1 and 4 |
| B1 | layout literal in a gate: flat `readdirSync` | `scripts/lint/handover-format.mjs:110` |
| B2 | layout literal in staged pathspecs | `scripts/check_handover_format.sh:52`, `src/capability/git-hooks/pre-commit.sh:82` |
| B3 | layout literal as a record-tree prefix | `.markdownlint-cli2.mjs:24` |
| B4 | layout literal in session measurement | `scripts/measure_sessions.mjs:20` |
| C1 | id rule restated as `max + 1` | `.agents/skills/work-log/SKILL.md:35` |
| C2 | path and identity restated in reference prose | `documentation_taxonomy.md:21`, `terminology.md:75` |
| C3 | milestone scalar restated | `.agents/skills/task-list/SKILL.md:83` |
| A6 | open discussion records found by listing the folder | `plan.md:29`, `check-in/SKILL.md:52` |
| A7 | open feedback entries found by scanning the file | `milestone-start.md:20`, `milestone-close.md:20`, `check-in/SKILL.md:50` |
| B5 | discussion gate roots hardcoded | `scripts/lint/record-name.mjs:4`, `scripts/check_record_names.sh:12` |
| B6 | feedback shape restated in readers | `.agents/skills/work-log/SKILL.md:163`, `milestone-close.md:32` |

The class matters more than the list. This repository already solved the same shape once: `src/build/container-interface.json` declares the instruction surfaces as data, and `src/build/container-interface.mjs` is the only reader every gate goes through. The record layer should use that pattern, not a new one.

### The survey beyond handovers

A literal scan of `scripts/`, `workflow/`, `src/build/` and `.agents/` finds the same pattern in every record tree, not only the handover one:

| Tree | Files carrying the literal |
|---|---:|
| `docs/adr` | 29 |
| `devlog/roadmap` | 25 |
| `devlog/discussions` | 21 |
| `devlog/handovers` | 12 |
| `devlog/changelog` | 7 |

Eighteen gate scripts carry a record-path literal. The derived reads are concentrated in the prompts. So the class is not a handover defect; it is the record layer's shape, and the stopgap should not fix only its handover instance.

## Options Considered

### The read seam

| Option | Trade-off | Verdict |
|---|---|---|
| A. Each prompt computes its own read | status quo; eight places to drift, each costing context | rejected |
| B. `work-log` states the read, the agent computes | one rule instead of eight, but the agent still loads the folder and computes, and a gate cannot hold prose | insufficient |
| C. One tool the prompts call; `work-log` states the rules it cannot decide; one declared layout is the data | the derived reads become a command; gates and prompts share one accessor | **proposed** |
| D. A harness-level tool beside `taskq` | must also run in the repository and ship with the workflow; a larger seam than the problem needs | rejected for now |

### The layout declaration

| Option | Trade-off | Verdict |
|---|---|---|
| A. Extend `src/build/container-interface.json` | reuses the existing single reader | **proposed**, if the record layout fits its schema |
| B. A new `src/build/record-layout.json` | a second declaration, but a clean subject boundary | acceptable fallback |
| C. Constants inside the tool | the gates would still restate them, so the class survives | rejected |

### The id scheme

| Option | Trade-off | Verdict |
|---|---|---|
| A. A block reserved per track, recorded with the track | keeps 1,142 bare references valid; one allocation per track, never per record | **proposed** |
| B. Path-qualified references | unique without a block, but breaks 1,142 citations | rejected for now |
| C. Date plus slug, no index | collides on a repeated slug; loses the identity the gate resolves | rejected |

## Decision

Settled 2026-11-05; the implementation questions below are left to `/scope` and the units.

- **The seam's final scope is `work-log`.** Handovers first, with the data shape built to extend to discussions and the feedback record. The task list is not in the seam: task-list violations have had no real consequence so far, while work-log violations produce administrative churn, so the work-log is where the seam earns its keep. A task-list tool is a separate decision, taken only if this one works.
- **This work is M3.5.1**, the work-log layer of M3.5. M3.5.2 owns the task-list mechanism, and M3.5.3 owns the rules that span both, including the durable parallel-milestone rule.
- **The record seam is one tool** that answers the work-log derived reads: the latest handover, the active handover, the current work-log track, the next reserved id, the list, the path. Prompts and gates call it. `work-log` keeps only the rules a tool cannot decide: what a record says, its sections, its types, its states.
- **The layout is declared once as data** and read through one accessor. Gates and the tool both go through it. `.markdownlint-cli2.mjs` already declares `recordTrees`, which `linking.mjs` and `doc-wrap.mjs` share, so the new declaration should absorb that rather than add a second. The home is `src/build/container-interface.json` if it fits, otherwise `src/build/record-layout.json`.
- **The record model is the six confirmed invariants above.**
- **The migration is two units:** the contract (model, seam, layout, gate walk) and the migration (move 240 files, re-path relative links, cut the tag). The gate must learn to walk nested folders before files move, so the contract unit lands first and leaves flat files valid.

Implementation questions, not principle questions: the tool's name and language; whether the layout reuses `container-interface.json` or absorbs `recordTrees`; where a track's id block lives; when the tag is cut.

### The read surface, built to extend

The work-log kinds the seam must eventually answer, and the commands that answer them. Only the handover rows are built in the stopgap; the discussion and feedback rows define the data shape so the later kinds are additions, not a redesign.

| Read | Command | Consumers | Built now |
|---|---|---|---|
| the latest handover on the track | `latest --kind handover` | `iter`, `plan`, `milestone-start`, `milestone-close` | yes |
| the active handover | `active` | `commit`, `check-in` | yes |
| the current work-log track | `track` | `iter`, `check-in`, `backlog-triage` | yes |
| the next reserved id | `reserve-id --track <id>` | the agent writing a handover | yes |
| the handovers on a track | `list --kind handover` | `handover-maintenance` | yes |
| the open discussion records | `list --kind discussion --state open` | `plan`, `check-in` | no, shape only |
| the open feedback entries | `feedback --state open` | `milestone-start`, `milestone-close`, `check-in` | no, shape only |

Every command reads the same declaration and the same accessor. A new kind adds a row to the declaration and a command; it does not add a path literal to a gate or a `tail -1` to a prompt.

## Consequences

- Eight prompts lose a computed read; four gates lose a layout literal; three documents stop restating identity.
- A track orients from its folder alone, and two tracks write on one day without collision.
- The tool is the seam M3.5's store replaces; the invariants survive its replacement.
- Cost: a new script and its tests, plus a migration touching 240 files and their relative links.
- Forecloses: per-folder id sequences without path-qualified references; `archive/` as a track; an `integration/` folder; dropping the unit rule to buy order.
