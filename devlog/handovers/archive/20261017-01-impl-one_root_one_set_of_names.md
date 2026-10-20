---
date: 2026-10-17
milestone: Unrouted - the active-tracker skill's path ownership
type: Implementation
status: Closed
---

# Handover - The active-tracker skill owns its filenames

## Objective

Retire the three settable paths from the active-tracker skill in favour of one root and four fixed names, so a caller can no longer split the store, the tracker and the log across three directories.

## Scope

No roadmap row names this work, which is why the milestone line reads `Unrouted`. `grep -rn "active-tracker" devlog/roadmap.md` returns nothing. The change was found while auditing a recording of the skill, and it is scoped to the skill directory, its two test files, and the installed copy under `$AGENT_HOME`.

The three path arguments were the residue of `33ac34df workflow: merge the memory into one tracker skill with one report`. Before that merge, `tree` and `memory` were separate skills and each owned its own file. After the merge the facade took over path construction, and the arguments survived on the libraries.

`README.md` stated the goal the arguments broke. One paragraph said the two libraries share a lifecycle and that one entry point makes the shared state hard to get wrong. The next paragraph licensed them to be used separately, and three independently settable paths made the split expressible. A guarantee that can be expressed around is not a guarantee.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A fresh session opens the tracker with no hand-seeding | `node active-tracker.mjs init` in an empty directory, then `push`, `view`, `report` with no root argument, all exit 0 | Accepted |
| One root holds every file, and the names are fixed | `bash tests/test_documented_defaults.sh`, case `test_one_root_holds_every_file` | Accepted |
| A retired path flag refuses rather than landing in the default root | `node active-tracker.mjs view --store /tmp/x` prints `--store is gone; name one --root instead` and exits 1 | Accepted |
| The shipped suite survives the migration | `bash tests/test_active_tracker.sh`, 21 passed | Accepted |
| The documentation states the contract the code holds | the `SKILL.md` command table and codemode section, and `README.md` section `The skill owns its filenames` | Accepted |
| The installed copy matches the shipped one | `diff -q` across the five skill files | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One root and fixed names, not three paths with defaults | Three paths let a caller put the store in one directory and the log in another, which is the inconsistency the README already said the design prevents | `README.md`, section `The skill owns its filenames` |
| Retire `--store`, `--tracker` and `--log` rather than keep them as aliases | An alias beside `--root` leaves two ways to address one state, so the split stays reachable through the old spelling | this handover |
| The retired flags refuse by name instead of falling through to the default root | A caller that kept one would otherwise write to `.scratchpad` and never be told | `active-tracker.mjs`, the argument loop |
| `init` seeds the tracker rather than `push` creating a store on demand | `tests/test_active_tracker.sh` asserts that a render against a missing store refuses, and that refusal is deliberate. `init` adds the missing capability without weakening it | `tests/test_documented_defaults.sh`, `test_the_facade_refuses_and_the_library_names_the_path` |
| Only the facade takes `root`; `memory.mjs` still takes `log` | The facade is the one place that builds a filename, and `memory` derives its `.view` and `.state` from the log it is handed. Changing the library's parameter is a larger edit than this one and buys nothing while the facade is the entry point | `SKILL.md`, codemode section |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The three path arguments were residue of the two-skill merge, and the README's own guarantee was reachable-around | design | a caller could split the session state across directories, which is the failure the facade exists to prevent | closed here |
| `SKILL.md` promised a path default that only the facade had, and the libraries threw a bare `TypeError` instead | defect | a library call with no log named neither the log nor the reason | closed here |
| `README.md` said the two libraries were "each usable alone", one paragraph before saying one entry point makes the state hard to get wrong | defect | the record licensed the shape the same page argued against | closed here |
| The storage is still two logs and two report marks | design | the merge unified the report, not the storage, so the same argument that retired three paths applies to five files | open, named, not resolved here |
| `memory.mjs` still takes `log`, so a library caller can address the log apart from the store's root | design | the remaining seam, and the same question one level down | open, named, not resolved here |
| `gitHead` leaked git's `fatal: not a git repository` to stderr when the root was not a repository | defect | `init` made it reachable in any directory, so the first command a new user runs printed an alarming line that changed nothing | closed here, via `stdio: ["ignore", "pipe", "ignore"]` |
| The lint gate scans `.scratchpad/`, so every artifact an extractor emits there must satisfy the one-paragraph-per-line rule | process | two generated files broke the gate before the generator paired each prose line with a blank one | `devlog/AGENT_FEEDBACK.md` candidate, not yet filed |

## Completed

| Item | Result |
|---|---|
| `active-tracker.mjs` | `NAMES`, `paths({ root })`, `init`, `--root`, and a refusal for the three retired flags |
| `memory.mjs` | `requireLog`, called from `pathsOf` and `ensure`, so a missing log names itself |
| `tree.mjs` | `gitHead` runs git with stderr discarded, so a root outside a repository opens quietly |
| `tests/test_active_tracker.sh` | two call sites migrated, the fixture filenames moved to the canonical ones |
| `tests/test_documented_defaults.sh` | new, four cases, all passing |
| `SKILL.md`, `README.md` | the contract the code now holds |
| the installed copy | re-synced and verified identical |

## Verification

Lint clean across 8 gates. `scripts/run_tests.sh` reports 1190 tests across 85 files, all passing, which is 4 more than the previous run.
