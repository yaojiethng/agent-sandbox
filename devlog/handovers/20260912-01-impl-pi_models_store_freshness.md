# Agent Handover

**Date:** 2026-09-12
**Milestone:** M2 -- Provider layer (pi provider)
**Type:** Impl
**Status:** Closed

## Objective
Make the pi provider's model catalog store (`$AGENT_HOME/agent/models-store.json`) serve a fresh catalogue on every container start, instead of serving a build-time-frozen overlay for up to 4 hours after image build.

## Scope
- `src/reasoning/providers/pi/preflight.sh`: reset `checkedAt` to 0 for every provider entry in `models-store.json` at container start (Option B -- keep the baked catalogue as offline fallback, force etag revalidation at first refresh).
- pi-bump: pin `@earendil-works/pi-coding-agent` to the latest version (per `src/reasoning/agent/skills/pi-bump/SKILL.md`), pending operator confirmation of the target version.
- Roadmap: record and close the item.

## Out of scope
- Replacing `RUN pi install` in `provider.dockerfile` (the install step legitimately bakes an initial catalogue; Option B neutralises its staleness at runtime).
- Option A (deleting `models-store.json` at startup) -- rejected, see Decisions.

## Findings (investigation this iteration)
Pi caches model catalogs in three layers: a compiled-in static catalogue (pi-ai generated files), a persisted pi.dev overlay in `$AGENT_HOME/agent/models-store.json` (`{ models, checkedAt, lastModified, etag }` per provider, written by `dist/core/remote-catalog-provider.js`), and in-process `dynamicModels` published by `ModelRuntime.refresh()`. Key behaviors:

- Startup refresh is network-off (`agent-session-services.js` calls `ModelRuntime.create` without `allowModelNetwork`), so pi serves the stored overlay as-is at start.
- The `/model` selector auto-refreshes on open, but `withRemoteCatalog` skips the network while `now - checkedAt < 4h` (`REMOTE_CATALOG_REFRESH_INTERVAL_MS`); it revalidates with an etag afterwards (304 bumps `checkedAt` only).
- The TUI "Model catalogs refreshed." message appears whenever the refresh completes without errors -- even when the network was skipped by the 4h window. It is not proof of a fetch.
- In agent-sandbox, `models-store.json` is neither seeded (template `config/agent/` omits it) nor copied out (only `prompts/sessions/skills` are bind-mounted). The store in the container comes from the `RUN pi install npm:pi-opencode-provider` build step, which refreshes catalogs as `agentuser` and bakes the store into the image layer. Consequence: the container serves a build-time catalogue whose `checkedAt` may still be inside the 4h window, making even the `/model` refresh network-free and stale.
- The `pi-opencode-provider` extension does not schedule its own refreshes; its `opencode`/`opencode-go` providers refresh through the same `withRemoteCatalog` path and the same store entries. The delay was not extension-caused.
- `models-store.json` reads revalidate the file revision on every read (`dev:ino:size:mtime:ctime`), so runtime edits to the store are safe and picked up by a fresh process.

## Decisions

| Decision | Rationale |
|---|---|
| Option B (reset `checkedAt` to 0 at startup) over Option A (delete the store) | Option B keeps the baked catalogue as an offline fallback and turns the first `/model` open into a cheap conditional GET (304 if unchanged, full fetch if stale). Option A forces a full download on every start and leaves only the compiled-in catalogue when the container has no network. |
| Edit at runtime (preflight.sh), not build time | The staleness is a function of time since `checkedAt`; only a container-start hook can neutralise it regardless of image age. |
| `RUN pi update --models` in `provider.dockerfile` is insufficient as the fix | It produces a fresh store at build time, but `checkedAt` is then frozen at the build date. The 4h freshness window is evaluated against wall-clock time at container use, so any container started within 4h of the build skips the network entirely, and staleness grows with image age. It duplicates what `RUN pi install` already does and only helps when builds are frequent relative to catalog churn. It cannot make an old image serve a fresh catalogue. |

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| AC1 | preflight resets `checkedAt` to 0 for every entry when the store exists; no-op when absent; invalid JSON handled | test | Agent -- pass (4 new tests) |
| AC2 | Baked etag/lastModified retained (revalidation stays conditional) | test | Agent -- pass |
| AC3 | pi pinned to latest with `lastChangelogVersion` in step across base.dockerfile, config settings.json, roadmap_future note | grep + curl | Agent -- pass (`0.85.1` == pi.dev latest-version) |
| AC4 | Full test suite passes | suite | Agent -- pass (742/742) |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/providers/pi/preflight.sh`](src/reasoning/providers/pi/preflight.sh) | New `_reset_models_store_freshness()`: zeroes `checkedAt` on every entry of `$AGENT_HOME/agent/models-store.json` via node; keeps `etag`/`lastModified`/`models`; silent no-op when the file is absent; WARN (file untouched) on invalid JSON. Wired into the Run section. |
| [`tests/test_providers_pi_preflight.sh`](tests/test_providers_pi_preflight.sh) | 4 new tests: zeroes `checkedAt` on all entries; preserves etag/lastModified/models; no-op when store absent; warns on invalid JSON. File total 18 passed. |
| [`src/reasoning/providers/pi/base.dockerfile`](src/reasoning/providers/pi/base.dockerfile) | pi pin `0.84.1` -> `0.85.1` (pi-bump). |
| [`src/reasoning/providers/pi/config/agent/settings.json`](src/reasoning/providers/pi/config/agent/settings.json) | `lastChangelogVersion` -> `0.85.1` (pi-bump). |
| [`devlog/roadmap_future.md`](devlog/roadmap_future.md) | M7 Dependency Security pinned-version note -> `0.85.1` (pi-bump). |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Freshness-reset item recorded and closed. |

## Deferred items
(none)
