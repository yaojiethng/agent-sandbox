# Sandbox and Host Interface

The sandbox and host repository are never the same git repository -- they have divergent histories, different baselines, and no shared object store. Yet they must stay in correspondence: the sandbox must know what the host looks like, the host must be able to receive what the sandbox produced, and across multiple sessions these two states must remain coherent.

This document is the interface contract between them. It names the contract surfaces, what the harness expects from each co-resident copy, and the version declaration and comparison points that keep the copies interoperable. It covers three distinct cases: live sandbox, stopped sandbox, and newly started sandbox.

The interface contract governs the container boundary. The agent tool surface (CLI flags, output formats) is a different boundary -- see [`tool_interface.md`](../architecture/tool_interface.md). The two documents do not overlap: tool_interface names what an agent sees; this document names what the harness wires and what each copy must provide.

Implementation detail and command shapes: [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) (Phase 3 -- Join) and [`tool_interface.md`](../architecture/tool_interface.md) (Commands).
Reasoning record: [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md).

---

## Contract surfaces

The interface contract has four surfaces. Each is versioned by the same `INTERFACE_CONTRACT_VERSION` constant (see [Version declaration and comparison](#version-declaration-and-comparison)).

| Surface | What it is | Co-resident copies |
|---|---|---|
| Wiring shape | Bind-mount folder shape, `SANDBOX_DIR` format, container entrypoints, volume layout | Host source (`scripts/`, `src/build/`), baked images, generated `.compose` file |
| Command semantics | `package-branch`, `diff_export`, `make apply/draft/confirm/reject` shapes; entrypoint validation requirements | Host commands, baked `/opt/sandbox/lib/` in each image |
| Record schema | `.compose/<session-id>.yml` label set + in-worktree `SESSION_STATE` key set | Generated record, host readers (resume/list), both containers' libs |
| Docker labels | `agent-sandbox.*` label set consumed by orchestration and identity lookups | Built images, generated `.compose` file |

## Expectations per co-resident copy

| Copy | Expectation |
|---|---|
| Host source | Declares `INTERFACE_CONTRACT_VERSION` once; drives comparisons at preflight; writes the record stamps (`.compose` labels at compose generation, `SESSION_STATE` key at session write) |
| Tier-3 images (sandbox + agent) | Carry the `agent-sandbox.interface-contract-version` label baked at build |
| Record (`.compose` + `SESSION_STATE`) | Carries the version stamped at session write; host-readable without starting a container |
| Both containers | At P2 (authoritative regime), the agent entrypoint compares container-baked constants (sandbox inits first) |

## Version declaration and comparison

`INTERFACE_CONTRACT_VERSION` is declared once in `src/libs/interface_contract.sh` (host side). Bump rule: increment it exactly when a cross-boundary contract change lands -- wiring shape, mount/bind shape, `SANDBOX_DIR` format, onboard command shape, host/container command semantics, session-record schema, or the docker labels a container consumes. Doc edits, tests, and internal refactors never bump it. The record schema is itself versioned by the same constant on its next bump.

Declaration points:

1. **Build time** -- tier-3 images receive `agent-sandbox.interface-contract-version` as a build label (`build_image` in `scripts/build.sh`).
2. **Session write** -- the generated `.compose/<session-id>.yml` records the constant in its session label set; `session_state_write_set` writes the `interface_contract_version` key into `SESSION_STATE`.

Comparison points (authoritative, at start and resume preflight): the contract is fail-closed by default, with no runtime escape hatch. An override was considered and rejected as a backdoor that would weaken the contract.

- Host constant vs sandbox-image label; host constant vs agent-image label. A drift or missing label refuses preflight (non-zero) and names the rebuild remedy; alignment stays silent.

Container<->container comparison (agent entrypoint, sandbox inits first and writes its own baked version into `SESSION_STATE`, read by the agent via `volumes_from: sandbox`):

- The agent entrypoint compares its baked version against the sandbox's recorded version. A definite mismatch hard-stops the agent as an orchestration/corruption signal; a missing record key or file warns (pre-record image, upgrade path); a missing lib skips silently.

The interim `container-sig` source-subset hash and its preflight comparison are retired; the interface-contract version is the standalone container-boundary contract.

Deferred (host constant vs record stamps at preflight): the record surface compares at the agent entrypoint only, not yet at preflight. This remains a candidate extension; it is not scheduled.

The P0-P3 rollover and the container-sig retirement are recorded in [the design record](../../devlog/discussions/20260919-design-interface_contract_compatibility.md) and [interface_contract_compatibility.md](../adr/interface_contract_compatibility.md).

### Relationship to MAKEFILE_VERSION

The sandbox's `.env` carries a separate host-side marker, `MAKEFILE_VERSION`, stamped at onboard time from the `Makefile.template` version marker. It is a different use case, not part of the interface contract: it is host-internal (template in the repo vs the onboarded project copy), has no container party, and bumps on Makefile-template surface changes (frequent). `INTERFACE_CONTRACT_VERSION` is the cross-boundary contract and bumps only on contract changes (rare). Do not fold the two into one number. As of this writing `MAKEFILE_VERSION` has no consumer -- it is a write-only marker; the stale-onboarded-file detection it was designed for is not wired. Its doc edits and interface surfaces live in [`project_onboarding_guide.md`](../operations/project_onboarding_guide.md).

---

## Core Principle

Git is a tool used independently inside each repo. It is not the correspondence mechanism between sandbox and host. The correspondence mechanism is the diff file -- a git-agnostic unified diff that applies cleanly when the target files are in the expected state.

This separation means the harness does not depend on git history, commit SHAs, or object stores being shared or compatible across the boundary. Any tool that produces or consumes unified diffs participates in the model.

Further reading: the rationale for this mechanism -- git-mediated correspondence as the rejected alternative, and its relation to the worktree rejection -- is recorded in [container_host_correspondence_mechanism.md](../adr/container_host_correspondence_mechanism.md).

---

## Primitives

| Primitive | Definition |
|---|---|
| **`init_sha`** (from SESSION_STATE) | SHA of the root (baseline) commit in the sandbox. Written once at container init to `.git/SESSION_STATE`, never updated. Defines the lower boundary for `package-branch` -- all committed work after this commit belongs to the agent session. `session_ts` is written alongside it. |
| **`package-branch` output** | Numbered per-commit `.diff` files (`patches/`), uncommitted working tree changes (`uncommitted.diff`), all-changes since baseline (`all-changes.diff`), changed-files/ with MANIFEST.txt, and `.export-status` (STATUS, TIMESTAMP, INIT_SHA). On exit, written to `CHANGES_DIR/session/<EXPORT_TIME>-<SESSION_ID>/` by the dispatcher. Overwrites on each run -- always reflects full branch history since `init_sha`. |
| **Draft branch** | `draft/<branch-name>` -- temporary branch on the host. Populated by sequential diff application + optional `uncommitted.diff`, ready for `git rebase -i`. |
| **`draft-state`** | File committed as the first commit on a `draft/` branch. Records source branch, from hash, session identity, and diff count. Dropped automatically by `make confirm` before merge -- never lands on the target branch. |
| **`.export-status`** | Consolidated metadata file (key=value) written by both `diff_export` and `package_branch`. Contains STATUS, TIMESTAMP, INIT_SHA, and EXIT_CODE on failure. Consumed by `draft.sh` on the host to resolve baseline and timestamp. Replaces prior `EXPORT-TIME.txt` and `.init_sha`. |
| **`SESSION_ID`** | 6-char hex hash: `sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]`. Identifies a single session run. `SANDBOX_DIR` is canonicalized so every path spelling of one folder converges to one id. Replaces `SESSION_TS` in container names and artefact paths. The former separate `SANDBOX_ID` intermediate was removed (see [session_identifier.md](../adr/session_identifier.md)). |
| **`HOST_HEAD_SHA`** | Full SHA of host HEAD at session start. Replaces `REPO_COMMIT`. |
| **Session artefact directory** | `SANDBOX_DIR/.workspace/session-diffs/{session,autosave}/` -- `session/` holds per-export directories named `<EXPORT_TIME>-<SESSION_ID>` (exit artefacts), `autosave/` holds the single `<SESSION_ID>/` checkpoint directory, overwritten on each autosave tick. |
| **Session label set** | Docker labels set on containers at session start, baked into the generated compose file (`x-session-labels` anchor). Labels: `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.host-head-sha`, `agent-sandbox.host-branch`, `agent-sandbox.session-ts`, `agent-sandbox.session-id`, `agent-sandbox.agent-image-digest`, `agent-sandbox.sandbox-image-digest`, `agent-sandbox.interface-contract-version`. |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow via diff files through the bind-mounted workspace.
- No `docker exec` is used for correspondence operations. All state transfer happens via bind-mounted files.
- No unreviewed changes become commits. `make apply` lands changes uncommitted; `make draft` lands changes on an explicitly-named `draft/` branch requiring operator review before merge.
- One draft is active per repo at a time. `draft-state` records which branch is staged; `make draft` guards against starting a second draft while one is in progress.
- The harness does not track which diffs have been applied. The operator selects what to apply via explicit arguments. Defaults cover the common case.
- Session artefact directories are non-colliding across concurrent sessions: `SESSION_ID` (canonical sandbox dir, host HEAD, session timestamp) is the folder differentiator, and per-export timestamps keep successive exports apart.

---

## Correspondence Cycle

The full lifecycle -- init, running, stopped, restart -- as a single sequence. Loop checkpoints mark where the cycle repeats.

```text
[Host]                               [Sandbox]
HEAD = A                             (not yet started)
  │                                    │
  │        [INIT]                      │
  ├─ seeder: cp .git ─────────────────►│
  │  stream git-enumerated worktree    ├─ .git + working tree + SESSION_STATE
  │  (git status parity verified)      │  init_sha = A
  │                                    │
  │        [RUNNING — loop start]      │
  │                                    ├─ agent works, commits accumulate
  │                                    │
  │  ◄── autosave ──────────────────────┤  sandbox → host (mid-session checkpoint)
  │      autosave/<SESSION_ID>/         │    uncommitted.diff + patches/ + changed-files/ (overwritten each tick)
  │                                    │
  ├─ make apply DIFF=<path> ──────────►│  host → sandbox (amendment, fix)
  │                                    ├─ agent reviews, commits
  │                                    │
  │  ◄── diff_export ─────────────────┤  sandbox → host (on exit)
  │      session/<EXPORT_TIME>-<SESSION_ID>/ │  uncommitted.diff + all-changes.diff + patches/*.diff + changed-files/
  │                                    │
  │        [STOPPED]                   │
  │                                    X  container exits; artefacts persisted
  │
  ├─ make draft [BUNDLE=<name>]
  │             [CHANNEL=<channel>]
  │    └─ draft/<branch> created
  │       diffs applied in order via git apply
  │
  ├─ git rebase -i / review
  ├─ make confirm
  ▼
HEAD = B
  │
  │        [RESTART — loop back to INIT]
  └─ (new container snapshots HEAD = B; new init_sha established)
```

### INIT -- establishing correspondence

Before the container starts, the harness seeds the sandbox volume with the helper-container transport: a one-shot seeder copies the repository natively (`.git` including the index), streams the git-enumerated working tree into the volume, and writes `init_sha` (the repository HEAD at seed time) plus the session identity into SESSION_STATE. The seeder verifies the result by comparing `git status` between the project and the volume before it exits. At this point sandbox file content and staging state exactly match the host. `init_sha` is the fixed reference for all diff packaging in this container lifetime.

### RUNNING -- bidirectional flow

Changes can flow in either direction at any time while the sandbox is live. All transfers use the same diff format and the same `make apply` command regardless of direction.

- **Sandbox -> host (mid-session checkpoint):** The autosave loop exports `uncommitted.diff`, `patches/`, and `changed-files/` under `autosave/<SESSION_ID>/`. Overwritten each tick. Operator runs `make apply DIFF=<full path to exact diff file>` on the host, reviews, commits manually.
- **Host -> sandbox (amendment):** Operator packages a host change with `make package-branch` (host-side, writes to `INPUT_DIR`). Agent reviews and commits. The next `package-branch` includes this commit in the series.
- **Sandbox -> host (committed work):** On container exit, `diff_export` writes `uncommitted.diff`, `all-changes.diff`, `patches/*.diff`, and `changed-files/` into `session/<EXPORT_TIME>-<SESSION_ID>/`. This runs automatically via the EXIT trap.

### STOPPED -- applying persisted artefacts

The operator works entirely from the persisted session artefacts. No container interaction is possible or required. `make draft` creates a `draft/<branch>` branch from `FROM` (default: `HEAD`; supply an explicit hash if the host has advanced) and applies the numbered diffs in order. `DIFFS=start..end` selects a sub-range -- the operator's mechanism for skipping already-confirmed diffs without harness tracking. After `git rebase -i` and merge, `make confirm` cleans up the draft branch.

On failure: `make draft` stops at the failing diff and reports the file and hunk. Operator runs `make reject`, amends the failing diff in the source export folder, and re-runs `make draft`. The diff series is the source of truth; the draft branch is always derived from it.

### RESTART -- resetting correspondence

On the next container start, the harness snapshots the current host HEAD -- incorporating all sessions confirmed since the last container -- and establishes a new `init_sha` from that snapshot. What carries over: session artefacts in `session-diffs/` persist in `SANDBOX_DIR` and remain available to the operator; provider config files are copied into the new container at startup. What resets: `init_sha` is recomputed from scratch; agent session context (conversation history, in-progress work) is lost unless the provider supports session resume (M2.6 scope).

---

## Diff Format

One format. Two directions. Same tools.

Produced by `git diff` with `index <sha>..<sha>` lines stripped. Applied by `git apply` with the same stripping:

```bash
grep -v '^index ' "$DIFF" | git -C "$TARGET_DIR" apply
```

No `git am`, no `format-patch`, no git metadata headers. Works identically in both directions and on both host and container.

---

## Command Map

| Command | Available on | What it does |
|---|---|---|
| `bash /opt/sandbox/lib/package_branch.sh --to=<dir>` | Container | Packages all artefacts (patches, uncommitted, all-changes, changed-files) into `<to>/bundles/<ts>[-<label>]-<runid>/`. |
| `bash .../package_branch.sh --to=<dir> [--baseline=<sha>]` | Container | Packages all commits since `init_sha` as numbered diffs + `uncommitted.diff` + `all-changes.diff` + `changed-files/` under `<to>/bundles/<ts>-<label>/`. |

| `agent-sandbox package-branch --sandbox=<path>` | Host | Host-side wrapper. Derives `INPUT_DIR` from `SANDBOX_DIR` via `dirs_resolve`, writes to `INPUT_DIR/bundles/<ts>-<label>/`. |
| `make apply DIFF=<path> [INTERACTIVE=1]` | Host | Applies an exact diff file (`--diff=<path>` required) uncommitted. `--interactive` previews the changes + asks for confirmation. |
| `make draft [CHANNEL=<channel>] [BUNDLE=<name>] [INTERACTIVE=1]` | Host | Creates `draft/<branch>`, applies patches then `uncommitted.diff`. Default: `session` channel. `INTERACTIVE=1` prompts through channel/bundle picker. |
| `make confirm [TARGET=<branch>]` | Host | Cleans up draft branch after operator rebase and merge. |
| `make reject` | Host | Discards draft branch. Artefacts unchanged. |

---

## Correspondence Across Parallel Sessions

Two sessions against different worktrees maintain independent correspondence with their respective host worktrees. Every token that could collide is scoped per worktree:

| Token | Scoped by | Collision possible? |
|---|---|---|
| Session artefact directory | Branch name | No -- git enforces branch uniqueness across worktrees |
| Container names | Session identity | No -- per-session name |
| Container labels | `project-name` label scopes lookup | No -- label lookup is project-scoped |
| `draft-state` | `SANDBOX_DIR` | No -- separate file per worktree |

Each worktree session runs its correspondence cycle independently. Merging worktree output to the main repo branch is standard git -- the harness does not orchestrate cross-worktree merges.

---

## Model Gaps

**Mixing `make apply` and `make draft` within a single session:** Resolved. Under the current model the two paths are structurally separate: `make apply` applies an exact diff file (`--diff=<path>`, no channel resolution) and lands changes uncommitted in the working tree; `make draft` resolves from the `session` channel (`session-diffs/session/`) or `bundles` channel (`output/bundles/`) and applies committed diffs to a branch. The artefact locations do not overlap and there is no shared application mechanism. No undefined behaviour remains.

**Mixed session types across sessions:** Closed as explicitly out of scope. A project using both Claude Chat sessions (`package-branch` / `make apply`) and OpenCode sessions (`package-branch` / `make draft`) against the same repo involves intentionally different workflows targeting different artefact channels. The harness makes no claim to coordinate across session types, and doing so is not intended behaviour. If cross-session-type coordination becomes a real use case, it warrants a story at that time.

---

## References

| Document | Purpose |
|---|---|
| [`interface_contract_compatibility.md`](../adr/interface_contract_compatibility.md) | Interface-contract version mechanism, rollover gates |
| [`container_host_correspondence_mechanism.md`](../adr/container_host_correspondence_mechanism.md) | Why the diff file, not git, is the mechanism |
| [`sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md) | Delivery wiring (copy/mount) -- the wiring surface |
| [`harness_versioning.md`](../adr/harness_versioning.md) | Per-surface version semantics (digest, HEAD, symlink) |
| [`drift_state_coherence.md`](../adr/drift_state_coherence.md) | Coherence by minimisation, not detection |
| [`session_identifier.md`](../adr/session_identifier.md) | Project/session identity |
| [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md) | Full design record -- export pipeline, channels, commands |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline; SESSION_STATE initialisation; Phase 3 join |
| [`provider_lifecycle.md`](../architecture/provider_lifecycle.md) | Provider config copy-in at session start |
