# The home-repo pattern's repository shapes

**Status:** open

## Context

The home-repo pattern is one git repo holding shared skills, `AGENTS.md` and shared docs, whose `AGENTS.md` points at the operator's other repositories by local path, and the agent runs from it. An operator project under this harness is organised that way, which raised the question the audit row under [M3.4.7](../roadmap.md#m347---environment-declaration-plane) asks: which repository shapes the delivery model supports.

This record carries the three measurements taken before the row was filed, and the commands that reproduce each. The audit row owns it.

**This file is a working record.** It is deleted when that row closes, once its findings have landed in the durable document the audit names. Neither this file nor its archive is a design artifact: the durable statement of supported shapes belongs in that document, and this record only carries the evidence until it exists. `scripts/check_record_lifecycle.sh` holds the other half, and the row's own text says the deletion is part of its close.

## What came of the measurement

Three incompatibilities, each a different failure at a different time.

| # | The incompatibility | Where it is enforced or assumed | What a user meets |
|---|---|---|---|
| 1 | A tracked gitlink, meaning a submodule or an embedded repo already committed, is refused by both delivery paths. | `src/capability/seed_volume.sh:163` and `src/capability/snapshot.sh:115`, both `git ls-files --stage \| grep -q '^160000'`, both dying with a host-side `git submodule deinit --all` remedy. Recorded as an edge case in [`sandbox_delivery_model.md`](../../docs/adr/sandbox_delivery_model.md) and as a guard beside the linked-worktree row in [`sandbox_lifecycle.md`](../../docs/reference/sandbox_lifecycle.md). | A session that refuses to start, before any work is done, with a remediation that is the operator's to run on the host. |
| 2 | An independent nested repo, meaning a second `.git` under the project tree that is not a gitlink yet, passes the seed guard and becomes a gitlink on the first commit that stages it. | The guard reads the index, so an untracked nested repo is invisible to it; `git add -A` then warns `adding embedded git repository` and records mode `160000`, dropping the content. | A refusal one session late, against a tree the agent just built, where the commit that caused it looks successful. |
| 3 | The pattern's `## Other Repos` pointers name paths the session does not mount, and the harness's writes assume one `.git` directory. | `src/build/docker-compose.copy.yml:50` mounts one `{{PROJECT_DIR}}` to `/src`; `src/capability/entrypoint.sh:108` reads `SESSION_STATE` from `$SANDBOX_DIR/.git/`, `src/capability/entrypoint.sh:179` installs the hook there, and `src/capability/snapshot.sh:87` writes the identity and `core.fileMode` into that one config. | An instruction the agent cannot follow: "read its `AGENTS.md` first" names a path that does not exist in the session, and no second repo's git identity, hook or session state is ever written. |

The third bounds the pattern by construction rather than by refusal. The first two are guards, and they disagree about *when* they fire, which is the defect worth settling: the point a user creates the shape is the point a refusal is cheap.

## Reproduction

Run from the repository root. The second block creates a temporary tree and removes it.

```bash
# 1. Both delivery paths refuse a tracked gitlink.
grep -n '160000' src/capability/seed_volume.sh src/capability/snapshot.sh
# seed_volume.sh:163  snapshot.sh:115

# 2. An untracked nested repo passes the seed guard, then becomes a gitlink.
d=$(mktemp -d) && cd "$d"
git init -q child && echo x > child/f && git -C child add -A \
  && git -C child -c user.email=a@b -c user.name=a commit -qm i
git init -q home && echo y > home/readme.md && git -C home add -A \
  && git -C home -c user.email=a@b -c user.name=a commit -qm i
git -C home ls-files --stage | grep -c '^160000'
# 0 -- the guard the seed runs finds nothing
mv child home/child
git -C home add -A
# warning: adding embedded git repository: child
git -C home ls-files -s | grep '^160000'
# 160000 <sha> 0	child
cd / && rm -rf "$d"

# 3. One tree is mounted, and one .git is assumed.
grep -n 'target: /src' -B1 src/build/docker-compose.copy.yml
grep -n 'git/SESSION_STATE' src/capability/entrypoint.sh
grep -n 'config user\|config core\|git/hooks' src/capability/snapshot.sh src/capability/entrypoint.sh
# snapshot.sh:87,92 config; entrypoint.sh:179,184 install
```

## What the audit decides

Three questions, and the row's close names the durable document that answers them.

1. Which shapes are supported: a single repository; sibling checkouts on the host; one checkout per session instead of a home repo.
2. Whether the one-`.git` assumption behind `SESSION_STATE`, the identity writes and the hook install is a boundary the pattern can work within, or a limit the pattern may not cross.
3. Whether a nested repo is refused at seed rather than a session later, and whether an untracked one is refused at all.

## Artifacts

| Artifact | Its source of truth |
|---|---|
| The audit row, with the three incompatibilities named | [`roadmap.md`](../roadmap.md#m347---environment-declaration-plane), M3.4.7 |
| The submodule and linked-worktree guards | [`sandbox_delivery_model.md`](../../docs/adr/sandbox_delivery_model.md), [`sandbox_lifecycle.md`](../../docs/reference/sandbox_lifecycle.md) |
| The supported shapes, once stated | the durable document the audit names, not this record |
