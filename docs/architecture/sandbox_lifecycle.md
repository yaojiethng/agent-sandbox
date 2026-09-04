# Sandbox Lifecycle

This document describes the capability layer session arc: how project content enters the sandbox, how the agent works, and how changes are returned to the host.

The reasoning layer lifecycle — provider config copy-in, input channels, copy-out — is in [`provider_lifecycle.md`](provider_lifecycle.md). How the two layers are wired together — mount shape, compose generation, start/stop sequencing — is in [`execution_model.md`](execution_model.md). The conceptual delivery models this lifecycle implements: [`copy_delivery.md`](../concepts/copy_delivery.md) (current) and [`mount_delivery.md`](../concepts/mount_delivery.md) (wired, not runnable).

The sandbox is the unit of isolation. The current implementation uses git for baseline tracking and diff generation — this is an implementation choice, not an architectural constraint.

All snapshot and diff functions are defined in `libs/snapshot.sh` and `libs/diff_export.sh`, sourced by both `scripts/start_agent.sh` and the capability layer entrypoint.

---

## Overview

A capability layer session has three phases:

1. **Fork** — the host project state is replicated into the sandbox before the containers start. The host repository is never modified.
2. **Work** — the agent operates exclusively inside the sandbox. The host is untouched.
3. **Join** — the agent's changes are packaged as diffs and written to the host for operator review.

---

## Phase 1 — Fork (Volume Seed Pipeline)

The seed pipeline replicates the host repository state into the capability layer sandbox volume. The seed is the helper-container transport: a one-shot seeder service (the sandbox image) fills the volume before the sandbox container exists. Design and requirement mapping: [`docs/adr/sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md), 2026-09-04 entry.

### Host side (`scripts/run_agent.sh` seed_sandbox_volume)

On a fresh start (`--reset-volume`, copy delivery), `run_agent.sh` runs the `seeder` compose service once (`docker compose run --rm -T seeder`). The seeder mounts the project read-only at `/src` and the session volume at the sandbox service's own target path (first-mount ownership initialization: the volume root inherits the image directory's `agentuser` ownership). The seeder's exit code is the only readiness signal: the invocation is timeout-bounded (`SEED_TIMEOUT`, default 300s), and a nonzero exit or timeout aborts the start and discards the session volume. Resume never seeds.

Inside the seeder (`src/capability/seed_volume.sh`):

1. **Guards (fail closed, readable errors):** repository tracks the `.agent-sandbox-seed/` sentinel (harness staging captured by a host commit), linked worktree (`.git` is a gitfile), no commits (unborn HEAD), submodules (the gitlink would cross without its content).
2. **Repository copy** — `cp -a /src/.git /dest/.git`: the repository crosses natively, index included; no reset runs, so the volume's `git status` is porcelain-identical to the operator's repo (staging state preserved).
3. **Working tree copy** — git enumerates the working tree (tracked files still on disk plus untracked non-ignored files, all ignore sources honored, negation patterns included); an existence filter drops tracked paths absent from the disk, so unstaged deletions are visible in the volume; tar streams the enumerated set pipe-to-pipe. The stream never touches an intermediate location, and no harness state is written into the operator's worktree (R7).
4. **SESSION_STATE** — the seeder writes `init_sha` (HEAD at seed time; the fixed lower boundary for `package-branch`), `session_ts`, `session_id`, and `host_head_sha` into the volume's git directory.
5. **Self-verification** — `git status --porcelain` is compared between `/src` and `/dest`; any divergence aborts the seed.

The seed guarantees the full working tree state matrix in the volume:

| Operator state | git status in sandbox |
|---|---|
| Untracked file | `??` untracked |
| Tracked file with unstaged edits | ` M` unstaged modification |
| Tracked file with staged edits | `M ` staged (staging state preserved) |
| Tracked file deleted without staging | ` D` unstaged deletion |
| Gitignored file | Not visible |

### Capability layer side (entrypoint)

The entrypoint validates the volume: git state and `SESSION_STATE` must exist (the seeder wrote them); an unseeded volume aborts the container start with a readable error. Workspace paths (`changes_dir`, `input_dir`, `output_dir`) are written to `SESSION_STATE` deterministically on every start.

### Harness directory lifecycle

No staging exists anywhere: the seeder streams content directly into the volume and nothing is ever extracted into the operator's worktree. On a resumed session, the seed step is skipped entirely.

### Resume path (M2.6.2 volume-based persistence)

**Current — single-volume model:**

```
volume exists + REFRESH not set?
  ├── No  → normal init
  │         Host: compute fresh identity, run the seeder
  │         Container: .git present → validate + write workspace paths
  └── Yes → resume
            Host: read identity from the compose registry, skip seeding
            Container: .git present → validate + write workspace paths
```

Host-side identity is recorded in the per-run compose registry (`.compose/<session-id>.yml`) and, for copy-mode resume, read from the named volume's Docker labels. The legacy `.run-identity` cache file is deprecated and no longer written.

**Session start (M2.6.5):** `start` always begins a NEW session; resume is split out into `make resume`. `make start INTERACTIVE=1` opens the config wizard (pick a provider + build policy, confirm, then start); provider and `.env` values otherwise come from the Makefile/`.env`.

```
--refresh/--rebuild passed?
  ├── Yes → new session (rebuild images + fresh volume + full seed)
  └── No  → new session (fresh volume + full seed)
            start carries no resume path (F2 design D10); to resume a
            previous session, use the split-out `make resume` command.
```

**Session resume (`make resume`):** the resume command reads identity from the per-run compose registry (`.compose/<session-id>.yml`) rather than Docker volume labels. `make resume SESSION_ID=<id>` selects exactly one session and resumes silently. `make resume LIST=1` lists registry sessions in an enriched table (`SESSION_ID | PROVIDER | STARTED | BRANCH | LAST_USED`) filtered by an optional `PROVIDER=<n>`, capped at 10 rows per page (same cap as the draft picker; remainder reported in a footer). `STARTED` and `LAST_USED` are relative times ("2 hours ago"; `LAST_USED` = time since the session was last stopped, read from its `.compose/<session-id>.log` per-session activity log; `---` when the session is running or never stopped). The table sorts newest-first by the raw `session-ts`. Staleness is reported exception-only as a warning label rather than an always-present column: `[SANDBOX_STALE]` when the record's `host-head-sha` differs from the current project HEAD (worktree identity, ADR harness_versioning.md); no label when fresh or unknown. Image staleness is retired -- the record's `*-image-digest` labels are identity, and the list path makes zero docker calls.
`make resume INTERACTIVE=1` presents a picker over the inventory and confirms before resuming (also `PROVIDER=<n>`-filterable); the picker marks `[SANDBOX_STALE]` sessions and paginates at 10 rows. The legacy volume-label resume machinery was removed from `start` (see `20260821-04`).

**Session prune (`make prune`):** the registry-based prune (Rules 1+2, `20260821-08`) replaces the legacy volume-label `--stale` + `docker system prune` path. It is always a complete pass: **Rule 1** removes stale `.compose/<session-id>.yml` records (selected by registry-truth sandbox staleness or image-staleness per the `STALE` kind — default `all` picks a record stale by either dimension — plus optional `PROVIDER` / `AGE_DAYS` filters); **Rule 2** removes now-orphaned resources (containers, networks, volumes labeled `sandbox-dir` whose `session-id` has no record), delivery-scoped (copy → volume + containers; mount → registry resources only; worktrees never touched). `DRY_RUN=1` simulates, `INTERACTIVE=1` confirms.
`STALE=sandbox|image|all` select the sandbox-stale / image-stale / either criterion; image staleness compares the referenced image's baked `container-sig` label against a recomputation of the current source (`20260821-09`).

---

## Phase 2 — Work

The agent works exclusively inside `sandbox/`. The host repository is never mounted and cannot be reached from inside the container.

---

## Phase 3 — Join (Diff Pipeline)

On capability layer container exit, an EXIT trap runs the diff pipeline. The entrypoint constructs the output path via `export_path` (from `routing.sh`) and calls `diff_export`, which delegates to `package_branch`:

1. **`package_commits`** — Produces one numbered `.diff` file per agent commit since `init_sha`, written into `patches/`. Git index lines are stripped. No sweep commit — uncommitted changes are captured separately.
2. **`write_uncommitted_diff`** — Captures working tree delta from HEAD as `uncommitted.diff`. Includes untracked files via temporary `git add -N` staging.
3. **`write_all_changes_diff`** — Captures net delta from `init_sha` (committed + uncommitted) as `all-changes.diff`.
4. **`write_changed_files`** — Copies all changed files into `changed-files/` with `MANIFEST.txt`, preserving directory structure.

No sweep commit is performed. Uncommitted changes are preserved in the working tree — `diff_export` never commits.

All artefacts land in the session export directory constructed by `export_path`:

```
workspace/session-diffs/session/<EXPORT_TIME>-<SESSION_ID>/
  .export-status        — STATUS, TIMESTAMP, INIT_SHA (and EXIT_CODE on failure)
  uncommitted.diff      — uncommitted changes vs HEAD (no sweep)
  all-changes.diff      — net delta init_sha..HEAD
  patches/
    0001-abc1234-<subject>.diff  — per-commit diffs from package_branch
    0001-abc1234-<subject>.msg   — full commit message for each diff
  changed-files/
    MANIFEST.txt
    <path>/<file>        — working tree copies of all changed files
```

### Autosave

The autosave loop runs inside the capability container on a configurable interval (default 60s). Each cycle overwrites a single directory:

```
workspace/session-diffs/autosave/<SESSION_ID>/
  .export-status        — STATUS, TIMESTAMP, INIT_SHA (updated each cycle)
  uncommitted.diff      — uncommitted changes vs HEAD
  all-changes.diff      — net delta init_sha..HEAD
  patches/
  changed-files/
```

Only one autosave directory exists per session — the old one is `rm -rf`'d before each write. No accumulation, no pruning needed within a session.

`workspace/session-diffs/session/` accumulates one directory per container stop and is not automatically pruned.

### Apply workflow

On the host, `agent-sandbox` dispatches to routers in `routing.sh` which resolve the appropriate diff file or source directory, then pass the resolved path to the workflow library:

**`make draft [BUNDLE=<name>] [CHANNEL=<channel>]`** — resolves a source directory via routing (`session`, `autosave`, or `bundles` channel), then applies `patches/*.diff` sequentially followed by `uncommitted.diff` if present. Creates a `draft/<EXPORT_TIME>-<slug>-<sha6>` branch. `BUNDLE` is name-only (rejected if absolute).

**`make draft FROM=bundles`** — shorthand for `--channel=bundles`. Resolves from `output/bundles/`.

**`make draft FROM=autosave`** — shorthand for `--channel=autosave`. Resolves from `session-diffs/autosave/`.

**`make draft INTERACTIVE=1`** — interactive mode: guides the operator through a two-step numbered picker (channel then bundle) instead of requiring explicit `BUNDLE=` or `FROM=` arguments. After selections are made, the equivalent non-interactive command is printed (e.g. `Running: make draft CHANNEL=session BUNDLE=<name>`). When `BUNDLE=<name>` is provided and the named bundle is not in the displayed list, it is injected as option 0 and becomes the default. When more bundles exist than the display limit (10), `n` and `p` navigate between pages.

**`make confirm [TARGET=<branch>]`** — cleans up the draft branch after the operator has rebased and merged.

**`make reject`** — discards the draft branch. Artefacts unchanged.

**`make apply DIFF=<path>`** — applies an exact diff file via `git apply` with index lines stripped. `DIFF=<path>` is required; no channel, bundle, or auto-resolution is performed. No commits created.

**`make apply INTERACTIVE=1`** — interactive mode: prints a git-oneline-style preview of the changes (the files the diff touches and the total file count), then asks for confirmation with a single y/N prompt before applying.

**`make package-branch [BUNDLE_SUMMARY=<text>] [BASELINE=<sha>]`** — runs `agent-sandbox package-branch`, which writes to `OUTPUT_DIR/bundles/<ts>[-<summary>]-<runid>/`. Produces `patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, and `changed-files/`. `BASELINE=<sha>` diffs against an explicit SHA instead of the session baseline.

No checkpoint git tags are used. No `git am`. No `docker exec`. All correspondence flows via diff files through the bind-mounted workspace.

---

## References

| Topic | Document |
|---|---|
| Correspondence model — three cases, bidirectional flow | [../concepts/sandbox_host_correspondence_model.md](../concepts/sandbox_host_correspondence_model.md) |
| Reasoning layer lifecycle | [provider_lifecycle.md](provider_lifecycle.md) |
| Mount shape and container wiring | [execution_model.md](execution_model.md) |
| Mount shape guarantees | [tool_interface.md](tool_interface.md#mount-shape-guarantees) |
| Project onboarding | [../operations/project_onboarding_guide.md](../operations/project_onboarding_guide.md) |
