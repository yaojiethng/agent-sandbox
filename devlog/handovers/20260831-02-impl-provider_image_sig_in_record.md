# Handover — 20260831-02-impl provider image-sig in record

**Status:** Closed
**Iteration:** 20260831-02
**Type:** impl
**Milestone:** M2.6 - Session Persistence (post-close from 54d26d6)
**Predecessor:** 20260831-01 (inv) — PROVIDER image identifier investigation (closed; operator accepted its recommendation)
**Operator-approved design (a'):** bake the loaded agent image's `container-sig` into the record at start/resume via docker inspect (already required there), persist as `agent-sandbox.image-sig`; `make resume --list` reads it docker-free and shows `pi (<short-sig>)`. Image-TAG tracking decision from the naming question: do NOT use `host-head-sha` (it names the host project commit, not image content — wrong axis); keep `host-head-sha` = project identity and `image-sig` = image-content identity orthogonal; image digest (`@sha256:`) tracking deferred (docker-only, marginal value).

## Objective
Surface the PROVIDER image identifier in `make resume --list` as `pi (<7-char image-sig>)` from the session record — registry-available, no docker dependency at list time — resolving the 20260828-05 deferral.

## Scope
- IN: `container_sig.sh` `image_baked_sig` helper (+ refactor `image_is_stale`); `compose_generate` bake `agent-sandbox.image-sig`; `resume_agent.sh` read + render `pi (<sig>)` in `--list`/picker; tests; docs.
- OUT: `host-head-sha` behavior, docker-free `--list` (already true before this), sandbox-image sig (tracking agent sig only, per agreed scope), digest tracking.

## Carried forward
- None new. Standing: SERVE mode integration (roadmap); Bug E (`make stop` template + duplicate-ID); contextual-knowledge-light naming fold; image-digest tracking (deferred, decided this iteration).

## Acceptance criteria
- AC1: `compose_generate` bakes the loaded agent image's `container-sig` into the record `agent-sandbox.image-sig` (empty when docker/image/label unavailable).
- AC2: `make resume --list` shows `pi (<7-char sig>)` in the PROVIDER cell, read from the record (docker-free at list time); bare `pi` when the field is empty/absent.
- AC3: interactive picker shows the same sig.
- AC4: tests updated + added (sig display, empty-field fallback, bake regression); suite + lint clean.

## Hot files
- `src/libs/container_sig.sh`, `src/build/compose.sh`, `src/build/docker-compose.yml`, `scripts/resume_agent.sh`, `tests/test_resume.sh`, `tests/test_trace_compose_gen.sh`, `docs/architecture/{sandbox_lifecycle,tool_interface,execution_model}.md`.

## Findings
- Docker identity hierarchy (from inv): tags = mutable version pointers; digests `<repo>@sha256:` = atomic/immutable; labels = finer build metadata. Our images use fixed mutable tags (`<provider>-agent-<project>`, `sandbox-<project>`); `container-sig` is baked only as a label. `host-head-sha` names the host project commit, NOT image content — so it is the wrong axis for an image tag; `image-sig` (content) is the correct identifier and is now recorded.
- Bake-at-record-gen (a') supersedes the build-side-artifact idea: start/resume already require docker and already `docker image inspect` the images (preflight), so reading the agent image's baked `container-sig` label there is free; `--list` remains docker-free by reading the recorded field.

## Completed
- `src/libs/container_sig.sh`: added `image_baked_sig IMAGE` (docker inspect of the `agent-sandbox.container-sig` label); refactored `image_is_stale` to use it (single source).
- `src/build/compose.sh`: in `compose_generate`, compute `image_sig` from the agent image (guarded by `command -v docker`) and substitute `{{IMAGE_SIG}}` into the record.
- `src/build/docker-compose.yml`: added `agent-sandbox.image-sig: {{IMAGE_SIG}}` to `x-session-labels`.
- `scripts/resume_agent.sh`: `build_inventory` reads `image-sig` (7-char short) as a 9th row field; `--list` header `PROVIDER (SIG)`, cell `pi (<sig>) [IMAGE_STALE]`; picker shows `(<sig>)` too.
- Tests: `test_resume.sh` — fixture `image-sig`, new `test_list_shows_image_sig_short` + `test_list_no_sig_when_field_empty`; `test_trace_compose_gen.sh` — new `test_record_bakes_image_sig`.
- Docs: `sandbox_lifecycle.md`, `tool_interface.md`, `execution_model.md` describe the `image-sig` field + `pi (<short-sig>)` PROVIDER cell.
- Suite **737/43/0**, lint 0 warnings / 100 files. End-to-end demo: record baked `image-sig: deadbeefcafe0123456789`; `--list` → `pi (deadbee)`.

## Deferred items
- Image digest (`@sha256:`) tracking — decided not to add (docker-only at list time, marginal value over `image-sig`).
- Standing: SERVE mode integration (roadmap); Bug E (`make stop` template + duplicate-ID); contextual-knowledge-light naming fold.

## What's Next
M2.6 - Session Persistence. Post-close bookkeeping: n/a (mid-milestone).
This iteration delivered the registry-available PROVIDER image identifier: `compose_generate` bakes `agent-sandbox.image-sig` (loaded agent image's `container-sig`) into the record; `make resume --list` shows `pi (<short-sig>)` docker-free.
Watch-outs: dual-grep bridge; full-tree close-out greps.