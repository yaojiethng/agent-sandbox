---
date: 2026-11-01
milestone: M3.3.3 - The skill maintenance pipeline
type: Implementation
status: Closed
---

# Handover - the session reports a shipped skill name an added package also holds

## Objective

Report, where the session starts, that a package the project added holds a skill name the shipped stack also holds, naming both paths and changing no bytes.

## Scope

The roadmap row `Report a shipped skill name that an added package also holds`, whose draft handoff `.agents/drafts/shipped-skill-name-collision-handoff.md` is consumed and deleted with this record.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A shipped name an added package holds reports the name and both paths | `bash tests/test_skill_collisions.sh`, `test_an_added_package_holding_a_shipped_name_is_reported` | accepted |
| A session with no collision reports nothing | the same file, `test_a_package_with_no_shipped_name_reports_nothing` and `test_a_session_with_no_package_reports_nothing` | accepted |
| The report surfaces where the session starts | `src/reasoning/providers/pi/preflight.sh`, `_preflight_report_skill_collisions` | accepted |
| The report changes no bytes and fails nothing | the CLI returns 0 on every path, asserted by the first test, and the preflight call ignores its exit status | accepted |
| The tree passes its gates | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | accepted, 17 gates clean and 1416 of 1416 tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The report asks pi for both sides rather than resolving either | pi's loader decides every name and pi's package manager resolves the configured package to its installed path, so a second resolver would be the copy `principle-delegation-over-machinery` forbids | `scripts/skill_collisions.mjs` header |
| The shipped side is the layer table, filtered to `shipped` | the project layer is the project's own and is not what the image ships | `scripts/skill_collisions.mjs` |
| The declared image and home copies of a shipped payload are not collisions | a session configures `/opt/workflow/agent/...` as a package, and that is one artifact in two declared places; reporting it produced 42 false lines on this repository | `scripts/skill_collisions.mjs`, `sameArtifact` |
| The session-start surface is pi's preflight hook, not a log file | the hook prints to stderr before the TUI starts, so the line is in front of the operator at the moment the session opens | `preflight.sh` |
| The hook runs only when `SANDBOX_DIR` names the tree | the shipped stack is defined against the tree's own layer table, and a project without the script gets no report rather than a second copy of that table | `preflight.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| none | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A live run reported 42 collisions, all of them the image copy of the shipped payload | defect | the first shape would have been pure noise; the declared copies are now excluded, and the live run prints nothing | this handover, Decisions |
| The hook ran in the preflight test and pushed it past its 10 second deadline, because `SANDBOX_DIR` fell back to this repository | defect | the fallback is gone; the hook is inert unless the entrypoint set `SANDBOX_DIR`, which it always does in a container | this handover, Decisions |

## Completed

| File | Change |
|---|---|
| `scripts/skill_collisions.mjs` | the report: pi's settings and package manager for the added side, pi's loader for both sides, the declared-copy exclusion, the CLI |
| `src/reasoning/providers/pi/preflight.sh` | `_preflight_report_skill_collisions`, called at the end of the preflight |
| `tests/test_skill_collisions.sh` | four cases: reported, declared copy, clean, no package |
| `.agents/drafts/shipped-skill-name-collision-handoff.md` | deleted, its task landed |
| `devlog/roadmap.md` | the row closed, its handoff link replaced by this record |
