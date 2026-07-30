# Design — Mount Model

**Status:** active

**Direction + Parent:** M2.6.4 — Mount Model Design and Implementation. Canonical record of the mount model framing. When this design settles, an ADR is recorded per `docs/operations/adr_policy.md` and this document is marked settled.

## Context

The harness originally used a copy-only pipeline: `baseline.tar` unpacked into an anonymous Docker volume, agent changes exported through a diff pipeline. Three problems motivated change: work was lost when the container or host crashed (no durable persistence), the copy step added overhead every session, and the diff pipeline was fragile (`git apply` failures on binary files, renames, index-line mismatches).

The durability fix was to bind-mount the sandbox folder. Once mounted, the folder on the host end can be backed differently — a tar clone with a reinitialized baseline, a git worktree linked to the host repository, or the raw project dir — each granting the agent more access and more risk. The operator does not intend to offer the raw project dir or grant push access at the current stage.

Two earlier framings were retired during this exploration:

- **The three-tier model** (Copy+Tar / Mount+Tar / Mount+Worktree) conflated the durability decision (how the working tree reaches the container) with the coupling decision (what that tree is backed by). Its Tier 2 invariant set was Tier 1's plus one path — the same posture with a different delivery mechanism. Retired before implementation.
- **Capability-layer git mediation** (the capability layer manages git operations on behalf of the agent, with `PROJECT_DIR/.git` mounted read-only into the capability layer only) was retired: git operations are executed by the agent in the reasoning layer — directly or via the provider's command prefix (e.g. pi's `!`) — and the capability layer never invokes git. A read-only `.git` mount cannot accept commits in any case.

**Consolidation note.** This document consolidates two earlier ADRs — `20260721-adr-settled-worktree_mount_model` and `20260722-adr-settled-mount_model_axes` — which were labeled settled but revised within days while nothing was implemented against them. Both were removed before the model reached implementation; their content is preserved in git history. The criterion applied: an ADR whose decision was never implemented and is still being revised is a design document, not a settled record.

## Options Considered

### Option A — Copy-only status quo

Keep the anonymous volume + copy-in pipeline as the only model.

- **Disadvantages:** No durable persistence path; copy overhead every session; diff-pipeline fragility unaddressed.

### Option B — Pure inheritance framing

State only that "the sandbox inherits the security posture of the host repo" and drop structural rules.

- **Disadvantages:** Wrong polarity — the mechanism is subtractive (the default share is nothing; every mount is an explicit grant), while inheritance implies the agent receives the host's posture by default. Risks implying the agent is as trustworthy as the repo, when the agent runtime is explicitly untrusted in all configurations.
- **Adopted partially:** as the stated principle, with polarity corrected.

### Option C — Two-axis model (adopted)

Separate the durability decision (delivery) from the coupling decision (backing), and attach security content to each option.

- **Advantages:** One universal invariant set plus per-option exposures. Matches the operator-facing framing. Explains the old ladder without numbering.
- **Disadvantages:** Loses the compact ordering signal of tier numbering; each option states its own exposure and the combination is left to the reader.

### Raw project dir backing — rejected

The agent is never given the operator's own checkout. Documented as a non-goal in `security.md`.

## Decision

1. **Principle.** The sandbox adds no security beyond what the host provides — it only restricts what the host shares. The default share is nothing. Every mount is an explicit grant, and each grant carries its required controls.

2. **Delivery axis (durability).** *Copy* freezes the agent's view at session start; host changes during the session are invisible to the agent. *Mount* gives a live view of host content and carries its own exposure: mid-session host changes (including secrets accidentally placed in the mounted directory) become visible with no review step; the user-error surface increases; and it rests on the mount-containment assumption — that the agent cannot escape the mount boundary to reach the backing filesystem. Container escapes are outside the current threat model, but the assumption's strength erodes over time.

3. **Backing axis (coupling).** *Fresh baseline* is decoupled: a reinitialized repository with no shared history, refs, remotes, or config. *Worktree* is coupled: agent commits land in the host repository's object store on an agent branch; the mechanism is proposed in [20260722-design-active-worktree_mount_mechanism.md](20260722-design-active-worktree_mount_mechanism.md). *Raw project dir* is not offered.

4. **Constraint.** Worktree backing requires mount delivery — a copied worktree severs the gitdir pointer. All other combinations are valid.

5. **Support statuses.** Copy = current default (supported). Mount = not yet implemented. Worktree = not supported; the security assertion is contingent on implementation and audit. Raw project dir = not offered.

6. **Documentation structure.** `security.md` expresses the model as configuration options with per-option exposure; invariants are stated once (universal set) plus per-backing profiles.

## Consequences

### Positive

- One invariant set plus per-option exposures; the "identical to Tier 1" cross-referencing and the tier-language drift class are eliminated.
- Documentation asserts only implemented postures; proposals live in design documents until audited.
- The ADR directory contains no mount-model entry until there is a genuinely settled decision to record.

### Negative

- The tier numbering's compact ordering signal is lost; each option states its own exposure.

### Neutral

- Implementation may still proceed in steps (mounted snapshot before worktree), without security semantics attached to the sequence.

## Open questions

These must be resolved before mount delivery implementation begins.

- WORKTREE_DIR as baked placeholder vs runtime variable
- Separate compose overlay vs conditional mount in the base template
- Pi direct bind mounts (prompts/sessions/skills) under mount modes vs copy-in/copy-out
- `--volumes-from` retained or dropped under mount modes
- Role of `make apply` under mount modes (native git merge vs `staged.diff`)
- Snapshot pipeline under mount modes — skip entirely, or produce what?
- Migration path — conditional flag at session start vs separate Makefile target

## Decision: Worktree backing deferred

Worktree backing (git worktree add/remove, refs/agent/ namespace, gitdir pointer resolution, draft/confirm adaptation for branches, safety audit) is permanently deferred. Recorded in roadmap M2.6.6 under Not in scope. The mechanism design is preserved in [`20260722-design-active-worktree_mount_mechanism.md`](20260722-design-active-worktree_mount_mechanism.md) as a reference. May be revisited if mount delivery proves viable.
- Tier terminology persists in historical documents (handovers, discussions, git history) as a record of the decision process.

### Settlement path

This document settles — and the canonical ADR is recorded — when the framing has been applied across the architecture docs (`security.md` restructure, propagation pass) and proven stable. The worktree mechanism settles separately: after implementation and safety audit, per the exit condition in the mechanism design doc, with its own ADR.
