# Design — Mount Model (Host-backed Sandbox)

**Status:** active

**Direction + Parent:** M2.6.6 — Mount Model: Host-backed Sandbox. Defines the mount-based delivery model where the agent works on a bind-mounted directory backed by the host filesystem, replacing the anonymous-volume copy pipeline.

## Context

The harness originally used a copy-only pipeline: `baseline.tar` unpacked into an anonymous Docker volume, agent changes exported through a diff pipeline. Three problems motivated change: work was lost on container or host crashes (no durable persistence), the copy step added overhead every session, and the diff pipeline was fragile (`git apply` failures on binary files, renames, index-line mismatches).

The durability fix is to bind-mount the sandbox folder. Once mounted, the folder on the host end can contain any `.git` repository the user chooses — a fresh baseline, a clone, or a snapshot — each granting the agent different levels of git access. The harness does not mediate git operations; the user owns the risk of what `.git` they provide. Raw project dir backing is not offered.

Worktree backing (agent commits landing in the host object store via `git worktree add`) is rejected — see [ADR](../../docs/adr/20260730-adr-settled-worktree_rejection.md) and [full analysis](20260730-study-settled-worktree_rejection.md).

Three earlier framings were retired during this exploration:

- **Three-tier model** (Copy+Tar / Mount+Tar / Mount+Worktree): conflated the durability decision (how the working tree reaches the container) with the coupling decision (what that tree is backed by). Retired before implementation.
- **Capability-layer git mediation**: git operations are executed by the agent in the reasoning layer. The capability layer never invokes git. Retired.
- **Two ADRs** (`20260721-adr-settled-worktree_mount_model`, `20260722-adr-settled-mount_model_axes`): labeled settled but revised within days with nothing implemented against them. Consolidated into this document.

## Two-axis model

Separate the durability decision (delivery) from the coupling decision (backing):

| Axis | Options |
|---|---|
| **Delivery** (durability) | Copy — agent view frozen at session start. Mount — live view of host content. |
| **Backing** (coupling) | User-provided `.git` — whatever repo the user places in the mounted directory. Fresh baseline, clone, snapshot — harness does not mediate. |

Constraint: none. Copy and mount are independent of backing — the user controls what `.git` the sandbox contains.

## Decisions

1. **Principle.** The sandbox adds no security beyond what the host provides — it only restricts what the host shares. The default share is nothing. Every mount is an explicit grant, and each grant carries its required controls.

2. **Delivery axis.** *Copy* freezes the agent's view at session start; host changes during the session are invisible. *Mount* gives a live view and carries its own exposure: mid-session host changes (including secrets accidentally placed in the mounted directory) become visible with no review step; the user-error surface increases; it rests on the mount-containment assumption — that the agent cannot escape the mount boundary to reach the backing filesystem. Container escapes are outside the current threat model, but the assumption's strength erodes over time.

3. **Backing axis.** The harness provides no opinion on what `.git` repository backs the sandbox. The user places a `.git` directory (fresh baseline, clone, snapshot, or any valid git repo) in the mounted directory. The harness does not mediate, protect, or audit git operations. Git is the agent's tool and the user's responsibility. *Raw project dir* (the operator's own checkout) is not offered.

4. **Support statuses.** Copy + fresh baseline = supported (M2.6.5). Mount + user-provided `.git` = not yet implemented (M2.6.6).

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

## Worktree backing: rejected

Worktree backing is rejected. See [ADR — Worktree Backing Rejected](../../docs/adr/20260730-adr-settled-worktree_rejection.md) and the [full investigation](20260730-study-settled-worktree_rejection.md).

## Superseded documents

This document supersedes:

- `20260722-design-active-mount_model.md` — Prior mount model design (consolidated here)
- `20260722-study-settled-mount_wiring_survey.md` — Mount wiring gap survey (gaps distilled to open questions)
- `20260622-study-settled-security_delta_worktree_model.md` — Security delta analysis (consolidated into [worktree rejection study](20260730-study-settled-worktree_rejection.md))

## References

| Document | Purpose |
|---|---|
| [`docs/architecture/security.md`](../architecture/security.md) | Authoritative security posture — Mount modes table, universal invariants, per-backing profiles |
| [`docs/architecture/threat_model_stride.md`](../architecture/threat_model_stride.md) | STRIDE threat model — basis for worktree safety audit |
| [`docs/architecture/execution_model.md`](../architecture/execution_model.md) | Mount shape, compose generation |
| [`devlog/roadmap.md`](../roadmap.md) | M2.6.6 task list and Not in scope |
| [`devlog/discussions/20260730-study-settled-worktree_rejection.md`](20260730-study-settled-worktree_rejection.md) | Worktree backing: full investigation, security analysis, rejection rationale |
| [`docs/adr/20260730-adr-settled-worktree_rejection.md`](../adr/20260730-adr-settled-worktree_rejection.md) | ADR: worktree backing rejected |
