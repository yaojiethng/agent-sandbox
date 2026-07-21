# Design — Directory Restructuring (Structural Cleanup)

**Status:** Active. Session 1 (libs/ stage) complete; sessions 2+ pending.

---

## 0. Progress Summary

| Session | Scope | Status |
|---|---|---|
| 1 — libs/ stage | All `libs/` files moved to target directories per assignment table below | ✅ Complete (session `20260526-06`) |
| 2 — providers/ + agent/ + devlog/ | Move `providers/`, `agent/`, and `docs/devlog/` to their target locations | ⬜ Pending |
| 3 — Dockerfile layer refactoring | Create `src/reasoning/Dockerfile.node`, `Dockerfile.python`; trim per-provider bases | ⬜ Pending |
| 4+ — UID Mapping | Per M2.7 Track C | ⬜ Pending |

---

## 1. Decisions

### Principles

1. **Deployment target as primary split** — files grouped by where they execute: host, reasoning container, or capability container.
2. **Life stage as secondary split** — build-time configuration separated from runtime code.
3. **All code under `src/`** — build files, libs, scripts, entrypoints all land under `src/`. No top-level code directories outside `src/`, `docs/`, `devlog/`, `tests/`, `workflow/` and project root files.
4. **Naming convention: underscores** — all `.sh` file names use underscores (`session_state.sh`). Dashes reserved for CLI subcommands (`agent-sandbox package-diff`). Exceptions: `docker-compose.yml` (Docker convention), `agent-sandbox.sh` (installed binary).
5. **`devlog/` at root** — agent development history is not project documentation.

### Cross-cutting libs → `src/libs/`

| File | Rationale | Status |
|---|---|---|
| `dirs.sh` | Sourced by host, reasoning container, and capability container | ✅ |
| `session_state.sh` | `session_state_read`/`write` — extracted from `session.sh` | ✅ |
| `routing.sh` | Path layout conventions | ✅ |
| `diff.sh` | Diff utilities (strip_index_lines, write_*_diff, write_changed_files) | ✅ |
| `diff_export.sh` | `diff_export` orchestrator — extracted from `diff.sh` | ✅ |
| `package_branch.sh` | Branch packaging — paired with package_diff | ✅ |
| `package_diff.sh` | Diff packaging | ✅ |

### Host-side guards → `scripts/guards.sh`

`validate_project_dir` and `draft_clear_stale_lock` extracted from `session.sh`. Host-side only — not deployed to containers.

| Function | Source | Status |
|---|---|---|
| `validate_project_dir()` | `session.sh` | ✅ |
| `draft_clear_stale_lock()` | `session.sh` | ✅ |

### Reasoning container → `src/reasoning/`

| File | Rationale | Status |
|---|---|---|
| `entrypoint.sh` | Runs inside reasoning container (was `provider-entrypoint.sh`) | ✅ |
| `agent/` (skills, prompts, config) | Agent workflow files | ⬜ Pending |
| `Dockerfile.node` / `Dockerfile.python` | Harness bases | ⬜ Pending |
| `providers/<n>/` (all files) | Per-provider files | ⬜ Pending |

### Capability container → `src/capability/`

| File | Rationale | Status |
|---|---|---|
| `entrypoint.sh` | Runs inside capability container (was `sandbox-entrypoint.sh`) | ✅ |
| `Dockerfile` | Capability layer image definition (was `sandbox.Dockerfile`) | ✅ |
| `snapshot.sh` | Snapshot pipeline | ✅ |

### Build pipeline → `src/build/`

| File | Rationale | Status |
|---|---|---|
| `image.sh` | Image naming + container identity (extracted from `containers.sh`) | ✅ |
| `context.sh` | Build context prep (extracted from `containers.sh`) | ✅ |
| `compose.sh` | Compose file generation (was `libs/compose.sh`) | ✅ |
| `docker-compose.yml` | Build-time config template | ✅ |
| `docker-compose.dry-run.yml` | Dry-run compose overlay | ✅ |

Build orchestration (`build_image`, `build_agent`, `build_sandbox`, `preflight`) moved to `scripts/build.sh`.

### Host orchestration → `src/scripts/`

All existing `scripts/` files plus host-side workflow files from `libs/`. Build orchestration functions from `containers.sh` moved to `scripts/build.sh`.

### Workflow files → `src/scripts/workflows/`

| File | Source | Status |
|---|---|---|
| `draft.sh` | `libs/draft_workflow.sh` (draft_run + helpers) | ✅ |
| `confirm.sh` | `libs/draft_workflow.sh` (confirm_run) | ✅ |
| `reject.sh` | `libs/draft_workflow.sh` (reject_run) | ✅ |
| `apply.sh` | `libs/diff_workflow.sh` | ✅ |
| `interactive.sh` | `libs/interactive_session_select.sh` | ✅ |

---

## 2. Assignment Table

### ✅ Completed — `src/libs/`

| File | Current path (new) | Status |
|---|---|---|
| `dirs.sh` | `src/libs/dirs.sh` | ✅ |
| `session_state.sh` | `src/libs/session_state.sh` | ✅ |
| `routing.sh` | `src/libs/routing.sh` | ✅ |
| `diff.sh` | `src/libs/diff.sh` | ✅ |
| `diff_export.sh` | `src/libs/diff_export.sh` | ✅ |
| `package_branch.sh` | `src/libs/package_branch.sh` | ✅ |
| `package_diff.sh` | `src/libs/package_diff.sh` | ✅ |

### ✅ Completed — `src/capability/`

| File | New path | Status |
|---|---|---|
| `entrypoint.sh` | `src/capability/entrypoint.sh` | ✅ |
| `Dockerfile` | `src/capability/Dockerfile` | ✅ |
| `snapshot.sh` | `src/capability/snapshot.sh` | ✅ |

### ✅ Completed — `src/reasoning/`

| File | New path | Status |
|---|---|---|
| `entrypoint.sh` | `src/reasoning/entrypoint.sh` | ✅ |

### ✅ Completed — `src/build/`

| File | New path | Status |
|---|---|---|
| `image.sh` | `src/build/image.sh` | ✅ |
| `context.sh` | `src/build/context.sh` | ✅ |
| `compose.sh` | `src/build/compose.sh` | ✅ |
| `docker-compose.yml` | `src/build/docker-compose.yml` | ✅ |
| `docker-compose.dry-run.yml` | `src/build/docker-compose.dry-run.yml` | ✅ |

### ✅ Completed — `scripts/`

| File | New path | Status |
|---|---|---|
| `build.sh` | `scripts/build.sh` | ✅ |
| `guards.sh` | `scripts/guards.sh` | ✅ |

### ✅ Completed — `scripts/workflows/`

| File | New path | Status |
|---|---|---|
| `draft.sh` | `scripts/workflows/draft.sh` | ✅ |
| `confirm.sh` | `scripts/workflows/confirm.sh` | ✅ |
| `reject.sh` | `scripts/workflows/reject.sh` | ✅ |
| `apply.sh` | `scripts/workflows/apply.sh` | ✅ |
| `interactive.sh` | `scripts/workflows/interactive.sh` | ✅ |

### ✅ Completed — `scripts/templates/`

All moved from `libs/_templates/`.

---

### ⬜ Pending — `src/reasoning/` (remaining items)

| Current path | Target path |
|---|---|
| `agent/` (root) | `src/reasoning/agent/` |
| (to create) | `src/reasoning/Dockerfile.node` |
| (to create) | `src/reasoning/Dockerfile.python` |
| `providers/pi/base.Dockerfile` | `src/reasoning/providers/pi/base.Dockerfile` |
| `providers/pi/provider.Dockerfile` | `src/reasoning/providers/pi/provider.Dockerfile` |
| `providers/pi/preflight.sh` | `src/reasoning/providers/pi/preflight.sh` |
| `providers/pi/setup.sh` | `src/reasoning/providers/pi/setup.sh` |
| `providers/pi/onboard.sh` | `src/reasoning/providers/pi/onboard.sh` |
| `providers/pi/docker-compose.pi.yml` | `src/reasoning/providers/pi/docker-compose.pi.yml` |
| `providers/pi/docker-compose.serve.yml` | `src/reasoning/providers/pi/docker-compose.serve.yml` |
| `providers/pi/config/` | `src/reasoning/providers/pi/config/` |
| `providers/pi/onboard-readme.md` | `src/reasoning/providers/pi/onboard-readme.md` |
| All claude-code, hermes, opencode, claude-ai files | `src/reasoning/providers/<n>/...` |

### ⬜ Pending — `devlog/`

`docs/devlog/` → root `devlog/`.

### ⬜ Pending — `tests/eval/`

`eval/` → `tests/eval/`.

### Root level — stays

`docs/`, `Makefile`, `workflow/`, `.devcontainer/`, `.gitignore`, `AGENTS.md`, `LICENSE`, `readme.md`.

---

## 3. Implementation Sequence (updated)

```
Session 1: libs/ stage ✅ COMPLETE
  - All src/libs/, src/build/, src/capability/, src/reasoning/entrypoint,
    scripts/build.sh, scripts/guards.sh, scripts/workflows/, scripts/templates/
  - containers.sh split, session.sh split, draft_workflow.sh split, diff.sh split
  - Packaging pipeline made symmetrical across all providers
  - File naming standardised to underscores
  - Context resolution convention applied (_self_dir, $AGENT_SANDBOX_REPO, $REPO_ROOT)
  - New tests: test_diff_export.sh, test_packaging_symmetry.sh
  - Rename workflow formalised: agent/drafts/refactor-mv-rename-file.skill.md

Session 2: providers/ + agent/ + devlog/ ⬜ PENDING
  - Move providers/*/ to src/reasoning/providers/<n>/
  - Move agent/ to src/reasoning/agent/
  - Move docs/devlog/ to root devlog/
  - Update all path references
  - Apply rename workflow (refactor-mv-rename-file.skill.md) per file
  - Use rename propagation checklist (Step 1): grep every reference before mv
  - Use file lifecycle gate (Steps 3-5): create → update refs → verify → delete old → re-verify

Session 3: Dockerfile layer refactoring ⬜ PENDING
  - Create src/reasoning/Dockerfile.node, Dockerfile.python
  - Trim per-provider base Dockerfiles
  - Update build pipeline for three-tier build

Session 4+: UID Mapping (per M2.7 Track C) ⬜ PENDING
```

---

## Workflow Amendments (from Session 1 learnings)

These are now formalised in `agent/drafts/refactor-mv-rename-file.skill.md`:

1. **Rename propagation checklist** — before any `git mv`, grep every reference across the entire tree, categorise by whether it must change, produce a propagation table.
2. **File lifecycle gate** — create new → update refs → verify (make test) → delete old → re-verify. Never batch-remove before path updates are confirmed.
3. **Convention-first design** — naming convention frozen in design doc before implementation. No mid-session changes.
4. **Container-side path verification** — test that every `/opt/sandbox/lib/` source path has a matching Dockerfile COPY.

These apply to all subsequent structural cleanup sessions.

---

## 4. Reference: Current File Tree

*For the implementer. Describes the starting state before any changes.*

### Current `libs/` contents

| File | Category | Consumed by |
|---|---|---|
| `containers.sh` | Host-side | scripts/run_agent.sh, scripts/start_agent.sh |
| `compose.sh` | Host-side | scripts/run_agent.sh |
| `draft_workflow.sh` | Host-side | scripts/agent-sandbox.sh |
| `diff_workflow.sh` | Host-side | scripts/agent-sandbox.sh |
| `interactive_session_select.sh` | Host-side | scripts/agent-sandbox.sh |
| `provider-entrypoint.sh` | Reasoning | build_context_agent → reasoning image |
| `dirs.sh` | Shared lib | Both build contexts → both images |
| `session.sh` | Shared lib | Both build contexts → both images |
| `routing.sh` | Shared lib | Both build contexts → both images |
| `sandbox-entrypoint.sh` | Capability | build_context_sandbox → sandbox image |
| `snapshot.sh` | Capability | build_context_sandbox → sandbox image |
| `diff.sh` | Capability | build_context_sandbox → sandbox image |
| `package_branch.sh` | Capability | Both build contexts → both images |
| `package_diff.sh` | Reasoning | build_context_agent → reasoning image |
| `docker-compose.yml` | Compose | compose.sh template |
| `docker-compose.dry-run.yml` | Compose | compose.sh template |
| `sandbox.Dockerfile` | Capability | build_sandbox() |
| `_templates/` | Onboarding | scripts/onboard.sh |

### Current `providers/` tree

```
providers/
├── pi/            base.Dockerfile, provider.Dockerfile, preflight.sh,
│                    setup.sh, onboard.sh, AGENTS.md, config/,
│                    docker-compose.pi.yml, docker-compose.serve.yml
├── claude-code/   base.Dockerfile, provider.Dockerfile, setup.sh,
│                    AGENTS.md, docker-compose.*.yml
├── hermes/        base.Dockerfile, provider.Dockerfile, config/,
│                    AGENTS.md, docker-compose.*.yml, quickstart.md
├── opencode/      base.Dockerfile, provider.Dockerfile, config/,
│                    AGENTS.md, docker-compose.*.yml, quickstart.md
└── claude-ai/     AGENTS.md only
```

### Current `scripts/` tree

```
scripts/
├── agent-sandbox.sh         CLI entrypoint — dispatches to scripts/
├── start_agent.sh           Session startup — preflight, snapshot, compose
├── run_agent.sh              Container lifecycle — compose, up/down
├── stop.sh                  Clean teardown
├── onboard.sh               Project onboarding
├── checkpoint.sh            Checkpoint tag management
├── run_tests.sh              Test runner
├── check_test_coverage.sh    Coverage checker
├── dry_run_reasoning.sh      Reasoning layer dry-run
└── dry_run_capability.sh     Capability layer dry-run
```

---

## 5. Reference: Dependency Chain

*For the implementer. Shows which files `source` which others — needed to validate path substitutions.*

| File | Sources |
|---|---|
| `libs/routing.sh` | `session.sh`, `dirs.sh` |
| `libs/diff.sh` | `session.sh`, `routing.sh` |
| `libs/draft_workflow.sh` | `session.sh`, `routing.sh`, `diff.sh` |
| `libs/diff_workflow.sh` | `session.sh`, `diff.sh` |
| `libs/package_branch.sh` | `session.sh`, `diff.sh`, `routing.sh` |
| `libs/package_diff.sh` | `session.sh`, `diff.sh`, `routing.sh` |
| `libs/interactive_session_select.sh` | `routing.sh` |
| `libs/sandbox-entrypoint.sh` | `dirs.sh`, `session.sh`, `snapshot.sh`, `diff.sh`, `routing.sh` (all from `/opt/sandbox/lib/`) |
| `libs/provider-entrypoint.sh` | (none — it is sourced by the entrypoint) |
| `scripts/agent-sandbox.sh` | `containers.sh`, `draft_workflow.sh`, `diff_workflow.sh`, `routing.sh` (host paths) + exec `package_diff.sh`, `package_branch.sh` |
| `scripts/run_agent.sh` | `containers.sh`, `compose.sh` |
| `scripts/start_agent.sh` | `containers.sh`, `snapshot.sh` |
| `scripts/dry_run_reasoning.sh` | `session.sh`, `dirs.sh` (from `/opt/sandbox/lib/`) |
| `scripts/dry_run_capability.sh` | `session.sh`, `diff.sh`, `dirs.sh` (from `/opt/sandbox/lib/`) |
