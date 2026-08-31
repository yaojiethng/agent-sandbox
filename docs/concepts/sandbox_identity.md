# Sandbox Identity Model

The agent-sandbox harness uses a content-addressed identity model with three scopes: project-level identity, sandbox-instance identity, and session-run identity. This document defines the primitives, derivation rules, and consumption patterns. The terms [session](terminology.md#session) and [iteration](terminology.md#iteration) are reserved technical terms.

## Primitives

| Primitive | Derivation | Scope | Purpose |
|---|---|---|---|
| `PROJECT_NAME` | User-provided at `onboard` | Host | Human-readable project identifier. Used in container names, image names, labels. |
| `PROJECT_DIR` | User-provided at `onboard` | Host | Absolute path to the project directory on the host. Used for git operations and path derivation. |
| `SANDBOX_DIR` | Operator-supplied at `onboard` (defaults to `PROJECT_DIR-sandbox`) | Sandbox instance | Absolute path to the sandbox instance directory on the host. The identity factor that distinguishes parallel worktree sessions. |
| `HOST_HEAD_SHA` | `git -C PROJECT_DIR rev-parse HEAD` at first start | Sandbox instance | Full SHA of the host git HEAD at session start. Records the branch point for provenance tracking. On copy-mode resume, read from the volume label; on mount-mode resume, from the registry record. |
| `SESSION_TS` | `date -u +%Y%m%d-%H%M%S` at first start | Session run | Human-readable session timestamp. On resume, read from the volume label / registry record to ensure consistency with the volume's SESSION_STATE. |

## Derived Identifiers

### SESSION_ID — Session Run Identity

```
SESSION_ID = sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]
```

A 6-character hex hash that identifies a single session run. Replaces `SESSION_TS` in container names and output artefact paths while `SESSION_TS` is preserved in labels for human readability. The former two-stage model (separate `SANDBOX_ID = sha256(SANDBOX_DIR:HOST_HEAD_SHA)[:8]` intermediate fed into `SESSION_ID`) was collapsed into this single canonical hash — see `docs/adr/20260831-adr-settled-single_canonical_session_identity.md`.

`canon(SANDBOX_DIR)` is the sandbox directory resolved to its canonical absolute form (`readlink -f`/`realpath` after leading-`~` expansion), so every path spelling of one folder (absolute, `~`, relative, symlink, trailing-slash, `./`) converges to one `SESSION_ID`. An unresolvable `SANDBOX_DIR` is a hard error (start/resume fail loudly).

**Properties:**
- Unique per session even with the same sandbox instance and branch (timestamp component).
- Deterministic: same canonical inputs produce same `SESSION_ID`.
- Sensitive to all three identity factors: canonical sandbox dir, host HEAD, and session timestamp.
- 24 bits of entropy (6 hex chars), sufficient for session disambiguation.

## Container and Image Naming

| Entity | Format | Example |
|---|---|---|
| Sandbox (base) image | `sandbox-<project>` | `sandbox-agent-sandbox` |
| Agent image | `<provider>-agent-<project>` | `pi-agent-sandbox` |
| Sandbox container | `sandbox-<project>-<session_id>` | `sandbox-agent-sandbox-f6e5d4` |
| Agent container | `<provider>-<project>-<session_id>` | `pi-agent-sandbox-f6e5d4` |

Images are tagged by harness code identity, not project repo state. Project repo state is captured at runtime by the snapshot pipeline. Provenance for past sessions is carried by Docker labels (`agent-sandbox.host-head-sha`, `agent-sandbox.sandbox-dir`, `agent-sandbox.session-id`), not by image tags.

## Docker Label Schema

The compose template exports the following labels on all containers:

```
agent-sandbox.project-name:     <PROJECT_NAME>
agent-sandbox.project-dir:      <PROJECT_DIR>
agent-sandbox.sandbox-dir:      <SANDBOX_DIR>
agent-sandbox.host-head-sha:    <HOST_HEAD_SHA>
agent-sandbox.host-branch:      <sanitised branch name>
agent-sandbox.session-ts:       <SESSION_TS>
agent-sandbox.session-id:           <SESSION_ID>
```

These labels serve two purposes:
- **Provenance:** Operators can inspect any container to determine which project, worktree, host commit, and session run it belongs to.
- **Lifecycle management:** `make stop` and `make prune` filter by `project-name` + `sandbox-dir` labels to scope operations to a specific worktree.

### Label Lifecycle by Artifact Type

Labels are classified by stability: a label's value changes at most once per artifact lifetime (stable) or changes every session (ephemeral). The set of labels carried by an artifact reflects its lifecycle — ephemeral artifacts (containers) carry all labels; persistent artifacts (volumes) carry only the stable subset because their labels are set at creation and never updated.

| Label | Stability | On containers | On volumes | On images | Reason |
|---|---|---|---|---|---|
| `project-name` | Stable | ✅ | ✅ | ❌ | Never changes for a project; images are tagged by name, not labeled |
| `sandbox-dir` | Stable | ✅ | ✅ | ❌ | Never changes for a sandbox instance; runtime-only label |
| `host-head-sha` | Stable | ✅ | ✅ | ❌ | Set at volume creation; backlink to repo state; runtime-only |
| `host-branch` | Stable | ✅ | ✅ | ❌ | Set at volume creation; backlink to branch; runtime-only |
| `session-ts` | Ephemeral | ✅ | ❌ | ❌ | Changes every session; volume/images labels would be stale on resume |
| `session-id` | Ephemeral | ✅ | ❌ | ❌ | Changes every session; volume/images labels would be stale on resume |
| `project-dir` | Stable | ✅ | ❌ | ❌ | Host path; not relevant for volume or image lifecycle |
| `container-sig` | Stable | ❌ | ❌ | ✅ | SHA-256 of source files baked at build time; never changes for a given image |

Containers are ephemeral — they live for one session and die. All labels are accurate for the container's entire lifetime. Volumes persist across sessions; carrying ephemeral labels like `session-id` would create dangling references pointing to a session that may no longer exist. Images are build artifacts — their labels record build-time provenance (source file hash), not runtime identity.

**Standardization rule:** all Docker artifacts carry the same label schema. Where a label is omitted (volume omitting session-scoped labels, images carrying only build-time labels), the omission is intentional and documented here. No artifact type introduces labels not present in the base schema.

## Container-sig (Image Staleness Detection)

Images carry an `agent-sandbox.container-sig` Docker label that records a SHA-256 hash of the source files that populate the image's `/opt/sandbox/` and `/opt/workflow/` directories at build time. This hash is computed in `scripts/build.sh` by the `container_sig()` function and injected as a `--label` at build time.

### Derivation

For the sandbox image, the hash covers all files under these repo-relative paths:
- `src/libs/` (→ `/opt/sandbox/lib/`)
- `src/capability/entrypoint.sh` (→ `/opt/sandbox/bin/sandbox-entrypoint.sh`)
- `src/capability/snapshot.sh` (→ `/opt/sandbox/lib/snapshot.sh`)
- `docs/architecture/` (→ `/opt/sandbox/docs/architecture/`)
- `docs/concepts/` (→ `/opt/sandbox/docs/concepts/`)

For an agent image, the hash covers:
- `src/libs/` (→ `/opt/sandbox/lib/`)
- `src/reasoning/entrypoint.sh` (→ `/opt/sandbox/bin/provider-entrypoint.sh`)
- `src/reasoning/providers/<n>/preflight.sh` (if exists → `/opt/sandbox/bin/provider-preflight.sh`)
- `src/reasoning/agent/skills/` (→ `/opt/workflow/agent/skills/`)
- `src/reasoning/agent/prompts/` (→ `/opt/workflow/agent/prompts/`)
- `src/reasoning/providers/<n>/config/` (if exists → `/opt/workflow/agent/config/`)
- `docs/architecture/` (→ `/opt/sandbox/docs/architecture/`)
- `docs/concepts/` (→ `/opt/sandbox/docs/concepts/`)

### Preflight check

The `preflight()` function in `scripts/build.sh` reads the baked `agent-sandbox.container-sig` label from existing images, re-computes it from current source files, and warns on mismatch. The check is non-blocking (warning only) — stale images are not an error to avoid blocking development workflows.

### Scope

Container-sig covers only the sandbox image and tier-3 agent images (the final provider image in the three-tier build). Tier 1 (shared node base) and tier 2 (provider base) images do not carry `/opt/sandbox/` or `/opt/workflow/` content and therefore have no container-sig label.

Harness-sig (runtime drift detection for the harness binary itself) is deferred to a future milestone.


## Identity persistence (registry)

Host-side session identity is recorded in the per-run compose registry, the persisted file `$SANDBOX_DIR/.compose/<SESSION_ID>.yml` (written every run by the compose pipeline). The merged file embeds the identity in the container labels and environment (`SESSION_ID`, `HOST_HEAD_SHA`, `SESSION_TS`), so each run's effective identity survives for inspection and resume recall. Copy-mode resume additionally reads identity from the named volume's Docker labels; mount-mode resume reads it from the registry (M2.6.6). The legacy `.run-identity` cache file is deprecated and no longer written.

On resume, `start_agent.sh` reads this file and exports the values as env vars instead of recomputing them. This guarantees that `diff_export` (reads env vars at teardown) and `package_branch` (reads SESSION_STATE from the volume) use the same identity values.

## SESSION_STATE Schema

Written to the sandbox git repository's state file at container init (first start only):

```
init_sha=<40-char sandbox baseline commit SHA>
session_ts=<timestamp>
host_head_sha=<40-char host HEAD SHA>
session_id=<6-char session run ID>
```

`host_head_sha` enables downstream scripts (apply, draft) running on the host to determine the exact host commit the session branched from, without needing the variable passed in from the session runtime. `session_id` is read by `package_branch` to construct output paths consistent with the session's diff exports.

## Artefact Paths

| Artefact | Path | Notes |
|---|---|---|
| Session diff export | `session-diffs/session/<SESSION_ID>-<BRANCH>/` | Written on container exit |
| Autosave diffs | `session-diffs/autosave/<SESSION_ID>-<BRANCH>/` | Written on autosave ticks |
| Package-branch output | `output/bundles/<EXPORT_TIME>-<LABEL>-<SESSION_ID>/` | On explicit branch packaging |

`SESSION_ID` replaces `SESSION_TS` in artefact directory names. The branch name component (when present) provides human-readable context; `SESSION_ID` provides unique addressing.

## Where Primitives Are Consumed

| Primitive | Derived from | Consumed by |
|---|---|---|
| `PROJECT_NAME` | User input | Image names, container names, Docker labels, compose project name |
| `PROJECT_DIR` | User input | git operations, `HOST_HEAD_SHA` derivation, Docker labels |
| `SANDBOX_DIR` | Operator-supplied | `SESSION_ID` derivation (canonicalized), Docker labels, workspace path derivation |
| `HOST_HEAD_SHA` | `git rev-parse HEAD` | `SESSION_ID` derivation, SESSION_STATE, Docker labels |
| `SESSION_TS` | `date -u` | `SESSION_ID` derivation, Docker labels |
| `SESSION_ID` | `canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS` hash | Container names, artefact paths, Docker labels |
