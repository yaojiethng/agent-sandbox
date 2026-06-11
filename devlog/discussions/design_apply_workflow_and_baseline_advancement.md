# Design — Apply Workflow, Baseline Advancement, and Diff Primitives

**Target milestone:** M2.3 (Changes 3, 5, 6) + Change 5 prerequisite (container naming)

> [SUPERSEDED: Change 6 as originally specified is rejected and replaced. See `design_diff_and_branch_packaging_workflow.md`. All other content is preserved as the reasoning record. SUPERSEDED markers indicate the specific decisions that changed.]

---

## Primitives

| Primitive | Definition |
|---|---|
| **Main repo** | `PROJECT_DIR` — host git repository with full commit history |
| **Worktree repo** | `git worktree add` checkout of the same object store; distinct path, distinct branch, shared tags and object store |
| **Sandbox** | Container-local git repository initialised from a snapshot of the host at session start |
| **Baseline commit** | Synthetic first commit in sandbox, representing exactly `HEAD` of host at session start. Produced via `git archive HEAD` → unpack → commit |
| **`BASELINE_SHA`** | SHA of the baseline commit, written to `sandbox/.git/BASELINE_SHA` at init. All diffs computed against this [SUPERSEDED: advancing `BASELINE_SHA` removed; replaced by `INIT_SHA` — written once at container init, never updated. See new design.] |
| **`staged.diff`** | Flat aggregate diff since `BASELINE_SHA`. Human-readable overview artefact |
| **`patches/`** | Per-commit `.patch` files from sandbox history via `git format-patch BASELINE_SHA..HEAD`. One file per agent commit. Machine-apply artefact [SUPERSEDED: `.patch` files with git metadata headers replaced by plain numbered `.diff` files with index lines stripped, applied via `git apply`. See new design.] |
| **Checkpoint tag** | `agent-checkpoint/<worktree-id>/<timestamp>` — lightweight tag in the host repo marking host state before session start. Recovery point and draft branch base [SUPERSEDED: checkpoint git tags removed — they pollute the remote for all users. `make draft` accepts `FROM=<hash>` for branch base; defaults to `HEAD`. See new design.] |
| **Draft branch** | `draft/<branch>-<session-ts>` — temporary branch in the host repo. Preserves original branch-name slashes; disambiguates sessions with session timestamp |
| **`draft-state`** | File at `SANDBOX_DIR/.workspace/draft-state`. Records active draft: source branch, working branch, session directory. One per `SANDBOX_DIR` |
| **`WORKTREE_ID`** | Short hash of `PROJECT_DIR` absolute path. Namespaces checkpoint tags and container names per worktree instance |
| **`ADVANCED_SESSIONS`** | File at `sandbox/.git/ADVANCED_SESSIONS` inside the container. Append-only log of session names whose patches have been applied to the sandbox via baseline advancement [SUPERSEDED: removed entirely — no harness-side tracking of applied state. See new design.] |
| **Session artefact directory** | `SANDBOX_DIR/.workspace/session-diffs/<session-name>/` — scoped directory holding `staged.diff`, `patches/`, and `autosave.diff` for one session # renamed from changes/ in M2.3 [SUPERSEDED: folder key changes from `<session-name>` to `<branch-name>`; contents change from `patches/` of `.patch` files to numbered `.diff` files. See new design.] |
| **Container labels** | Docker labels set on the capability layer container at session start. Ground truth for session identity — not derivable from files that can go stale. Labels: `agent-sandbox.project-dir`, `agent-sandbox.session-name`, `agent-sandbox.checkpoint-tag` [SUPERSEDED: `agent-sandbox.checkpoint-tag` label removed alongside checkpoint tags. Other labels retained.] |
| **`scripts/checkpoint.sh`** | Consolidates all checkpoint logic: tag creation, pruning, lookup, and `WORKTREE_ID` derivation. Sourced by `start_agent.sh`, `apply_workspace.sh`, and `advance_baseline.sh` [SUPERSEDED: tag creation, pruning, and lookup removed from `scripts/checkpoint.sh`; `WORKTREE_ID` derivation retained for container naming.] |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow out as patches and are applied by the operator.
- The sandbox and host repo have divergent git histories. The shared language between them is the **patch set** — patches produced from sandbox history apply cleanly to host state at the checkpoint because both represent the same content lineage from the same baseline. [SUPERSEDED: "patch set" and "checkpoint" replaced by "diff file" and "session-start file state". The shared language is a git-agnostic unified diff, not a git patch. See new design.]
- One draft is active per repo at a time. Git enforces this by allowing only one checked-out branch. `draft-state` records which session is staged; `make draft` guards against starting a second draft while one is in progress.
- Patches apply cleanly when sandbox and host are in unison at the baseline. A patch that does not apply cleanly signals content divergence — the conflict is resolved on the pre-patch state, not mid-apply.
- Baseline advancement requires a clean sandbox working tree. Uncommitted agent work must be committed before the operator triggers advancement. [SUPERSEDED: baseline advancement via `docker exec` removed entirely; this invariant no longer applies.]
- Session artefact directories are non-colliding across concurrent worktree sessions. `SESSION_NAME` encodes branch and timestamp; git worktree enforces branch uniqueness.

---

## Functional Requirements

**Apply workflow (host side):**
- Operator reviews agent changes on a working branch before merging to any target branch
- Review branch is created from the checkpoint tag — the exact host state the agent worked against [SUPERSEDED: checkpoint tag removed; branch base is `FROM=<hash>` argument, defaulting to `HEAD`. Operator supplies hash explicitly when needed.]
- Merge is always linear; no merge commits
- A failed or unwanted draft can be cleanly discarded with no lasting effect on the host repo
- Pre-M2.3 sessions (flat diff, no patches) remain applicable via a legacy path
- Operator can recover to pre-session host state via checkpoint tag lookup — `checkpoint.sh` provides the lookup function; no ref file required [SUPERSEDED: checkpoint tag lookup removed; recovery via `git reflog` or operator knowledge of pre-session commit SHA.]

**Baseline advancement:**
- After confirming a patch set to the host, the sandbox baseline advances to match — without container restart [SUPERSEDED: baseline advancement via `docker exec`/`git am` removed. `INIT_SHA` is fixed and never advanced. Full re-export via `package-branch` on demand replaces incremental advancement. See new design.]
- Advancement is idempotent: a session cannot be applied to the sandbox twice [SUPERSEDED: `ADVANCED_SESSIONS` idempotency guard removed.]
- Multiple unadvanced sessions are applied in sequence in timestamp order [SUPERSEDED: multi-session advancement removed.]
- When no container is running, advancement is skipped gracefully; the operator restarts to get a fresh baseline from the updated snapshot

**Diff primitives:**
- Two complementary primitives with distinct semantics are available [SUPERSEDED: two primitives collapsed to one unified diff format. See new design.]
- Both are accessible as shell functions in `libs/diff.sh` and as agent-facing skills in `.skills/`

**Parallel sessions:**
- Two sessions against different worktrees of the same repo do not collide in artefacts, tags, container names, or draft state
- Merging worktree output to the main repo branch is handled by standard git workflow

---

## Apply Workflow

### draft / confirm / reject

**`make draft [SESSION=<n>]`**

Resolves the target session: explicit name if provided, otherwise the lexicographically
last entry in `.workspace/session-diffs/` (chronologically latest, given `<branch>-<timestamp>`
naming). Resolves the base checkpoint tag via `checkpoint.sh` — derives `WORKTREE_ID` from
`PROJECT_DIR`, looks up the latest `agent-checkpoint/<worktree-id>/*` tag by sort order.
Creates
`draft/<branch>-<session-ts>` from the checkpoint, preserving original branch-name slashes
for readability and disambiguating sessions with the session timestamp. Applies all patches in `patches/` in
sort order via `git am --3way` with per-patch author reset to operator's `git config`.
Writes `draft-state`.

On patch application failure: runs `git am --abort`, deletes the partially-created draft
branch, removes `draft-state`, exits with a message identifying the failing patch and
conflict. The repo is left in its pre-draft state.

[SUPERSEDED: `make draft` redesigned — checkpoint tag lookup replaced by `FROM=<hash>` (default: `HEAD`); `SESSION=<n>` replaced by branch-name folder with `DIFFS=<start>..<end>` range argument; `git am --3way` replaced by sequential `git apply` with index lines stripped; per-patch author reset removed. See new design.]

**`make confirm [TARGET=<branch>] [SYNC=1]`**

Reads `draft-state`. Rebases working branch onto target (default: `SOURCE_BRANCH`).
Fast-forward merges to target. Deletes working branch. Clears `draft-state`.

With `SYNC=1`: after the host-side merge, triggers baseline advancement in the running
container. Locates the container by querying Docker for a running container whose
`agent-sandbox.project-dir` label matches `PROJECT_DIR`. Validates that the container's
`agent-sandbox.session-name` label matches the session being confirmed — if it does not,
the container was started for a different session and `SYNC=1` fails with a clear error
rather than advancing an incompatible baseline. If no container is running, `SYNC=1` is
silently ignored.

[SUPERSEDED: `SYNC=1` and `docker exec` baseline advancement removed. `make confirm` now only cleans up the draft branch and clears `draft-state`. Operator runs `git rebase -i` manually before calling `make confirm`. See new design.]

**`make reject`**

Reads `draft-state`. Returns to `SOURCE_BRANCH`. Deletes working branch. Clears
`draft-state`. Session artefacts are retained unchanged.

**`make sync`**

Advances the sandbox baseline in a running container to match the current host state.
Locates the container by `agent-sandbox.project-dir` label. Reads `ADVANCED_SESSIONS`
from the container to determine which sessions have already been applied. Collects all
session directories in `.workspace/session-diffs/` not present in `ADVANCED_SESSIONS`, sorted
by timestamp, and applies them in sequence. Does not validate session name against the
container label — `make sync` is an explicit catch-up operation, not a tight per-confirm
sync. Fails if no container is running.

[SUPERSEDED: `make sync` removed entirely. `ADVANCED_SESSIONS` removed. No harness-side baseline advancement. See new design.]

**Legacy path — `make apply` (reasoning layer output channel)**

`make apply` applies `changes.diff` from the reasoning layer output channel at
`.workspace/output/`. This is the host-side consumer of reasoning layer output, distinct
from the capability layer diff channel (`.workspace/session-diffs/`) consumed by `make draft`.

**Session resolution:**
- With no `SESSION=`: lexicographically last entry in `.workspace/output/` (by basename sort)
- With `SESSION=<n>`: explicit directory `.workspace/output/<n>/` — errors if not found

**Artefact format:** Each session package is a directory containing:
- `changes.diff` — unified diff for application via `git apply --3way`
- `changed-files/` — supporting files referenced by the diff (if any) [SUPERSEDED: `changed-files/` removed in M2.3 Change 7.]
- `migration-guide.md` — operator-facing guide describing the changes (printed by script)

**Behaviour:**
- Prints path to `migration-guide.md` if present — operator should read before proceeding
- Applies via `git apply --3way changes.diff` against `PROJECT_DIR` [SUPERSEDED: replaced by `grep -v '^index ' | git apply` in M2.3 Change 7.]
- With `--force`: uses `git apply --reject`; `.rej` files created for failed hunks
- Prints summary: files changed, any conflicts
- Does not create commits — operator reviews and commits manually

**Cleanup policy:** `OUTPUT_DIR` is not cleared automatically. Operator clears manually
between sessions if desired.

**Pre-M2.3 sessions:** Sessions produced before the reasoning layer packaging convention
used `staged.diff` in `.workspace/session-diffs/`. Those are no longer supported by
`make apply` — operators should use `make draft` for capability layer sessions.

### Session resolution

`make draft` with no `SESSION=` resolves to the lexicographically last entry in
`.workspace/session-diffs/` — the latest session by sort order. Explicit `SESSION=<n>` is
available for older sessions. Short-form aliases are not implemented; revisit when operator
feedback identifies friction.

[SUPERSEDED: session resolution by `SESSION=<n>` replaced by branch-name folder with `DIFFS=<start>..<end>` range argument. See new design.]

---

## Baseline Advancement

### Why it is needed

After `make confirm`, the host repo has advanced. The sandbox `BASELINE_SHA` still points
to the synthetic baseline commit from session start. Without advancement, the next session
exit re-emits patches covering already-confirmed work, producing a diff the operator has
already reviewed and applied.

Container restart resolves this — a fresh snapshot is built from the updated host — but at
the cost of snapshot rebuild, volume recreation, and session context loss.

[SUPERSEDED: the problem framing is correct but the solution (`docker exec` / `git am` advancement) is wrong and removed. `package-branch` always re-exports the full branch history since `INIT_SHA`; the operator manages range selection via `DIFFS=<start>..` argument. The design section below is superseded in full. See new design.]

### Design

Two advancement paths exist with different validation profiles:

**`make confirm SYNC=1`** — tight, per-confirm sync. Validates that the container's
`agent-sandbox.session-name` label matches the session being confirmed before applying
patches. Fails loudly if there is a mismatch. Use when the container is known to be
running for the current session.

**`make sync`** — explicit catch-up. No session name validation. Applies all confirmed
sessions not yet in `ADVANCED_SESSIONS` in timestamp order. Use when the container has
fallen behind by one or more sessions, or when the operator wants explicit control over
when advancement runs.

When no container is running, both paths degrade gracefully — the operator restarts the
container to reinitialise from the current host state via a fresh snapshot.

**Container lookup:** Both paths locate the running capability layer container by querying
Docker for a container whose `agent-sandbox.project-dir` label matches `PROJECT_DIR`.
No ref files are consulted. The label is set at container start and is authoritative for
the lifetime of the container.

**Advancement sequence** (executed inside the container via `docker exec`):

1. Read `ADVANCED_SESSIONS`. If the session name is already recorded, exit — already advanced.
2. Verify sandbox working tree is clean. If dirty, exit with error: agent must commit before baseline can be advanced.
3. Apply patches from `workspace/session-diffs/<session-name>/patches/` in sort order via `git am --3way`.
4. On success: write new `HEAD` SHA to `BASELINE_SHA`. Append session name to `ADVANCED_SESSIONS`.
5. On conflict: run `git am --abort`. Exit with error naming the conflicting patch. Operator resolves on pre-patch state and re-runs `make confirm`.

**Multi-session advancement:** When multiple sessions have been confirmed without
intermediate advancement, `make confirm` collects all session directories absent from
`ADVANCED_SESSIONS`, sorted by timestamp, and applies them in sequence. A failure halts at
the conflicting session; already-advanced sessions are not re-applied.

**Idempotency:** `ADVANCED_SESSIONS` is the sole guard. A session recorded there is never
re-applied.

### Container naming and label prerequisite

Advancement uses `docker exec` into the running capability layer container, located by
label lookup rather than by a stored ref file. This requires two things from Change 5:

- Explicit `container_name:` in the generated compose, derived from session identity, so
  the container has a predictable and stable name for `docker exec`
- Container labels (`agent-sandbox.project-dir`, `agent-sandbox.session-name`,
  `agent-sandbox.checkpoint-tag`) set at session start via the compose environment

`scripts/checkpoint.sh` is introduced in Change 5 to consolidate checkpoint tag creation,
pruning, lookup, and `WORKTREE_ID` derivation. It is sourced by `start_agent.sh`,
`apply_workspace.sh`, and the advancement script — all checkpoint operations go through
this single library rather than being duplicated across scripts.

---

## Diff Primitives

Two primitives with distinct semantics. Both available as functions in `libs/diff.sh` and
as skills in `.skills/`.

[SUPERSEDED: two primitives collapsed to one unified diff format. `format-patch` removed. `package-diff` retained and extended. New `package-branch` command added. See new design.]

### `format-patch` — history-preserving

Produces one `.patch` file per agent commit via `git format-patch BASELINE_SHA..HEAD`.
Preserves commit messages and authorship. Applied via `git am` — each sandbox commit
becomes a real commit in host history. **Not idempotent:** applying the same patch twice
conflicts because the content is already present.

Used by: `make draft` / `make confirm`; baseline advancement inside the container.

[SUPERSEDED: `format-patch` removed. Replaced by `package-branch` producing plain numbered `.diff` files applied via `git apply`. See new design.]

### `package-diff` — content-addressed, history-neutral

Produces a single unified diff representing the net change between two states, disregarding
intermediate commit history. **Idempotent:** applying the same diff to content that already
reflects it is a no-op. Convertible to a single commit by staging and committing the result.

Two directions of use:

**Sandbox → host (agent-initiated):** Baseline is `HEAD` in the sandbox. Captures the net
change of uncommitted work as a mid-session checkpoint. The agent invokes this manually
when a partial package is wanted before session exit.

**Host → sandbox (operator-initiated):** Baseline is `BASELINE_SHA` in the sandbox.
Captures host amendments the sandbox has not yet seen. The operator uses this to push
changes into a running container without restart — the symmetric counterpart to baseline
advancement.

**Skill location:** `.skills/package-diff.md` in the harness repo. Available to all agents
by default; projects may extend or override for project-specific packaging conventions. The
`migration-guide.md` generation step is part of the skill layer — it requires agent
reasoning and is not mechanically produced by `libs/diff.sh`.

---

## Parallel Sessions

### Collision properties

| Token | Scoped by | Collision possible? |
|---|---|---|
| Session artefact directory | `SESSION_NAME` — branch + timestamp | No — git enforces branch uniqueness across worktrees |
| Checkpoint tags | `WORKTREE_ID` namespace | No — separate namespace per worktree [SUPERSEDED: checkpoint tags removed.] |
| Container names | Session identity via `container_name:` (Change 5) | No — per-session name |
| Container labels | Set at session start; `project-dir` label scopes lookup to correct container | No — label lookup is project-scoped |
| `draft-state` | `SANDBOX_DIR` | No — separate file per worktree |
| `ADVANCED_SESSIONS` | Container-internal; scoped to sandbox | No — separate container per session [SUPERSEDED: `ADVANCED_SESSIONS` removed.] |

### Worktree to main repo

Changes produced in a worktree session land on the worktree branch after `make confirm`.
Merging to the main repo branch is standard git — the operator merges or rebases the
worktree branch into the target. The harness does not orchestrate cross-worktree merges.

### Operator workflow

```bash
git worktree add ../project-feature feature-branch
mkdir ../project-feature-sandbox
agent-sandbox onboard --name=project \
  --project=../project-feature \
  --sandbox=../project-feature-sandbox
make start PROVIDER=<n>
```

Each worktree is an independent harness instance with its own `SANDBOX_DIR`. Sessions
proceed independently. The worktree branch uniqueness constraint is the sole sequencing
requirement.

---

## References

| Document | Purpose |
|---|---|
| [`story_diff_pipeline_unification_and_baseline_advancement.md`](story_diff_pipeline_unification_and_baseline_advancement.md) | Resolved — design recorded here |
| [`story_parallel_sessions_worktree.md`](story_parallel_sessions_worktree.md) | Resolved pending Change 5 implementation |
| [`story_session_identity_and_harness_versioning.md`](story_session_identity_and_harness_versioning.md) | Two-sig model; M2.7 scope |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline; baseline commit construction |
| [`design_diff_and_branch_packaging_workflow.md`](design_diff_and_branch_packaging_workflow.md) | Superseding design — diff packaging and branch review workflow |
