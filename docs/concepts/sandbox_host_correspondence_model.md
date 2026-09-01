# Sandbox and Host Correspondence Model

The sandbox and host repository are never the same git repository — they have divergent
histories, different baselines, and no shared object store. Yet they must stay in
correspondence: the sandbox must know what the host looks like, the host must be able to
receive what the sandbox produced, and across multiple sessions these two states must
remain coherent.

This document describes the model that keeps them in correspondence across three distinct
cases: live sandbox, stopped sandbox, and newly started sandbox.

Implementation detail and command shapes: [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) (Phase 3 — Join) and [`tool_interface.md`](../architecture/tool_interface.md) (Commands).
Reasoning record: [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md).

---

## Core Principle

Git is a tool used independently inside each repo. It is not the correspondence mechanism
between sandbox and host. The correspondence mechanism is the diff file — a git-agnostic
unified diff that applies cleanly when the target files are in the expected state.

This separation means the harness does not depend on git history, commit SHAs, or object
stores being shared or compatible across the boundary. Any tool that produces or consumes
unified diffs participates in the model.

Further reading: the rationale for this mechanism — git-mediated correspondence as the rejected
alternative, and its relation to the worktree rejection — is recorded in
[container_host_correspondence_mechanism.md](../adr/container_host_correspondence_mechanism.md).

---

## Primitives

| Primitive | Definition |
|---|---|
| **`init_sha`** (from SESSION_STATE) | SHA of the root (baseline) commit in the sandbox. Written once at container init to `.git/SESSION_STATE`, never updated. Defines the lower boundary for `package-branch` — all committed work after this commit belongs to the agent session. `session_ts` is written alongside it. |
| **`package-branch` output** | Numbered per-commit `.diff` files (`patches/`), uncommitted working tree changes (`uncommitted.diff`), all-changes since baseline (`all-changes.diff`), changed-files/ with MANIFEST.txt, and `.export-status` (STATUS, TIMESTAMP, INIT_SHA). On exit, written to `CHANGES_DIR/session/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/` by the dispatcher. Overwrites on each run — always reflects full branch history since `init_sha`. |
| **Draft branch** | `draft/<branch-name>` — temporary branch on the host. Populated by sequential diff application + optional `uncommitted.diff`, ready for `git rebase -i`. |
| **`draft-state`** | File committed as the first commit on a `draft/` branch. Records source branch, from hash, session identity, and diff count. Dropped automatically by `make confirm` before merge — never lands on the target branch. |
| **`.export-status`** | Consolidated metadata file (key=value) written by both `diff_export` and `package_branch`. Contains STATUS, TIMESTAMP, INIT_SHA, and EXIT_CODE on failure. Consumed by `draft.sh` on the host to resolve baseline and timestamp. Replaces prior `EXPORT-TIME.txt` and `.init_sha`. |
| **`SESSION_ID`** | 6-char hex hash: `sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]`. Identifies a single session run. `SANDBOX_DIR` is canonicalized so every path spelling of one folder converges to one id. Replaces `SESSION_TS` in container names and artefact paths. The former separate `SANDBOX_ID` intermediate was removed (see [session_identifier.md](../adr/session_identifier.md)). |
| **`HOST_HEAD_SHA`** | Full SHA of host HEAD at session start. Replaces `REPO_COMMIT`. |
| **Session artefact directory** | `SANDBOX_DIR/.workspace/session-diffs/{session,autosave}/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/` — `session/` holds exit artefacts, `autosave/` holds checkpoint artefacts. Each is overwritten on each invocation. |
| **Container labels** | Docker labels set on the capability layer container at session start. Ground truth for session identity. Labels: `agent-sandbox.project-dir`, `agent-sandbox.session-name`. |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow via diff files through the bind-mounted workspace.
- No `docker exec` is used for correspondence operations. All state transfer happens via bind-mounted files.
- No unreviewed changes become commits. `make apply` lands changes uncommitted; `make draft` lands changes on an explicitly-named `draft/` branch requiring operator review before merge.
- One draft is active per repo at a time. `draft-state` records which branch is staged; `make draft` guards against starting a second draft while one is in progress.
- The harness does not track which diffs have been applied. The operator selects what to apply via explicit arguments. Defaults cover the common case.
- Session artefact directories are non-colliding across concurrent worktree sessions. Branch name is the folder differentiator; git enforces branch uniqueness across worktrees.

---

## Correspondence Cycle

The full lifecycle — init, running, stopped, restart — as a single sequence. Loop
checkpoints mark where the cycle repeats.

```
[Host]                               [Sandbox]
HEAD = A                             (not yet started)
  │                                    │
  │        [INIT]                      │
  ├─ git archive HEAD ─────────────────►│
  │  rsync working tree                ├─ unpack baseline.tar → baseline commit
  │                                    ├─ init_sha written to SESSION_STATE (root commit SHA)
  │                                    ├─ rsync overlay (working tree state)
  │                                    │  init_sha = A
  │                                    │
  │        [RUNNING — loop start]      │
  │                                    ├─ agent works, commits accumulate
  │                                    │
  │  ◄── autosave ──────────────────────┤  sandbox → host (mid-session checkpoint)
  │      autosave/<SESSION_TS>-<BRANCH>/  │    uncommitted.diff + patches/ + changed-files/ (overwritten each tick)
  │                                    │
  ├─ make apply DIFF=<path> ──────────►│  host → sandbox (amendment, fix)
  │                                    ├─ agent reviews, commits
  │                                    │
  │  ◄── diff_export ─────────────────┤  sandbox → host (on exit)
  │      session/<SESSION_TS>-<BRANCH>/   │  uncommitted.diff + all-changes.diff + patches/*.diff + changed-files/
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

**INIT — establishing correspondence**

Before the container starts, the harness snapshots the host: `git archive HEAD` produces a
tar of the committed state; rsync copies the operator's working tree alongside it. Inside
the container, `snapshot_init_git` unpacks the tar, commits as the baseline, writes
`init_sha` (via SESSION_STATE), then overlays the rsync copy so the working tree matches the operator's
on-disk state. At this point sandbox file content exactly matches the host. `init_sha` is
the fixed reference for all diff packaging in this container lifetime.

**RUNNING — bidirectional flow**

Changes can flow in either direction at any time while the sandbox is live. All transfers
use the same diff format and the same `make apply` command regardless of direction.

- **Sandbox → host (mid-session checkpoint):** The autosave loop exports `uncommitted.diff`, `patches/`, and `changed-files/` under `autosave/<SESSION_TS>-<BRANCH>/`. Overwritten each tick. Operator runs `make apply DIFF=<full path to exact diff file>` on the host, reviews, commits manually.
- **Host → sandbox (amendment):** Operator packages a host change with `make package-branch` (host-side, writes to `INPUT_DIR`). Agent reviews and commits. The next `package-branch` includes this commit in the series.
- **Sandbox → host (committed work):** On container exit, `diff_export` writes `uncommitted.diff`, `all-changes.diff`, `patches/*.diff`, and `changed-files/` into `session/<SESSION_TS>-<BRANCH>/`. This runs automatically via the EXIT trap.

**STOPPED — applying persisted artefacts**

The operator works entirely from the persisted session artefacts. No container interaction
is possible or required. `make draft` creates a `draft/<branch>` branch from `FROM`
(default: `HEAD`; supply an explicit hash if the host has advanced) and applies the
numbered diffs in order. `DIFFS=start..end` selects a sub-range — the operator's mechanism
for skipping already-confirmed diffs without harness tracking. After `git rebase -i` and
merge, `make confirm` cleans up the draft branch.

On failure: `make draft` stops at the failing diff and reports the file and hunk. Operator
runs `make reject`, amends the failing diff in the source export folder, and re-runs
`make draft`. The diff series is the source of truth; the draft branch is always derived
from it.

**RESTART — resetting correspondence**

On the next container start, the harness snapshots the current host HEAD — incorporating
all sessions confirmed since the last container — and establishes a new `init_sha` from
that snapshot. What carries over: session artefacts in `session-diffs/` persist in
`SANDBOX_DIR` and remain available to the operator; provider config files are copied into
the new container at startup. What resets: `init_sha` is recomputed from scratch; agent
session context (conversation history, in-progress work) is lost unless the provider
supports session resume (M2.6 scope).

---

## Diff Format

One format. Two directions. Same tools.

Produced by `git diff` with `index <sha>..<sha>` lines stripped. Applied by `git apply`
with the same stripping:

```bash
grep -v '^index ' "$DIFF" | git -C "$TARGET_DIR" apply
```

No `git am`, no `format-patch`, no git metadata headers. Works identically in both
directions and on both host and container.

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

Two sessions against different worktrees maintain independent correspondence with their
respective host worktrees. Every token that could collide is scoped per worktree:

| Token | Scoped by | Collision possible? |
|---|---|---|
| Session artefact directory | Branch name | No — git enforces branch uniqueness across worktrees |
| Container names | Session identity | No — per-session name |
| Container labels | `project-dir` label scopes lookup | No — label lookup is project-scoped |
| `draft-state` | `SANDBOX_DIR` | No — separate file per worktree |

Each worktree session runs its correspondence cycle independently. Merging worktree output
to the main repo branch is standard git — the harness does not orchestrate cross-worktree
merges.

---

## Model Gaps

**Mixing `make apply` and `make draft` within a single session:** Resolved. Under the
current model the two paths are structurally separate: `make apply` applies an exact
diff file (`--diff=<path>`, no channel resolution) and lands changes uncommitted in
the working tree; `make draft` resolves from the `session` channel
(`session-diffs/session/`) or `bundles` channel (`output/bundles/`) and applies
committed diffs to a branch. The artefact locations do not overlap and there is no
shared application mechanism. No undefined behaviour remains.

**Mixed session types across sessions:** Closed as explicitly out of scope. A project
using both Claude Chat sessions (`package-branch` / `make apply`) and OpenCode sessions
(`package-branch` / `make draft`) against the same repo involves intentionally different
workflows targeting different artefact channels. The harness makes no claim to coordinate
across session types, and doing so is not intended behaviour. If cross-session-type
coordination becomes a real use case, it warrants a story at that time.

---

## References

| Document | Purpose |
|---|---|
| [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md) | Full design record — export pipeline, channels, commands |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline; SESSION_STATE initialisation; Phase 3 join |
| [`provider_lifecycle.md`](../architecture/provider_lifecycle.md) | Provider config copy-in at session start |
