# Spec — Directory Restructuring (Structural Cleanup)

**Status:** Final. Ready for implementation.

---

## 1. Decisions

### Principles

1. **Deployment target as primary split** — files grouped by where they execute: host, reasoning container, or capability container.
2. **Life stage as secondary split** — build-time configuration separated from runtime code.
3. **No intermediate nesting layer** — files land directly in their target directory under `src/`.
4. **`devlog/` at root** — agent development history is not project documentation.

### Cross-cutting libs → `src/libs/`

| File | Rationale |
|---|---|
| `dirs.sh` | Sourced by host, reasoning container, and capability container |
| `session.sh` | `session_state_read`/`write` used across all three |
| `routing.sh` | Same |
| `diff.sh` | Sourced by host (draft_workflow), reasoning (package_branch), capability (sandbox-entrypoint) |
| `snapshot.sh` | Used by both host (start_agent.sh) and capability (sandbox-entrypoint). Kept whole. |
| `package_branch.sh` | Paired with package_diff. Both exec'd from host AND present in containers. |
| `package_diff.sh` | Same. |

### Reasoning container → `src/reasoning/`

| File | Rationale |
|---|---|
| `provider-entrypoint.sh` | Runs inside reasoning container |
| `agent/` (skills, prompts, config) | Agent workflow files — kept together until coding-agent seam is clear |
| `Dockerfile.node` / `Dockerfile.python` | Harness bases — live alongside providers they serve |
| `providers/<n>/` (all files) | Per-provider files stay nested under their provider, including host-run files (setup.sh, onboard.sh) — provider ownership is the organising principle |

### Capability container → `src/capability/`

| File | Rationale |
|---|---|
| `sandbox-entrypoint.sh` | Runs inside capability container |
| `Dockerfile.sandbox` | Capability layer image definition |

### Build pipeline → `src/build/`

| File | Rationale |
|---|---|
| `docker-compose.yml` | Build-time config, consumed by compose pipeline |
| `docker-compose.dry-run.yml` | Same |
| `compose.sh` | Build pipeline code — paired with compose templates |
| `containers.sh` | Build pipeline code — Docker lifecycle |

### Host orchestration → `src/scripts/`

All existing `scripts/` files plus host-side workflow files from `libs/`.

---

## 2. Assignment Table

### `src/libs/` — cross-target libraries

| File | Current path |
|---|---|
| `dirs.sh` | `libs/dirs.sh` |
| `session.sh` | `libs/session.sh` |
| `routing.sh` | `libs/routing.sh` |
| `diff.sh` | `libs/diff.sh` |
| `snapshot.sh` | `libs/snapshot.sh` |
| `package_branch.sh` | `libs/package_branch.sh` |
| `package_diff.sh` | `libs/package_diff.sh` |

### `src/reasoning/` — agent container

| File | Current path | New path |
|---|---|---|
| `provider-entrypoint.sh` | `libs/provider-entrypoint.sh` | `src/reasoning/provider-entrypoint.sh` |
| `agent/` dir | `agent/` (root) | `src/reasoning/agent/` |
| `Dockerfile.node` | (to create) | `src/reasoning/Dockerfile.node` |
| `Dockerfile.python` | (to create) | `src/reasoning/Dockerfile.python` |
| `providers/pi/base.Dockerfile` | `providers/pi/base.Dockerfile` | `src/reasoning/providers/pi/base.Dockerfile` |
| `providers/pi/provider.Dockerfile` | `providers/pi/provider.Dockerfile` | `src/reasoning/providers/pi/provider.Dockerfile` |
| `providers/pi/preflight.sh` | `providers/pi/preflight.sh` | `src/reasoning/providers/pi/preflight.sh` |
| `providers/pi/setup.sh` | `providers/pi/setup.sh` | `src/reasoning/providers/pi/setup.sh` |
| `providers/pi/onboard.sh` | `providers/pi/onboard.sh` | `src/reasoning/providers/pi/onboard.sh` |
| `providers/pi/docker-compose.pi.yml` | `providers/pi/docker-compose.pi.yml` | `src/reasoning/providers/pi/docker-compose.pi.yml` |
| `providers/pi/docker-compose.serve.yml` | `providers/pi/docker-compose.serve.yml` | `src/reasoning/providers/pi/docker-compose.serve.yml` |
| `providers/pi/config/` | `providers/pi/config/` | `src/reasoning/providers/pi/config/` |
| `providers/pi/onboard-readme.md` | `providers/pi/onboard-readme.md` | `src/reasoning/providers/pi/onboard-readme.md` |
| `providers/claude-code/base.Dockerfile` | — | `src/reasoning/providers/claude-code/base.Dockerfile` |
| `providers/claude-code/provider.Dockerfile` | — | `src/reasoning/providers/claude-code/provider.Dockerfile` |
| `providers/claude-code/setup.sh` | — | `src/reasoning/providers/claude-code/setup.sh` |
| `providers/claude-code/docker-compose.claude-code.yml` | — | `src/reasoning/providers/claude-code/docker-compose.claude-code.yml` |
| `providers/claude-code/docker-compose.serve.yml` | — | `src/reasoning/providers/claude-code/docker-compose.serve.yml` |
| `providers/claude-code/AGENTS.md` | — | `src/reasoning/providers/claude-code/AGENTS.md` |
| `providers/hermes/base.Dockerfile` | — | `src/reasoning/providers/hermes/base.Dockerfile` |
| `providers/hermes/provider.Dockerfile` | — | `src/reasoning/providers/hermes/provider.Dockerfile` |
| `providers/hermes/docker-compose.hermes.yml` | — | `src/reasoning/providers/hermes/docker-compose.hermes.yml` |
| `providers/hermes/docker-compose.serve.yml` | — | `src/reasoning/providers/hermes/docker-compose.serve.yml` |
| `providers/hermes/config/` | — | `src/reasoning/providers/hermes/config/` |
| `providers/hermes/quickstart.md` | — | `src/reasoning/providers/hermes/quickstart.md` |
| `providers/hermes/AGENTS.md` | — | `src/reasoning/providers/hermes/AGENTS.md` |
| `providers/opencode/base.Dockerfile` | — | `src/reasoning/providers/opencode/base.Dockerfile` |
| `providers/opencode/provider.Dockerfile` | — | `src/reasoning/providers/opencode/provider.Dockerfile` |
| `providers/opencode/docker-compose.serve.yml` | — | `src/reasoning/providers/opencode/docker-compose.serve.yml` |
| `providers/opencode/config/` | — | `src/reasoning/providers/opencode/config/` |
| `providers/opencode/quickstart.md` | — | `src/reasoning/providers/opencode/quickstart.md` |
| `providers/opencode/AGENTS.md` | — | `src/reasoning/providers/opencode/AGENTS.md` |
| `providers/claude-ai/AGENTS.md` | — | `src/reasoning/providers/claude-ai/AGENTS.md` | Minimal provider — single AGENTS.md only |

### `src/capability/` — sandbox container

| File | Current path |
|---|---|
| `sandbox-entrypoint.sh` | `libs/sandbox-entrypoint.sh` |
| `Dockerfile.sandbox` | `libs/sandbox.Dockerfile` |

### `src/build/` — build pipeline

| File | Current path |
|---|---|
| `docker-compose.yml` | `libs/docker-compose.yml` |
| `docker-compose.dry-run.yml` | `libs/docker-compose.dry-run.yml` |
| `compose.sh` | `libs/compose.sh` |
| `containers.sh` | `libs/containers.sh` |

### `src/scripts/` — host-level orchestration

| File | Current path |
|---|---|
| `agent-sandbox.sh` | `scripts/agent-sandbox.sh` |
| `start_agent.sh` | `scripts/start_agent.sh` |
| `run_agent.sh` | `scripts/run_agent.sh` |
| `stop.sh` | `scripts/stop.sh` |
| `onboard.sh` | `scripts/onboard.sh` |
| `checkpoint.sh` | `scripts/checkpoint.sh` |
| `run_tests.sh` | `scripts/run_tests.sh` |
| `check_test_coverage.sh` | `scripts/check_test_coverage.sh` |
| `dry_run_reasoning.sh` | `scripts/dry_run_reasoning.sh` |
| `dry_run_capability.sh` | `scripts/dry_run_capability.sh` |
| `draft_workflow.sh` | `libs/draft_workflow.sh` |
| `diff_workflow.sh` | `libs/diff_workflow.sh` |
| `interactive_session_select.sh` | `libs/interactive_session_select.sh` |
| `templates/Makefile.template` | `libs/_templates/Makefile.template` |
| `templates/PULL_REQUEST.md.template` | `libs/_templates/PULL_REQUEST.md.template` |
| `templates/TASK.md.template` | `libs/_templates/TASK.md.template` |
| `templates/AGENTS.template.md` | `providers/AGENTS.template.md` | `src/scripts/templates/AGENTS.template.md` |

### Root level

| Path | Action |
|---|---|
| `devlog/` | Move from `docs/devlog/` to root |
| `docs/` | Stays (architecture, concepts, operations) |
| `tests/` | Stays |
| `tests/eval/` | Move from `eval/` to `tests/eval/` |
| `Makefile` | Stays at root |
| `workflow/` | Stays at root (vault workflow, VSCode config) |
| `.devcontainer/` | Stays at root (development infra, like `.gitignore`) |
| `.gitignore` | Stays at root |
| `AGENTS.md` | Stays at root (project-level) |
| `LICENSE` | Stays at root |
| `readme.md` | Stays at root |

---

## 3. Implementation Sequence

```
Session 1: Structural cleanup
  - Create new directory tree (src/libs/, src/reasoning/, src/capability/, src/scripts/, src/build/)
  - Move files per assignment table
  - Update all source/exec/COPY path references
  - Update build_context_* functions in containers.sh
  - Update mock_repo_fixtures.sh test fixture
  - Migrate all test path references
  - Move devlog/ to root
  - Move eval/ to tests/eval/
  - Tests pass, no logic changes
  - libs/ and old providers/ directories removed (or left empty with README)

Session 2: Dockerfile layer refactoring
  - Create src/reasoning/Dockerfile.node, Dockerfile.python
  - Trim per-provider base Dockerfiles
  - Update build pipeline for three-tier build
  - Tests pass

Session 3+: UID Mapping (per M2.7 Track C)
```

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
