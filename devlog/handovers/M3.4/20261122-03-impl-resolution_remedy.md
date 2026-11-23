---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the resolution remedy belongs to the setting

## Objective

The resolution primitive's failure text names the remedy of the setting it could not read, and a default `.env` is never reported as a specified path.

## Scope

The M3.4.2 row **The resolution primitive's failure text names the identity setting**, third of the three iterations this session runs. The row has two halves: the hardcoded onboard remedy, and the default `.env` arriving as a specified one. The file list is the scope proposal's and is presented at the scope gate.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The remedy is the caller's, not the primitive's | `bash tests/test_env_resolve.sh` - `env_resolve_one` with no remedy prints the generic set-the-key line, with one prints that remedy | Agent [x] |
| A missing identity setting still names `onboard` | `test_resolve_missing_all_is_hard_error` passes | Agent [x] |
| An absent default `.env` is not reported as a specified path | `test_resolve_default_env_absent_is_not_specified` - ambient identity plus `--sandbox`, no `.env` in the sandbox, rc 0 | Agent [x] |
| A specified `--env` that is absent still names the path | `test_resolve_specified_env_absent_names_the_path` - rc 1 and `A specified --env path must exist` | Agent [x] |
| The start path passes no literal `.env` as its default | `grep -n 'ENV_REL=".env"' scripts/start_agent.sh` prints nothing | Agent [x] |
| The roadmap row compacts to its landing note and handover link | `grep -n 'resolution primitive.s failure text' devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the delivery diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The remedy is an argument of `env_resolve_one`, defaulting to the generic "set this key" line. | The primitive cannot know which command owns a setting; the caller can. The row's own framing is that the remedy is a property of the setting. A default keeps the two callers that suppress stderr unchanged. | This table; `src/libs/env_resolve.sh` |
| `env_resolve_identity` passes the onboard remedy for the identity triple. | Every key it resolves is written by `onboard`, so that is the true remedy for all three, and it is now stated by the caller rather than by the primitive. | This table; `src/libs/env_resolve.sh` |
| The default `.env` is the empty env-ref, and `scripts/start_agent.sh` stops passing the literal `.env`. | The library already treats empty as "the caller specified nothing" and derives `<sandbox>/.env`; start was the one caller that handed its default in as a specification, which made a resolved sandbox with no `.env` fail with a message about a path nobody specified. The library's contract is unchanged. | This table; `scripts/start_agent.sh` |
| The row's `INSTALL_DIR` example is reconciled, not re-implemented: `scripts/install.sh` suppresses the primitive's stderr by design and falls back to `~/.local/bin`. | The wrong remedy was never printed on that path. What the primitive owed was the ability to print the right one, which the remedy argument gives it. | This table; `src/libs/env_resolve.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `INSTALL_DIR` half of the row's premise did not reproduce: `install.sh` and `onboard.sh` both discard the primitive's stderr, so the onboard remedy was never shown for a non-identity key. | record | The row's example described a message no caller printed. | This iteration's write-back, which records the reconciliation. |

## Completed

| File | Change |
|---|---|
| [`src/libs/env_resolve.sh`](../../../src/libs/env_resolve.sh) | The remedy is the fourth argument, defaulting to the generic line; `env_resolve_identity` passes the onboard remedy for the triple. |
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh) | The env-ref default is empty, so a default `.env` no longer arrives as a specified path. |
| [`tests/test_env_resolve.sh`](../../../tests/test_env_resolve.sh) | Units for the remedy argument, the default-absent `.env`, and the specified-absent `.env`. |
| [`devlog/roadmap.md`](../../roadmap.md) | The **The resolution primitive's failure text names the identity setting** row compacts to its landing note and handover link. |
