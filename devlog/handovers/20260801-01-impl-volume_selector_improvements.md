# Agent Handover

**Session date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Session type:** Implementation — Volume selector ordering, stale prune, default new-session behaviour
**Status:** Closed

## Design

### Unit 1 — Sort volumes by session-ts

`discover_volumes()` returns `docker volume ls --format '{{.Name}}'` unsorted. Change approach: use `--format` to emit `session-ts|name`, pipe through `sort -r`, then extract names. Volumes appear newest-first in the picker.

### Unit 2 — `--stale` flag for prune.sh

New `--stale` flag. When set, instead of `docker system prune --filter until=Nd`, iterate volumes matching the sandbox-dir label, check `volume_is_stale` for each, and `docker volume rm` only stale ones. Non-stale volumes are left untouched. No age check when `--stale` is set.

### Unit 3 — Default new session, `--resume` flag

Add `--resume` flag to `start_agent.sh`. Change default logic:
- No `--resume`: skip volume discovery entirely → always new session (current `VOLUME_COUNT == 0` path).
- `--resume`: run volume discovery → single volume auto-resumes, multiple volumes show picker, zero volumes falls through to new session with message.
- `--refresh`: still respected; when combined with `--resume`, forces new session (skips discovery).

## Objective

Three UX improvements for session management: sort volumes by recency in the picker, add a `--stale` prune flag for immediate removal of stale volumes, and default `make start` to new session (picker only on `--resume`).

## Scope

Three units:

1. **Sort volumes by `session-ts`** — `discover_volumes()` currently returns unsorted output from `docker volume ls`. Sort by `agent-sandbox.session-ts` label, newest first.
2. **`--stale` flag for `prune.sh`** — bypass the 3-day age threshold and prune only volumes where `host-head-sha != current HEAD`.
3. **Default new session, `--resume` flag** — change `start_agent.sh` default: skip volume discovery and start new session. Only discover + show picker when `--resume` is passed.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | Volume picker displays sessions ordered newest-first by `session-ts` | `bash tests/test_interactive_session_select.sh` (or manual: `make start --resume`) | |
| 2 | `prune.sh --stale` removes only stale volumes (host-head-sha != current HEAD), leaves fresh volumes intact | Manual: tag two volumes with different SHAs, run `prune.sh --stale`, confirm only stale removed | |
| 3 | `make start` (no `--resume`) starts a new session without showing volume picker | Manual: `make start` with existing volumes present → no picker, new session | |
| 4 | `make start --resume` shows volume picker when multiple volumes exist | Manual: `make start --resume` with multiple volumes → picker shown | |
| 5 | `make start --resume` resumes single volume without picker | Manual: `make start --resume` with one volume → auto-resumes | |
| 6 | `--refresh` remains compatible with `--resume` (REFRESH overrides, starts new session) | Manual: `make start --resume --refresh` → new session | |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | Volume discovery, sort, and resume/default logic |
| [`scripts/prune.sh`](../../scripts/prune.sh) | Stale-volume immediate prune flag |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| [`scripts/start_agent.sh`](../../scripts/start_agent.sh) | Sorted volumes by session-ts (newest first); added `--resume` flag; default to new session; extracted `_new_session_identity` and `_resume_from_volume` helpers; RESET_VOLUME_FLAG for default path |
| [`scripts/prune.sh`](../../scripts/prune.sh) | Added `--stale` flag: immediate prune of volumes where host-head-sha ≠ current HEAD |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Forward passthrough args to prune.sh |
| [`docs/development/quickstart.md`](../../docs/development/quickstart.md) | Updated session persistence section for new default/resume behaviour |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Updated start flow diagram for --resume flag |
| [`docs/concepts/sandbox_identity.md`](../../docs/concepts/sandbox_identity.md) | Updated .run-identity description |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Updated make start/serve docs with --resume flag |
| [`scripts/templates/Makefile.template`](../../scripts/templates/Makefile.template) | Added RESUME/STALE variables, flags, guards, and header docs |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.6.6 — Mount Model: Host-backed Sandbox

**Blocking design questions:** Seven unresolved questions in `devlog/discussions/20260730-design-settled-mount_model.md`.

**Conclusions from this session:** TBD
