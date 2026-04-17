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

