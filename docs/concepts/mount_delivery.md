# Mount Delivery (Host-Backed Sandbox)

Mount delivery (M2.6.6) is the second sandbox delivery: the agent works directly on a bind-mounted host directory instead of a copied volume. **Status: wired, not runnable end-to-end** — the delivery-aware entrypoint and worktree materialization are implemented, but runnability verification is outstanding (no-mount/`baseline.tar`-transfer gap, handover `20260828-01`). Companion model: [`copy_delivery.md`](copy_delivery.md). Rationale for the delivery-model axis: [`sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md).

This document is a stub: the settled decisions are summarized here and carried by the historical design record; the delivery is not yet verified runnable, and its detailed model will be written up when it lands.

---

## Model

- A host directory (`.worktree/` under the sandbox, default; custom mount point as a `make start` arg) is bind-mounted into the capability layer. The agent's working content lives on the host filesystem.
- No copy overhead and no diff pipeline requirement — but higher exposure: mid-session host changes are visible to the agent with no review step, and the model rests on the mount-containment assumption (see [`../architecture/security.md`](../architecture/security.md), mount profiles).
- Backing is user-provided: the user places whatever `.git` they choose (fresh baseline, clone, snapshot) in the mounted directory. The harness does not mediate, protect, or audit git operations. Raw project directory backing is not offered. Worktree backing is rejected — [`../adr/sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md).
- First run materializes the worktree via the shared snapshot primitive minus `baseline.tar`, then git-init + baseline commit on the host. Resume stages nothing — the registry record and worktree init marker are authoritative. `SESSION_STATE` is written into the worktree `.git` (doubles as the init marker).
- `.snapshot/` does not exist in this delivery; copy staging is per-run tmp only.

## Settled decisions (summary)

Settled during the M2.6.6 design walks (`20260818-02`, `20260821-02`, `20260828`); full rationale in the historical design record:

- Compose file set selectable per delivery at generation time; no YAML conditionals.
- Single shared worktree per sandbox (N1); per-run `SESSION_ID`, sandbox identity frozen per sandbox (N2); flock per mount point (N3); port-back via the existing diff machinery (N4); containers strictly per-run — persistence exclusively via mounted sources (N5).
- Two-command start/resume split is shared with copy delivery.

## Out of scope

Copy-delivery pipeline work (tar-only serialization, host-side volume seeding) does not apply to this delivery — it has no snapshot staging and no RO mount. The mount delivery's runnability verification is tracked on the roadmap (M2.6.6).

---

## References

| Document | Purpose |
|---|---|
| [`../adr/sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md) | Why copy/mount, worktree backing rejected |
| [`copy_delivery.md`](copy_delivery.md) | Companion delivery model (current default) |
| [`../architecture/security.md`](../architecture/security.md) | Authoritative security posture — mount profiles, invariants |
| [`../architecture/execution_model.md`](../architecture/execution_model.md) | Mount shape, compose generation |
| [`../../devlog/discussions/20260730-design-settled-mount_model.md`](../../devlog/discussions/20260730-design-settled-mount_model.md) | Historical design record — full decision rationale |
| [`../../devlog/discussions/20260730-study-settled-worktree_rejection.md`](../../devlog/discussions/20260730-study-settled-worktree_rejection.md) | Worktree backing: full investigation |
