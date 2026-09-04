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

## Current pipeline — host-side volume seed

Fresh start (`run_agent.sh` `seed_sandbox_volume`, copy delivery only):

| Step | Where | Mechanism |
|---|---|---|
| Seed tar build | host | `snapshot_seed_tar` — git-enumerated working tree under the sentinel prefix + `baseline.tar` (`git archive HEAD`), to a per-run mktemp |
| Volume creation | host | `docker compose create sandbox` — creates volume + container without starting |
| Content transfer | host | `docker cp` extracts the seed tar into the volume through the container's mount path |
| Sandbox init | container | `snapshot_init_git` — extract `baseline.tar` into the sandbox (index = HEAD), commit, then rsync the seed's `worktree/` over it (`--delete`; working tree = disk); seed members and staging removed |
| Resume | — | pipeline skipped entirely; the volume's git state is authoritative |

Staging exists only during the seed step. There is no snapshot mount, no `.snapshot/` directory, and no entrypoint gate — a failed seed aborts the start before any container runs. On filesystems that do not track exec bits, `core.fileMode=false` is set and modes recover through the diff pipeline.

## Settled direction — implemented (record)

The RO-mount pipeline this replaced had two defects now resolved by construction:

- **Negation patterns** — rsync treats `!pattern` in an exclude file as *clear the exclude list*: a global `!keep.debug` line silently leaked every previously excluded file (including gitignored content) into the sandbox. The git-enumerated tar honors negation correctly. Discovered in handover `20260901-13`; a live leak in the previous pipeline.
- **Empty directories** existed only in the rsync copy; git cannot represent them and the tar does not carry them. Invisible to `git status`; accepted behavior change.

The serialization is **git-enumerated tar**: enumerate the file set with git itself (`git ls-files --cached` for tracked files still on disk, plus `git ls-files --others --exclude-standard` for untracked non-ignored files), then pack that exact list (`tar --null -T`). Deleted tracked files are absent by construction, and all three ignore sources are honored by git's own rules — no tar-side exclusion logic. The index/worktree split (index = HEAD, worktree = disk) is reconstructed in-container by `snapshot_init_git` from the seeded members.

Discovery record: `tests/knowledge/discovery_tar_*.sh` (handover `20260901-13`).

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
