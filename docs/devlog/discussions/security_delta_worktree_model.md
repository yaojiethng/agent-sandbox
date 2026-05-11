# Security Delta — Worktree Model vs Snapshot+Diff Model

**Status:** Analysis complete. Feeds into `investigation_git_worktrees.md` and any future decision to adopt the worktree model.

**Companion document:** [`investigation_git_worktrees.md`](investigation_git_worktrees.md)  
**Security baseline:** [`docs/architecture/security.md`](../architecture/security.md)  
**Threat model:** [`docs/architecture/threat_model_stride.md`](../architecture/threat_model_stride.md)

---

## Purpose

The worktree investigation concluded feasible under a set of relaxed assumptions. Before that conclusion can be acted on, those assumptions need to be formally compared against the current security model: which invariants break, which hold, what new boundaries are introduced, and what assets remain at risk after the proposed mitigations. This document is that analysis.

---

## Part 1 — Assumption Comparison

### Current model assumptions

1. **The agent runtime is explicitly untrusted.** The reasoning layer runs agent code (LLM runtime, tool executors, project dependencies) that is not fully auditable.
2. **PROJECT_DIR is never reachable from either container.** The agent's view of the project is limited to what `git ls-files` enumerated and copied into `.snapshot/` before the run. No path inside `PROJECT_DIR` — including `.git/` — is accessible.
3. **Gitignored files are never visible to the agent.** `git ls-files --cached --others --exclude-standard` filters by `.gitignore`. Secrets excluded from tracking are excluded from the snapshot.
4. **Repository mutation requires human review first.** `staged.diff` must be reviewed by the operator before `apply_workspace.sh` is run. The agent cannot modify PROJECT_DIR without an explicit, operator-initiated apply step.
5. **Containers are ephemeral.** The agent's Docker volume (`sandbox/`) is anonymous and scoped to the capability layer container's lifetime. It is destroyed on `docker compose down -v`.
6. **Secrets are excluded from the snapshot by gitignore.** No `.env`, credential file, or secret that is gitignored can reach the agent.

### New assumptions (worktree model, as proposed)

1. **The agent runtime remains untrusted.** Unchanged.
2. **`PROJECT_DIR/.git` must be accessible from the container.** A worktree's `.git` file contains an absolute host path pointing back to `PROJECT_DIR/.git`. When only the worktree directory is bind-mounted, that path is unresolvable — git commands inside the container fail. Making the worktree functional requires additionally mounting `PROJECT_DIR/.git` into the container at a reachable path. This is the core mount change.
3. **Gitignored files remain invisible in the working tree.** `git worktree add` checks out only tracked files. Gitignored files from `PROJECT_DIR`'s working tree do not appear in the worktree. This filtering property is preserved.
4. **Commit history is clean.** Assumed by the operator — no secrets have ever been committed. The harness cannot verify or enforce this. It is an operator precondition.
5. **Remote operations are blocked.** `--network=none` on the agent container prevents all TCP/IP operations. `git push` and `git fetch` fail at the syscall level.
6. **Main branch protection is enforced by file permissions.** `git pack-refs --all` consolidates all loose refs into `packed-refs`; `chmod a-w .git/packed-refs` then makes all branch pointers read-only from inside the container.
7. **Repository mutation occurs on the agent's branch immediately.** The agent's commits go directly into `PROJECT_DIR`'s object store and onto the agent branch. The operator reviews and merges (or discards) after the fact.

---

## Part 2 — Invariant-by-Invariant Comparison

The current security invariants are enumerated in `security.md`. Each is assessed below.

---

**Invariant 1: `PROJECT_DIR` must not be mounted into either container at runtime.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ❌ Broken — by design |

The worktree model requires mounting `PROJECT_DIR/.git` into the container. This is a subpath of `PROJECT_DIR` and constitutes mounting part of `PROJECT_DIR`. The original invariant cannot hold and must be rewritten if this model is adopted.

**Proposed replacement invariant:** `PROJECT_DIR`'s working tree must not be mounted into either container. `PROJECT_DIR/.git` may be mounted read-only into the capability layer only, not into the reasoning layer. The reasoning layer accesses the worktree working directory exclusively.

Note: this still requires deciding whether `.git` is mounted into the capability layer only (capability layer manages git operations on behalf of the agent) or into the reasoning layer (agent runs git directly). The former is architecturally cleaner and is assessed separately below.

---

**Invariant 2: The capability layer container must not access host filesystem paths outside `.snapshot/` and `.workspace/session-diffs/`.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ⚠️ Requires revision |

Under the worktree model, the capability layer needs access to the worktree directory (the agent's working copy) and to `PROJECT_DIR/.git` (to create/remove worktrees and commit pending changes). The invariant must be updated to name these explicitly.

---

**Invariant 3: The reasoning layer container must not access host filesystem paths outside `.workspace/input/` and `.workspace/output/`.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ❌ Broken — by design |

The reasoning layer (agent container) needs access to the worktree working directory, which is a bind-mounted host path. This is a new host filesystem access point for the untrusted container.

Whether `PROJECT_DIR/.git` is also accessible to the reasoning layer depends on architecture choice:

- **Option A (preferred):** Only the worktree working directory is mounted into the reasoning layer. `PROJECT_DIR/.git` is mounted into the capability layer only. The agent cannot run `git log`, `git show`, etc. directly — the git object store is outside its reach. Git operations available to the agent are limited to commands that work via the worktree working tree without needing the object store (i.e., almost nothing useful). This option effectively breaks git inside the reasoning layer.

- **Option B:** Both the worktree directory and `PROJECT_DIR/.git` are mounted into the reasoning layer. The agent can run the full git toolchain. This is required if the agent is expected to make its own `git commit` calls. Full history is readable.

Option A preserves more of the original isolation model but requires the capability layer to act as a git proxy (staging and committing changes on behalf of the agent — a behaviour change to the agent workflow). Option B is what the addendum in the investigation assumed.

---

**Invariant 4: Neither container must have access to the Docker socket.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ✅ Holds — unchanged |

No change.

---

**Invariant 5: Repository mutation must occur only on the host after human review.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ❌ Broken — by design |

This is the most significant procedural invariant change. Under the current model, the agent cannot modify `PROJECT_DIR` in any form — it works in an isolated Docker volume, and `apply_workspace.sh` is the only path from the sandbox to `PROJECT_DIR`, and it requires operator action. The review gate is mandatory and pre-mutation.

Under the worktree model, the agent's commits go directly into `PROJECT_DIR`'s git object store on the agent's branch. Mutation of the repository (object creation) occurs during the session, not after review. The operator can reject the entire branch (`git branch -d agent/session`) but cannot prevent the objects from having been written. The review gate becomes post-mutation.

This changes the threat posture for prompt injection and agent compromise scenarios. A compromised agent can now write objects to `PROJECT_DIR`'s git database without any operator action. The operator's control is limited to "merge or discard the branch" rather than "apply or discard the diff."

**Proposed replacement invariant:** Agent-produced commits must not be merged into any protected branch without operator review and an explicit merge action. The agent's branch is not a protected branch. Object creation in the agent's branch is an accepted risk under the worktree model.

---

**Invariant 6: Agent-produced changes must be staged as `staged.diff` before application.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ❌ Eliminated — model change |

`staged.diff` does not exist in the worktree model. This invariant is replaced by the branch protection model above. It should be removed from `security.md` if the worktree model is adopted and replaced with the branch-protection invariant.

---

**Invariant 7: Gitignored files must never be copied into `.snapshot/` or `sandbox/`.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds via snapshot pipeline | ✅ Holds via worktree checkout |

As established in the investigation: `git worktree add` checks out only tracked files. Gitignored files in `PROJECT_DIR`'s working tree do not materialise in the worktree. The filtering property is preserved — by a different mechanism (git's own checkout behaviour rather than the snapshot pipeline's explicit enumeration). The invariant holds but should be updated to reference the new mechanism.

**Important boundary condition:** this covers the *working tree* only. Gitignored files that were accidentally committed at any point in history are present in the object store and readable under Option B. Under the new assumptions (clean history), this is accepted but unverified.

---

**Invariant 8: `agent-output/` must not contain binary or executable files.**

| | Current | Worktree model |
|---|---|---|
| Status | ✅ Holds | ✅ Holds — unchanged |

The `workspace/output/` mount is unchanged in the worktree model. No change.

---

## Part 3 — New Trust Boundaries

The current trust boundary list (from `security.md`) has seven entries. The worktree model introduces two new ones and modifies one existing one.

**Modified boundary — Containers ↔ Mounted host directories:**

Currently: `.snapshot/` (RO) and `.workspace/` subdirectories.  
Under worktree model: adds `PROJECT_DIR/.git` (RO or RW — see below) and the worktree working directory (RW bind mount).

**New boundary 1 — Reasoning layer ↔ PROJECT_DIR git object store:**

The agent container gains read access to the full git history, config, and ref store. Under Option B (agent runs git directly), it also gains write access for object creation and the agent's branch ref. This boundary does not exist in the current model.

**New boundary 2 — SESSION LIFETIME ↔ PROJECT_DIR repo integrity:**

Currently, PROJECT_DIR's git repo is never touched during a session — only after. Under the worktree model, the repo is modified during the session (objects written, refs updated). A crash, an OOM kill, or a malicious mid-session action can leave the repo in a partially-written state. The git object model is content-addressed and self-checking, which provides some protection, but the boundary between "session in progress" and "repo is safe to use" collapses.

---

## Part 4 — Assets at Risk After Proposed Mitigations

The investigation proposed two mitigations: `--network=none` (remote blocking) and `chmod a-w .git/packed-refs` (branch pointer protection). This section evaluates what each covers and what remains exposed.

### Mitigation 1: `--network=none`

**Covers:**
- `git push` — TCP blocked at syscall level.
- `git fetch` — TCP blocked.
- Data exfiltration to remote endpoints — blocked.
- Connecting to external services injected via git config (`[url]` rewrites, custom remotes) — blocked.

**Does not cover:**
- Reading `.git/config` (remote URLs, user identity, `core.hooksPath` if set) — config is local, no network needed.
- Writing to `.git/config` — local write, no network needed.
- Modifying hook scripts in `.git/hooks/` — local write, no network needed.
- Object store integrity attacks (writing corrupt or garbage objects) — local, no network needed.
- Creating new loose refs (new branch names) in `.git/refs/heads/` — local write.

**Assessment:** `--network=none` is a strong, reliable mitigation for the exfiltration threat. It does not address the local git-level threats.

---

### Mitigation 2: `chmod a-w .git/packed-refs`

**Covers:**
- Moving the `main` branch pointer — `packed-refs` is the canonical location after `git pack-refs --all`. A write attempt fails at the OS level.
- Moving any other branch pointer that has been consolidated into `packed-refs`.

**Does not cover:**

1. **New loose ref creation.** After `git pack-refs --all`, loose refs under `.git/refs/heads/` have been removed (they're now in `packed-refs`). But the agent can create a NEW loose ref by writing a new file to `.git/refs/heads/new-branch`. This does not touch `packed-refs`. The agent can create arbitrary new branch names in PROJECT_DIR's repo.

   Risk: ref namespace pollution. New branches created by the agent persist in PROJECT_DIR's repo after the session. The operator must manually clean them up. This is an annoyance risk, not a critical security risk, but it degrades repo hygiene and could confuse the operator's review workflow.

2. **`.git/config` write access.** If `.git/config` is writable (which it would be by default), the agent can:
   - Add new remotes with attacker-controlled URLs — blocked by `--network=none` at execution time, but the config is modified permanently.
   - Change `core.hooksPath` to point to a directory the agent controls — hooks run on subsequent git operations, potentially on the host after the session ends.
   - Add `[include]` directives to pull in a config file the agent has written.

   The `core.hooksPath` risk is the most serious: if the agent sets `core.hooksPath` to a path inside the worktree, and the operator later runs a git command in PROJECT_DIR after the session (e.g., `git merge agent/session`), git would execute the agent's hooks **on the host**, outside the container. This is a post-session code execution risk on the host.

   **This is the highest-severity residual risk in the worktree model after the proposed mitigations.** It is not covered by either proposed mitigation.

3. **`.git/hooks/` write access.** Similar to the `core.hooksPath` risk. If the agent can write to `PROJECT_DIR/.git/hooks/`, it can install hooks that execute on the host during the operator's post-session git workflow.

   Note: under Option A (only worktree directory mounted, not `.git/`), this risk does not exist — the agent cannot reach `.git/hooks/`. Under Option B (`.git/` also mounted and writable), this risk is fully present.

4. **Object store pollution.** The agent can write arbitrary git objects to `PROJECT_DIR/.git/objects/`. These are content-addressed and do not affect the working tree or refs unless referenced by a commit. However, they persist in the object store until `git gc --prune` and accumulate disk space over many sessions. Not a security risk but an operational hygiene concern.

5. **`worktrees/` directory manipulation.** `PROJECT_DIR/.git/worktrees/sandbox/` is the worktree-specific metadata directory. If writable, the agent can modify `HEAD`, `index`, `commondir`, and `gitdir` files within it. Modifying `HEAD` changes which branch the worktree is on without a checkout. Modifying `commondir` could redirect git operations to a different git directory. These are integrity attacks within the worktree context.

---

## Part 5 — Unverifiable Precondition

The new assumption that "commit history is clean" is **an operator assertion, not a harness guarantee.** The harness cannot verify it. The consequences of this assumption being wrong:

- Any secret committed at any point in the project's history (even if removed in a later commit) is present in the object store as a blob and readable via `git cat-file blob <sha>`.
- Under Option B, the agent can enumerate blobs via `git rev-list --objects --all` and read any of them.
- A compromised agent can systematically extract historical content.

The correct operational posture is that the harness documentation must state this precondition explicitly, and the operator must verify it (e.g., via `git secrets --scan-history` or equivalent) before enabling the worktree model for a given repository. The harness itself cannot enforce it.

---

## Part 6 — Summary Table

| Asset | Current model | Worktree model (after proposed mitigations) | Residual risk |
|---|---|---|---|
| PROJECT_DIR working tree files | ❌ Not accessible | ❌ Not accessible (worktree checkout only) | None |
| Gitignored files (working tree) | ❌ Not accessible | ❌ Not accessible | None |
| Full commit history (object store) | ❌ Not accessible | ✅ Readable (under Option B) | Accepted under new assumptions; unverifiable |
| Secrets in git history | ❌ Not accessible | ✅ Readable if present | **Unmitigated** — operator precondition only |
| `.git/config` (remote URLs, identity) | ❌ Not accessible | ✅ Readable; ✅ Writable | **`core.hooksPath` write is high-severity** |
| `.git/hooks/` | ❌ Not accessible | ✅ Readable; ✅ Writable | **Post-session host code execution** if writable |
| Main branch pointer | ❌ Not accessible | ✅ Read; ❌ Write-protected by `chmod` | Covered by mitigation |
| Other branch pointers (packed) | ❌ Not accessible | ✅ Read; ❌ Write-protected by `chmod` | Covered by mitigation |
| New branch creation (loose refs) | ❌ Not possible | ✅ Possible | Ref pollution; not critical |
| Remote push/fetch | ❌ Not possible | ❌ Blocked by `--network=none` | Covered by mitigation |
| `.git/config` write (core.hooksPath) | ❌ Not possible | ✅ Possible | **High severity — not mitigated** |
| Object store integrity | ❌ Not accessible | ✅ Writable | Operational hygiene concern |
| Review gate (pre-mutation) | ✅ Mandatory before any mutation | ❌ Mutation occurs during session | Fundamental model change |

---

## Part 7 — Required Additional Mitigations

The two proposed mitigations (`--network=none` and `chmod a-w .git/packed-refs`) are necessary but not sufficient. Two additional mitigations are required before the worktree model can be considered adequately hardened:

**Mitigation 3 — Make `.git/config` and `.git/hooks/` read-only inside the container.**

After worktree creation, in `start_agent.sh`, before the container starts:

```bash
chmod a-w PROJECT_DIR/.git/config
chmod -R a-w PROJECT_DIR/.git/hooks/
```

Restored after the session:

```bash
chmod u+w PROJECT_DIR/.git/config
chmod -R u+w PROJECT_DIR/.git/hooks/
```

This closes the `core.hooksPath` and hook-installation vectors. The agent cannot modify git configuration or install hooks that execute on the host post-session.

**Mitigation 4 — Architecture choice: mount `.git/` into capability layer only (Option A), not reasoning layer.**

If the agent does not need to run `git` commands directly — if the capability layer handles all git operations (staging pending changes, committing on exit) — then `PROJECT_DIR/.git` does not need to be mounted into the reasoning layer at all. The reasoning layer gets only the worktree working directory (tracked files). This eliminates the object store read access, config write access, hooks write access, and ref pollution risks entirely for the reasoning layer.

The cost: the agent cannot run `git status`, `git log`, or `git commit` itself. Whether this is acceptable depends on the agent's workflow. For agents that use git as part of their task (e.g., reading commit history to understand context), this is a regression. For agents that only read and write files, it is not.

---

## Conclusion

The worktree model requires breaking three current security invariants: (1) no PROJECT_DIR mount, (2) no host mutation before review, (3) diff-as-review-gate. Two of these are fundamental model changes that must be accepted, not mitigated — the worktree model cannot provide a pre-mutation review gate, and it cannot function without mounting part of PROJECT_DIR. The third (diff gate) is eliminated and replaced by a branch-protection model.

The proposed mitigations (`--network=none` + `chmod a-w packed-refs`) leave two high-severity gaps: `.git/config` write access (enabling `core.hooksPath` manipulation for post-session host code execution) and `.git/hooks/` write access. Both require additional mitigations (making config and hooks read-only, and/or restricting `.git/` to the capability layer only).

If all four mitigations are applied, the residual risks are: (a) the operator's "clean history" precondition is unverifiable by the harness, and (b) the review gate is now post-mutation rather than pre-mutation. Both are accepted model changes under the new assumptions, not engineering failures.

The security model documentation (`security.md`, `threat_model_stride.md`) would need material revision before the worktree model is adopted. The invariant rewrites are itemised in Part 2 above.
