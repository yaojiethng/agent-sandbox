# Design — Mount Model (Host-backed Sandbox)

**Status:** active

**Direction + Parent:** M2.6.6 — Mount Model: Host-backed Sandbox. Defines the mount-based delivery model where the agent works on a bind-mounted directory backed by the host filesystem, replacing the anonymous-volume copy pipeline.

## Context

The harness originally used a copy-only pipeline: `baseline.tar` unpacked into an anonymous Docker volume, agent changes exported through a diff pipeline. Three problems motivated change: work was lost on container or host crashes (no durable persistence), the copy step added overhead every session, and the diff pipeline was fragile (`git apply` failures on binary files, renames, index-line mismatches).

The durability fix is to bind-mount the sandbox folder. Once mounted, the folder on the host end can be backed differently — a tar clone with a reinitialized baseline, or a git worktree linked to the host repository — each granting the agent more access and more risk. Raw project dir backing is not offered.

Three earlier framings were retired during this exploration:

- **Three-tier model** (Copy+Tar / Mount+Tar / Mount+Worktree): conflated the durability decision (how the working tree reaches the container) with the coupling decision (what that tree is backed by). Retired before implementation.
- **Capability-layer git mediation**: git operations are executed by the agent in the reasoning layer. The capability layer never invokes git. Retired.
- **Two ADRs** (`20260721-adr-settled-worktree_mount_model`, `20260722-adr-settled-mount_model_axes`): labeled settled but revised within days with nothing implemented against them. Consolidated into this document.

## Two-axis model

Separate the durability decision (delivery) from the coupling decision (backing):

| Axis | Options |
|---|---|
| **Delivery** (durability) | Copy — agent view frozen at session start. Mount — live view of host content. |
| **Backing** (coupling) | Fresh baseline — reinitialized repo, no shared history. Worktree — agent commits land in host object store on `refs/agent/` branch. |

Constraint: worktree backing requires mount delivery — a copied worktree severs the gitdir pointer. All other combinations are valid.

## Decisions

1. **Principle.** The sandbox adds no security beyond what the host provides — it only restricts what the host shares. The default share is nothing. Every mount is an explicit grant, and each grant carries its required controls.

2. **Delivery axis.** *Copy* freezes the agent's view at session start; host changes during the session are invisible. *Mount* gives a live view and carries its own exposure: mid-session host changes (including secrets accidentally placed in the mounted directory) become visible with no review step; the user-error surface increases; it rests on the mount-containment assumption — that the agent cannot escape the mount boundary to reach the backing filesystem. Container escapes are outside the current threat model, but the assumption's strength erodes over time.

3. **Backing axis.** *Fresh baseline* is decoupled: a reinitialized repository with no shared history, refs, remotes, or config. *Worktree* is coupled: agent commits land in the host repository's object store on an agent branch (`refs/agent/<session-id>`). The mechanism involves: mounting `PROJECT_DIR/.git` RW at a fixed container path, rewriting the worktree `.git` pointer, filesystem `chmod` protection of non-agent refs, and `--network=none` on the agent container. *Raw project dir* is not offered.

4. **Support statuses.** Copy + fresh baseline = supported (M2.6.5). Mount + fresh baseline = not yet implemented (M2.6.6). Mount + worktree = not supported; the security assertion is contingent on implementation and a safety audit (permanently deferred, recorded in roadmap M2.6.6 Not in scope).

5. **Documentation.** `security.md` expresses the model as configuration options with per-option exposure; invariants are stated once (universal set) plus per-backing profiles. `docs/architecture/security.md` is the authoritative source for the current security posture. This document is the design record.

## Open questions

Resolved before mount delivery implementation begins:

- WORKTREE_DIR as baked placeholder vs runtime variable
- Separate compose overlay vs conditional mount in the base template
- Pi direct bind mounts (prompts/sessions/skills) under mount modes vs copy-in/copy-out
- `--volumes-from` retained or dropped under mount modes
- Role of `make apply` under mount modes (native git merge vs `staged.diff`)
- Snapshot pipeline under mount modes — skip entirely, or produce what?
- Migration path — conditional flag at session start vs separate Makefile target

## Decision: Worktree backing permanently deferred

Worktree backing (git worktree add/remove, `refs/agent/` namespace, gitdir pointer resolution, `chmod` ref protection, safety audit per `docs/architecture/threat_model_stride.md`) is permanently deferred. Recorded in roadmap M2.6.6 Not in scope. The mechanism design is summarized in the Backing axis decision above; the detailed proposal is archived in git history. May be revisited if mount delivery proves viable and the security model warrants the additional coupling risk.

## Superseded documents

This document supersedes:

- `20260416-study-superseded-git_worktrees.md` — Git worktree feasibility investigation
- `20260417-story-superseded-parallel_sessions_worktree.md` — Parallel sessions story
- `20260611-story-superseded-agent_git_surface.md` — Agent git surface story
- `20260722-design-active-mount_model.md` — Prior mount model design (consolidated here)
- `20260722-design-active-worktree_mount_mechanism.md` — Worktree mechanism design (deferred, summarized above)
- `20260722-study-settled-mount_wiring_survey.md` — Mount wiring gap survey (gaps distilled to open questions)

Documents preserved as future reference:

- `20260622-study-settled-security_delta_worktree_model.md` — Security delta analysis. Retained for potential `security.md` rewrite reflecting the two-route M2.6.5/M2.6.6 structure.

## References

| Document | Purpose |
|---|---|
| [`docs/architecture/security.md`](../architecture/security.md) | Authoritative security posture — Mount modes table, universal invariants, per-backing profiles |
| [`docs/architecture/threat_model_stride.md`](../architecture/threat_model_stride.md) | STRIDE threat model — basis for worktree safety audit |
| [`docs/architecture/execution_model.md`](../architecture/execution_model.md) | Mount shape, compose generation |
| [`devlog/roadmap.md`](../roadmap.md) | M2.6.6 task list and Not in scope |
| [`devlog/discussions/20260622-study-settled-security_delta_worktree_model.md`](20260622-study-settled-security_delta_worktree_model.md) | Security delta analysis (retained for future security.md rewrite) |
| [`devlog/discussions/20260730-design-settled-copy_model.md`](20260730-design-settled-copy_model.md) | Copy model (M2.6.5) — companion design doc |
