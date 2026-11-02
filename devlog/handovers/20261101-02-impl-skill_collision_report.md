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
| Both sides of a collision are paths in the session's load set | a name can only race inside what pi loads: the user root, the project root, then each configured package. The repository's source tree is not in that set, so comparing a committed path with a loaded path compared a build input with a build output, and that difference is drift, which the provenance graph owns | `scripts/skill_collisions.mjs` |
| The session-start surface is pi's preflight hook, not a log file | the hook prints to stderr before the TUI starts, so the line is in front of the operator at the moment the session opens | `preflight.sh` |
| The hook runs only when `SANDBOX_DIR` names the tree | the shipped stack is defined against the tree's own layer table, and a project without the script gets no report rather than a second copy of that table | `preflight.sh` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| none | -- | -- |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A live run reported 46 collisions, every one of them the committed source against the image copy of the same payload | defect | the report compared a build input with a build output, so no pair could ever race; the live run now loads the session's own set, 98 skills, and reports nothing | this handover, Decisions |
| The load set holds our own payload twice: 30 collisions between `$AGENT_HOME/agent/skills` (seeded from the image) and `/opt/workflow/agent` (the same payload configured as a package) | defect | first wins, so the home copy is live and the package copy is dead weight that can drift; the report leaves the pair out because it is our seeding, and the question is filed as its own row | roadmap, `A shipped payload is loaded twice` |
| The hook ran in the preflight test and pushed it past its 10 second deadline, because `SANDBOX_DIR` fell back to this repository | defect | the fallback is gone; the hook is inert unless the entrypoint set `SANDBOX_DIR`, which it always does in a container | this handover, Decisions |

## Completed

| File | Change |
|---|---|
| `scripts/skill_collisions.mjs` | the report: pi's settings and package manager for the added side, pi's loader for both sides, the declared-copy exclusion, the CLI |
| `src/reasoning/providers/pi/preflight.sh` | `_preflight_report_skill_collisions`, called at the end of the preflight |
| `tests/test_skill_collisions.sh` | five cases: reported, the destination, above the destination, clean, no package |
| `.agents/drafts/shipped-skill-name-collision-handoff.md` | deleted, its task landed |
| `devlog/roadmap.md` | the row closed, its handoff link replaced by this record |
