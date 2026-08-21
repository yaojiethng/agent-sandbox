# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Implement the `make start --interactive` **provider/config wizard** (roadmap L151, design decision D11 from F2 session `20260821-02`). `start_agent.sh` currently carries a `--interactive` flag that errors `not yet implemented` — that block is the ready attachment point. This iteration wires the wizard so `make start INTERACTIVE=1` collects the config (provider, refresh/rebuild, serve) and then starts a new session, completing the L151 checklist. Per operator (start `2026-08-21`): the wizard covers **all non-`.env` start flags** (provider picker + refresh + rebuild as toggles; `.env` values — name/project/sandbox/env — are supplied by the Makefile automatically and not manually entered); **serve becomes an on/off toggle** on start (`make start SERVE=1`); **dry-run split-out is a Finding** (recorded, not implemented this iteration); the wizard runs in **start mode** only.
## Context

### Design intent (D1, D11, `20260821-02`)
- **D1 — fast = supplied args, slow = `--interactive`.** Interactive is never default. Args already provided **override** the interaction's suggested default rather than being re-prompted: if `--provider` is given, the wizard does not re-ask for provider.
- **D11 — `make start --interactive` is a provider/config wizard.** `start` unconditionally begins a new session (nothing to browse), so its `--interactive` is a config wizard: selection menus + confirm over `PROVIDER` (and other optional start settings), then starts new. Fast path = supply `PROVIDER=` directly.
- The cross-command convention is already realised in `resume` (`20260821-05`): `--list` fast, `--interactive` slow (picker + `interactive_confirm_or_abort`).

### Current `start_agent.sh` state (attach points)
- Arg parsing (L107-132): `PROJECT_NAME`, `PROJECT_DIR`, `SANDBOX_DIR_OVERRIDE`, `ENV_REL`, `PROVIDER_NAME`, `REFRESH`, `REBUILD`, `INTERACTIVE`.
- **L133-141 hard required-checks that exit before the wizard can run:**
  - L133-136: `--name` and `--project` required.
  - L138-141: `--provider` required (no default; clear diagnostic).
- **L200-205 the `--interactive` block** errors `Not yet implemented — planned for the F2 start-wizard iteration.` and exits.
- `_new_session_identity()` computes fresh `SESSION_TS`/`HOST_HEAD_SHA`/`SANDBOX_ID`/`SESSION_ID`; `session_env_names` derives branch/image/container names/delivery.

### How `make start INTERACTIVE=1` passes args (Makefile.template L155-164)
The sandbox Makefile `start:` target always passes `--name=$(PROJECT_NAME)` and `--project=$(PROJECT_DIR)` from `.env`, plus `--sandbox`, `--env`, and `INTERACTIVE_FLAG = --interactive` **only when `INTERACTIVE` is set**. `PROVIDER_FLAG = --provider=$(PROVIDER)` only when `PROVIDER` is set.

**Consequence:** under `make start INTERACTIVE=1` *without* `PROVIDER=`, `--provider` is absent → the L138 required-check exits **before** the interactive block. The wizard must therefore be dispatched **before** the hard provider check (and, if it may supply name/project, before those too).

### Provider enumeration
Providers live as directories under `src/reasoning/providers/<n>/`; those with a `provider.dockerfile` are actionable providers (`pi`, `hermes`, `opencode`). The wizard's provider picker should enumerate these.

### Reusable interactive primitives
`scripts/workflows/interactive.sh` (already consumed by `resume --interactive`, and requiring `AGENT_SANDBOX_REPO` for `routing.sh`):
- `interactive_pick LABEL ENTRIES_VAR [DEFAULT] [PAGE_SIZE] [AUTO_SELECT]` — numbered picker; entries `value|display` in a named array; prints value to stdout, display to stderr; returns 1 on q/abort.
- `interactive_confirm_or_abort LABEL ITEMS...` — prints label+items, `Proceed? [y/N]`; returns 0 on y.

`start_agent.sh` must set `AGENT_SANDBOX_REPO="${AGENT_SANDBOX_REPO:-$REPO_ROOT}"` before sourcing interactive.sh (mirroring `resume_agent.sh` L22-23, L174).

### Scope refinement (operator, start `2026-08-21`)
- Wizard covers **all non-`.env` start flags**: `PROVIDER` picker + `--refresh`/`--rebuild` toggles + confirm. `.env` values (name/project/sandbox/env) are supplied by the Makefile and **not** manually entered in the wizard.
- Wizard runs in **start mode** only.
- **serve as on/off and dry-run split are DEFERRED** as a major refactor (roadmap L153) — see What's Next / Findings for the plan. This iteration leaves `MODE` plumbing, `serve`/`dry-run` Makefile targets, and dispatcher subcommands untouched (refactor-safety), so the wizard stays scoped to start mode.

## Decisions
*Resolved in-session; final decisions only. Persistents reference these by descriptive name, not transient chat numbers.*

**D-w1 — Wizard dispatched before the provider required-check, after name/project + path validation.** `--name`/`--project` remain required from args (always supplied by the Makefile; Q2) and are validated first; SANDBOX_DIR is derived before the wizard so its confirm can show it; the wizard fills a missing `PROVIDER_NAME` (and build policy) before the provider required-check runs. Fast path (no `--interactive`) behaviour is unchanged.

**D-w2 — Wizard surface = provider picker + build-policy picker + summary confirm (D11).** Environment `.env` values (name/project/sandbox/env) are not entered. Provider is prompted only when `--provider` absent; build policy (default/refresh/rebuild) only when neither `--refresh` nor `--rebuild` supplied (D1: supplied args override, not re-prompt). Confirm aborts cleanly (exit 1) before any session state is created.

**D-w3 — `--interactive` on `serve`/`dry-run` is an explicit error (refactor-safety).** Because the wizard is deliberately start-mode-only this iteration (deferred refactor, roadmap L153), passing `--interactive` to a non-`standard` mode prints a clear error rather than silently dropping the flag.

**D-w4 — `AGENT_SANDBOX_REPO` fallback added to `start_agent.sh`** (mirrors `resume_agent.sh` L22-23) so the wizard can source `interactive.sh` (which needs `routing.sh` under `AGENT_SANDBOX_REPO`).

## Findings
| Finding | Type | Impact |
|---|---|---|
| `dry-run` shares `start_agent.sh`'s mode plumbing with `standard`/`serve`; a future split into its own command is desirable (operator) | design | deferred — roadmap L153 carries the plan; not implemented this iteration; the wizard stays start-only |
| `serve` is expressed as a positional mode (`start_agent.sh serve`) + a separate `make serve` target; operator wants it as an on/off on `start` (`make start SERVE=1`) | design | deferred — roadmap L153; sequencing requires landing the `MODE` refactor before a serve toggle can be added to the wizard |
| `start --interactive` with a missing `--provider` previously hit the provider required-check before reaching the wizard; the wizard is now dispatched before that check (the reason `--name`/`--project`/path validation precede it) | process | resolved this iteration — the check-order reorder (D-w1) is the fix |

## Completed
| File | Change |
|---|---|
| `scripts/start_agent.sh` | Wired the interactive config wizard (D11): `_start_providers()` (enumerates `src/reasoning/providers/*/provider.dockerfile`), `_start_wizard()` (provider picker when absent, build-policy picker default/refresh/rebuild when neither supplied, summary + `interactive_confirm_or_abort`); dispatches the wizard before the provider required-check (D-w1); serve/dry-run `--interactive` guard (D-w3); removed the dead "not yet implemented" block; `AGENT_SANDBOX_REPO` fallback (D-w4); usage/help documents the wizard and recommends `--interactive` (D2) |
| `tests/test_start_agent.sh` | 4 new wizard tests: help describes wizard (no "not yet implemented"); picker+confirm abort → non-zero + no session record; supplied `--provider` not re-prompted + confirm shows it; accept path runs to completion under the docker stub (compose record + up) |
| `scripts/templates/Makefile.template` | `INTERACTIVE` comment block + help line updated from "NOT YET IMPLEMENTED" to the config-wizard description |
| `docs/architecture/tool_interface.md` | `make start ... [INTERACTIVE=1]` section: wizard behaviour, provider/build policy selection, `.env` values from Makefile, args-override (D1) |
| `docs/architecture/sandbox_lifecycle.md`, `docs/development/quickstart.md` | Session-start notes gained the `INTERACTIVE=1` config-wizard mention |
| `devlog/roadmap.md` | L152 start/resume redesign: added the start-wizard sub-task note; **new L153** deferred entry for the serve-as-toggle + dry-run-split refactor |

## What's Next
- Present AC status + suite output for pre-close review (Gate 3); set Status Closed and commit.
- Acknowledge completion on roadmap L152 (start/resume redesign — the start-wizard sub-task) at close.

## Deferred (roadmap L153) — serve-as-toggle and dry-run split refactor
Fully deferred; this iteration is refactor-safe (wizard start-only; `MODE` plumbing, `serve`/`dry-run` Makefile targets, and dispatcher subcommands untouched). Plan:
1. **Land `--serve` as an on/off flag on `start` first** (touches the `MODE` plumbing in `start_agent.sh` → `run_agent.sh "$MODE"` and the dispatcher). `make start SERVE=1` passes it; `make serve` collapses to `make start SERVE=1`.
2. **Add a serve toggle to the start wizard** only after step 1, so the toggle maps to a real `--serve` flag.
3. **Split `dry-run` into its own command** (independent of serve), decoupled from the start wizard, once the mode plumbing is clean.