# Design — Copy Delivery Seed Transport (Helper Container)

**Status:** settled — decision recorded in [`../../docs/adr/sandbox_delivery_model.md`](../../docs/adr/sandbox_delivery_model.md) (2026-09-04 entry)

**Direction + Parent:** M2.6 — Session Persistence (copy delivery seed transport). Companion to [`20260730-design-settled-copy_model.md`](20260730-design-settled-copy_model.md), which owns the volume persistence and concurrency model this transport serves.

## Context

Fresh-start copy delivery must materialize the operator's state into the sandbox volume: git index = HEAD, working tree = on-disk state (tracked modifications, untracked non-ignored files, deletions), gitignored content absent. The current pipeline does this in seven host/container steps built around `docker cp` of a hand-built seed tar: tar build (mktemp, member-prefix transform) → `docker cp` stdin extract → read-back verification (stdin-mode byte counter always reports 0B) → container-side `baseline.tar` unpack → mixed git init → rsync overlay → tar-transform symlink repair + staging cleanup.

A production stall (session `20260902-182452` dry-run: host branch tracked `.agent-sandbox-seed/worktree/**` capability-layer draft state; container unpack collided with the extracted seed; readiness never signalled; health-wait blocked) triggered a diagnosis that ended in a location-level verdict: every mitigation in the pipeline exists because staging lives **inside the sandbox repo root**. The prefix, the transform, the repair, the init-time gitignore, the pollution incident, and the tracking guards are all consequences of that one location decision.

This doc records the options considered when relocating the seed, including two external suggestions (from another agent) that were evaluated and rejected, and the design adopted.

## Options Considered

### Option A — status quo: host-built seed tar via `docker cp` (current)

As described above. Correct invariants (git-enumerated content crosses, gitignored never read, symlinks/exec bits preserved, deletions absent by construction) but the step count is high, the staging namespace shares the repo root, the stdin verification is indirect, and a tracked sentinel poisons `baseline.tar` (= `git archive HEAD`) with no host-side error until the container dies.

### Option B — rejected: whole-tree copy then purge (external "Method 1")

```
docker run --rm \
  -v "$(pwd)":/src \
  -v my_volume_name:/dest \
  alpine sh -c "cp -a /src/. /dest/ && cd /dest && apk add --no-cache git && git clean -fXd"
```

Copy the entire project (including `.git`, untracked files, and gitignored files) into the volume, then purge gitignored content in place.

**Rejected — violates the gitignored-never-crosses invariant.** `cp -a` copies gitignored secrets into the persistent volume *first*; `git clean -fXd` removes them *after*. Between the two commands (and permanently, if the container crashes mid-seed) secrets sit in volume storage. The invariant — recorded in `copy_delivery.md` and enforced by tests — is that gitignored content never crosses the boundary at all; "copy everything, delete the sensitive parts afterwards" is the exact shape the invariant forbids. Secondary costs: `apk add git` requires network at seed time (new failure mode; non-starter offline), and the copy burns IO on potentially large ignored trees (`node_modules`, build output) only to purge them.

### Option C — rejected: clone into volume + patch stream (external "Method 2")

```
docker run --rm -v "$(pwd)":/src -v my_volume_name:/dest alpine/git clone /src /dest
git diff | docker run --rm -i -v my_volume_name:/dest alpine/git -C /dest apply
```

Clone the local repo into the volume, then stream `git diff` output and apply it in the volume.

**Rejected — fails git-status parity.** The method's own note concedes it: untracked files never cross. Untracked non-ignored content is part of the operator's state and must materialize in the sandbox; the option cannot satisfy the core invariant regardless of patch details.

### Option D — considered, superseded: second mountpoint of the same volume

Keep the seed-tar pipeline but `docker cp` into a second mount of the sandbox volume (e.g. `/opt/agent-sandbox-seed`) instead of the repo root. Staging leaves the repo namespace, so the member-prefix transform and symlink repair retire, and the `rename(2)`-within-one-filesystem property removes any copy cost.

**Superseded** by Option E: it removes the in-repo staging but keeps the tar build, stdin transfer, 0B verification, and the `baseline.tar` + overlay reconstruction — the transport itself was the complexity, not only the destination.

### Option E — adopted: helper-container seed (two mounts, copy executed in-container)

A one-shot seeder container (the sandbox image — already carries git and rsync; no network dependency) with the project bind-mounted **read-only** at `/src` and the sandbox volume at `/dest`:

```
cp -a /src/.git /dest/.git

git -C /src ls-files -z --cached --others --exclude-standard \
  | tar -C /src --null -T - -cf - | tar -C /dest -xf -

git -C /dest reset --quiet
```

Step 1 brings history and config across natively — no `baseline.tar`, no unpack, no mixed-init reconstruction. Step 2 is the same git-enumerated copy the current pipeline uses (gitignored content is never read; symlinks and exec bits ride the tar stream; deletions are absent by construction on the fresh volume) but executes inside the container where both filesystems are directly mounted — no `docker cp`, no stdin, no verification dance. Step 3 is the parity invariant in one command: mixed reset sets index = HEAD and leaves the working tree untouched.

Retained from the current design: the case-mismatch check, volume-label identity wiring, and the sentinel fail-closed tripwire concept (re-implement if still warranted for legacy/polluted repos). Retired: the seed tar member prefix and transform, symlink-target repair, stdin 0B read-back verification, `baseline.tar` + mixed-init reconstruction, and the in-project-tree sentinel location itself.

## Decision

Adopt Option E. The project tree never hosts harness state; the repo root never sees staging; the seed reduces to three in-container commands that each map to one invariant. The decision is recorded in the working handover `devlog/handovers/20260904-01-design-start_resume_rsync_stall.md` (D5); the ADR entry and concept/architecture doc updates are this iteration's remaining scope.

## Consequences

- **Enables:** deletion of the transform/repair/verify machinery; a host-side seed failure surface (seeder container exits non-zero with a readable error) instead of a container-side stall; onboarding of arbitrary projects without depending on their gitignore hygiene.
- **Forecloses:** nothing in the delivery model — mount delivery, resume, and the diff pipeline are untouched. The `docker cp` seed path is retired and must not be re-introduced without revisiting this doc.
- **Implementation debt to schedule:** compose seeder service definition, `run_agent.sh` seed-path retirement, `snapshot.sh` cleanup (`snapshot_seed_tar`, `snapshot_init_git` staging logic), entrypoint simplification, trace-test rewrites asserting on the old sentinel paths.
