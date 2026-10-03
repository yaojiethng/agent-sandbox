# Agent Handover

**Date:** 2026-09-20
**Milestone:** M7 -- Dependency Security (roadmap_future)
**Type:** Workflow
**Status:** Closed

## Objective

Bump the pinned `@earendil-works/pi-coding-agent` version from `0.85.1` to `0.86.0` across the provider overlay, the config record, and the roadmap note.

## Scope

The M7 Dependency Security "Pi version pinned" row is actively maintained by this bump. Per the bump policy the operator decides when to bump; the operator approved `0.86.0` after the changelog review confirmed the harness uses the stock `pi` provider, so the release's provider-streaming and `user_bash` breaking changes do not apply.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `base.dockerfile` pins `@earendil-works/pi-coding-agent@0.86.0` | `grep @earendil-works/pi-coding-agent@ src/reasoning/providers/pi/base.dockerfile` | accepted |
| AC2 | `settings.json` `lastChangelogVersion` is `0.86.0` and the file parses | `node -e require(...)` | accepted |
| AC3 | The `roadmap_future.md` M7 note reads `0.86.0`; no stale `0.85` pin remains | `grep -rn "0\.85" src/reasoning/providers/pi/ devlog/roadmap_future.md` | accepted |
| AC4 | The knowledge test `tests/knowledge/knowledge_pi_config_cycle.sh` still passes | `bash tests/knowledge/knowledge_pi_config_cycle.sh` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/base.dockerfile`](src/reasoning/providers/pi/base.dockerfile) | Source-of-truth pi pin |
| [`src/reasoning/providers/pi/config/agent/settings.json`](src/reasoning/providers/pi/config/agent/settings.json) | `lastChangelogVersion` record |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M7 pinned-version note |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Bump the pi pin to `0.86.0` | Operator approved after changelog review confirmed no harness impact | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `0.86.0` carries provider-stream and `user_bash` breaking changes; the harness runs the stock `pi` provider and implements neither | steering | assessed, no code impact |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/base.dockerfile`](src/reasoning/providers/pi/base.dockerfile) | Pin `0.85.1` -> `0.86.0` |
| [`src/reasoning/providers/pi/config/agent/settings.json`](src/reasoning/providers/pi/config/agent/settings.json) | `lastChangelogVersion` -> `0.86.0` |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M7 note -> `0.86.0` |

## Deferred items

None.

## What's Next

The pin takes effect at the next image rebuild, when `base.dockerfile` installs `0.86.0` as root. The pi-bump skill (already committed) remains the procedure for future bumps. M7 keeps open the lockfile-for-global-install consideration.
