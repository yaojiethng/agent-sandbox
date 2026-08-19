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

**All resolved during the M2.6.6 design walk (2026-08-18** — live record: handover `20260818-02`). Terminology note: per the terminology decision (agent run / agent iteration), harness unit = *agent run*, ops unit = *agent iteration*; "session" reserved.

**Retired with evidence:** Q1 (WORKTREE_DIR — replaced by SANDBOX_ID/RUN_ID, M2.7); Q3 (pre-answered by M2.4 selective bind-mounts in `.pi/agent`); Q5 (downstream of the settled no-git-mediation principle: harness does not mediate git); Q6 (downstream of mount replacing copy-in — copy pipeline shapes per-run staging only).

**Settled (see handover for full rationale):**
- **Q2** — compose file set selectable at generation time per delivery; no YAML conditionals; volumes handled at generation time.
- **Q4** — `--volumes-from` retained; reasoning layer reaches the worktree only via the capability layer's propagated mount; invariant 7 unchanged.
- **Q7 / start redesign** — `make start` becomes the interactive-by-default wizard: agent-run inventory first (copy runs via labels; bind-mount runs via registry), resume-N or new; fresh = freshest container (implicit rebuild downgraded by staleness detection); config prefilled from the newest run's record; prints the full non-interactive command; `--run=<id>` resumes (absence = new); no subcommand split. (Includes: freshness-on-fresh-run clarification = container freshness, implicit rebuild auto-downgraded; the flag name was settled by the terminology decision — `--run`.)
- **N1** — single shared worktree per sandbox at `.worktree/` (default; custom mount point as `make start` arg, injected into compose at generation); copy staging relocated to per-run tmp; `.snapshot` dropped from `SANDBOX_DIR`; resume stages nothing (copy: volume labels; bind-mount: registry); preflight delivery-aware.
- **N2** — per-run RUN_ID (never reused); SANDBOX_ID frozen once per sandbox (derivation kept, `SANDBOX_DIR:HOST_HEAD_SHA` = branch-point tag); resume = config-recall from the resumed registry record; identity lives in the registry (registry fold; completely deprecates `.run-identity`); SESSION_STATE retained as container-side co-located provenance (see N4); mount-source per-run field/label.
- **N3** — flock per mount point (`$SANDBOX_DIR/.locks/<hash(mount-source)>.lock`, held for run lifetime); copy keeps `volume_in_use` — no cross-blocking; parallel runs via distinct mount points; workspace paths verified unique; re-init always acquire-then-mutate.
- **N4** — first run materializes the worktree via the shared snapshot primitive minus baseline.tar (future clone strategies incl. git history — roadmap task); start validation = `.git` + init marker, no clean-HEAD requirement; current branch, no silent switching; mount entrypoint minimal; port-back = existing package_branch/make draft diff machinery (no common ancestor); durable-rule for in-tree artifacts: harness declares non-management (see the in-tree-artifacts decision); SESSION_STATE retained both delivery shapes (container-side co-located provenance; mount writes it into the worktree `.git` — metadata, doubles as init marker).
- **N5** — option (b): containers strictly per-run; persistence exclusively via mounted sources (worktree, workspace dirs, registry, explicitly-designated durable volumes), never container state; environment-change persistence out of scope, deferred item filed.

**Grouped decisions:** prune — rule 2 confirmed; command-shape redesign deferred until after M2.6.5/M2.6.6 artifact shapes settle; `STALE=1` rejected. Terminology — agent run + agent iteration, session reserved; sweep is its own roadmap task. Start redesign — realized by the wizard (see Q7).

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
