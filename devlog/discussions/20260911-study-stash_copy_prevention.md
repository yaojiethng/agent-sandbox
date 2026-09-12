# Study -- Stash Copy Mechanism and Prevention

**Status:** settled -- decision recorded in [`../../docs/adr/sandbox_delivery_model.md`](../../docs/adr/sandbox_delivery_model.md) (2026-09-11 entry: full `.git` copy stands; stash cleared post-copy via the roadmap impl item)
**Type:** study
**Parent:** M2.6 session-persistence cross-cutting concerns; raised by the operator after the 2026-09-11 check-in (21 accumulated stashes in the sandbox tree, most stale).

## Question

The sandbox starts with stashes the host repository never created. Confirm the mechanism that causes host stashes to be copied into the sandbox, and determine how to prevent the copy -- or whether dropping all stashes at sandbox initialization is the correct, simpler solution.

## Findings

### Mechanism confirmed

The helper-container seeder copies the repository natively: `src/capability/seed_volume.sh`, layer 1 of the seed:

```bash
cp -a "$SRC/.git" "$DEST/.git"
```

`cp -a` copies the entire `.git` directory, including the stash state:

- `.git/refs/stash` -- the ref pointing at the newest stash commit
- `.git/logs/refs/stash` -- the stash stack (every stash entry, oldest to newest)

So every `git stash` the operator has ever run on the host crosses into the session volume on every fresh start. This is a property of the seed design (repository crosses natively, per the 2026-09-04 ADR entry), not a bug in the copy command. The design's self-verification (`git status --porcelain` parity) does not notice: stashes are not working-tree state.

### Why the stashes are stale, not just copied

The volume copy is one-way. Git state changes made inside the container (commits, stashes) never flow back to the host -- the host receives only the diff export (`patches/`, `uncommitted.diff`) and applies it on a fresh draft branch. So:

- Host stashes appear in every new session and accumulate across sessions only as fresh copies (no multiplication: each session starts from the host state).
- The 21 stashes observed on the sandbox branch are host stashes copied in, plus any stashes the agent created inside sessions (those die with the volume at prune; only the copies of host state recur).
- Session stash operations can mutate the *copy* (a `git stash pop` inside the container applies host WIP into the session working tree). That change then flows back through the diff pipeline as if the agent produced it -- an unintended-content channel.

### Risk assessment

Risk-bearing in two ways:

1. **Unintended content in diffs.** A `stash pop` or `stash apply` in-session imports host WIP into the agent's working tree; the diff export then presents it as agent output for review. Low likelihood, but the review gate exists precisely to catch content the operator did not sanction -- here the harness itself injects candidate content.
2. **Confusion signal.** `git stash list` in-session shows history the agent did not create; agents reasoning about repo state (check-in surveys, audits) read it as session state.

Counter-consideration: a stash can be legitimate context ("operator parked work mid-change"). But the operator's workflow record (AGENTS.md collaboration protocol) treats uncommitted work as session-scoped, and `package-branch` exports are the sanctioned transport. Stash state is not part of any documented contract.

## Options Considered

### Option A -- drop all stashes in the seeder after copy

After `cp -a .git`, run `git -C "$DEST" stash clear` (equivalently: delete `refs/stash` and `logs/refs/stash`). The host stash stack is untouched -- the clear runs on the volume copy only.

- Pros: one line; no new exclusion machinery; matches the documented one-way model (the sandbox is a baseline, not a mirror).
- Cons: none functional. The seeder already mutates the copied `.git` (it writes `SESSION_STATE`), so post-copy adjustment is established practice.

### Option B -- prevent the copy (exclude stash refs during the copy)

Replace `cp -a` with a filtered copy (tar exclude, or rsync-style exclusion) that omits `refs/stash` and `logs/refs/stash`.

- Pros: prevention at the mechanism level; the stash never crosses.
- Cons: `cp -a` is chosen for exactness (permissions, hardlinks, all ref state); every filter re-introduces the class of partial-copy bugs the seed redesign retired. Complexity is not justified for two files.

### Option C -- leave as is, document

- Cons: leaves the unintended-content channel open and keeps misleading session state. Rejected.

## Recommendation

**Adopt Option A** -- `git stash clear` in the seeder immediately after the `.git` copy, with a comment naming the reason (stashes are host session state; the sandbox baseline carries none). It is necessarily the cleaner solution: prevention via filtered copy (Option B) buys nothing over clearing the two-file state after an exact copy, and costs the exactness guarantees of `cp -a`.

Open question for the design handover that implements this: whether the seed self-verification should also assert an empty stash stack (cheap tripwire, catches regressions).

## Resolution

Adopted (decision recorded) -- the 2026-09-11 ADR entry adopts Option A (post-copy `git stash clear`) and rejects history-trimming absent a measured seed-cost driver. Implementation remains open as the roadmap item "Seeder stash-clear".
