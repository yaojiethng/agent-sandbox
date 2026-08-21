# Agent Handover

**Date:** 2026-08-21
**Milestone:** M2.6 — Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective
Consolidate image-staleness across every surface that reasons about a session's freshness, now that the criterion is shared (`src/libs/container_sig.sh` `image_is_stale`, from `20260821-09`):
1. **`resume --list`** — add an image-staleness column to the enriched session table (alongside the existing sandbox-staleness column). Explicit operator ask (image-staleness column previously deferred from `20260821-05`).
2. **`make start`** — consolidate the rebuild-required check to shared staleness logic: rebuild sandbox/agent when their image is image-stale (rather than only on explicit `REFRESH`/`REBUILD`/missing-image). Explicit operator ask.
3. **"Anywhere else we missed it"** — sweep remaining consumers: `resume --interactive` picker, `serve`/`dry-run` (share start_agent), `preflight` warning (already shared). Ensure one canonical `image_is_stale`/`record_image_stale` everywhere.

## What exists today (grounding)
- **Criterion:** `src/libs/container_sig.sh` `image_is_stale <image> <type:sandbox|agent> <repo_root> [provider]` → `fresh|stale|unknown` (baked `agent-sandbox.container-sig` vs recomputed source sig). Shared by `build.sh` `_check_container_sig` (warning) and `prune.sh` `STALE=image`.
- **`record_image_stale <file>`** currently lives in `scripts/prune.sh` (derives agent + sandbox images from a record's `image: <provider>-agent-<proj>` line, returns `fresh|stale|unknown`). Not yet shared — resume would duplicate it. **Should be lifted into the shared lib** alongside `image_is_stale`.
- **`resume_agent.sh`:** `build_inventory` (in `session_inventory.sh` is NOT shared — it's local to resume) emits `SESSION_ID|provider|session-ts|branch|stale` (5 fields; `stale` = sandbox staleness via `session_stale`). `--list`/`--interactive` print this. resume sources `session_inventory.sh` (record helpers) but NOT `container_sig.sh` (it reaches `image_is_stale` only transitively via build.sh in the resume path — not before `--list` returns). So `--list` needs a direct `source container_sig.sh` (pure, cheap).
- **`start_agent.sh` (lines ~353-376):** sources build.sh; rebuilds only on `REBUILD`/`REFRESH`; then `preflight(provider, project, repo_root)` (build_missing=true) which warns via `_check_container_sig` on image staleness. `serve`/`dry-run` share start_agent (mode arg) → same path.
- **Docker stub** already supports per-image container-sig (`DOCKER_STUB_IMAGE_SIG_LABELS` — the per-image sig map, added `20260821-09`), so `resume --list` / `start` staleness is stub-testable.

## Design decisions (Gate 2 settled — operator `2026-08-21`)
1. **`--list` column shape:** **two columns** — `sandbox-stale | image-stale` (mirrors the terminology dimensions; the distinction is the point).
2. **Entry cap + pagination:** cap displayed entries at **10 per page** (same as draft's `INTERACTIVE_MAX_ENTRIES=10`, `scripts/workflows/interactive.sh` L32). `--interactive` gets real pagination for free via `interactive_pick`'s existing `PAGE_SIZE` arg (n/p nav). `--list` (non-interactive) caps at 10 with an honest footer (e.g. `(...N more sessions — use --interactive or --provider= to narrow)`). **One shared constant** so both consumers agree.
3. **`start` contract: unchanged.** No behavior change — only confirm the staleness *check* is the common implementation. Already true: `start_agent.sh` → `preflight` → `_check_container_sig` → `image_is_stale` (shared lib, refactored `20260821-09`). Deliverable = verify + (if missing) a test proving start's staleness warning goes through the shared lib; warning presentation unchanged.
4. **`--interactive`:** add image-stale marker in the picker (`[IMG-STALE]` alongside `[STALE]`/`[status]`). One backing change (6-field inventory) feeds both `--list` and `--interactive`.

## Implementation plan
1. **`src/libs/container_sig.sh`**: add `record_image_stale <file> <repo_root>` (moved verbatim from `scripts/prune.sh` L192-207, signature gains `repo_root` to match `image_is_stale`). One copy; prune + resume consume it.
2. **`scripts/prune.sh`**: delete the local `record_image_stale`; call the lib version (`record_image_stale "$f" "$REPO_ROOT"` — 3 call sites: L164, L167-168, and inside Rule 1 selection).
3. **`scripts/resume_agent.sh`**: `source "$REPO_ROOT/src/libs/container_sig.sh"` next to the session_inventory source (L83, before `build_inventory` at L90); `build_inventory` gains a 6th field `image_stale="$(record_image_stale "$f" "$REPO_ROOT")"` → `sid|provider|ts|branch|sandbox_stale|image_stale`.
   - `--list` (L125-148): header `[sandbox stale] [image stale]`; per-row `printf` with both columns; cap at page size + footer when more.
   - `--interactive` (L150-174): PICKER display gains the image marker; `interactive_pick ... PICKER "" "$PAGE_SIZE"` passes the 10-page cap.
   - Page size constant: one place — resume defines `RESUME_PAGE_SIZE=10` (or reuse `INTERACTIVE_MAX_ENTRIES` name); keep the same value as draft's 10.
4. **`start`/serve/dry-run**: no change (already shared via `_check_container_sig`).
5. **Tests** (`tests/test_resume.sh` — direct resume invocation, no stub currently):
   - New tests set `PATH="$REPO_ROOT/test/stubs:$PATH"` + `DOCKER_STUB_IMAGE_SIG_LABELS` (per-image map from `20260821-09`) so `image_is_stale` hits the stub.
   - Property tests: (a) image-stale record shows `image-stale` column + `[IMG-STALE]` marker; (b) sandbox-fresh + image-stale → columns independent (both visible); (c) fresh-image record (per-image recomputed sigs) shows `image-fresh`; (d) `--list` caps at 10 with footer when >10 records; (e) picker paginates at 10 (n key) — optional; (f) existing sandbox-staleness + enriched tests still green (they'll see `image_stale=unknown` for stub-less runs — best-effort, must not break existing greps).
   - `tests/test_prune.sh` unchanged semantics; verify green after the `record_image_stale` move.
6. **Docs**: tool_interface (`resume --list` two stale columns + cap, `resume --interactive` marker), quickstart (`make resume --list` example row shape), sandbox_lifecycle if it shows the list; terminology `## staleness` already covers both dimensions.
7. **Verify**: full suite deterministic ×3; shellcheck clean; installed CLI `resume --list`/`--interactive` render (stale-CLI heuristic: diff installed `Valid subcommands` / usage after touching `scripts/agent-sandbox.sh` — resume is dispatched from it, so re-run `make install` check).

## Open questions for the operator
- `--list` cap footer wording + whether the cap should also apply to `--list` at all (non-interactive) — default: cap + footer.
- `--interactive` marker text: `[IMG-STALE]` (proposed) vs `[IMAGE-STALE]`.

## Completed (pre-close record)

| File | Change |
|---|---|
| `src/libs/container_sig.sh` | `record_image_stale <file> <repo_root>` lifted from prune.sh (moved verbatim, signature gains `repo_root`) — one record-level image-staleness criterion shared by prune + resume |
| `scripts/prune.sh` | Local `record_image_stale` deleted; both call sites pass `"$f" "$REPO_ROOT"` to the lib version |
| `scripts/resume_agent.sh` | Sources `container_sig.sh`; `build_inventory` emits 6 fields (`sid|provider|ts|branch|sandbox_stale|image_stale`); `--list` prints both columns, capped at `RESUME_LIST_PAGE_SIZE=10` with a stderr remainder footer; `--interactive` PICKER marks `[STALE]`/`[IMG-STALE]` and passes `PAGE_SIZE=$RESUME_LIST_PAGE_SIZE` (pagination); usage text updated |
| `tests/test_resume.sh` | +6 property tests: image-stale column, image-fresh when sigs match, independent columns (sandbox-fresh+image-stale), `[IMG-STALE]` picker marker, `--list` caps at 10 with footer, picker paginates at 10 |
| `tests/test_trace_build.sh` | `test_check_container_sig_warns_via_shared_predicate` — stale sig warns / matching sig silent via the shared `image_is_stale` (start's preflight surface) |
| `docs/architecture/tool_interface.md` | `resume LIST=1` two stale columns + 10-row cap; `INTERACTIVE=1` marker + pagination |
| `docs/architecture/sandbox_lifecycle.md` | Resume list table + cap + markers documented |
| `docs/development/quickstart.md` | Resume list description updated |
| `devlog/roadmap.md` | L250 entry extended with the `20260821-10` follow-up (resume surfaces + start preflight confirmation) |

**Gate-2 settlement (`20260821-10`):** two columns; 10-row cap shared with draft (`INTERACTIVE_MAX_ENTRIES=10`); start contract unchanged (already shared via `_check_container_sig` — verified + locked by test); interactive marker `[IMG-STALE]`. Footer on stderr keeps the `--list` data stream clean.

**Findings (new this iteration):**
- F-B1: `local` at top-level script scope in the `--list` block aborts (`local: can only be used in a function`) — fixed with plain `shown`/`remaining` vars (top-level blocks are not functions).
- F-B2: quoted `<<'EOF'` heredoc in `usage()` does not expand `$RESUME_LIST_PAGE_SIZE` — hardcoded `10` in the usage text (constants in heredocs must be literal).
- F-B3 (test authoring): `_check_container_sig` agent-form arg order is `<provider> <repo_root>` — my first test passed them reversed, producing a shifted `container_sig <provider> ...` trace; fixed the test, code was correct.
- F-B4: `--list` footer goes to stderr — the cap test initially captured stdout only and missed it.

## What's Next
- Pre-close review (Gate 3): present AC status + full-suite output. Suite **500/500**, deterministic across 3 runs.
- Set Status `Closed` and commit after release.

## Deferred / not in scope
- N3 mount-point lock (separate).
- Auto-rebuild-on-stale for `start` (explicitly out per Gate-2 #3 — contract unchanged).