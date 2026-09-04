# Copy Delivery (Volume-Backed Sandbox)

Copy delivery is the default sandbox delivery: the agent's working content lives in a named Docker volume, filled once at session start from the host's working tree, and changes return to the host through the diff pipeline. The delivery-model rationale (why copy or mount, why worktree backing is rejected, the seed-transport decision) is recorded in [`sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md). Companion model: [`mount_delivery.md`](mount_delivery.md).

## Model

- The sandbox is one Docker volume per session, identified by the session id. It survives stop and start; teardown never destroys it.
- At fresh start, a seeder fills the volume with the operator's state: repository with its index, working tree at disk state.
- The agent works exclusively inside the volume. Host changes during the session are invisible -- copy delivery freezes the agent's view at session start.
- Changes return to the host through the diff pipeline, which is git-agnostic and needs no shared history -- see [`sandbox_host_correspondence_model.md`](sandbox_host_correspondence_model.md).
- Resume skips seeding entirely: the volume's git state is authoritative. Fresh start and resume differ only in the fill step.

## What the user relies on

Copy delivery is a behavioral contract between the harness and the operator. Everything below is observable from outside the harness; the internal design that delivers it is recorded in [`sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md).

- **Your ignored files stay on your machine.** What enters the sandbox is decided by git's own ignore resolution. Gitignored content is never copied into the sandbox, and never copied-and-cleaned-up-afterwards -- there is no point in the pipeline where it exists on the sandbox side.
- **The sandbox starts as your repo.** After a fresh start, `git status` inside the sandbox is exactly what you see in your project, including which changes you had staged: your on-disk edits in the working tree, your staged changes still staged, your untracked non-ignored files present, your deletions visible.
- **The harness never touches your git history.** The harness copies your repository and returns changes as diffs you review. It does not commit, merge, rewrite, or mediate any git operation between you and your repository.
- **Sessions are isolated.** Each session works in its own volume. Two sessions of the same project never see each other's content.
- **Your repo is the only source of truth.** The volume is the agent's workspace only. Changes come back exclusively as diffs; nothing writes to your project directory during a session.
- **Starting works offline.** Filling the sandbox needs no network: no image pulls, no package installs at start time.
- **The harness leaves no litter in your repo.** Harness working state never lives inside your project's git worktree -- not permanently, not transiently during a session.

## Seed interface

Fresh start fills the empty volume with a one-shot seeder container. The interface:

```
project (bind, read-only)  ──►  seeder  ──►  session volume (write)
```

The seeder is the sandbox image. It reads the project read-only, writes the volume, and exits. Its contract:

| Input | Output | Guarantee |
|---|---|---|
| Project worktree at `/src`, session volume at the sandbox mount point | Volume holding `.git` and the working tree | `git status` identical to the project including staging state, gitignored content absent, no harness state in the worktree |

Internally the seeder copies the repository natively, including its index, and streams the git-enumerated file set; it verifies the copy by comparing `git status` between the project and the volume, and a divergence aborts the start. The exact commands and their per-requirement mapping are in the ADR's seed-transport entry. The seeder runs offline and before any session container starts: a failed seed aborts the start with a host-side error, and no session container is created.

## Session lifecycle

| Action | Behavior |
|---|---|
| `make start` (new) | New session id, fresh volume, seeder runs |
| `make resume` | Registry lookup, volume re-attached, no seeding |
| `make stop` | Containers stopped, volume preserved |
| `make prune` | Removes stopped sessions with no registry record (volumes and containers) |

Volume locking: a volume attached to a running session cannot start a second concurrent session. Registry-based discovery is the source of truth for resume and prune; volume labels remain for docker-side disambiguation.

## References

| Document | Purpose |
|---|---|
| [`../adr/sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md) | Requirements, seed-transport decision, rejected alternatives, defect history |
| [`mount_delivery.md`](mount_delivery.md) | Companion delivery model |
| [`../architecture/sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Session lifecycle implementation detail |
| [`../architecture/execution_model.md`](../architecture/execution_model.md) | Compose generation and container topology |
| [`../architecture/security.md`](../architecture/security.md) | Security posture -- copy and fresh-baseline profile |
