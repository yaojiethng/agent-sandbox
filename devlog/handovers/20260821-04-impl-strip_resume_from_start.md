# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Impl
**Status:** Closed

## Objective
Two objectives in this iteration:

1. **(Main scope, operator-directed)** — **Strip `--resume` / `_auto_resume_or_new` (and the resume machinery) from `start`**. This is "ID 04 / D6/D10" from the F2 design: `make start` should unconditionally start a NEW session; all resume logic now lives in the split-out `make resume` (implemented in `20260821-03`). The design decision D10 states: `start` has no resume branch — its default path always calls `_new_session_identity`; `_auto_resume_or_new`, the `--resume` flag, volume-discovery-on-start become dead in `start` and are removed.

2. **Fold in two already-completed items from the post-close debugging** of `20260821-03` (the `make resume` "does not work" incident), ANSWERED in an earlier turn but NOT yet committed:
   - **Help-string correction** — `scripts/resume_agent.sh` Makefile forms now `LIST=1`/`INTERACTIVE=1` (done, uncommitted).
   - **Class A staleness-guard note** — `devlog/AGENT_FEEDBACK.md` new entry re installed-CLI staleness vs refreshed Makefile divergence (done, uncommitted).

## Context (verified — needed to start)
### The `make resume` "does not work" incident (post-close, 2026-08-21)
- **Root cause was NOT a code defect:** the sandbox Makefile had refreshed (template `resume:` present at L221), but the **installed `agent-sandbox` CLI was stale** — it lacked `resume` and still listed `package-diff` (which current source removed). `make install` re-installs `scripts/agent-sandbox.sh` verbatim (sed-substituting `@@AGENT_SANDBOX_REPO@@`) to `$INSTALL_DIR`. Operator ran `make install`; it works now.
- Relevant: `agent-sandbox` install mechanism — `make install` (repo-root Makefile) copies `scripts/agent-sandbox.sh` to `$INSTALL_DIR/agent-sandbox`. CLI staleness makes new subcommands surface as `Unknown subcommand`.

### Current resume machinery in `scripts/start_agent.sh` (to be stripped)
Grep-mapped exact locations (post-`20260821-03` refactor, which introduced the shared `session_env` prelude):
- L76 `--resume` flag in usage/help
- L108 `RESUME=false` var init
- L121 `--resume) RESUME=true ;;` parse
- L196 `discover_volumes()` + L208 `volume_label()` + L214 `volume_is_stale()` + L223 `volume_in_use()` — volume-discovery helpers (resume-only)
- L230 `_new_session_identity()` (sets `RESUME_SESSION=false` + computes SESSION_TS/SESSION_ID/HOST_HEAD_SHA/SANDBOX_ID)
- L241 `_resume_from_volume()` (reads volume labels → SESSION id; sets `RESUME_SESSION=true`)
- L270-315 `_auto_resume_or_new()` (default path: silent-resume-1 / warn-resume-stale / picker) — **to be REMOVED**
- L317 `_show_volume_picker()` (interactive volume selection, shared by --resume + auto path)
- Dispatch block ~L358-392: `--interactive` (errors, NOT YET IMPLEMENTED — keep this for the start config wizard F2), then `REFRESH` path, then `--resume` branch (L371-385), else default `_auto_resume_or_new` (L388)
- L409 `if [[ "$RESUME_SESSION" == true ]]` — workspace setup branch (resume path)
- L492 `elif [[ "$RESUME_SESSION" != true ]]` — RESET_VOLUME logic

### The design intent (from `20260821-02`, decisions)
- **D10**: `start` unconditionally starts new; resume logic relocates to `resume`. `_auto_resume_or_new` + `--resume` removed.
- **D11**: `start --interactive` is a config wizard (NOT YET IMPLEMENTED — the L360 `--interactive` error stays, attaching point for start config wizard).
- **`--interactive` on `start` remains** (repurposed to config-wizard; NOT removed as part of this strip).
- Resume flag is `--session-id=<id>` (D3); resume owns all resume surfaces.

### What resume currently provides (so the strip leaves nothing orphaned)
- `make resume` (via `scripts/resume_agent.sh`, routed through `agent-sandbox resume`): `--session-id` direct silent resume from `.compose/<session-id>.yml` registry, primitive `--list`, bare→help, `--interactive`/`--provider` routed-but-not-implemented. `stop.sh` prints `make resume SESSION_ID=<id>`.
- Shared host-side prelude now lives in `src/libs/session_env.sh` (2-phase `session_env_common_init` + `session_env_names`, uses `dirs_resolve`) — sourced by BOTH `start_agent.sh` and `resume_agent.sh`. `start_agent` calls phase-1 early (after arg/SANDBOX_DIR/path validation) and phase-2 (`session_env_names`) after `_new_session_identity`, then `source build.sh` before rebuild/preflight.

## Two completed items (fold in — already edited, uncommitted)
1. `scripts/resume_agent.sh` — help string: Makefile forms corrected to `LIST=1`/`INTERACTIVE=1`; direct CLI keeps `agent-sandbox resume --list`. **Verified: resume tests 6/6 pass after this.**
2. `devlog/AGENT_FEEDBACK.md` — new Class A entry: "Installed CLI staleness is hard to detect" (labeled `## Agent experience — session 20260821-03`).

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `make start` unconditionally starts new; no `--resume` flag/branch; `_auto_resume_or_new`, `_show_volume_picker`, `_resume_from_volume`, volume-discovery removed | ✅ implemented |
| 2 | `--interactive` on `start` retained as not-implemented error (start config-wizard attach point, D11) | ✅ retained |
| 3 | reset-volume always forwarded (new-session-only) | ✅ implemented |
| 4 | `scripts/resume_agent.sh` help Makefile forms `LIST=1`/`INTERACTIVE=1` (pre-folded item) | ✅ intact |
| 5 | AGENT_FEEDBACK staleness-guard entry (pre-folded item) | ✅ intact |
| 6 | Makefile template: no `RESUME`/`RESUME_FLAG` for start/serve/dry-run; resume target kept | ✅ implemented |
| 7 | Docs swept (tool_interface, sandbox_lifecycle, quickstart) to two-command design | ✅ implemented |
| 8 | Suite green | ✅ 465/465 |

## Findings
*Pending.*

## Decisions
*Design settled in `20260821-02` (D1–D11); impl decisions ID 01–07 in `20260821-03`. This iteration realises D10 (start new-only) — no new decisions; the `--interactive` error is retained per D11.*

## Completed
| File | Change |
|---|---|
| `devlog/handovers/20260821-04-impl-strip_resume_from_start.md` | Created this impl handover (strip `--resume`/`_auto_resume_or_new` from `start`; fold in the two post-close items) |
| `scripts/resume_agent.sh` | **(pre-folded, uncommitted)** help Makefile forms → `LIST=1`/`INTERACTIVE=1` |
| `devlog/AGENT_FEEDBACK.md` | **(pre-folded, uncommitted)** Class A staleness-guard entry |

## Completed
| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260821-04-impl-strip_resume_from_start.md` | Created this impl handover (strip `--resume`/`_auto_resume_or_new` from `start`; fold in the two post-close items) | done |
| `scripts/resume_agent.sh` | (pre-folded) help Makefile forms → `LIST=1`/`INTERACTIVE=1` | done |
| `devlog/AGENT_FEEDBACK.md` | (pre-folded) Class A staleness-guard entry | done |
| `scripts/start_agent.sh` | Stripped all resume machinery: `--resume` flag (usage/init/parse), `RESUME_SESSION`, `_resume_from_volume`, `_auto_resume_or_new`, `_show_volume_picker`, `discover_volumes`/`volume_label`/`volume_is_stale`/`volume_in_use`; `_new_session_identity` + `--interactive` error (D11) kept; reset-volume now unconditional; dispatch is start-new-only | done |
| `scripts/templates/Makefile.template` | Removed `RESUME ?=`, `RESUME_FLAG`, start/serve/dry-run `$(RESUME_FLAG)` uses, help `RESUME=1`; RESUME comment block → NOTE ON RESUME; resume target + `RESUME_LIST/INTERACTIVE/PROVIDER_FLAG` kept | done |
| `docs/architecture/tool_interface.md` | `start`/`serve` = new-only (no RESUME); added `make resume` section | done |
| `docs/architecture/sandbox_lifecycle.md` | Session-start tree → new-only; added `make resume` registry-based resume | done |
| `docs/development/quickstart.md` | Session persistence → new session / `make resume SESSION_ID=` | done |

## What's Next
- Present AC status + suite output for pre-close review (Gate 3); then set Status Closed and commit.
- Post-close: ID 03 (`PROVIDER=` filter + `--interactive` picker on resume); later `make start` config wizard (D11) closes roadmap L151.