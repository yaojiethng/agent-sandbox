# Story — Agent-Git Surface

> **Superseded by:** [20260721-adr-settled-worktree_mount_model.md](../../../docs/adr/20260721-adr-settled-worktree_mount_model.md)

**Status:** Resolved — superseded by M2.6 design decisions

---

## Context

The harness's expectations of the agent's relationship to git are currently underspecified. Today's working pattern, in practice:

- The agent does not commit on its own initiative. No policy directs it to.
- The operator commits inside the running agent session via the `!`-hook to bash (e.g. `!git commit -am ...`), which executes in the same shell the agent has access to. The agent sees the command history and accounts for it on its next turn but does not feel an urge to commit unless explicitly instructed.
- Autosave (`AUTOSAVE_INTERVAL`, default 60s) sweeps any uncommitted state in `sandbox/` between operator commits.
- The capability layer's diff pipeline produces `staged.diff` (net delta `INIT_SHA..HEAD`) and per-commit `.patch` files at teardown — regardless of whether commits are operator-authored, autosave-authored, or (hypothetically) agent-authored.
- The agent's git world is one commit deep: `baseline.tar` is `git archive HEAD`, which is contents-only; the agent sees `INIT_SHA` and whatever has accumulated above it during this session.
- The agent never writes to the host repo. `make apply` / `make draft` is operator-driven.

This works today because the agent is not asked to perform git operations. The status quo is "agent reads git state and works off it; operator does git operations manually." It is not written down anywhere as a deliberate policy — it is the behaviour that emerges from no policy directing otherwise.

The story exists because the surface will become load-bearing under at least two conditions: (a) any future workflow that wants the agent to author commits with intent (e.g. one-commit-per-logical-change for nicer per-commit `.patch` files), and (b) any operator-side work that gives the operator richer git tooling on `sandbox/` (e.g. an editor with a git pane open on the sandbox), which surfaces gaps in the agent's git world that previously didn't matter.

---

## Pain Points

There is no acute pain today. The pain is anticipated, not present:

- **Per-commit `.patch` files mix authorship.** `staged.diff` is a clean net delta, but the per-commit series in `session-diffs/<branch>/` is a mix of operator `!`-driven commits, autosave sweeps, and (today, none) agent commits. If a future workflow wants per-commit semantic meaning — selectable application, per-feature review, replay — the current series cannot deliver it without the agent participating in commit boundaries.
- **The agent's history horizon is one commit.** It cannot answer questions like "what changed in this file in the last three commits on the host repo," because `baseline.tar` strips history. Today this is fine. If reasoning over history becomes useful, the snapshot pipeline has to change.
- **No reference to other branches.** If the agent is asked to consult another branch (e.g. "look at how this was done on `feature/x`"), it can't — the snapshot is single-branch. Same shape: today this is fine; tomorrow it might not be.
- **Branch hygiene is undefined.** If the agent does start authoring commits, should it tidy them before teardown — squash, reorder, drop noise commits — or hand off raw? Today this question doesn't arise because the agent doesn't commit.

These are gaps in the design space, not bugs. The point of the story is to record that they exist so they can be addressed deliberately when they become load-bearing rather than under pressure.

---

## Constraints

These hold across any future resolution.

1. **Security invariants preserved.** The four invariants in [`security.md`](../architecture/security.md) hold: agents in containers, output via diffs, human approval gate, depth ≤ 2 with no grandchildren. In particular: agent never writes to the host repo. `make apply` / `make draft` remains operator-driven.
2. **Snapshot pipeline integrity.** Whatever git context the agent receives must come through the snapshot pipeline ([`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md#stage-2--capability-layer-side-capability-layer-entrypoint)) — there is no other path. Expanding what the agent sees means changing what the snapshot contains, not opening a new channel.
3. **Diff pipeline contract preserved.** The diff pipeline produces `staged.diff` and per-commit `.patch` files at teardown. Any change to commit authorship has to remain compatible with this output shape (or the change to that shape must be made deliberately as part of the same scope).
4. **`INIT_SHA` is fixed.** `INIT_SHA` is set once at capability layer start and never updated within a session. It is the lower boundary of `package-branch`. Any change to the snapshot contents must not change `INIT_SHA`'s role as a stable session boundary.
5. **Operator authority over commits is preserved.** Whatever the agent is permitted to do with git, the operator's `!`-hook authority and direct access to the sandbox's git state continues to work without coordination.

---

## Open Questions

1. **Should the agent ever commit on its own initiative?** And if so, under what conditions — at logical breakpoints, only when explicitly asked, only when a skill directs it?
2. **Should the agent see git history beyond `INIT_SHA`?** Today `baseline.tar` is `git archive HEAD` (contents only). Granting deeper history requires switching the snapshot mechanism (e.g. `git clone --depth N`, `git bundle`). What depth is useful, and at what cost in snapshot size and snapshot-pipeline complexity?
3. **Should the agent see other branches as reference material?** If yes, which branches — all local branches, named branches, branches matching a pattern? Same snapshot-mechanism question.
4. **If the agent commits, should it perform branch hygiene before teardown?** Rebase, squash, drop noise commits, write semantic commit messages. What are the failure modes when the agent gets this wrong?
5. **How do agent-authored commits interact with `!`-hook commits and autosave sweeps in the same session?** Concretely: in what order, with what authorship metadata, and how does the per-commit `.patch` series look at the end?
6. **Does the existing `staged.diff` + per-commit `.patch` output remain useful under any of the above changes,** or do consumers (e.g. `make apply`, `make draft`) need to evolve in lockstep?

---

## Investigation Findings

None recorded. This story is shelved at creation — see Resolution path below.

---

## Status note — shelved

This story is created in `Investigation in progress` state but is intentionally not actively worked. It is parked until one of the following triggers fires:

- A workflow change requires the agent to author commits with intent (e.g. one-commit-per-logical-change).
- An operator-side surface (editor with git pane on `sandbox/`, richer review tooling) surfaces a concrete gap caused by the agent's one-commit history horizon.
- A new sub-milestone scope makes any of the open questions load-bearing.

When a trigger fires, this story moves into active investigation: open questions get worked, findings accumulate, and a Resolution is reached. Until then, the status quo holds: agent reads git state without being asked to manipulate it; operator does git operations manually via the `!`-hook; autosave sweeps in between.

The story exists so the surface is recorded with framing intact, not so that work is done on it now.

---

## References

| Document | Purpose |
|---|---|
| [`sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline, baseline commit construction, diff pipeline |
| [`execution_model.md`](../architecture/execution_model.md) | Capability layer entrypoint, `INIT_SHA`, autosave, EXIT trap |
| [`security.md`](../architecture/security.md) | Security invariants this scope must preserve |
| [`tool_interface.md`](../architecture/tool_interface.md) | `make apply` / `make draft` contract |
| [`story_policy.md`](../operations/story_policy.md) | Story format, lifecycle, graduation |

## Resolution

**Status:** Resolved — superseded by M2.6 design decisions.

### Summary

The agent-git relationship design questions raised in this story are settled by the M2.6 three-tier mount model:

- **Tier 1 (copy + tar):** Status quo holds — agent does not interact with git. Operator uses `!`-hook for git commands. No change.
- **Tier 2 (mount + tar):** Agent works in a mounted `.snapshot/` but still has no link to `PROJECT_DIR/.git`. No git interaction. No change.
- **Tier 3 (mount + worktree):** Agent commits to a real branch on `PROJECT_DIR`. The commit boundary is managed by the capability layer (staging on behalf of the agent). The operator reviews and merges with native git tooling. Agent-authored commits, autosave sweeps, and operator `!`-hook commits all coexist on the same branch.

### Open questions disposition

| # | Question | Disposition |
|---|---|---|
| 1 | Should the agent ever commit on its own initiative? | In Tier 3, yes — the capability layer stages and commits on behalf of the agent. Under Tiers 1 and 2, no — operator only. |
| 2 | Should the agent see git history beyond `INIT_SHA`? | Tier 3 makes this moot — the agent works on a branch connected to the full object store. For Tiers 1 and 2, the question is deferred (not load-bearing). |
| 3 | Should the agent see other branches? | Deferred — not load-bearing in any tier. Can be addressed if the design session specifies a need. |
| 4 | If the agent commits, should it perform branch hygiene? | The capability layer manages commit boundaries. Agent-authored commits are raw (no squash, reorder, or message rewrite). Branch hygiene is the operator's responsibility during merge review. |
| 5 | How do agent-authored commits interact with `!`-hook commits and autosave sweeps? | All go onto the same agent branch. The per-commit `.patch` series in `session-diffs/` reflects this mixed authorship. No semantic separation is attempted. |
| 6 | Does `staged.diff` + per-commit `.patch` remain useful? | Yes — `staged.diff` becomes `main..agent/session` diff (equivalent to net delta). Per-commit patches remain as a detailed series. Both are preserved for backward compatibility. |

### References

- Security model: [`docs/architecture/security.md`](../architecture/security.md) — Tier 3 invariant replacing mutation gate
- Mount models: Trust Boundaries — Tier 3 worktree specification
