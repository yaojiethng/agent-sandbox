# Context Resolution

**Role:** Defines how code in the agent-sandbox project determines its runtime context — where it's executing, how to locate its dependencies, and which conventions apply. Establishes a three-layer interface seam that works across host-side execution, container-side execution, and files that bridge both.

---

## The Three Runtime Contexts

The codebase is organised into three deployment contexts. Each determines its identity and locates its neighbours differently.

```
┌─────────────────────────────────────────────────────────┐
│ HOST CONTEXT                                             │
│                                                          │
│  Identity: knows the repo root via $AGENT_SANDBOX_REPO   │
│            (installed CLI) or $REPO_ROOT (checkout)      │
│                                                          │
│  Convention: resolve dependencies via repo-root-relative │
│              paths from the known root variable           │
│                                                          │
│  Constraint: never runs inside a container                │
│                                                          │
│  Files: agent-sandbox.sh, start_agent.sh, run_agent.sh,  │
│         onboard.sh, workflows/*.sh, guards.sh,            │
│         tests/test_*.sh                                   │
└─────────────────────┬───────────────────────────────────┘
                      │ sourced by
                      ▼
┌─────────────────────────────────────────────────────────┐
│ AMBIGUOUS CONTEXT (shared libs)                          │
│                                                          │
│  Identity: must determine location dynamically — runs    │
│            in both host and container                     │
│                                                          │
│  Convention: self-resolution via BASH_SOURCE — computes  │
│              own directory at source time, then finds     │
│              siblings relative to that directory          │
│                                                          │
│  Constraint: cannot assume any host-only variable exists  │
│                                                          │
│  Files: session_state.sh, routing.sh, diff_export.sh,           │
│         package_branch.sh, dirs.sh      │
└─────────────────────┬───────────────────────────────────┘
                      │ sourced by (via self-resolution)
                      ▼
┌─────────────────────────────────────────────────────────┐
│ CONTAINER CONTEXT                                        │
│                                                          │
│  Identity: knows paths baked into the image at build     │
│            time — /opt/sandbox/lib/, /opt/sandbox/bin/   │
│                                                          │
│  Convention: hardcoded absolute paths — the image is     │
│              the source of truth for its own layout      │
│                                                          │
│  Constraint: filesystem is immutable at runtime;         │
│              paths are fixed by Dockerfile COPY          │
│                                                          │
│  Files: sandbox-entrypoint.sh, provider-entrypoint.sh,   │
│         snapshot.sh, dry_run_*.sh                         │
└─────────────────────────────────────────────────────────┘
```

---

## Context Determination by Layer

### Host Context — `$AGENT_SANDBOX_REPO` or `$REPO_ROOT`

Files in the host context determine the repo root in one of two ways.

**Installed CLI (`agent-sandbox.sh`):** uses a build-time macro
`@@AGENT_SANDBOX_REPO@@` that is replaced by `sed` at `make install` time with the absolute path to the repo checkout. After install, the script lives at `/usr/local/bin/agent-sandbox` and cannot derive the repo root from its own location.

```bash
# agent-sandbox.sh
AGENT_SANDBOX_REPO="@@AGENT_SANDBOX_REPO@@"
source "$AGENT_SANDBOX_REPO/src/libs/routing.sh"
```

**Host workflow libs** (sourced by `agent-sandbox.sh`): use `$AGENT_SANDBOX_REPO` because the variable is set by `agent-sandbox.sh` before sourcing them. These files (draft, confirm, reject, apply, interactive, guards) never execute outside the CLI context.

```bash
# src/scripts/workflows/draft.sh (sourced by agent-sandbox.sh)
source "$AGENT_SANDBOX_REPO/src/libs/session_state.sh"
```

**Repo scripts** (`start_agent.sh`, `run_agent.sh`, `onboard.sh`): derive `$REPO_ROOT` from their own location. These always run from the repo checkout, so `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)` reliably resolves to the checkout root.

```bash
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_ROOT/src/libs/session_state.sh"
```

**Test files** (`tests/test_*.sh`): follow the same pattern as repo scripts, deriving `$TEST_DIR` from their own location.

```bash
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TEST_DIR/.." && pwd)"
source "$REPO_ROOT/src/libs/diff_export.sh"
```

### Ambiguous Context — Self-resolution

Files deployed to both the host filesystem and container images cannot assume any host-only or container-only variable exists. They determine their context dynamically by computing their own directory at source time:

```bash
_self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_self_dir/session_state.sh"
source "$_self_dir/routing.sh"
```

This works in both contexts because `BASH_SOURCE[0]` resolves to the file's actual location:
| Context | File location | `_self_dir` resolves to |
|---|---|---|
| Host | `$AGENT_SANDBOX_REPO/src/libs/diff_export.sh` | `$AGENT_SANDBOX_REPO/src/libs/` |
| Container | `/opt/sandbox/lib/diff_export.sh` | `/opt/sandbox/lib/` |

All ambiguous-context files use the canonical variable name `_self_dir`. This was standardised from six different naming conventions (`_DIFF_SH_DIR`, `_PB_SCRIPT_DIR`, `_PD_SCRIPT_DIR`, `_DW_SCRIPT_DIR`, `_ISS_SCRIPT_DIR`, plus inline `$(cd...)`).

**Files in this layer:** `session_state.sh`, `routing.sh`, `diff_export.sh`, `package_branch.sh`, `dirs.sh`

### Container Context — Hardcoded paths

Files that run exclusively inside a container know their layout from the image build. They source dependencies via absolute paths baked in by the Dockerfile:

```bash
source /opt/sandbox/lib/session_state.sh
source /opt/sandbox/lib/diff_export.sh
```

These paths are immutable at runtime. The entrypoint files and diagnostic scripts use this convention. The destination paths (`/opt/sandbox/lib/`) are stable across renames of the host-side source tree — only the COPY source paths in Dockerfiles change when files move.

---

## How Context Propagates

Context is not inherited — each file declares how it resolves its own location.

```
agent-sandbox.sh ── sets $AGENT_SANDBOX_REPO
  └─ sources ── workflow/draft.sh ── uses $AGENT_SANDBOX_REPO
                   └─ sources ── src/libs/session_state.sh ── uses _self_dir (self-resolution)
                                  └─ sources ── src/libs/routing.sh ── uses _self_dir

sandbox-entrypoint.sh ── hardcoded /opt/sandbox/lib/
  └─ sources ── /opt/sandbox/lib/diff_export.sh ── uses _self_dir (→ /opt/sandbox/lib/)
```

At the seam between host context and ambiguous-context libs, the host's variable (`$AGENT_SANDBOX_REPO`) provides the path to the ambiguous-context file, but once that file loads, it resolves its own siblings via self-resolution. The same ambiguous-context file, when loaded inside a container via a hardcoded path, resolves its siblings identically — the mechanism is the same, only the starting path differs.

---

## Summary

| Context | Identity mechanism | Convention | Files |
|---|---|---|---|
| Host — installed CLI | `$AGENT_SANDBOX_REPO` (macro) | Repo-root-relative paths | `agent-sandbox.sh` |
| Host — workflow libs | `$AGENT_SANDBOX_REPO` (inherited) | Repo-root-relative paths | `draft.sh`, `confirm.sh`, `reject.sh`, `apply.sh`, `interactive.sh`, `guards.sh` |
| Host — repo scripts | `$REPO_ROOT` (derived) | Repo-root-relative paths | `start_agent.sh`, `run_agent.sh`, `onboard.sh` |
| Host — tests | `$REPO_ROOT` (derived) | Repo-root-relative paths | `tests/test_*.sh` |
| Ambiguous | `_self_dir` (self-resolution) | Sibling-relative paths | `session_state.sh`, `routing.sh`, `diff_export.sh`, `package_branch.sh`, `dirs.sh` |
| Container | `/opt/sandbox/lib/` (baked) | Absolute paths | `sandbox-entrypoint.sh`, `provider-entrypoint.sh`, `snapshot.sh`, `dry_run_*.sh` |

---

## Control Flow Constraints

The dependency graph follows directional rules that enforce separation between layers:

```
scripts/  ──→ libs/shared/          host scripts source shared libs
scripts/  ──→ scripts/              may source other scripts if logically
                                      a library (e.g. checkpoint.sh)
libs/*    ──→ libs/shared/ only    libs never source scripts
tests/*   ──→ anything              tests can source everything
☐ nothing ──→ tests/               nothing sources tests
containers ──→ libs/shared/ only   entrypoints only source shared libs
```

### Boundary rules

- **libs/ → scripts/**: Forbidden. A library must not depend on a host script. If a script contains reusable functions, it belongs in `libs/`, not `scripts/`.
- **scripts/ → scripts/**: Allowed only when the target script is logically a library (defines functions, has no `main()` entry point). `src/build/image.sh` is the canonical example — it defines `sandbox_image_name()`, `agent_image_name()`, and the identity derivation functions sourced by `start_agent.sh` and `build.sh`.
- **tests/ → anything**: Tests import whatever they need to test. They are not imported by anything else.
- **Container → Container only**: Entrypoints inside containers source only from their own `libs/` directory hierarchy (`/opt/sandbox/lib/`).

## References

- [`execution_model.md`](../architecture/execution_model.md) — Directory layout and mount shape
- [`sandbox_host_correspondence_model.md`](sandbox_host_correspondence_model.md) — Host-container operation correspondence
- [`two_layer_model.md`](two_layer_model.md) — Reasoning/capability layer separation
