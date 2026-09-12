# Study -- Seed Cleanliness: Pruning the Copied Object Store

**Status:** settled -- recommendation adopted and implemented (handover `20260911-11`; ADR sandbox_delivery_model.md, 2026-09-11 unreachable-object prune entry)
**Type:** study
**Parent:** `20260911-study-stash_copy_prevention.md` (settled); operator question: does leaving stash objects (and other unreachable data) in the volume violate the cleanliness goal, and do clone/bundle offer a better transport?

## Question

`git stash clear` removes the refs, not the objects. Unreachable host data (stash commits, reflogs, session junk) remains in the volume's object store, discoverable by a snooping agent via `git fsck --unreachable`. Is there a transport that gets a clean baseline without the `cp -a` archaeology -- `git clone`? `git bundle`?

## Findings

### The snooping surface is real and large

Measured on this repo's own `.git` (26 MB): after simulating the seed, `git fsck --unreachable` lists stash commits, stash blobs, and reflog-anchored session commits. `reflog expire --expire=now --all && gc --prune=now` reduces the gitdir from 26 MB to 4.2 MB and leaves zero unreachable objects. The dominant junk is not the stashes -- it is reflog-anchored history.

### Clone and bundle fail on the index, not on the checkout

The ADR's clone rejection (2026-09-04) named checkout semantics (autocrlf, smudge, origin remote). But the deeper blocker is staging state: the host index references blobs (staged edits, staged new files) that exist in **no commit** -- not in HEAD's history. A bundle of HEAD and a `--depth 1` clone both lack exactly the objects the index needs. Closing the gap requires re-staging from the worktree copy by replaying `git diff --cached` paths -- a reconstruction sequence of the class the 2026-09-04 redesign retired. Bundle adds nothing clone does not; both re-introduce index surgery.

### Copy-then-prune achieves the clean result without reconstruction

Verified experimentally (fixture repo and this repo):

1. `cp -a .git` exactly as today (index untouched, parity contract intact).
2. `git stash clear` (landed, `20260911-08`).
3. `git reflog expire --expire=now --all`.
4. `git gc --prune=now --quiet` -- removes all unreachable objects.
5. `git fsck --unreachable` returns empty; status parity unaffected (gc touches no refs, index, or worktree).

Cost measured: 0.6 s on this repo. For very large repositories the prune can be conditional: run `git fsck --unreachable` first and gc only when something is found (on a clean host repo the check is near-free and gc never runs).

### History truncation is available and separate

A shallow boundary at the seed HEAD (`echo $INIT_SHA > .git/shallow` before the gc) truncates the baseline to the seed point: `rev-list --all --count` drops accordingly, commits and diffs still work, fsck stays clean, gc prunes everything below the boundary. Full truncation to the baseline alone additionally requires deleting non-HEAD refs (host branches and remotes cross today). This is a behavior change beyond cleanliness -- the agent loses the ability to read project history -- and interacts with the "full git history" clone-strategy roadmap item. It is a separate decision, not part of the artifact fix.

## Options Considered

| Option | Cleans artifacts | Keeps exactness contract | Cost | Verdict |
|---|---|---|---|---|
| A: status quo (stash clear only) | no -- reflogs and unreachable objects cross | yes | none | insufficient per the cleanliness goal |
| B: copy-then-prune (reflog expire + gc, conditional) | yes -- fsck-verified empty | yes -- no index or checkout surgery | ~0.6 s on this repo, conditional on dirt | **recommended** |
| C: bundle transport | yes | no -- index reconstruction (staged blobs absent from HEAD bundle) | new transform class | rejected |
| D: clone transport | yes | no -- same index gap; plus shallow/graft and remote artifacts | new transform class | rejected |

## Recommendation

**Adopt Option B.** In the seeder, after the stash clear: run `git fsck --unreachable` on the volume; if anything is found, `git reflog expire --expire=now --all && git gc --prune=now --quiet`, then assert `fsck --unreachable` is empty (tripwire, same pattern as the stash tripwire). Update the ADR 2026-09-11 residual paragraph: the residual is removed by the prune, so the "recorded, accepted" text is superseded. Defer history truncation (shallow boundary, ref deletion) to its own decision -- it changes what the agent can see, not just what is reachable.

## Resolution

Adopted (implemented): Option B -- the seeder probes with `fsck --unreachable` and, when the store is dirty, expires reflogs and runs `gc --prune=now`, then asserts fsck-empty. Implementation: handover `20260911-11`; ADR 2026-09-11 entry updated (residual paragraph superseded). History truncation deferred as its own decision.
