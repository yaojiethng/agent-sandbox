# Git Boundary

**Status:** draft - first write, not yet reviewed. Awaits the operator's decision.

**Scope:** where repository knowledge lives. It names the two parts that may run git - the diff pipeline and the project delivery mechanism - states what each owns, and derives the lock policy and the identity rule from that split. In: the boundary, the interface between the parts, the six current violators, and the lock behaviour measured for each operation class. Out: the mount and copy mechanics themselves (the settled copy and mount notes and `docs/architecture/sandbox_lifecycle.md`), the pipeline's internals (the sibling unification note), the recovery semantics of a dirty tree (the diff-invariants note), and the session registry, execution lifecycle, record formats, host setup, and provider context branches, which take their own notes in this series.

## Context

The read-through covered every shell file in the tree and found git calls in twenty of them, spread across both container layers. Most of the individual calls are correct. What is missing is any statement of which files are allowed to run git at all, so every new reader adds its own invocation.

Three passes found the same defect from three directions without naming it. The `guards.sh` pass found a three-valued dirty read that `session_save_policy.sh` implements a second time. The `reject.sh` pass found a pre-work step that deletes `.git/index.lock` before any git call has run. The `package_branch.sh` pass found a lockfile wait that no unit pins and one caller omits. Each is a symptom of an undefined boundary.

The lock investigation supplied the mechanism. With `.git/index.lock` held, every read the harness uses returns 0 with the correct verdict (`status --porcelain`, `diff --stat`, `ls-files -m`, `ls-files --others --exclude-standard`, `rev-parse`, `rev-list`, `for-each-ref`, `merge-base`, `cat-file`, `log`, `show-ref`), while every writer fails with rc 128 (`add -A`, `commit`, `checkout -b`, `apply --index`). A scratch index stages a full change set with rc 0 while the lock is held, leaves the lock untouched, and produces a byte-identical artifact. `git status --porcelain` writes the index when its stat cache is stale, and `GIT_OPTIONAL_LOCKS=0` leaves the index untouched with the verdict unchanged. So the harness creates the lock itself while merely reading, and it cannot then tell its own false lock from a genuine one or from a stale one.

The delivery mode decides how much of this matters. The pre-commit hook header states the split: copy delivery keeps `.git` inside the session volume, where the hook can never run on the host, and mount delivery exposes a host `.git` to the container and installs no hook. In copy mode the replica index is private, and the contenders are the agent's own git commands and the exporter. In mount mode a container-side write contends with host-side workflow writes across the boundary, so the pipeline's read discipline is load-bearing rather than merely efficient.

Six modules run git today without belonging to either part, and all six only read state that delivery already recorded: `session_save_policy.sh` reimplements the three-valued dirty read, `session_inventory.sh` derives the current branch and HEAD for display, `session_state.sh` validates `init_sha` with `cat-file`, `session_env.sh` validates the repository with `rev-parse HEAD`, `start_agent.sh` captures `HOST_HEAD_SHA` and the flatten flag, and `manual/fix_exec_bits.sh` walks `ls-files` over the host checkout.

The cost of leaving this undefined is concrete: three mechanisms exist only to manage locks the harness cannot attribute - the wait, the `lsof` probe, and the automatic delete - and one read is implemented twice.

## Options Considered

**Option A - one shared git library for the whole harness.** A single module owns every git call and every other file imports it. The strongest single statement, and the easiest to police. It also puts two different jobs behind one interface: delivering a replica, which may copy and validate but must not write the source, and moving patches, which must write behind a lock. The two jobs have different lock policies and run in different containers, so the module's surface becomes the union and its tests must cover both policies. It does not by itself remove the duplicated dirty read or the identity re-derivations.

**Option B - two parts, recorded identity, and a per-part interface (recommended).** Part 1 is the diff pipeline, container side and host side under one contract. Part 2 is project delivery, mount and copy. Delivery records the replica's identity when it creates the replica - initial commit, branch, mode - and every other module reads that record instead of running git. Only Part 1 may leave a deliberate index lock, and only through two named operations. Cost: the boundary must be stated and kept, the six violators must be converted, and the recorded identity needs the same discipline as any other record (the baseline is already captured once at delivery, which is the pattern to keep).

**Option C - keep the current shape and fix each symptom where it appears.** Add `GIT_OPTIONAL_LOCKS=0` to the reads that create a lock, keep the wait, keep the probe, keep the delete, and pin each with a unit. Smallest immediate diff and no new interface. It leaves the boundary undefined, so the next reader adds a seventh invocation, and it keeps three mechanisms whose only purpose is to guess whether a lock was ours. It also leaves the duplicate dirty read in place.

## Decision

Recommend Option B.

**Part 1, the diff pipeline.** Container side: `diff.sh`, `diff_export.sh`, `entrypoint.sh`, `dry_run_capability.sh`, and the pre-commit sentinel. Host side: `package_branch.sh`, `draft_state.sh`, `export_status.sh`, the four workflows, and `guards.sh`, which has no consumer outside this part and therefore belongs inside it rather than beside it.

Its interface is four operations. `replica_state(dir)` returns clean, dirty, or unreadable, and reads without taking a lock. `diff_produce(dir)` returns an artifact, written through a scratch index. `patch_apply(project, artifact)` and `draft_branch_create(project, name)` are the only two operations in the harness allowed to hold an index lock.

**Part 2, the project delivery mechanism.** `seed_volume.sh`, `snapshot.sh`, the compose mount and copy decision, `onboard.sh`, `install.sh`, the host hook installer, and the copy identity upgrade. It owns how a project's `.git` becomes a replica and what identity that replica carries. It may copy the `.git`, read it to validate it, and write inside the replica it is creating; it must not write the source repository.

Its interface is `replica_mode()`, `replica_create(project, mode)`, `replica_baseline()` returning the recorded initial commit, and `replica_hook_install()`.

**The lock rule.** Only Part 1 leaves a deliberate `.git/index.lock`, and only through the two named operations. Everything that reads state sets `GIT_OPTIONAL_LOCKS=0`, so the harness never creates the file while reading. A lock the harness did not create is a refusal: the message names the lock's age and the process that may hold it, and removal is an acknowledged path rather than an automatic pre-work step. That one rule retires the wait, the `lsof` probe, and the delete together, and for the first time it makes the stale case distinguishable from the genuine one.

**Recorded identity replaces the read-side git calls.** The six violators listed in the Context read the identity that delivery recorded rather than running git. This is the change row 19 already recommends from the registry side, and it removes the duplicate dirty read: `session_save_policy.sh` calls the guard in `guards.sh` instead of carrying its own copy.

**Why not Option A.** One library would carry the delivery policy and the pipeline policy in one interface, and the two are enforced by different callers in different containers with opposite write rules.

**Why not Option C.** The three lock mechanisms exist because the harness cannot tell its own lock from another's. Removing the creation on the read path removes the false class at its source; keeping the mechanisms means paying for them forever and still guessing.

## Consequences

What this changes. Six modules lose their git calls and read a record. `wait_git_lockfile` is deleted, and `draft_clear_stale_lock`'s automatic delete becomes the acknowledged recovery path of the invariants note, if it survives at all. The `lsof` host dependency leaves the read path. `session_save_policy.sh` calls the shared guard.

What this enables. One place to state and test the invariants. Part 1's state read can be pinned with a unit asserting the index is not written and no lock is created; the artifact can be pinned byte-identical across both staging forms; the two lock-taking operations can be pinned for the refusal text and the acknowledged path. It also gives the delivery mode a stated consequence for the first time: mount delivery shares an index across the boundary, and Part 1's read discipline is what keeps that safe.

What this forecloses. No new git call outside the two parts without a boundary change. A future third delivery mode - a remote seed, an object store - implements Part 2's interface rather than teaching the pipeline a new trick.

What it does not do. It does not make a genuine lock impossible. `patch_apply` and `draft_branch_create` must hold the lock, and two concurrent runs will still contend. The change is that the harness stops manufacturing the lock while reading and stops deleting one it cannot attribute.

Landing. An implementation handover that converts Part 1's state readers, sets `GIT_OPTIONAL_LOCKS=0` on the read paths, removes the wait and the probe, and pins each with a unit. Until it lands, the read-through's rows stand as the evidence.

Related rows: 63 and 70 own the pipeline change, 278 and 284 the lock policy, 253 the recovery semantics, 22 and 38 and 242 the record side, 19 the identity generator, and 285 the harness leak that made a flake look like a gate bug.
