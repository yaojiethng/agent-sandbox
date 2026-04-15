# Investigation — Git Worktrees as Sandbox Isolation Mechanism

**Status:** In progress — original findings complete; addendum added under relaxed assumptions (see below)

**Direction:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline  
**Parent story:** [`docs/devlog/roadmap.md` — M2.3](#)

---

## Required Reading

- [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants; the core constraint this investigation tests.
- [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — mount shape, `--volumes-from`, and why `PROJECT_DIR` is never mounted.
- [`docs/architecture/sandbox_lifecycle.md`](../sandbox_lifecycle.md) — snapshot + diff pipeline as currently implemented.
- [`docs/devlog/discussions/investigation_hermes.md`](investigation_hermes.md) — prior Hermes investigation; confirmed `terminal.backend: local` satisfies harness constraints.

> **Source note:** The Hermes worktree documentation (`hermes-agent.nousresearch.com/docs/user-guide/git-worktrees/`) and source (`github.com/NousResearch/hermes-agent`) were referenced by the operator but are not reachable at investigation time (no web access inside the container). This investigation draws on: general `git worktree` semantics, the existing Hermes investigation findings in this repo, and the current harness architecture. Any claim attributed specifically to the Hermes source is from prior investigation context, not live inspection.

---

## Summary

Hermes uses `git worktree add` to give each agent task an isolated working directory that is a real branch inside the project's git repository. The agent works in the worktree; changes are committed to a real branch; the developer reviews and merges. This eliminates the copy-in / diff / apply round-trip entirely. The question is whether this model — or something structurally similar — is viable as a replacement or complement to the current snapshot+diff pipeline.

---

## How Hermes Uses Worktrees

When given a task, Hermes creates a new worktree on a fresh branch:

```bash
git worktree add -b agent/task-name /path/to/worktree-dir
```

The worktree directory is a real checkout of the project at that branch. It shares the same `.git` object store — no duplication of history, blobs, or pack files. The agent works inside this directory; all `git` commands in the worktree operate against the shared `.git`. On completion, the worktree can be reviewed, merged, or `git worktree remove`d and the branch deleted if rejected.

**Why worktree over other options (Hermes's perspective):**

| Alternative | Why rejected |
|---|---|
| `git checkout -b new-branch` | Displaces the developer's current working state; untracked files, stash, partial edits all get disrupted |
| `git clone` | Duplicates the full object store to disk; expensive for large repos; two repos means manual branch sync after |
| Separate directory + manual diff | No git history; no `git log`; apply is a patch operation with no conflict tooling |
| `git stash + new branch` | Stash is a stopgap, not an isolation unit; WIP stash can be corrupted by aggressive operations; fragile |
| Submodule | Far too complex for an ephemeral task workspace |

The worktree is the clean answer when: you trust the process working in it, it runs on your machine, and the primary goal is "don't disturb my current working tree."

---

## Findings Against the Current Architecture

### Finding 1 — The core incompatibility: PROJECT_DIR is never mounted

The current security model has one non-negotiable invariant:

> *"PROJECT_DIR is not mounted into either container, so the agent runtime cannot read host repository files directly."* — `security.md`

A git worktree is inseparable from the project's `.git` directory. When `git worktree add` creates `worktree-dir/`, it places a `.git` **file** (not a directory) inside it that points back to `PROJECT_DIR/.git/worktrees/...`. Every git operation inside the worktree uses the shared object store. This means:

- To use a worktree, you must either mount `PROJECT_DIR` or the worktree path (which resides inside `PROJECT_DIR`'s filesystem) into the agent container.
- Either way, the agent container can resolve the `.git` pointer and read the full repository: `git log --all`, `git show <any-sha>`, `git stash list`, packed refs for all branches and remotes.

**This breaks the harness security model at its foundation.** The snapshot pipeline exists precisely to give the agent a filtered view (gitignore-respecting, history-free copy). The worktree bypasses every part of that filtering.

### Finding 2 — What the agent gains access to with a worktree

If the worktree were mounted into the container, the agent runtime could:

| Access | Current (snapshot) | Worktree |
|---|---|---|
| Current project files | ✅ filtered via gitignore | ✅ (working tree only) |
| Full commit history | ❌ no `.git` in sandbox | ✅ shared `.git` |
| All branches / tags | ❌ | ✅ |
| Secrets that were ever committed (then removed) | ❌ | ✅ via `git show` |
| Remote configuration (`origin`, push URLs) | ❌ | ✅ |
| Ability to `git push` to remotes | ❌ | ✅ (if remote configured) |
| Ability to rewrite history (`git rebase -i`, `git reset`) | ❌ | ✅ |

The threat model treats the agent runtime as explicitly untrusted (`security.md`). The worktree model requires trusting it with full repository access, which is a significant and hard-to-audit regression.

Can these risks be mitigated within the worktree model? Considered options:

- **Git hooks to block dangerous operations:** Fragile. The agent controls the shell; it can bypass hooks with `--no-verify` or by removing them.
- **Read-only mount of `.git`:** The worktree requires write access to `.git/worktrees/<name>/` for lock files and HEAD updates. A read-only `.git` makes the worktree non-functional.
- **Separate git dir (`--separate-git-dir`):** This would decouple the working tree from the main `.git`, but then it is no longer a worktree — it is a clone, and you lose the shared-object-store benefit.

None of these preserve the worktree model while satisfying the security invariant.

### Finding 3 — The "worktree as container volume" hybrid

One possible rethinking: rather than mounting the actual PROJECT_DIR worktree, create an independent git repository in `sandbox/` (as today) but structure it as a **persistent branching repo** instead of a single-session throwaway:

- Session N creates branch `agent/YYYYMMDD-HHMMSS` off the baseline commit.
- Session N+1 creates a new branch off a new baseline.
- The sandbox repo accumulates session branches over time.
- `apply_workspace.sh` cherry-picks or fast-forward merges the session branch into PROJECT_DIR.

This is **structurally identical to the M2.3 format-patch design**, minus the `git worktree` mechanism. It preserves all the same benefits (named branches, real history, `git log` per session, PR-ready units) without mounting PROJECT_DIR or exposing the host `.git`. The M2.3 design already arrives at this via format-patch + `git am`; there is no need to introduce worktrees to achieve it.

### Finding 4 — The one genuine advantage: no large-repo copy

The worktree shares the object store, so no files are duplicated. For large repos (hundreds of MB, or repos with large binary history), the current snapshot copy (`cp -a` in `snapshot_copy_files`) can be slow and expensive.

This is a real cost that the worktree model eliminates. However:

- The snapshot copy is of **working tree files only** — it copies what `git ls-files` enumerates, not the `.git` directory. Pack files and history are never copied.
- The cost is proportional to the number and size of tracked files, not repo history depth.
- For the repos this harness is designed for (code projects), this is typically fast. It becomes a real problem only for repos with large binary assets under version control.
- If this becomes a bottleneck, the correct fix is incremental snapshot (rsync instead of cp, or content-addressed caching) — not a worktree, which brings the security regression.

### Finding 5 — Why worktrees work for Hermes but not for agent-sandbox

Hermes's trust model is different. Hermes is a **local agent running on the developer's own machine** — the agent is the developer's process, operating with the developer's credentials and filesystem access. The separation of concerns is task isolation (don't mess up my current checkout), not security isolation (don't let the agent see my secrets). Git worktrees are the right tool for task isolation.

Agent-sandbox's trust model is different: **the agent runtime is explicitly untrusted**. The container is a security boundary, not just a convenience wrapper. The snapshot pipeline is a trust filter, not just a working-copy mechanism. These are different problems, and worktrees solve only the former.

---

## Open Questions

None blocking a recommendation. The analysis is sufficient for a clear conclusion.

---

## Constraints

- The agent runtime is explicitly untrusted. No mechanism that requires mounting `PROJECT_DIR` (or any path connected to its `.git`) into the agent container is viable.
- Gitignored files, including secrets, must never be visible to the agent runtime.
- The operator must be able to review all changes before they reach `PROJECT_DIR`. "No round-trip" means "no review gate" — this is not a goal.

---

## Addendum — Revised Feasibility Under Relaxed Assumptions

**Trigger:** Operator re-scoped the assumptions. The following analysis supersedes Finding 1 and Finding 2 for the purposes of future architectural consideration. The original findings remain as the basis for the M2.3 recommendation, which is unchanged.

**New assumptions:**
1. Commit history is clean — no secrets ever committed. History exposure is a performance question, not a security question.
2. Remote operations must be blocked (no `git push`, `git fetch`, no network).
3. The agent gets a local-only git identity — no remote credentials.
4. Main branch protection (preventing the agent from corrupting the main branch pointer) is an engineering problem in scope, not a rejection criterion.

---

### Corrected finding: gitignore filtering is preserved by worktrees

The original analysis assumed worktrees expose gitignored files. This is wrong. `git worktree add -b agent/session /path/to/worktree` creates a clean checkout of only tracked files. Gitignored files from PROJECT_DIR (`.env`, build artifacts, secrets) are not tracked and therefore do not appear in the worktree directory. The worktree is a filtered view of the project — identical in content coverage to what `snapshot_enumerate_files` + `snapshot_copy_files` produces today.

This is a material correction: the snapshot pipeline's gitignore-based filtering is **not a differentiator** over worktrees. Both approaches give the agent exactly the tracked working tree.

What worktrees still expose that the snapshot does not: full git history (via the shared `.git/` object store). Under the new assumptions, this is an accepted non-issue.

---

### The pipeline collapse

Current pipeline (8 steps):

1. `snapshot_enumerate_files` — `git ls-files` on PROJECT_DIR
2. `snapshot_copy_files` — `cp -a` each file to `.snapshot/`
3. Capability layer copies `.snapshot/` → `sandbox/` Docker volume
4. `snapshot_init_git` — fresh `git init`, baseline commit, record SHA
5. Agent works, commits
6. `diff_commit_pending` — sweep uncommitted changes into a commit
7. `diff_generate` — `git diff BASELINE..HEAD` → `staged.diff`
8. `diff_format_patch` (M2.3) — `git format-patch` → `patches/*.patch`
9. Operator: `apply_workspace.sh` — `git am` or `git apply` into PROJECT_DIR

Worktree pipeline (4 steps):

1. `git worktree add -b agent/session SANDBOX_DIR/sandbox` — on host, in `start_agent.sh`
2. Container mounts `SANDBOX_DIR/sandbox/` as the agent's working directory (bind mount, not Docker volume)
3. Agent works, commits — commits land directly in PROJECT_DIR's repo on `agent/session` branch
4. On exit: commit any pending changes; `git worktree remove SANDBOX_DIR/sandbox`
5. Operator: `git log agent/session`, then `git merge` or `git branch -d`

Steps 1–4 of the current pipeline collapse to a single `git worktree add`. Steps 6–9 collapse to the operator's standard git workflow. The diff pipeline (`diff.sh`), apply script (`apply_workspace.sh`), and `.snapshot/` directory are eliminated entirely.

---

### Engineering problems and solutions

**1. Blocking remote operations**

The agent container currently has unrestricted network access in `standard` mode. Adding `--network=none` to the agent container's Docker run flags eliminates network access entirely. `git push` and `git fetch` fail at the TCP layer — no git-level configuration needed. This is a single-line change to the compose template and is cleaner than git-level controls (which the agent can bypass with `--no-verify` or by editing `.git/config`).

**Verdict: Trivially solvable. `--network=none` on the agent container.**

**2. Protecting the main branch pointer**

Worktrees prevent the agent from *checking out* a branch already checked out in another worktree. If `main` is checked out in the project's primary working tree, the agent container cannot run `git checkout main` in its worktree. However, the agent can still move the `main` branch pointer without checking it out:
- `git branch -f main <sha>`
- `git reset` (while on `agent/session`, then force-move main)
- `git merge --ff-only main` (if already on main-equivalent)

These operations write to `.git/refs/heads/main` or `.git/packed-refs`. The solutions, in order of robustness:

| Approach | How | Robustness |
|---|---|---|
| Make `refs/heads/main` read-only on the filesystem | `chmod a-w .git/refs/heads/main` after worktree creation, in `start_agent.sh` | High — syscall-level; agent cannot write without `chmod` first |
| Move to packed-refs and make read-only | `git pack-refs --all`, then `chmod a-w .git/packed-refs` | High — same mechanism, also covers all remote-tracking refs |
| Pre-commit / reference-transaction hook | Hook in `.git/hooks/` that rejects writes to `refs/heads/main` | Medium — agent can overwrite or delete the hook file |
| Separate git server with branch protection | Run a local bare repo, agent pushes to it | Overkill — adds infrastructure |

The `chmod` approach is the most robust option available without adding infrastructure. After `git worktree add`, `start_agent.sh` makes the main ref read-only at the filesystem level. The agent (running as `agentuser` inside the container) cannot overwrite it. The host (running `start_agent.sh` as the operator user) restores write permissions after the session.

One wrinkle: if `packed-refs` contains `main` (git sometimes migrates loose refs to packed-refs), making `refs/heads/main` read-only is insufficient. The correct sequence:

```bash
git pack-refs --all             # consolidate all loose refs into packed-refs
chmod a-w .git/packed-refs      # make packed-refs read-only
# ... start container ...
# after container exits:
chmod u+w .git/packed-refs      # restore write permissions for operator
```

This protects all branch pointers (not just main) from inside-container modification, which is actually a stronger posture.

**Verdict: Solvable. File permission manipulation on `packed-refs` after worktree creation.**

**3. History access**

Under the new assumptions, full history access is accepted. The shared `.git/` object store is present in the worktree. The agent can run `git log --all`. This is no longer a constraint.

The only remaining concern is **read performance**: a repo with deep history means the object store is large. This is the trade-off that replaces the security concern under the new assumptions. For most code repos, this is negligible. For repos with large binary history, it could be a concern — but this is the same class of problem as before and is not worsened by worktrees (the agent could read history from the sandbox repo's git history too, if it were preserved).

**4. Gitignored files**

As corrected above: not a problem. Worktrees contain only tracked files. `.env`, credentials, and build artifacts are not present in the worktree directory.

**5. The capability layer's role**

Currently the capability layer's two jobs are:
- Fork: copy snapshot into `sandbox/`, init git
- Join: run diff pipeline on exit, copy diff artefacts to `workspace/changes/`

Under the worktree model:
- Fork: validate the worktree exists and is healthy (the worktree was created by `start_agent.sh` on the host, not inside the container)
- Join: commit any pending changes in the worktree before the container exits

The capability layer becomes much lighter. Its join-phase diff pipeline is eliminated. It may not need to be a separate container at all — the pre/post logic could move into `start_agent.sh` and a post-exit hook. However, keeping the two-container model has non-security value: the capability layer is PID 1 and survives agent crashes, ensuring the commit-pending step always runs. This is worth retaining.

**6. The `--volumes-from` architecture**

The current model uses a Docker volume (anonymous, created by the capability layer) shared to the reasoning layer via `--volumes-from`. With a worktree bind-mounted from the host, both containers mount the same host directory via `type: bind`. `--volumes-from` is replaced by a direct bind mount in the reasoning layer's compose entry. This is simpler — the volume lifecycle is now just the host directory's lifecycle, managed by `start_agent.sh` and the worktree cleanup step.

**7. Review artefact**

`staged.diff` is the current operator review artefact. Under the worktree model it is replaced by:

```bash
git log main..agent/session       # commit-by-commit review
git diff main...agent/session     # full file diff
```

This is strictly better — it is the standard git review workflow, it is richer than a flat diff file, and it requires no operator tooling beyond git itself. The `workspace/changes/` directory and `staged.diff` are eliminated.

---

### What is lost vs the current model

| Current | Worktree |
|---|---|
| `staged.diff` written to `workspace/changes/` — operator reads before applying | Replaced by `git diff main..agent/session` — richer but requires operator to run a git command |
| `autosave.diff` written periodically | Replaced by mid-session commits in the worktree — already in the repo |
| Apply script (`apply_workspace.sh`) | Eliminated — operator uses `git merge` or `git cherry-pick` |
| Capability layer manages diff on exit | Capability layer commits pending changes on exit (simpler) |
| Snapshot copy isolates agent from PROJECT_DIR contents | Eliminated — agent mounts worktree (a path inside PROJECT_DIR's working tree) |

The main thing lost is the **explicit diff file as a review gate**. The operator currently reads `staged.diff` before running `make apply`. Under the worktree model, review is via git commands against the branch — functionally equivalent but less procedurally enforced. Whether this is a regression depends on the operator's workflow preference.

---

### Overall feasibility verdict under new assumptions

**Feasible. Architecturally clean. Represents a significant simplification.**

The three engineering problems (remote blocking, main branch protection, gitignore filtering) all have workable solutions. The pipeline collapses from 9 steps to 4. The diff generation, apply script, and `.snapshot/` directory are eliminated. The operator review workflow improves (git-native branch review rather than a flat diff file).

The cost is a significant architectural change: the snapshot + diff model is replaced by a worktree + branch model throughout `start_agent.sh`, `sandbox-entrypoint.sh`, `diff.sh`, and the compose templates. This is not an incremental change — it is a replacement of the core pipeline.

**Recommendation given current roadmap position:** M2.3 as designed (format-patch + `git am`) is the right immediate step — it is incremental and closes the current gap. The worktree model is the correct **post-M2.3** architectural direction if the operator accepts the relaxed assumptions documented here. It should be recorded in `roadmap_future.md` as a named candidate for a future milestone (M2.6 or similar) rather than retroactively displacing M2.3.

---

## Resolution

**Under original assumptions — Reject. Not applicable to M2.3.**

Git worktrees are the right mechanism when: the agent is trusted, it runs on the operator's machine, and the goal is working-tree isolation rather than security isolation. That is Hermes's operating context.

Agent-sandbox's operating context is the inverse: the agent is untrusted, it runs in a container, and the snapshot pipeline is a security filter. Adopting worktrees requires mounting a path rooted in PROJECT_DIR's `.git` into the agent container, giving the agent unrestricted access to full repository history, all branches, remote push URLs, and any secret ever committed. There are no mitigations that preserve worktree semantics while satisfying the original harness security model.

M2.3 format-patch captures the concrete benefits without the security regression. M2.3 proceeds as designed.

**Under relaxed assumptions — Feasible. Candidate for a future milestone.**

See Addendum above. When the assumptions shift (clean history, network-isolated container, main branch protection treated as an engineering problem), the worktree model is architecturally cleaner than the snapshot+diff pipeline: fewer steps, no apply script, native git review workflow, better performance on large repos. The three remaining engineering problems (remote blocking via `--network=none`, main branch protection via `chmod a-w .git/packed-refs`, gitignore filtering — naturally preserved by worktrees) all have workable solutions.

Record in `roadmap_future.md` as a named candidate for a post-M2.3 milestone. No codebase changes arise now.
