# Agent Handover

**Session date:** 2026-08-18
**Milestone:** M2.6.6 — Mount Model: Host-backed Sandbox
**Session type:** Design (resolve open design questions via grill-me)
**Status:** Closed

## Objective

Resolve the M2.6.6 open design questions (design record `devlog/discussions/20260730-design-settled-mount_model.md`) via the grill-me process: one question at a time, recommended answer each, codebase evidence instead of asking where the code answers. Also settles the three grouped M2.6 decisions (prune-command redesign, session-naming collision, `start`-command redesign) per the roadmap refile (operator steering 2026-08-18).

## Outcome

The design walk is complete: all open mount-model questions settled, the grouped decisions settled, accepted the operator's corrections and counterproposals throughout, and the design record formally refreshed. Follow-on implementation is task-tracked (see Tasks). Both process corrections from the walk were logged as records (GOTCHAS append-anchor `[G] 2026-08-18`; AGENT_FEEDBACK `[A] 2026-08-18` ×2).

## Decisions (compact)

*Transient numbers would be misleading here — persistent records reference decisions by descriptive name (documentation_policy §Numbering and cross-references). Full rationale per decision lives in the design record; this list is the compact settlement.*

**Delivery & compose**
1. **Compose file sets** — mode-selectable file set chosen at generation time via the existing `compose_generate` pipeline (base + copy/mount overlays merged through `docker compose config`); no YAML conditionals; the sandbox `volumes:` block handled at generation. The copy-only `SNAPSHOT_DIR` mount/env moves into the copy overlay (not the base), so mount-mode compose never inherits it.
2. **Writable layer is per-run** — verified: teardown = `docker compose down` at every run end (EXIT trap); the container filesystem (installs, caches, `/tmp`) is destroyed every run; the worktree is the only durable place. Durable rule wording for prompts/docs settled.
3. **In-tree generated artifacts** — land inside the mount; the harness explicitly does NOT control or maintain them (gitignored; the project provides setup instructions; current state, not locked). Harness-owned state (registry, volumes, containers, harness dirs) remains prunable.
4. **`--volumes-from` retained** — reasoning layer reaches the worktree only via the capability layer's propagated mount; `security.md` invariant 7 unchanged.
5. **Copy-in mechanism** — status quo kept: RO-mount-at-start. Host-side volume seeding (no snapshot mount, identical fresh/resume compose) parked as a deferred task (M2.6.5 follow-up) with the two vestigial operations as subtasks (always-mounted `SNAPSHOT_DIR`; unconditional `baseline.tar` preflight gate).

**Start / wizard**
6. **`make start` wizard** — interactive-by-default: run inventory first (copy runs via labels; bind-mount runs via registry) → resume-N or new; config prefilled from the newest run's record; prints the full non-interactive command at end; `--run=<id>` resumes (absence = new; terminology sweep); no `new/resume` subcommand split. Fresh runs always get the freshest container: implicit `--rebuild` auto-downgraded to `--refresh`/no-op by staleness detection (container image digest + config check).

**Registry & identity**
7. **Per-run registry** — no `.env` pinning; each run's effective config (delivery, provider, execution mode, identity) is recorded in the persisted `.compose/<run-id>.yml`, which becomes the registry/record of the run and the source of session memory. Prune rules: (1) `.compose/*.yml` per prune args; (2) a run with no matching `.compose` record is prunable — scope differs by delivery (copy: volume+containers; mount: registry resources only; worktrees never touched).
8. **Identity** — two-level model unchanged: per-run `RUN_ID` (never reused; compose filename + container names), `SANDBOX_ID` frozen once per sandbox (derivation kept — `hash(SANDBOX_DIR : HOST_HEAD_SHA)`, the branch-point tag; copy freezes via volume labels, mount via the first registry record). Resume = config-recall, never container-resume. Host-side identity folds into the registry; **`.run-identity` completely deprecated** (no runtime consumer; refactor task filed; consumer inventory verified). **`SESSION_STATE` RETAINED** for both shapes (container-side, co-located provenance for the in-container export machinery — the registry is invisible to containers and prunable); mount writes it into the worktree's `.git` (metadata, doubles as the init marker).
9. **Worktree** — single shared worktree per sandbox at `$SANDBOX_DIR/.worktree/` (default; custom mount point as a `make start` arg, injected into compose at generation). Copy staging relocates to per-run tmp; `.snapshot` disappears from `SANDBOX_DIR`; copy-in happens once per run-id at volume creation; resume stages nothing.

**Concurrency & persistence**
10. **Locking** — flock per mount point (`$SANDBOX_DIR/.locks/<hash(mount-source)>.lock`), held by the start process for the run lifetime; lock file outside the worktree. Copy keeps `volume_in_use` (no copy↔mount blocking); parallel runs = distinct mount points. Re-init always acquires the lock first (no TOCTOU absence checks); flock auto-releases on process death.
11. **Persistence model** — containers strictly per-run; persistence is delivered exclusively by mounted sources (worktree, workspace dirs, registry, explicitly-designated durable volumes) — never container state (Container State Contract extended). Environment-change persistence (apt, `pi install`/`pi update --self`) explicitly not in scope; deferred item filed (parked candidate: persisted install-cache volume fed per run).
12. **Start contract** — first run materializes the worktree via the shared snapshot primitive (copy pipeline minus `baseline.tar`; "starts off as a snapshot"); start validation = `.git` present + init marker; no clean-HEAD requirement; work off the worktree's current branch (no silent switching); mount entrypoint minimal (workspace path resolution; healthcheck unchanged — `.git` presence). Port-back under mount = the existing `package_branch`/`make draft` diff machinery (fresh repo has no common ancestor, so diffs are the vehicle). Future clone strategies (incl. git history — enabling git-based port-back) are sequenced into M2.6.6 after the current task set.

**Prune & terminology**
13. **Prune** — rule 2 confirmed now; the command-shape redesign is deferred until after M2.6.5/M2.6.6 artifact shapes settle. `STALE=1` rejected as terminology (boolean-vs-filter, prune-vs-keep, unknown "everything" command, scope incl. active containers undefined). Redesign minimums: interactive mode showing the cutoff + confirmation, descriptive option names, explicit scope semantics.
14. **Terminology** — "agent run" (one container lifecycle, run-id identified, its networks/volumes/registry record, artifacts spanning iterations or one draft branch) + "agent iteration" (work cycle producing handover + commit); keyword "session" reserved and retired from live use; both registered as STE Technical Names. Programmed sweep (`SESSION_TS→RUN_TS`, `SESSION_STATE→RUN_STATE`, `session-diffs→run-diffs`, `RESUME_SESSION→RESUME_RUN`, `--session→--run`…) is its own roadmap task. Delivery language: "project delivered via copy-in / via bind-mount", keywords `copy|mount`.

## Completed this session

- Grill-me walk of all open questions (Q1/Q3/Q5/Q6 retired with evidence; Q2, Q4, Q7 settled; N1–N5 created and settled one at a time, each with operator approval).
- Grouped decisions settled: prune (rule 2 confirmed; shape deferred), naming (agent run + agent iteration), start (wizard).
- Codebase verification where claims bore weight: per-run teardown, snapshot `.git` exclusion, routing path uniqueness, volume/container labels, entrypoint branches, `.run-identity` consumers, dry-run path.
- Design record formally refreshed (Open questions → settled summaries); roadmap updated (design task closed, delivery/terminology/deferred tasks filed); GOTCHAS + AGENT_FEEDBACK entries logged.

## Tasks

**Roadmap-tracked (M2.6.6):**
- Mount delivery enablement — depends on the compose file-set decision.
- Compose template — realizes the file-set decision (copy overlay carries the snapshot mount).
- `.run-identity` deprecation — host-side identity fold into the registry (consumer inventory in the decision above).
- Terminology sweep — agent run / agent iteration, session reserved (own task, not bundled with the design task).
- Mount worktree with git history — future clone strategy, sequenced after the current task set.

**Deferred (roadmap_future):**
- Host-side volume seeding (M2.6.5 follow-up; depends on the file-set mechanism; subtasks: drop always-mounted `SNAPSHOT_DIR`, re-scope the `baseline.tar` preflight gate).
- Environment-change persistence — not in scope, parked candidate.
- Prune command-shape redesign — deferred until artifact shapes settle.

**Carried notes:**
- Dry-run change-source gap (testing ported changes; F-dryrun) — resolve with the start-validation/wizard work.
- Entrypoint branch inversion cleanup (`if ! -d .git` → init; else → resume bookkeeping) — M2.6.6 delivery scope.
- Docs sweep to the settled names (identity lifecycle, execution_model, security unchanged per invariant-7 decision).
- Changelog extraction (M2.4, M2.6.x) + stale close-order label — M2.6 close housekeeping.

## Files in scope (read/grounding)

| File | Role |
|---|---|
| `devlog/discussions/20260730-design-settled-mount_model.md` | Design record — decisions + questions (formally refreshed) |
| `docs/architecture/execution_model.md`, `security.md` | Current architecture/security — mount shape, compose generation, Mount modes table |
| `src/build/docker-compose.yml` | Compose template (read) |
| `src/build/compose.sh`, `src/libs/dirs.sh` | Compose generation, path resolution |
| `scripts/start_agent.sh`, `scripts/run_agent.sh`, `scripts/stop.sh`, `scripts/prune.sh` | Lifecycle commands |
| `src/capability/entrypoint.sh`, `src/capability/snapshot.sh` | Snapshot copy-in, git baseline, entrypoint gating |
| `src/reasoning/providers/pi/` | Pi config seeding / bind-mount behavior |

## Acceptance criteria

- [x] All open design questions resolved as named decisions with rationale (stale questions retired explicitly)
- [x] 3 grouped M2.6 decisions settled (prune, naming, start) and recorded in the design record/roadmap
- [x] Roadmap checkboxes updated for each resolved item (design-question task, prune, naming, start)
- [x] Affected architecture docs updated to match settled decisions (security unchanged per decision 4)
- [x] Settled design presented to operator for confirmation