# Agent Handover

**Date:** 2026-07-30
**Milestone:** M2.6 — Session Resume and Mount Model Redesign
**Type:** Implementation — Compose project name leak causing volume non-persistence
**Status:** Closed

## Objective

Fix a bug where `compose_generate` leaks auto-generated volume names into the generated compose file, causing each session to create a new volume instead of reusing the existing one. Volume persistence does not actually work despite the post-agent `-v` fix.

## Root cause

`compose_generate` calls `docker compose config --no-interpolate` without `--project-name`. Compose auto-generates a project name from the temp staging directory and injects `name:` fields for all resources into the output. The grep filters strip only:

- `^name:` — top-level project name
- `^\s*name:.*_default$` — default network name

But the **volume's** `name:` line does not match either pattern and survives into the generated compose file:

```yaml
volumes:
  sandbox-data:
    name: tmpj0v7xr6iwo_sandbox-data   # auto-generated, not stripped
```

When `compose up` runs with `--project-name agent-sandbox-af381c`, the network is correctly scoped — but the volume has a hardcoded name pointing to the auto-generated project. Each run gets a fresh temp staging directory, so each run gets a different volume name. The old volume (containing session commits) is orphaned.

## Scope

Single fix in `src/build/compose.sh` `compose_generate`: replace the two `grep -v` patterns with a single pattern that strips ALL `name:` lines regardless of indentation.

Also add a trace test that verifies the generated compose file contains no `name:` lines.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | Generated compose file contains zero `name:` lines at any indentation | `grep -c '^[[:space:]]*name:'` on compose_generate output returns 0 | Agent ✅ |
| 2 | `compose_generate` strips volume-level `name:` injected by `compose config` | Test `test_no_name_lines_in_output` passes | Agent ✅ |
| 3 | Compose project name is the only source of volume naming | `sha256sum` of SANDBOX_DIR is stable per directory | Agent ✅ |
| 4 | `bash -n src/build/compose.sh` passes | Syntax check | Agent ✅ |
| 5 | All existing trace tests still pass (21 tests) | `bash tests/test_trace_*.sh` all exit 0 | Agent ✅ |
| 6 | End-to-end: session commits survive `make stop` / `make start` cycle | Operator: run cycle, check `git log` in sandbox shows prior session commits | Accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/build/compose.sh`](src/build/compose.sh) | `compose_generate` — single-line grep fix |
| [`tests/test_trace_compose_gen.sh`](tests/test_trace_compose_gen.sh) | New: verifies generated compose file has no `name:` leaks |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Strip all `name:` lines regardless of indentation | Simpler than passing `--project-name` to `compose config` (requires computing project name earlier). No source templates use `name:` fields — all are injected by compose config. | Chat |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `compose config` without `--project-name` auto-generates project name from staging dir and injects `name:` for volumes, networks, etc. | bug | Current session |
| Only top-level `name:` and `_default` network `name:` were stripped — volume `name:` leaked through | bug | Current session |

## Completed this session

| File | Change summary |
|---|---|
| [`src/build/compose.sh`](src/build/compose.sh) | Single-line fix: `grep -v '^[[:space:]]*name:'` replaces two patterns, strips all injected `name:` lines including volume |
| [`tests/test_trace_compose_gen.sh`](tests/test_trace_compose_gen.sh) | 3 tests: no `name:` lines in output, valid YAML structure, stub doesn't inject false positives |
| [`devlog/discussions/20260730-design-active-multi_volume_concurrency.md`](devlog/discussions/20260730-design-active-multi_volume_concurrency.md) | Design doc: volume-per-session, container persistence, volume locking, interactive selector. All four open questions resolved via grill-me review. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | M2.6.2 reopened with two new task groups: container persistence and multi-volume concurrency |

## Deferred items

None.

## Next session

M2.6.2 — Container persistence implementation. `compose_stop` → `docker compose stop`, `stop.sh` drops `docker rm`, `prune.sh` includes volumes.

**Conclusions from this session:** The compose project name leak was a one-pattern fix. The multi-volume design is complete with all questions resolved. M2.6.2 is now the active sub-milestone with container persistence and multi-volume concurrency as the next implementation targets.
