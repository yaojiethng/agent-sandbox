# agent-sandbox Changelog

Completed milestones extracted from `roadmap.md`. Each entry describes what the system can now do and the mechanisms built to enable it.

New entries are appended. Format is defined in `roadmap_policy.md`.

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

## M1.4 — Image Staleness Detection

*The harness warns the operator when the container image is out of date with the current source files before starting a run.*

A SHA-256 digest of all build inputs is embedded as a Docker image label at build time. At start time the digest is recomputed and compared; a mismatch produces a staleness warning and the run continues. Digest computation is centralised in `libs/image.sh` and covers all `libs/` files plus a provider-specific `image-files.txt`. The check applies to both `start` and `dry-run`.

---

## M1.5 — Workflow Convergence & Directory Restructuring

*The harness now separates the project repository from harness artefacts into sibling directories, keeping the project's git tree clean, and provides a dedicated operator input channel for passing task files and briefs to the agent before a run.*

Harness artefacts — snapshot, brief, workspace output — moved from `PROJECT_ROOT` into a sibling `SANDBOX_DIR`, eliminating harness pollution of the project git tree. The `.bootstrap/` directory was renamed `.agent-input/` and expanded to serve as the unified input channel: snapshot, brief, and operator-placed task files all enter the container through a single read-only mount. Directory names are defined once in `start_agent.sh` and passed to the container as environment variables, giving both host and container scripts a single source of truth. The `apply` subcommand now takes explicit `--project` and `--sandbox` flags, with the Makefile defining both paths so the operator workflow is unchanged. Open user stories (vault onboarding, website dev, knowledge store provider) were resolved or explicitly deferred to M2, and the workflow convergence decision was recorded. The onboarding skill was updated to reflect the new directory layout and modularised so that future convention changes require only variable updates.

---
