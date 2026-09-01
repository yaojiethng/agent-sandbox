# Agent Handover

**Date:** 2026-08-10
**Milestone:** M2.6 — Session Persistence (carried finding)
**Type:** Implementation (commit type: feat)
**Status:** Closed

## Objective

Persist the merged compose file at a stable on-disk path (`$SANDBOX_DIR/.compose/<run-id>.yml`)
instead of the current `/tmp` tmpfile, so each session's compose configuration survives the
session for inspection and compose-aware tooling (devcontainer integration, post-hoc teardown,
debugging).

## Scope

- `scripts/run_agent.sh` — replace `mktemp /tmp/agent-sandbox-*.yml` with
  `$SANDBOX_DIR/.compose/<run-id>.yml` (same sandbox-hash fallback as `compose_args` when
  RUN_ID is unset); `mkdir -p` the dir; `_session_cleanup` no longer deletes the file.
- `src/build/compose.sh` — no functional change; verify `compose_args`/`compose_generate`
  doc comments still accurate (caller-supplied output path).
- Docs reversing the documented "never written to SANDBOX_DIR" tmpfile decision:
  `docs/architecture/execution_model.md` Compose Generation, `docs/architecture/tool_interface.md`
  (compose file row), `src/build/docker-compose.yml` header comment.
- `.gitignore` — add `.compose/` (same class as `.workspace/`, `.snapshot/`).
- `tests/test_trace_start.sh` — behavior test: file exists at stable path after run and
  survives teardown; negative check (old tmpfile behavior deletes it).
- New ADR reversing the tmpfile decision (per `adr_policy.md` — design decision with
  implemented code).
- `devlog/roadmap.md` — mark carried finding done.

## Carried forward

| Item | From handover |
|---|---|
| Compose-file persistence — generated compose file should be persisted (e.g. `.compose/<run-id>.yml` in SANDBOX_DIR) so compose-aware teardown/inspection is possible. RUN_ID confirmed available at compose-generation time (exported by start_agent.sh before run_agent.sh) | 20260810-10, re-carried by 20260810-13 |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | After a standard run, the merged compose file exists at `$SANDBOX_DIR/.compose/test01.yml` and contains the baked agent/sandbox container names | `test_compose_file_persisted` in tests/test_trace_start.sh | Agent |
| 2 | The file survives `run_agent.sh` exit — teardown ran, EXIT trap no longer deletes it | Same test; NEG-A (trap re-adds `rm`) → test fails (verified: 15 passed/1 failed) | Agent |
| 3 | Compose invocations during the run use the persisted file (trace `compose-file` line = persisted path) | Stub logs `-f` path; assertion in same test | Agent |
| 4 | Architecture docs describe the system as built: `execution_model.md`, `tool_interface.md`, `docker-compose.yml` header no longer claim "never written to SANDBOX_DIR" | `grep -rn "never written to SANDBOX_DIR"` → 0 matches | Agent |
| 5 | Reversal + deferred pruning recorded (no ADR): execution_model.md lifecycle note states persistence + accumulation/deferral; roadmap carries pruning item; handover decisions table records the no-ADR decision | grep + file contents | Agent |
| 6 | `.compose/` listed in `.gitignore` | `grep` | Agent |
| 7 | Full suite green: 468 → 469 tests, 0 failed | `scripts/run_tests.sh` | Agent |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/run_agent.sh`](../../scripts/run_agent.sh) | COMPOSE_OUT source — mktemp → persisted path; trap keeps the file |
| [`src/build/compose.sh`](../../src/build/compose.sh) | compose_generate/compose_args consumers of the output path; verify comments |
| [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) | Header comment claims "never written to SANDBOX_DIR" — must be reversed |
| [`docs/architecture/execution_model.md`](../../docs/architecture/execution_model.md) | Compose Generation documents the tmpfile model |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | SANDBOX_DIR contents table claims compose files never written there |
| [`tests/test_trace_start.sh`](../../tests/test_trace_start.sh) | New behavior test for persisted compose file |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | Mark carried finding done |
| [`docs/adr/`](../../docs/adr/) | New ADR reversing the tmpfile decision |

## Decisions made this session
| Decision | Rationale | Where recorded |
|---|---|---|
| No ADR for the tmpfile-model reversal | Routine implementation choice (adr_policy exemption) — decision pre-settled in the carried finding + operator direction; pruning follow-up is minor and must not trigger ADR ceremony | execution_model.md lifecycle note, roadmap deferred item, this table |
| Compose file persists after session (not deleted by EXIT trap) | Persistence is the finding's point — a failed session's file is the diagnostic artifact | execution_model.md Compose Generation, run_agent.sh comment |
| Path = `$SANDBOX_DIR/.compose/<run-id>.yml`; hash fallback when RUN_ID unset | Identity-derived, deterministic, consistent with compose_args project naming; containers never mount SANDBOX_DIR root so no workspace pollution | ADR-free; execution_model.md |

## Mid-session findings
| # | Finding | Disposition |
|---|---|---|
| 1 | Operator steering: no ADR — "can't actually settle this"; pruning follow-up would need ADR ceremony for an extremely minor matter. At least leave a note. | Accepted: no ADR; note in execution_model.md lifecycle section + roadmap deferred item + this table. Adjusted AC #5 accordingly. |
