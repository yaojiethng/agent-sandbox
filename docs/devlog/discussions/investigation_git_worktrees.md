# Investigation — Git Worktrees as Sandbox Isolation Mechanism

**Status:** Resolved — Reject for M2.3; feasible candidate for future milestone under relaxed assumptions.

**Direction:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Parent story:** `docs/devlog/roadmap.md` — M2.3

---

## Required Reading

- [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants
- [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — mount shape and why `PROJECT_DIR` is never mounted
- [`docs/architecture/sandbox_lifecycle.md`](../sandbox_lifecycle.md) — snapshot + diff pipeline

---

## Summary

Hermes uses `git worktree add` to give each agent task an isolated working directory that is a real branch inside the project's git repository. The agent works in the worktree; changes are committed to a real branch; the developer reviews and merges. This eliminates the copy-in / diff / apply round-trip entirely. The question is whether this model is viable as a replacement or complement to the current snapshot+diff pipeline.

---

## How Hermes Uses Worktrees

When given a task, Hermes creates a new worktree on a fresh branch:

```bash
git worktree add -b agent/task-name /path/to/worktree-dir
```

The worktree directory is a real checkout of the project at that branch. It shares the same `.git` object store — no duplication of history, blobs, or pack files. The agent works inside this directory; all `git` commands operate against the shared `.git`. On completion, the worktree can be reviewed, merged, or removed and the branch deleted if rejected.

**Why worktree over other options (Hermes's perspective):**

| Alternative | Why rejected |
|---|---|
| `git checkout -b new-branch` | Displaces the developer's current working state |
| `git clone` | Duplicates the full object store; expensive for large repos |
| Separate directory + manual diff | No git history; no `git log`; apply is a patch operation with no conflict tooling |
| `git stash + new branch` | Stash is fragile; not an isolation unit |

The worktree is the clean answer when: you trust the process working in it, it runs on your machine, and the primary goal is "don't disturb my current working tree."

---

## Findings Against the Current Architecture

### Finding 1 — Core incompatibility: PROJECT_DIR is never mounted

The current security model has one non-negotiable invariant:

> *"PROJECT_DIR is not mounted into either container, so the agent runtime cannot read host repository files directly."* — `security.md`

A git worktree is inseparable from the project's `.git` directory. When `git worktree add` creates `worktree-dir/`, it places a `.git` **file** inside it that points back to `PROJECT_DIR/.git/worktrees/...`. Every git operation inside the worktree uses the shared object store. This means:

- To use a worktree, you must either mount `PROJECT_DIR` or the worktree path (which resides inside `PROJECT_DIR`'s filesystem) into the agent container.
- Either way, the agent container can resolve the `.git` pointer and read the full repository: `git log --all`, `git show <any-sha>`, all branches and remotes.

**This breaks the harness security model at its foundation.** The snapshot pipeline exists precisely to give the agent a filtered view. The worktree bypasses every part of that filtering.

### Finding 2 — What the agent gains access to with a worktree

| Access | Current (snapshot) | Worktree |
|---|---|---|
| Current project files | ✅ filtered via gitignore | ✅ (working tree only) |
| Full commit history | ❌ no `.git` in sandbox | ✅ shared `.git` |
| All branches / tags | ❌ | ✅ |
| Secrets that were ever committed | ❌ | ✅ via `git show` |
| Remote configuration | ❌ | ✅ |
| Ability to `git push` | ❌ | ✅ (if remote configured) |
| Ability to rewrite history | ❌ | ✅ |

Considered mitigations within the worktree model:
- **Git hooks to block dangerous operations:** Fragile — agent can bypass with `--no-verify` or by removing them.
- **Read-only mount of `.git`:** The worktree requires write access to `.git/worktrees/<n>/` for lock files and HEAD updates. Non-functional.
- **Separate git dir (`--separate-git-dir`):** No longer a worktree — it is a clone, and the shared-object-store benefit is lost.

None of these preserve the worktree model while satisfying the security invariant.

### Finding 3 — The worktree-as-volume hybrid

Rather than mounting an actual PROJECT_DIR worktree, create an independent git repository in `sandbox/` (as today) but structure it as a persistent branching repo:

- Session N creates branch `agent/YYYYMMDD-HHMMSS` off the baseline commit.
- `apply_workspace.sh` cherry-picks or fast-forward merges the session branch into PROJECT_DIR.

This is **structurally identical to the M2.3 format-patch design**, minus the `git worktree` mechanism. The M2.3 design achieves this via format-patch + `git am` without mounting PROJECT_DIR or exposing the host `.git`.

### Finding 4 — The one genuine advantage: no large-repo copy

The worktree shares the object store, so no files are duplicated. For large repos with large binary history, the snapshot copy can be slow.

This is a real cost the worktree model eliminates. For the repos this harness is designed for (code projects), the snapshot is typically fast and proportional to tracked file count, not history depth. If this becomes a bottleneck, incremental snapshot (rsync with content-addressed caching) is the correct fix — not a worktree.

### Finding 5 — Why worktrees work for Hermes but not for agent-sandbox

Hermes's trust model is different. Hermes is a local agent running on the developer's own machine — the agent is the developer's process, operating with the developer's credentials. The separation of concerns is task isolation (don't mess up my current checkout), not security isolation (don't let the agent see my secrets).

Agent-sandbox's trust model is the inverse: the agent runtime is explicitly untrusted. The container is a security boundary. The snapshot pipeline is a trust filter. Worktrees solve the task isolation problem; they do not solve the security isolation problem.

---

## Addendum — Revised Feasibility Under Relaxed Assumptions

**Trigger:** Operator re-scoped the assumptions. The following analysis supersedes Findings 1 and 2 for purposes of future architectural consideration. The M2.3 recommendation is unchanged.

**New assumptions:**
1. Commit history is clean — no secrets ever committed. History exposure is accepted.
2. Remote operations are blocked (`--network=none`).
3. The agent gets a local-only git identity — no remote credentials.
4. Main branch protection is an engineering problem in scope.

### Corrected finding: gitignore filtering is preserved by worktrees

The original analysis assumed worktrees expose gitignored files. This is wrong. `git worktree add -b agent/session /path/to/worktree` creates a clean checkout of only tracked files. Gitignored files (`.env`, build artifacts, secrets) are not tracked and do not appear in the worktree directory. The snapshot pipeline's gitignore-based filtering is **not a differentiator** over worktrees — both approaches give the agent exactly the tracked working tree.

What worktrees still expose that the snapshot does not: full git history via the shared `.git/` object store. Under the new assumptions, this is accepted.

### The pipeline collapse

Current pipeline (9 steps): enumerate files, copy to `.snapshot/`, copy to `sandbox/`, init git with baseline commit, agent works, sweep commit, generate diff, generate patches, operator applies.

Worktree pipeline (4 steps):
1. `git worktree add -b agent/session SANDBOX_DIR/sandbox` — on host in `start_agent.sh`
2. Container bind-mounts `SANDBOX_DIR/sandbox/` as the agent's working directory
3. Agent works, commits — commits land directly in PROJECT_DIR's repo on `agent/session`
4. On exit: commit pending changes; `git worktree remove SANDBOX_DIR/sandbox`
5. Operator: `git log agent/session`, then `git merge` or `git branch -d`

The diff pipeline, apply script, and `.snapshot/` directory are eliminated entirely.

### Engineering problems and solutions

**Blocking remote operations:** `--network=none` on the agent container. `git push` and `git fetch` fail at the TCP layer. Single-line change to compose template.

**Protecting the main branch pointer:** After worktree creation, `git pack-refs --all` then `chmod a-w .git/packed-refs`. This makes all branch pointers read-only at the filesystem level from inside the container. Restored after session by the host. See `security_delta_worktree_model.md` for full analysis of residual gaps.

**History access:** Under the new assumptions, full history access is accepted. The shared `.git/` object store is present. The only concern is read performance on repos with deep binary history — the same class of problem as before and not worsened by worktrees.

**Gitignored files:** Not a problem — see corrected finding above.

**Capability layer role:** Lightens significantly. Fork: validate worktree exists and is healthy. Join: commit pending changes before container exits. The diff pipeline is eliminated. The two-container model is still worth retaining — the capability layer as PID 1 ensures the commit-pending step always runs even if the agent crashes.

**`--volumes-from` architecture:** Replaced by a direct bind mount of the worktree directory in both containers. Simpler — the volume lifecycle is the host directory's lifecycle, managed by `start_agent.sh` and worktree cleanup.

**Review artefact:** `staged.diff` is replaced by:
```bash
git log main..agent/session     # commit-by-commit review
git diff main...agent/session   # full file diff
```
Standard git review workflow — richer than a flat diff file and requires no operator tooling beyond git.

### What is lost vs the current model

| Current | Worktree |
|---|---|
| `staged.diff` written to `workspace/changes/` — explicit review artefact | Replaced by `git diff main..agent/session` — richer but less procedurally enforced |
| `autosave.diff` written periodically | Replaced by mid-session commits in the worktree |
| `apply_workspace.sh` — explicit apply step | Eliminated — operator uses `git merge` or `git cherry-pick` |
| Capability layer manages diff on exit | Capability layer commits pending changes on exit (simpler) |
| Snapshot isolates agent from PROJECT_DIR contents | Eliminated — agent mounts worktree (path inside PROJECT_DIR's working tree) |

The main thing lost is the **explicit diff file as a review gate**. Under the worktree model, review is via git commands against the branch — functionally equivalent but less procedurally enforced.

### Overall feasibility verdict under new assumptions

**Feasible. Architecturally clean. Represents a significant simplification.**

The three engineering problems all have workable solutions. The pipeline collapses from 9 steps to 4. The diff pipeline, apply script, and `.snapshot/` directory are eliminated. The operator review workflow improves.

The cost is a significant architectural change — replacement of the core pipeline throughout `start_agent.sh`, `sandbox-entrypoint.sh`, `diff.sh`, and the compose templates. This is not an incremental change.

**Recommendation given current roadmap position:** M2.3 as designed (format-patch + `git am`) is the right immediate step — incremental and closes the current gap. The worktree model is the correct **post-M2.3** architectural direction if the operator accepts the relaxed assumptions. Record in `roadmap_future.md` as a named candidate for a future milestone. Do not retroactively displace M2.3.

---

## Resolution

**Under original assumptions — Reject. Not applicable to M2.3.**

Git worktrees require mounting a path rooted in PROJECT_DIR's `.git` into the agent container, giving the agent unrestricted access to full repository history, all branches, remote push URLs, and any secret ever committed. There are no mitigations that preserve worktree semantics while satisfying the original harness security model. M2.3 format-patch captures the concrete benefits without the security regression.

**Under relaxed assumptions — Feasible. Candidate for a future milestone.**

When the assumptions shift (clean history, network-isolated container, main branch protection treated as an engineering problem), the worktree model is architecturally cleaner than the snapshot+diff pipeline. The three engineering problems are solvable. Full security analysis of the relaxed-assumptions model is in [`security_delta_worktree_model.md`](security_delta_worktree_model.md).

Record in `roadmap_future.md` as a named candidate for a post-M2.3 milestone. No codebase changes arise now.
