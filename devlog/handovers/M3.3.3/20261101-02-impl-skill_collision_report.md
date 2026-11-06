---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the collision report was already pi's, and nothing was built

## Objective

Confirm whether the session already reports a skill name held twice, with both paths, where the session starts. It does, so this iteration builds nothing and deletes the report it had written.

## Scope

The roadmap row `Report a shipped skill name that an added package also holds`, whose draft handoff `.agents/drafts/shipped-skill-name-collision-handoff.md` is consumed and deleted with this record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The session reports a collision at its start, with both paths | pi 1.3.0 renders a `[Skill conflicts]` block from `showLoadedResources`, called at startup with `showDiagnosticsWhenQuiet: true` (`dist/modes/interactive/interactive-mode.js:1546`), formatting the winner with a check mark and each loser as skipped (`:1303`) | accepted, and it needs no code from us |
| A quiet startup does not hide it | `showDiagnostics` is true when either `showListing` or `showDiagnosticsWhenQuiet` holds (`:1331`), so `quietStartup` governs the listing and not the diagnostics | accepted |
| The tree carries no second report | `git ls-files scripts/skill_collisions.mjs tests/test_skill_collisions.sh` returns nothing | accepted |
| The tree passes its gates | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | accepted, 17 gates clean and 1416 of 1416 tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The report asks pi for both sides rather than resolving either | pi's loader decides every name and pi's package manager resolves the configured package to its installed path, so a second resolver would be the copy `principle-delegation-over-machinery` forbids | `scripts/skill_collisions.mjs` header |
| The shipped side is the layer table, filtered to `shipped` | the project layer is the project's own and is not what the image ships | `scripts/skill_collisions.mjs` |
| The report is deleted rather than corrected a third time | pi already owns the question: it decides the name race, it holds both paths, and it prints them at startup. A second report beside it is a copy of the owner's guarantee, which is the defect the sibling principle names | this handover, Decisions |
| Both sides of a collision must be paths in the session's load set | a name can only race inside what pi loads: the user root, the project root, then each configured package. The repository's source tree is not in that set, so comparing a committed path with a loaded path compared a build input with a build output | `devlog/AGENT_FEEDBACK.md`, entry `2026-11-01` |
| The session-start surface is pi's preflight hook, not a log file | the hook prints to stderr before the TUI starts, so the line is in front of the operator at the moment the session opens | `preflight.sh` |
| The hook runs only when `SANDBOX_DIR` names the tree | the shipped stack is defined against the tree's own layer table, and a project without the script gets no report rather than a second copy of that table | `preflight.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| none | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A live run reported 46 collisions, every one of them the committed source against the image copy of the same payload | defect | the report compared a build input with a build output, so no pair could ever race | this handover, Decisions |
| The handoff's premise, "a diagnostic nobody reads", is false for pi 1.3.0 | correction | the TUI prints the block at every start, so the task needed a reading of the loader, not a program | this handover, Acceptance criteria |
| The load set holds our own payload twice: 30 collisions between `$AGENT_HOME/agent/skills` (seeded from the image) and `/opt/workflow/agent` (the same payload configured as a package) | defect | first wins, so the home copy is live and the package copy is dead weight that can drift; the operator now meets all 30 as `[Skill conflicts]` lines at every session start, which makes the row for it the next thing to fix | roadmap, `A shipped payload is loaded twice` |
| The hook ran in the preflight test and pushed it past its 10 second deadline, because `SANDBOX_DIR` fell back to this repository | defect | the fallback is gone; the hook is inert unless the entrypoint set `SANDBOX_DIR`, which it always does in a container | this handover, Decisions |

## Completed

| File | Change |
|---|---|
| `scripts/skill_collisions.mjs` | written, corrected twice, then deleted: pi already prints the block at startup |
| `src/reasoning/providers/pi/preflight.sh` | the hook added, then removed with the script |
| `tests/test_skill_collisions.sh` | five cases over the load set, then deleted with the script |
| `.agents/drafts/shipped-skill-name-collision-handoff.md` | deleted, its task landed with no code |
| `devlog/roadmap.md` | the row closed, its handoff link replaced by this record |
