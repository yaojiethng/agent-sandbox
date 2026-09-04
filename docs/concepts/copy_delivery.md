# Copy Delivery (Volume-Backed Sandbox)

Copy delivery is the current default sandbox delivery: the agent's working content lives in a named Docker volume, seeded once at session start from the host's working tree, and changes return to the host through the diff pipeline. Companion model: [`mount_delivery.md`](mount_delivery.md). Rationale for the delivery-model axis (worktree rejection, harness-owns-the-boundary principle): [`sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md).

Implementation detail and command shapes: [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) and [`execution_model.md`](../architecture/execution_model.md).

---

## Model

- The sandbox is a named volume (`<compose-project>_sandbox-data`), one per session, identified by `SESSION_ID`. It survives stop/start; teardown (`compose down`) never destroys it.
- At fresh start, the host materializes the operator's state into the volume: git index = HEAD commit, working tree = operator's on-disk state (tracked modifications, untracked non-ignored files, uncommitted deletions and renames).
- The agent works exclusively inside the volume. Host changes during the session are invisible — copy delivery freezes the agent's view at session start.
- Changes are exported through the diff pipeline (`diff_export` / `package_branch`), which is git-agnostic and does not require shared history — see [`sandbox_host_correspondence_model.md`](sandbox_host_correspondence_model.md).
- Resume skips all seeding: the volume's git state is authoritative. Fresh-start and resume differ only in the seeding step.

### Core invariant — git status parity

After fresh-start seeding, `git status` inside the sandbox must show what the operator would see in `PROJECT_DIR`: index at HEAD, working tree matching disk, gitignored content absent. Exclusion correctness (local `.gitignore`, global `core.excludesFile`, `.git/info/exclude`) is a security requirement, not a convenience — gitignored files must never cross the boundary.

---

## Current pipeline (RO mount, current until seeding lands)

Fresh start (`start_agent.sh`) builds a staging directory and the container consumes it:

| Step | Where | Mechanism |
|---|---|---|
| Working-tree copy | host | rsync (`snapshot_copy_worktree`) into `$SANDBOX_DIR/.snapshot/` |
| Baseline archive | host | `git archive HEAD` → `.snapshot/baseline.tar` |
| Validation gate 1 | host | `snapshot_validate` — aborts before Docker on a bad snapshot |
| RO mount | compose | `.snapshot/` bind-mounted read-only into the capability layer only |
| Validation gate 2 | container | `snapshot_validate` against the mounted directory |
| Sandbox init | container | `snapshot_init_git` — extract `baseline.tar` into the volume (index = HEAD), then rsync the staged tree over it (`--delete`; working tree = disk) |
| Resume | — | pipeline skipped entirely; `.snapshot/` is stale but never accessed |

Staging is rebuilt from scratch on every fresh start (`rm -rf` first), so nothing from a prior session propagates. On filesystems that do not track exec bits, `core.fileMode=false` is set and modes recover through the diff pipeline.

## Settled direction — host-side volume seed (not yet implemented)

The RO mount is transitional. The settled mechanism (design walk `20260818-02`; its dependency, the compose file-set mechanism, has since landed) seeds the volume host-side before `compose up`:

1. Build a single tar of the working state host-side.
2. Seed the volume with a one-shot container (`docker create` + `docker cp`, or `docker run --rm` with both mounts) reusing the sandbox image.
3. Bring the session up with **no snapshot mount**: fresh and resume compose files become identical, staging exists only during the seed step, and gate 2 disappears.

The serialization is **git-enumerated tar** (discovery-validated, see below): enumerate the file set with git itself (`git ls-files --cached` for tracked files still on disk, plus `git ls-files --others --exclude-standard` for untracked non-ignored files), then pack that exact list (`tar --null -T`). Deleted tracked files are absent by construction, and all three ignore sources are honored by git's own rules — no tar-side exclusion logic. The index/worktree split (index = HEAD, worktree = disk) is reconstructed in-container from the seeded tree plus the baseline state.

Discovery results (sessions scripts: `scripts/manual/discovery_tar_filelist_parity.sh`, `scripts/manual/discovery_tar_roundtrip.sh`):

- **Round-trip is lossless** — file list, content hashes, modes, and symlink targets survive build-and-extract exactly.
- **Parity with the current pipeline holds on the full fixture matrix** (tracked/untracked/deleted/renamed/nested gitignore/global excludes/info-exclude/symlinks/exec bits/binary/spaces/unicode/negation patterns), with two recorded divergences:
  - **Negation patterns — the current pipeline is worse, not better.** rsync treats `!pattern` in an exclude file as *clear the exclude list*: a global `!keep.debug` line silently leaks every previously excluded file (`drop.debug`, and the globally-ignored `globalonly.txt`) into the sandbox. The git-enumerated tar honors negation correctly. This is a latent exclusion leak (invariant violation) in the current pipeline that seeding removes.
  - **Empty directories** exist only in the rsync copy; git cannot represent them and the tar does not carry them. Invisible to `git status`; recorded as an accepted behavior change.
- Open implementation decision (for the seeding iteration): the index/worktree split mechanism in-container, and the seed transport variant (`docker cp` vs `docker run --rm`).

---

## Session lifecycle

| Action | Behavior |
|---|---|
| `make start` (new) | New SESSION_ID, fresh volume, seed pipeline |
| `make resume` | Registry lookup (`.compose/<session-id>.yml`), volume re-attached, no seeding |
| `make stop` | `compose stop` — containers + volume preserved |
| `make prune` | Removes stopped sessions with no matching registry record (volumes + containers); worktrees untouched |

Volume locking: a volume attached to a running session cannot start a second concurrent session. Registry-based discovery is the source of truth for resume and prune; volume labels remain for docker-side disambiguation.

---

## References

| Document | Purpose |
|---|---|
| [`../adr/sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md) | Why copy/mount, worktree backing rejected |
| [`mount_delivery.md`](mount_delivery.md) | Companion delivery model (M2.6.6) |
| [`../architecture/sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Pipeline implementation detail |
| [`../architecture/security.md`](../architecture/security.md) | Security posture — copy + fresh baseline profile |
| [`../../devlog/discussions/20260730-design-settled-copy_model.md`](../../devlog/discussions/20260730-design-settled-copy_model.md) | Historical design record (volume-per-session concurrency) |
| [`../../devlog/roadmap_future.md`](../../devlog/roadmap_future.md) | Deferred seeding subtasks |
