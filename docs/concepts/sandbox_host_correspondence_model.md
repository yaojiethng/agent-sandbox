# Sandbox and Host Correspondence Model

The sandbox and host repository are never the same git repository — they have divergent
histories, different baselines, and no shared object store. Yet they must stay in
correspondence: the sandbox must know what the host looks like, the host must be able to
receive what the sandbox produced, and across multiple sessions these two states must
remain coherent.

This document describes the model that keeps them in correspondence — how correspondence
is established at session start, how it is transferred at session end, how the sandbox
catches up when the host advances, and how this repeats across the full project lifecycle.

Implementation detail and command shapes: [`apply_workflow.md`](../architecture/apply_workflow.md).  
Reasoning record: [`design_apply_workflow_and_baseline_advancement.md`](../discussions/design_apply_workflow_and_baseline_advancement.md).

---

## Primitives

| Primitive | Definition |
|---|---|
| **Baseline commit** | Synthetic first commit in sandbox, representing exactly `HEAD` of host at session start. Produced via `git archive HEAD` → unpack → commit |
| **`BASELINE_SHA`** | SHA of the baseline commit, written to `sandbox/.git/BASELINE_SHA` at init. All diffs computed against this |
| **`staged.diff`** | Flat aggregate diff since `BASELINE_SHA`. Human-readable overview artefact |
| **`patches/`** | Per-commit `.patch` files from sandbox history via `git format-patch BASELINE_SHA..HEAD`. One file per agent commit. Machine-apply artefact |
| **Checkpoint tag** | `agent-checkpoint/<worktree-id>/<timestamp>` — lightweight tag in the host repo marking host state before session start. Recovery point and draft branch base |
| **Draft branch** | `draft/<branch>-<session-ts>` — temporary branch in the host repo. Preserves original branch-name slashes; disambiguates sessions with session timestamp |
| **`draft-state`** | File at `SANDBOX_DIR/.workspace/draft-state`. Records active draft: source branch, working branch, session directory. One per `SANDBOX_DIR` |
| **`WORKTREE_ID`** | Short hash of `PROJECT_DIR` absolute path. Namespaces checkpoint tags and container names per worktree instance |
| **`ADVANCED_SESSIONS`** | File at `sandbox/.git/ADVANCED_SESSIONS` inside the container. Append-only log of session names whose patches have been applied to the sandbox via baseline advancement |
| **Session artefact directory** | `SANDBOX_DIR/.workspace/session-diffs/<session-name>/` — holds `staged.diff`, `patches/`, and `autosave.diff` for one session |
| **Container labels** | Docker labels set on the capability layer container at session start. Ground truth for session identity. Labels: `agent-sandbox.project-dir`, `agent-sandbox.session-name`, `agent-sandbox.checkpoint-tag` |

---

## Invariants

- The host repo is never modified by the container directly. All changes flow out as patches or diffs and are applied by the operator.
- The sandbox and host repo have divergent git histories. The shared language between them is the patch set — patches produced from sandbox history apply cleanly to host state at the checkpoint because both represent the same content lineage from the same baseline.
- One draft is active per repo at a time. `draft-state` records which session is staged; `make draft` guards against starting a second draft while one is in progress.
- Patches apply cleanly when sandbox and host are in unison at the baseline. A patch that does not apply cleanly signals content divergence — the conflict is resolved on the pre-patch state, not mid-apply.
- Baseline advancement requires a clean sandbox working tree. Uncommitted agent work must be committed before advancement is triggered.
- Session artefact directories are non-colliding across concurrent worktree sessions. `SESSION_NAME` encodes branch and timestamp; git worktree enforces branch uniqueness.

---

## The Correspondence Cycle

Correspondence is not a static property — it is re-established at the start of each
session and maintained through a repeating cycle. One full turn of the cycle covers:
session start, agent work, session exit, host application, and sandbox advancement.

```
[Host]                               [Sandbox]
HEAD = A                             (not yet started)
  │                                    │
  ├─ snapshot ─────────────────────────►│
  ├─ checkpoint tag written             ├─ baseline commit; BASELINE_SHA = A
  │                                    │
  │  (host untouched)                  ├─ agent works
  │                                    ├─ commits accumulate
  │                                    ▼
  │                                  HEAD = A+n
  │                                    │
  │◄── patches (BASELINE_SHA..HEAD) ───┤  (session exit)
  │                                    │
  ├─ make draft → draft branch         │
  ├─ make confirm                      │
  ▼                                    │
HEAD = B                               │
  │                                    │
  ├─ make sync / SYNC=1 ───────────────►│
  │                                    ├─ git am patches
  │                                    ├─ BASELINE_SHA = B
  │                                    ▼
  │                                  ADVANCED_SESSIONS += session
  │                                    │
  └─ (cycle repeats) ──────────────────┘
```

**1. Session start — establishing correspondence**

Before the container starts, the harness snapshots the host via `git archive HEAD` and
unpacks it into the sandbox. A baseline commit is created from this snapshot and its SHA
written to `BASELINE_SHA`. A checkpoint tag is written to the host repo marking this exact
host state.

At this point the sandbox and host are in correspondence: the sandbox baseline commit
represents exactly what the host looked like at session start. All subsequent diffs are
computed against this shared reference point.

**2. Agent work — correspondence held in reserve**

The agent works exclusively in the sandbox. The host is untouched. The sandbox accumulates
commits; the host does not. Correspondence is not maintained continuously during this phase
— it is held in reserve at `BASELINE_SHA`, which remains the stable reference point
throughout the session regardless of how much the sandbox diverges.

**3. Session exit — transferring correspondence to the host**

On container exit, the diff pipeline runs: `git format-patch BASELINE_SHA..HEAD` produces
one patch file per agent commit, written to the session artefact directory alongside a flat
`staged.diff`. These patch files are the correspondence transfer — they encode exactly what
the sandbox did relative to the shared baseline, in a form the host can apply.

The host has not changed since session start. The patches apply cleanly because both sides
still share the same baseline content, even though their git histories have diverged.

**4. Host application — correspondence lands on the host**

The operator runs `make draft`, which creates a draft branch from the checkpoint tag and
applies the patches via `git am`. Each sandbox commit becomes a real host commit. After
review, `make confirm` merges the draft to the target branch. The host has now advanced;
the sandbox has not.

At this point correspondence is broken: the sandbox `BASELINE_SHA` still points to the
pre-session baseline, but the host has moved forward by one session's worth of commits.

**5. Baseline advancement — restoring correspondence**

Advancement closes the gap opened in step 4. The confirmed patches are applied to the
running sandbox via `git am`, and `BASELINE_SHA` is updated to the new sandbox HEAD. The
sandbox now reflects the same content as the host. Correspondence is restored.

The cycle then repeats: the agent continues working in the sandbox, the next session exit
produces a new patch set against the updated baseline, and so on.

---

## Correspondence Across Container Restarts

The cycle above describes correspondence within a single container lifetime. Container
restarts reset the cycle rather than continuing it.

On restart, the harness snapshots the current host state — including all sessions confirmed
since the last container start — and establishes a new baseline from that snapshot.
Correspondence is re-established from the current host HEAD, not from where the previous
container left off. Any sandbox work that was not transferred to the host before the
restart is lost; any host advances that occurred during the container's lifetime are
automatically incorporated into the new baseline.

This makes restart the natural resolution when the container has been stopped and host
state has moved on: the new container simply starts from the current reality. Restart is
not a failure mode — it is the correct mechanism when session continuity is not required.

**Restart vs advancement:** When the container is still running and the host has advanced,
the operator chooses between advancement and restart:

- **Advancement** preserves the agent's in-progress work and accumulated session context.
  The baseline catches up without interrupting the session.
- **Restart** discards in-progress work but produces a clean, unambiguous baseline from
  the current host snapshot. It is the correct choice when the sandbox has accumulated
  enough drift that advancement would be complex, or when a clean slate is preferable.

Both paths restore correspondence. The choice is about whether continuity within the
current session has value worth preserving.

**`ADVANCED_SESSIONS` across restarts:** The `ADVANCED_SESSIONS` log lives inside the
container and is lost on restart. A fresh container starts with no advancement history.
This is correct: the new baseline is built from the current host snapshot, so there is
nothing to advance — the correspondence is already established from the right starting
point.

---

## Diff Primitives

Two primitives exist because the correspondence problem has two distinct shapes that no
single primitive satisfies.

### `format-patch` — history-preserving

Produces one patch file per agent commit. Applied via `git am` — each sandbox commit
becomes a real host commit, preserving authorship and message. Not idempotent: applying
the same patch twice conflicts.

This primitive is correct when the correspondence transfer should preserve commit
granularity — when the agent's intermediate steps are meaningful and should appear as
distinct commits in host history. The capability layer path uses it for this reason.

### `package-diff` — content-addressed, history-neutral

Produces a single unified diff representing the net change between two states, discarding
intermediate commits. Idempotent: applying the same diff to content that already reflects
it is a no-op.

This primitive is correct when only the endpoint matters — when intermediate steps are
noise, or when the same change may be packaged more than once before it lands. The
reasoning layer path uses it for this reason.

Sequential application of multiple packages requires the sandbox baseline to advance after
each round — otherwise the blob SHAs embedded in the next `changes.diff` will not match
the host index after the first package has been applied:

```
[Sandbox]                            [Host]
BASELINE_SHA = C0                    HEAD = X
  │                                    │
  ├─ make changes                      │
  ▼                                    │
state Y                                │
  ├─ package-diff → changes.diff       │
  │                                    ▼
  │                               make apply (changes.diff)
  │                               git commit
  │                                    │  (tree SHA = Y, commit SHA ≠ sandbox's)
  ├─ git commit                        │
  ▼                                    ▼
sandbox HEAD = Y                  host HEAD = Y
  │                                    │
  ├─ write sandbox HEAD SHA            │
  │  to BASELINE_SHA                   │
  ▼                                    │
BASELINE_SHA = C1                      │
  │                                    │
  └────────────────────────────────────┘
[Both repos now have identical blob SHAs for all files]
[Next package-diff --baseline=$BASELINE_SHA will apply cleanly]
```

### Why two primitives

The capability layer path and the reasoning layer path serve different correspondence
patterns. The capability layer path runs at session exit after the full agent work is
complete — commit granularity is known and fixed, and the patch set is applied once.
`format-patch` is correct here.

The reasoning layer path runs mid-session, on demand, before the agent has finished — the
same changes may be packaged multiple times as the work evolves. `package-diff` is correct
here because idempotency makes repeated application safe.

Using `format-patch` for the reasoning layer path would produce duplicate host commits
each time the agent repackages. Using `package-diff` for the capability layer path would
collapse the agent's commit history into a single diff, losing granularity that matters
for traceability.

---

## Correspondence Across Parallel Sessions

Two sessions against different worktrees maintain independent correspondence with their
respective host worktrees. Every token that could collide across sessions is scoped by a
distinct namespace derived from `WORKTREE_ID` — a short hash of the `PROJECT_DIR` absolute
path, which is unique per worktree instance:

| Token | Scoped by | Collision possible? |
|---|---|---|
| Session artefact directory | `SESSION_NAME` — branch + timestamp | No — git enforces branch uniqueness across worktrees |
| Checkpoint tags | `WORKTREE_ID` namespace | No — separate namespace per worktree |
| Container names | Session identity | No — per-session name |
| Container labels | `project-dir` label scopes lookup | No — label lookup is project-scoped |
| `draft-state` | `SANDBOX_DIR` | No — separate file per worktree |
| `ADVANCED_SESSIONS` | Container-internal; scoped to sandbox | No — separate container per session |

Each worktree session runs its correspondence cycle independently. Merging worktree output
to the main repo branch is standard git — the harness does not orchestrate cross-worktree
merges and the correspondence model does not extend to that boundary.

---

## Model Gaps

The following are cases where the correspondence model breaks down or is undefined. Each
requires a design session to resolve.

**Mixing the two paths within a single session:** The model assumes the reasoning layer
path (`make apply`) and the capability layer path (`make draft`) are used independently
per session. If `make apply` extracts partial changes during a live session and `make
draft` is then run at session exit, the format-patch patches will cover content the host
already has. The correspondence model does not define what the correct state is after this
— whether the host has double-applied content, whether `make draft` should detect and skip
already-applied patches, or whether the operator is expected to prevent this combination.

**Mixed session types against the same repo:** A project using both Claude Chat sessions
(reasoning layer path) and OpenCode sessions (capability layer path) against the same repo
has no defined correspondence across the two path types. `make apply` has no awareness of
`draft-state` or `ADVANCED_SESSIONS`; `make draft` has no awareness of prior `make apply`
applications. The correspondence model currently treats the two paths as independent — but
when both are used against the same repo, they are not independent and the model does not
account for their interaction.

---

## References

| Document | Purpose |
|---|---|
| [`apply_workflow.md`](../architecture/apply_workflow.md) | Implementation detail — command shapes, path mechanics |
| [`design_apply_workflow_and_baseline_advancement.md`](../discussions/design_apply_workflow_and_baseline_advancement.md) | Reasoning record — delivery sequence, design decisions |
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline; baseline commit construction |
