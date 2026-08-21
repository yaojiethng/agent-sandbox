# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Wire **image-staleness detection** into prune so `make prune STALE=image` selects image-stale sessions (deferred in `20260821-08`, roadmap entry L253). Today `STALE=image` raises "not yet implemented" (D8-6). Image staleness means the baked `agent-sandbox.container-sig` label ≠ recomputed source sig, so even resuming the session carries an incomplete/outdated feature set. See `docs/concepts/terminology.md` `## staleness` (image staleness dimension, registered `20260821-08`).

## What exists today (grounding)
- **Criterion source of truth:** `scripts/build.sh` — `container_sig <repo_root> <source_path...>` (pure hash), `_sandbox_sig_sources()`, `_agent_sig_sources <repo_root> <provider>`, and `_check_container_sig` (warning-only, called from `preflight`). Reads the baked label via `docker image inspect --format '{{ index .Config.Labels "agent-sandbox.container-sig" }}'`, recomputes, warns on mismatch. The sig hash is over the source files `/opt/sandbox` + `/opt/workflow` (sandbox) and `src/reasoning/providers/<provider>/` (agent).
- **Sig recompute root = agent-sandbox REPO_ROOT (self):** build/start/resume pass the agent-sandbox repo root, not the user project. prune self-locates `REPO_ROOT` — no new flag needed for recompute. (`--project` in prune is only the git HEAD source for sandbox staleness.)
- **Image naming:** `src/build/image.sh` — `agent_image_name(provider,project)` = `<provider>-agent-<proj-lower>`, `sandbox_image_name(project)` = `sandbox-<proj-lower>`. build.sh sources image.sh.
- **prune Rule 1 today:** `rule1_selected_records` selects sandbox-stale records (host-head-sha ≠ current HEAD) AND older than `AGE_DAYS`, narrowed by `PROVIDER`. `STALE=` is validated but only `sandbox|all|` act; `image` errors.
- **Record shape:** `.compose/<session-id>.yml` embeds `image: <provider>-agent-<lower-project>` (agent service) — so provider and lower-project are recoverable from the record; the referenced sandbox image = `sandbox-<lower-project>`.

## Design decisions (Gate 2 settled)
1. **Reuse / canonical home — option B (operator `2026-08-21`):** lifted the pure fns into `src/libs/container_sig.sh` with a shared `image_is_stale` predicate; sourced by build.sh + prune; `_check_container_sig` delegates to it (one criterion, two consumers).
2. **`STALE=all`/unset = either criterion** (sandbox-stale OR image-stale) — the "remove all stale" filter. `STALE=sandbox`/`image` select that dimension only. `AGE_DAYS`/`PROVIDER` still narrow whichever records pass. Rule 2 (resources) is delivery-based and unchanged; the complete-pass partition invariant holds.
3. **Per-record image classification:** images derived from the record's agent-image line (`<provider>-agent-<lower-project>`); agent + sandbox (`sandbox-<lower-project>`). A session is image-stale if either referenced image is stale; `unknown` when not determinable (missing image / no label).
4. **Sig recompute root = self-located `REPO_ROOT`** (agent-sandbox repo; build/start/resume already use it) — no new flag.
5. **No-live-docker tests:** docker stub `docker image inspect` container-sig via `DOCKER_STUB_IMAGE_SIG_LABELS` per-image map / single fallback; property tests (image-stale selected, image-fresh kept via recomputed sigs, OR semantics).

## Completed (pre-close record)

| File | Change |
|---|---|
| `src/libs/container_sig.sh` | NEW shared lib: `container_sig`, `_sandbox_sig_sources`, `_agent_sig_sources` (moved from build.sh) + `image_is_stale` predicate (`fresh|stale|unknown`) |
| `scripts/build.sh` | Source the lib; remove local sig fns; `_check_container_sig` delegates to `image_is_stale` (single criterion for build + prune) |
| `scripts/prune.sh` | Source container_sig lib; `STALE=image` selects image-stale records; `STALE=all`/unset = sandbox OR image; `record_image_stale` derives images from the record's agent-image line; removed the "not yet implemented" guard; help/header updated |
| `scripts/templates/Makefile.template` | `STALE=sandbox|image|all` documented; removed "not yet implemented" |
| `test/stubs/docker` | `docker image inspect` container-sig via `DOCKER_STUB_IMAGE_SIG_LABELS` (per-image map) / `DOCKER_STUB_IMAGE_SIG_LABEL` fallback |
| `tests/test_prune.sh` | NEW image-staleness property tests: selects image-stale, keeps image-fresh (recomputed per-image sigs), `STALE=all` OR semantics (image-stale+sandbox-fresh pruned by all, kept by sandbox-only) |
| `tests/test_trace_stop.sh` | `--stale=image` selects+removes image-stale record (replaces not-implemented guard) |
| `docs/architecture/tool_interface.md` | `STALE=sandbox\|image\|all` documented |
| `docs/architecture/sandbox_lifecycle.md` | image-staleness criterion documented (`20260821-09`) |
| `devlog/roadmap.md` | L253 image-staleness detection marked `[x]` (done) |

**Key decisions:** Gate 2 = **B** (shared `src/libs/container_sig.sh`), **all = sandbox OR image**, **cleaner** (`_check_container_sig` delegates to the shared predicate). Sig recompute uses the self-located agent-sandbox `REPO_ROOT` (no new flag). `image_is_stale` is best-effort (`unknown` on missing image/no label) and always returns 0 (safe under `set -e`).

## What's Next
- Pre-close review (Gate 3): present AC status + full-suite output. Suite **492/492**, deterministic across 3 runs.
- Set Status `Closed` and commit after release.

## Deferred / not in scope
- Image-staleness *column* in `resume --list` (separate; not requested).
- N3 mount-point lock (separate).