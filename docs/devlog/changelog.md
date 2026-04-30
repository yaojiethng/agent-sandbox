# agent-sandbox Changelog

Completed milestones extracted from `roadmap.md`. Each entry describes what the system can now do and the mechanisms built to enable it.

New entries are appended. Format is defined in `roadmap_policy.md`.

---

## [CORRECTION — 2026-04-12] Historical Inconsistency Warning

The following Milestone (M1.4) and its associated feature (Image Staleness Detection) was **DELETED** during the M2.1 refactor (2026-03-18). The changelog correctly reflects that it *was* completed at the time, but the code was later removed in favor of Docker layer caching at build-time. This removal led to a regression in the `start` flow where stale images are no longer detected.

---

## M1 — Barebones Agent Container

*The agent runs inside an isolated Docker container with network access, driven by a per-project Makefile.*

The core harness was established: Docker image, per-project config system, workspace output channel, and dry-run liveness check. Project identity is defined in a project-side Makefile; the container runs in `standard` mode. This is the minimum viable execution environment all subsequent milestones build on.

---

## M1.1 — Interactive Virtual Workspace / Serve Mode

*The agent can be prompted interactively from a browser on the host without a local OpenCode installation.*

OpenCode runs in server mode inside the container, exposed on a configurable port. Authentication and Windows client access were validated. This enables the operator to issue prompts and observe agent responses in real time through the OpenCode web interface.

---

## M1.2 — Sandbox File Isolation & Diff Workflow

*The agent works on a snapshot of the project and cannot access or modify the host repository directly; all changes are captured as a reviewable diff.*

Project files enter the sandbox via a host-built snapshot in `.bootstrap/`, constructed before the container starts. Gitignored files are excluded by construction; submodules are rejected with a clear error. Agent changes are captured by a modular diff pipeline (`libs/diff.sh`), producing `staged.diff` on exit and `autosave.diff` on interval. Apply scripts consume `staged.diff` and write back to the host via `git apply --3way`.

---

## M1.3 — Invocation Cleanup & Onboarding Workflow

*A single `agent-sandbox` CLI installed on the host dispatches all harness operations; new projects are onboarded via a Makefile and brief without touching the harness internals.*

The per-project conf file was removed in favour of named flags defined in the project-side Makefile with `PROJECT_ROOT` as `$(CURDIR)`. The `agent-sandbox` CLI wrapper handles build-if-missing and `--rebuild`. `start_agent.sh` and `build_agent.sh` are single-purpose scripts; apply scripts are unified into `apply_workspace.sh` with an optional `--branch` flag. Provider scripts and Dockerfile are flattened under `providers/opencode/`. Operator onboarding documentation and a provider-level debug reference are written.

---

## M1.4 — Image Staleness Detection [SUPERSEDED/REMOVED in M2.1]

*The harness warns the operator when the container image is out of date with the current source files before starting a run.*

**NOTE:** This implementation (based on `libs/image.sh` and `image-files.txt`) was **deleted in Milestone 2.1** during the Two-Container refactor. The system currently relies on the operator manually running `make build`.

A SHA-256 digest of all build inputs is embedded as a Docker image label at build time. At start time the digest is recomputed and compared; a mismatch produces a staleness warning and the run continues. Digest computation is centralised in `libs/image.sh` and covers all `libs/` files plus a provider-specific `image-files.txt`. The check applies to both `start` and `dry-run`.

---

## M1.5 — Workflow Convergence & Directory Restructuring

*The harness now separates the project repository from harness artefacts into sibling directories, keeping the project's git tree clean, and provides a dedicated operator input channel for passing task files and briefs to the agent before a run.*

Harness artefacts — snapshot, brief, workspace output — moved from `PROJECT_ROOT` into a sibling `SANDBOX_DIR`, eliminating harness pollution of the project git tree. The `.bootstrap/` directory was renamed `.agent-input/` and expanded to serve as the unified input channel: snapshot, brief, and operator-placed task files all enter the container through a single read-only mount. Directory names are defined once in `start_agent.sh` and passed to the container as environment variables, giving both host and container scripts a single source of truth. The `apply` subcommand now takes explicit `--project` and `--sandbox` flags, with the Makefile defining both paths so the operator workflow is unchanged. Open user stories (vault onboarding, website dev, knowledge store provider) were resolved or explicitly deferred to M2, and the workflow convergence decision was recorded. The onboarding skill was updated to reflect the new directory layout and modularised so that future convention changes require only variable updates.

---

## M2.1 — General Capability Layer Prototype

*The harness now runs two containers per session: a capability layer that owns the sandbox and diff pipeline, and a reasoning layer that runs the agent — proving the two-container model end-to-end against a real coding project.*

The single container was split into two. The capability layer initialises `sandbox/` from the project snapshot, records a baseline git commit, and writes `staged.diff` on exit via an EXIT trap. The reasoning layer attaches to `sandbox/` through Docker's `--volumes-from` mechanism and cannot start if the capability layer is not healthy — enforcing the ownership boundary at the infrastructure level. Docker Compose manages the two-container lifecycle; Compose files are generated from templates at each run. Build context for each image is assembled into a `mktemp` directory by `build_context` and discarded after the build, replacing the `image-files.txt` manifest. Onboarded template files carry a version tag; `build_sandbox.sh` detects stale installed files and prints a targeted refresh command. `make onboard` and `make refresh` targets in the repo Makefile handle the dogfood sandbox.

---

## M2.2 — Reasoning Layer Modularisation

*Any reasoning layer provider can now be added under `providers/<n>/` without modifying shared harness scripts or libraries.*

The provider interface was formalised: each provider supplies a `base.Dockerfile` (stable install layers), a `provider.Dockerfile` (runtime config and entrypoint), a serve overlay, and an `.env.example`. The harness discovers providers by glob and injects harness-owned files (`provider-entrypoint.sh`, `dirs.sh`, default config) into the build context at build time. Provider config lifecycle is handled inside the container: `provider-entrypoint.sh` seeds default config into `AGENT_HOME` on first run (seed-if-missing per file), registers an EXIT trap for copy-out, then execs the agent. The host-side persist step in `run_agent.sh` moves copy-out state to `$SANDBOX_DIR/.<provider>/` after container exit, giving each provider persistent config across sessions. Three providers now conform to the interface: OpenCode, Hermes (with a multi-stage base image reducing image size by ~2GB), and Pi. `make start` was hardened to stop any prior session before starting a new one.

---

## M2.3 — Apply Workflow: Capability Layer Diff Pipeline

*The operator can review agent work as shaped commits on a draft branch, confirm via rebase and fast-forward merge, or reject with no trace — all through a git-agnostic diff pipeline that works identically in both directions between sandbox and host.*

The diff pipeline was redesigned around a single git-agnostic unified diff format with index lines stripped, consumed by `git apply` in both directions. `package-diff` exports uncommitted working tree changes; `package-branch` exports the full committed branch history since `INIT_SHA` as numbered diffs. `make draft` creates a `draft/<name>` branch from the host, applies the numbered diffs sequentially, and commits `.draft-state` as metadata on the branch. `make confirm` validates the draft branch, drops `.draft-state`, rebases onto target, fast-forward merges, and deletes the draft branch — printing exact recovery commands on rebase conflict. `make reject` returns to the source branch and discards the draft. `make apply` applies a single diff uncommitted for mid-session sync in either direction. No checkpoint git tags, no `make sync`, no `SYNC=1`, and no `ADVANCED_SESSIONS` tracking — the harness does not bookkeeping which diffs have been applied.

**A.1 — Data model: output format unification (2026-04-29).** All packaging output now uses a single unified format. `package_branch` is a dispatcher orchestrating three operations: `package_commits` (numbered diffs under `patches/`), `write_uncommitted_diff` (`uncommitted.diff` from git diff HEAD), and `write_all_changes_diff` (`all-changes.diff` from git diff INIT_SHA). `diff_on_exit` and `diff_on_autosave` delegate to this dispatcher — no sweep commit, no `diff_commit_pending`. The `BASELINE_SHA` environment variable is eliminated; `diff_generate` and `diff_format_patch` use a generic `since_sha` parameter. `SESSION_STATE` is the single source of truth for session identity: `snapshot_init_git` writes `session_ts` and `init_sha` to `.git/SESSION_STATE` at container init, and the standalone `.git/INIT_SHA` file is no longer created. All readers migrate to `session_state_read`. `session_state_write` is added to `libs/session.sh` for atomic in-place updates.

**A.2 — CLI contract: `--channel` flag and routing (2026-04-29).** The `apply` and `draft` CLI contracts are restructured around a single `--channel` flag. `draft` channels: `session` (default), `autosave`, `bundles`. `apply` channels: `diffs` (default), `autosave`, `session`. `--session` is name-only: absolute paths are rejected with a clear error message, and the `--diff=<path>` escape hatch remains for arbitrary files. Channel resolution is consolidated into `resolve_source_for_draft` and `resolve_diff_for_apply` router functions in `scripts/agent-sandbox.sh`, keeping the workflow libraries (`libs/draft_workflow.sh`, `libs/diff_workflow.sh`) channel-agnostic. `draft_run` receives a `SOURCE_DIR` (containing `patches/` and optional `uncommitted.diff`) plus a `SESSION_NAME` for metadata. `apply_run` receives a file path directly with no hardcoded filename. The Makefile maps `AUTOSAVE=1` → `--channel=autosave` and `BUNDLE=1` → `--channel=bundles`. All 13 test files pass (237 assertions, 1 Docker skip).

**A.3 — Documentation and recovery (2026-04-29).** All architecture and concept documents are updated to reflect the unified contract. `execution_model.md`, `sandbox_lifecycle.md`, `tool_interface.md`, and `sandbox_host_correspondence_model.md` no longer reference `changes.diff`, `staged.diff`, `BASELINE_SHA`, `diff_commit_pending`, or the sweep commit. `tool_interface.md` documents the new `--channel`, `--session`, `--diff`, `--branch-from`, `--diffs`, and `--branch-summary` flags. `quickstart.md` recovery section is rewritten: checkpoint tags (deleted feature) removed; new recovery paths cover missing diff, wrong branch, rebase conflict, and bad diff scenarios. Stale `apply_workspace.sh` reference removed from `project_index.md`.

**A.4 — changed-files separate operation (2026-04-29).** The `changed-files/` working tree copy logic is extracted from `package_diff.sh` into a shared `write_changed_files(SANDBOX_DIR, SINCE_SHA, OUTPUT_DIR)` function in `libs/diff.sh`. It uses a two-source file list — `git diff --name-only SINCE_SHA` (committed + staged + unstaged) and `git ls-files --others --exclude-standard` (untracked) — deduplicated via `sort -u`. The function writes `MANIFEST.txt` and copies each file preserving directory structure, skipping deleted files. The `package_branch` dispatcher now calls `write_changed_files` with `SINCE_SHA=INIT_SHA`; `package_diff.sh` calls it with `SINCE_SHA=HEAD`. No operator-visible behaviour change — the output existed before; only the implementation is unified. Architecture documents updated: `execution_model.md` and `sandbox_lifecycle.md` directory trees include `changed-files/`. All 13 test files pass (241 assertions, 1 Docker skip).

---

