# Sandbox Delivery Model

**Current:** 2026-09-12

## 2026-09-12 -- Shared delivery dispatcher: full history by default, `--flatten` opt-out

**Decision.** Both delivery modes deliver full history by default: the shared `snapshot_deliver` dispatcher copies `.git` natively (full) and syncs the enumerated worktree, or syncs the worktree and inits a fresh baseline (`--flatten`). The dispatcher is the single owner of the delivery step for copy and mount; `snapshot_enumerate_worktree` is the single owner of the worktree enumeration.

**Mechanism.** `snapshot_deliver SOURCE DEST FLATTEN` (in `src/capability/snapshot.sh`) routes both modes through one primitives set (`snapshot_copy_git`, `snapshot_copy_worktree`, `snapshot_baseline_init`). The seed and the mount materialization both call it. The seed's worktree transport is now the shared enumeration fed to `rsync --from0 --files-from` (replacing the 2026-09-04 tar pipeline for the worktree layer; the `cp -a .git` layer is unchanged and still satisfies R2 for full). An empty enumeration is a no-op for rsync; the 2026-09-04 "skip the tar step" edge case no longer exists.

**Flatten semantics.** `--flatten` is an opt-out, not a default: both modes default to full. It follows the DELIVERY discipline -- ingested once at the start boundary, passed as an explicit argument to `run_agent`, persisted in the session record (a `FLATTEN` literal stamped into the sandbox service env), recovered on resume, never read from ambient env. The mount worktree records its delivery-history mode in `.git/config` (`agent-sandbox.flatten`); reuse refuses a mismatch and refuses a worktree with no recorded mode (pre-dates the contract).

**Unborn HEAD.** The harness requires host commits for every session: the session-env gate (`session_env_common_init`) rejects an empty repository before delivery dispatch, and both the seed and the mount materialization fire the same guard at the delivery layer. No delivery tolerates an empty repository.

**Verification.** Full seeds keep the 2026-09-04 status-parity self-check. Flatten seeds verify the committed file set equals the source enumeration and the worktree is clean (`verify_baseline`) -- coverage, not just a clean tree (R8).

### Edge cases / drivers

- **Worktree mode mismatch.** A materialized mount worktree keeps its first delivery-history mode (recorded in `.git/config` as `agent-sandbox.flatten`). A later start requesting the other mode is refused with a readable error; the worktree must be recreated under a different mode. A corrupt recorded value (not `true` or `false`) is refused in the clear rather than interpreted. Resume cross-checks the record's `FLATTEN` against the worktree's recorded mode and warns on a mismatch, continuing with the record value (resume never re-materializes).
- **Legacy worktree.** A worktree materialized before the flatten contract has no recorded mode (it is a flatten-style baseline). Reuse refuses it rather than mislabel it as full; the operator recreates it.
- **Empty enumeration.** An empty worktree enumeration is a no-op for rsync; the 2026-09-04 "skip the tar step" edge case no longer exists.
- **Unborn HEAD.** Refused for every session: the session-env gate requires host commits before delivery dispatch, and both delivery layers fire the same guard. No delivery tolerates an empty repository.

**Judgment strip.** Earlier text framed mount as the answer for large repos that cannot afford copying. With full-by-default, that framing is gone: full copy on a large repo is slow by construction, noted as a caveat, not a rule about what large repos can or cannot do.

**Rejected alternatives.**

- **Seed's full path through a second bespoke transport (tar).** Rejected: the shared dispatcher already serves both modes, and two sinks for one enumerated list is the duplication this entry removes.
- **Flatten tolerates an unborn-HEAD repository.** Proposed during review and initially implemented as a mode-scoped guard, then withdrawn: the harness session-env gate already requires host commits for every session before delivery dispatch, so a flatten tolerance path is unreachable through any supported flow. Universal refusal is the single coherent rule; a delivery-layer guard remains as defense-in-depth for direct invocation.

## Requirements

The delivery model fills an empty Docker volume with the operator's working state, returns changes through the diff pipeline, and keeps parallel sessions isolated. Every solution in this file is judged against these requirements. Requirements accumulate: a rejected solution can surface a new requirement, which then constrains the next solution.

| # | Requirement | Meaning |
|---|---|---|
| R1 | Boundary integrity | Gitignored files never cross into the sandbox. This is a security requirement, not a convenience. |
| R2 | Git status parity | After a fresh seed, `git status` in the sandbox is porcelain-identical to the operator's repo: staging state preserved, working tree at disk state, deletions visible. |
| R3 | No harness git mediation | The harness owns the container boundary; the user owns the git topology. The harness never mediates git between containers. |
| R4 | Session isolation | Each session gets its own volume. Parallel sessions never share working content. |
| R5 | Diff-based return | The volume is the only working content store. Changes return to the host through the diff pipeline, which is git-agnostic. |
| R6 | Offline seed | The seed step needs no network access. |
| R7 | No staging in the worktree | Harness transfer state never resides inside the operator's git worktree. A disposable payload in a git worktree is trackable by construction, and tracking failures follow. Promoted by the 2026-09-03 incident. |
| R8 | Flatten baseline coverage | A flattened seed verifies the committed file set equals the source enumeration and the worktree is clean; coverage, not just a clean tree (2026-09-12). |

## 2026-09-11 -- Seed repository copy: full `.git` is deliberate (stash and history-trim analysis)

**Trigger:** the operator observed 21 stale stashes on a sandbox branch and asked whether the seed could avoid copying the entire `.git` -- stashes in particular, and host history generally. Study: [`20260911-study-stash_copy_prevention.md`](../../devlog/discussions/20260911-study-stash_copy_prevention.md).

**Mechanism.** `cp -a /src/.git` crosses the host stash stack (`refs/stash`, `logs/refs/stash`) into every fresh session volume. The status-parity self-verification cannot see it: stashes are not working-tree state. An in-session `git stash pop` imports host WIP into the session working tree, which then flows back through the diff pipeline as if the agent produced it -- an unintended-content channel into the review gate.

**Functionally, history is not required.** Copy-mode consumers never walk below `init_sha` (HEAD at seed time): `package_branch` iterates `init_sha..HEAD`, the diff pipeline reads `init_sha` from `SESSION_STATE`. A "HEAD + trees + index" subset would satisfy every current consumer.

**Decision: the native full copy stands.** The exactness contract (R2) is what forbids a subset:

1. Staging state must cross. Any subset transport must reconstruct the index -- a restage sequence -- and status parity proves far less when the index is replayed than when it is copied.
2. History lives interleaved inside `objects/` with the objects the snapshot needs. Selecting "one snapshot's objects" requires repack/bundle machinery run against the operator's repo at every start -- new transform code of the class the 2026-09-04 redesign exists to retire.
3. `cp -a` carries no filtering logic, hence no filter bugs. Its costs (stash, reflog, full history) are bounded, session-scoped, and pruned with the volume; the volume never leaves the capability layer.

**Stash disposition:** surgical, not structural. The seeder runs `git stash clear` on the volume copy after the `.git` copy -- the host stack is untouched, no contract changes, no filtering machinery is added. Tracked as a roadmap implementation item. (The rejected clone alternative already recorded "drops stashes and reflogs" as a defect of reconstruction; the defect of exact copying is smaller and is removed post-copy.)

**Residual (superseded 2026-09-11, same day -- see below):** `git stash clear` removes the refs, not the objects. Stash commit objects remain in the volume's object store as unreachable data until a gc prunes them. They are invisible to `git status`, `git log`, and `stash list`, and unreachable by the agent through any normal git command; the diff pipeline cannot select them. Their presence is the same exposure class as the repository history that crosses by design (the native `.git` copy), so no additional pruning runs at seed time -- the added machinery outweighs removing data that no sanctioned path can reach. Recovering them requires deliberate forensic effort (`git fsck --unreachable`) inside the capability layer.

**Unreachable-object prune (adopted 2026-09-11, same day):** the residual was judged a cleanliness violation -- reflogs and unreachable objects (stash commits, session junk) are host archaeology a snooping agent can recover via `fsck --unreachable`, and they dominate the gitdir's size. After the stash clear, the seeder probes the volume object store with `git fsck --unreachable`; when anything is found, it runs `git reflog expire --expire=now --all` and `git gc --prune=now --quiet`, then asserts the store is fsck-empty (fail closed, same pattern as the stash tripwire). The prune touches no refs, no index, and no worktree, so the status-parity contract is unaffected; on a clean host repo the seed pays only the fsck probe. Clone and bundle transports remain rejected: staged blobs exist in no commit, so any HEAD-bounded transport lacks the objects the index references and re-introduces index reconstruction. History truncation (shallow boundary at the seed HEAD, deletion of non-HEAD refs) is a separate decision: it changes what the agent can see, not only what is reachable. Study: `devlog/discussions/20260911-study-seed_object_store_cleanliness.md`.

**History-trim disposition:** rejected absent a new driver. The only driver that would justify a snapshot-depth seed is seed time/size on large repositories, and the `--flatten` flag is the designed lever for that case -- a flattened delivery skips the native history copy while the flatten seed still builds a workable git repo. Full copy on a large repo is slow by construction; that is a caveat, not a rule about what large repos can or cannot do. Revisit only if seed cost becomes a measured problem on real repos.

## 2026-09-04 -- Seed transport: helper-container copy

**Decision:** The seed runs as a one-shot helper container (the sandbox image, which already contains git) with the project mounted read-only at `/src` and the sandbox volume mounted at the sandbox service's own target path. The volume target must match the sandbox service's: a fresh empty named volume is initialized -- content and ownership -- from the image's directory at the mount point, which makes the volume root writable by the unprivileged seeder; any other target leaves it root-owned. The copy executes in-container:

```text
cp -a /src/.git /dest/.git

git -C /src ls-files -z --cached --others --exclude-standard \
  | while IFS= read -r -d '' f; do [[ -e "$f" || -L "$f" ]] && printf '%s\0' "$f"; done \
  | tar -C /src --null -T - -cf - | tar -C /dest -xf -
```

The repository crosses natively, including the index: no reset runs, so `git status` in the volume is porcelain-identical to the operator's repo (R2). The existence filter in the enumeration drops tracked paths absent from the disk (unstaged deletions); it cannot drop ignored content, because every filtered path was tracked. The seeder then verifies the copy fail-closed by comparing `git status --porcelain=v1 -uall` between `/src` and `/dest`; any divergence aborts the seed. The seeder writes `SESSION_STATE` (`init_sha` = HEAD at seed time, `session_ts`) into the volume's git directory.

There is no host-built payload, no `docker cp`, no staging directory, and no container-side reconstruction sequence. The project tree never hosts harness state (R7).

**Completion signal.** The seeder container's exit code is the only readiness signal. The host waits on it event-driven with a hard timeout; on timeout or nonzero exit, the start aborts with the seeder logs and the session volume is discarded. Container create or start failures surface immediately as host-side errors -- they never reach the wait.

### Rationale

Requirement by requirement:

**R1 -- boundary integrity.** The enumeration lets git decide what crosses: `ls-files --cached --others --exclude-standard` resolves every ignore source, so gitignored content is never read, not copied-and-purged. Tar preserves symlinks and exec bits; content is streamed pipe-to-pipe and never lands in an intermediate location. The existence filter only drops index-listed paths absent from the disk; tracked paths cannot carry ignored content.

**R2 -- git status parity.** The repository crosses natively with its index, so no `baseline.tar` unpack or mixed-init sequence is needed. The enumeration copies exactly the tracked and untracked-non-ignored files on disk; unstaged deletions are absent from the volume but present in the index, so status shows them. No reset runs, so staging state is preserved and `git status` is porcelain-identical. The self-check enforces the guarantee at seed time instead of trusting the sequence.

**R3 -- no harness git mediation.** The seeder runs plain `cp`, `git`, and `tar` against mounted filesystems. It mediates no git operation between host and container; the diff pipeline remains the only return path (R5).

**R4 -- session isolation.** The seeder writes to the session's own volume, identified by the existing volume-label wiring. Nothing else changes about identity.

**R6 -- offline seed.** The seeder image is the sandbox image, which already contains git and rsync. No package install, no image pull at seed time.

### Rejected alternatives

Each entry states where the failure sits: intent (the idea cannot satisfy the requirements) or execution (the idea is sound and the implementation failed). Edge cases surfaced by a rejection are promoted into the Requirements table.

#### Whole-tree copy, then purge

`cp -a /src/. /dest/` followed by `git clean -fXd`. Copies the entire project, including `.git`, untracked files, and gitignored files, then removes ignored content in place.

Failure in intent: R1 forbids the crossing itself. Gitignored secrets reach the persistent volume before the purge runs, and a crash between the two commands leaves them there. The purge also needs network (`apk add git`), violating R6, and burns IO copying large ignored trees it must then delete.

Promoted edge case: partial satisfaction of R1 is still a violation -- content either never crosses or fully obeys the ignore rules. There is no transient zone. (R1 wording updated to carry this.)

#### Clone into the volume, then patch

`git clone /src /dest` followed by a porcelain-driven diff copy. The original rejection ("untracked files never cross") was wrong: a porcelain-driven copy crosses untracked files. The failure is in checkout semantics: clone materializes the baseline worktree through git's checkout path, so `core.autocrlf` rewrites line endings and smudge filters fire -- LFS smudge needs the network (R6), and content diverges silently either way. Clone also plants an `origin` remote pointing at `/src` and drops stashes and reflogs. The porcelain idea survives where it is strong: as the seed's fail-closed verification, not as the transport.

#### Second mountpoint of the same volume for the tar pipeline

Keeps the host-built tar and `docker cp`, but extracts into a second mount of the volume instead of the repo root, removing the staging location defect (R7 satisfied).

Failure in neither intent nor execution: the move between two mounts of one volume is a rename, so the fix costs nothing. Rejected as insufficient rather than wrong: the tar build, stdin transfer, indirect read-back verification, and the `baseline.tar` unpack sequence all remain, and the in-container transport makes all of it unnecessary.

#### Host-built tar via `docker cp` (previous solution)

The seed crossed as a host-built tar of two members -- `baseline.tar` (`git archive HEAD`) and a git-enumerated working-tree list -- staged inside the sandbox repo root under `.agent-sandbox-seed/`, then reconstructed container-side (unpack, mixed init, rsync overlay, member-prefix transform, symlink repair, staging cleanup).

Failure in intent, not execution: staging a disposable payload inside a git worktree makes tracking failures possible by construction (R7). When a host commit captured the staging directory, the payload poisoned itself, the container-side unpack failed, and the session stalled on the readiness wait. The container's fail-closed behavior worked as designed. See the 2026-09-03 entry.

### Edge cases / drivers

- **Polluted legacy repos.** A repo that already tracks `.agent-sandbox-seed/` must fail the seed with a readable host-side error naming the remediation. Tripwire not yet implemented -- scheduled with the implementation iteration.
- **Linked worktrees.** If `/src/.git` is a gitfile pointing at a host-side git directory, the copy produces a broken repository. The seeder detects this before copying and fails with a readable error.
- **Unborn HEAD.** A repository with no commits has no HEAD to verify against. The seeder fails with a readable error naming the limitation.
- **Empty worktrees.** (Superseded by 2026-09-12: the shared enumeration feeds `rsync`, which no-ops on an empty list.) Tar refuses an empty archive, so the 2026-09-04 seeder skipped the tar step when the enumeration was empty.
- **Submodules.** The gitlink crosses but module content does not. The seeder fails closed with a readable remediation message, matching the existing `snapshot_copy_worktree` precedent.
- **Stale index stat cache.** The copied index carries host inode and device ids; git reconciles them by content on the first status call. Correctness is unaffected.
- **Absolute `core.hooksPath`.** A local config pointing outside the project breaks hooks in the volume. Declared limitation; the harness installs one hook, in copy delivery only -- see [`git_hooks.md`](git_hooks.md).
- **Case-sensitivity.** The existing case-mismatch check runs before the seed and is retained unchanged.
- **Offline and restricted hosts.** The seeder must not pull images or install packages at seed time; the sandbox image is the dependency floor (R6).

## 2026-09-04 -- Mount-path worktree copy: git enumeration replaces rsync exclude lists

**Decision:** `snapshot_copy_worktree` (mount-delivery worktree materialization) replaces its hand-built rsync exclude lists with git enumeration -- `git ls-files -z --cached --others --exclude-standard`, existence-filtered, fed to `rsync --from0 --files-from`. We edited the original claim (which said `with --delete`) to drop the `--delete` flag: the mount worktree copy has no `--delete` pass, because delivery targets a fresh destination (or reuses an existing worktree without re-syncing) and deletion semantics come from the enumeration, not the sync.

**Rationale:** R1. The exclude-list approach silently ignores negation patterns (`!pattern`) in global gitignore and `.git/info/exclude` -- rsync treats a negation as clear-the-exclude-list -- so gitignored files leak into the worktree copy. The repo's knowledge test reproduces the leak: the negation and global-exclude cases report divergence for the current pipeline. Git's own ignore resolution decides what crosses, as in the volume-path seed. The same enumeration primitive serves both delivery paths. Implementation is scheduled with the seed-transport implementation iteration.

## 2026-09-03 -- Seed content source: git-enumerated tar; sentinel never tracked (superseded)

**Decision:** The seed crossed as a host-built tar of two members: `baseline.tar` (`git archive HEAD`) and a git-enumerated working-tree list packed under the `.agent-sandbox-seed/` prefix inside the sandbox repo root. The sentinel directory was to remain untracked.

**Rationale:** Git's own ignore resolution (including negation patterns, which rsync-based exclusion mishandled) decided what crossed, and the tar carried symlinks and exec bits the earlier rsync copy lost. The enumeration trusted the index: it packed exactly what git tracked.

**Rejected alternatives:**

- Dropping the offending commit entirely -- the commit carried the legitimate fail-closed seed-verification work; only its tracked sentinel content was defective. A rebase-edit to strip paths preserved the work.
- Untracking the sentinel in a later commit only -- left the polluted blobs in history and the failure reproducible from any earlier commit; the clean-history requirement ruled it out.

**Edge cases / drivers:** Readiness is signalled only after sandbox init completes, so a seed failure must fail the container fast -- and did. Docker-cp extraction created staging content root-owned; the unprivileged unpack could not overwrite or utime it, which turned silent overlap into a loud failure.

**Reason superseded by 2026-09-04:** the transport moved in-container with direct mounts, which removes the tar payload, the staging location, and the tracking-failure class instead of defending against it.

## 2026-07-30 -- Two-axis model; harness never mediates git (standing)

**Decision:** Delivery is a two-axis model: a delivery axis (copy or mount of the sandbox to the reasoning layer) and a backing axis (whatever `.git` the user provides). The harness owns the boundary; the user owns the git topology. Recorded as R3 and R5.

**Rationale:** Harness-mediated git (the worktree model) cost six preflight steps and left a high-severity host-execution vector (`core.hooksPath`) that no mitigation fully closed. The diff pipeline already worked and needed none of it.

**Rejected alternatives:**

- Worktree backing -- security cost exceeds value; permanently removed from scope.
- Raw project directory backing -- non-goal; the sandbox must be a harness-controlled boundary, not the user's live checkout.

**Edge cases / drivers:** Parallel sessions of one project must not share a sandbox; the `SANDBOX_DIR`-per-instance identity factor exists so distinct backings map to distinct sandboxes.

## 2026-07-21 -- Worktree mount model (superseded)

**Decision:** The sandbox working content was to be delivered via harness-managed `git worktree` wiring, with the harness mediating git operations across the boundary.

**Rationale:** At the time, worktree wiring looked like the cheapest way to give the agent a real checkout without copying.

**Rejected alternatives:**

- Full working-tree copy per session -- dismissed as too slow before the diff pipeline existed to make copy delivery cheap.

**Reason superseded by 2026-07-30:** the mediation concentrated unacceptable security cost and complexity to reproduce what the user provides directly.
