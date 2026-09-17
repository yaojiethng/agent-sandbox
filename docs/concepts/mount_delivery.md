# Mount Delivery (Host-Backed Sandbox)

Mount delivery (M2.6.6) is the second sandbox delivery: the agent works directly on a bind-mounted host directory instead of a copied volume. Runnable end-to-end (flatten-style materialization verified live `20260912-10`; full-history materialization host-test-verified with the `--flatten` feature, `20260912-14`). Companion model: [`copy_delivery.md`](copy_delivery.md). Rationale for the delivery-model axis: [`sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md).

---

## Model

- A host directory (`.worktree/` under the sandbox, default; custom mount point as a `make start` arg) is bind-mounted into the capability layer. The agent's working content lives on the host filesystem.
- Higher exposure: mid-session host changes are visible to the agent with no review step, and the model rests on the mount-containment assumption (see [`../architecture/security.md`](../architecture/security.md), mount profiles). Full history by default; `--flatten` delivers a fresh baseline without host history. A full-history copy on a large repo is slow by construction, but that is a caveat, not a rule about what large repos can or cannot do.
- The harness materializes the worktree repository from the project on first run (full: copy `.git`; flatten: sync + git-init baseline) and records the delivery-history mode in the worktree config; the user does not place a `.git` there. The harness does not otherwise mediate, protect, or audit git operations. Raw project directory backing is not offered. Worktree backing is rejected — [`../adr/sandbox_delivery_model.md`](../adr/sandbox_delivery_model.md).
- First run materializes the worktree via the shared snapshot primitive as above, then records the delivery-history mode in the worktree config. `start_agent.sh` refuses a later mode mismatch and refuses a corrupt (non-boolean) recorded mode in the clear. Resume stages nothing — the registry record and worktree init marker are authoritative — and cross-checks the record's flatten flag against the worktree's recorded mode, warning on a mismatch and continuing with the record value. `SESSION_STATE` is written into the worktree `.git` (doubles as the init marker).
- `.snapshot/` does not exist in this delivery; copy staging is per-run tmp only.

## Settled decisions (summary)

Settled during the M2.6.6 design walks (`20260818-02`, `20260821-02`, `20260828`); full rationale in the historical design record:

- Compose file set selectable per delivery at generation time; no YAML conditionals.
- Single shared worktree per sandbox (N1); per-run `SESSION_ID`, sandbox identity frozen per sandbox (N2); flock per mount point (N3); port-back via the existing diff machinery (N4); containers strictly per-run — persistence exclusively via mounted sources (N5).
- Two-command start/resume split is shared with copy delivery.

## Out of scope

Copy-delivery pipeline work (host-side volume seeding) does not apply to this delivery — it has no snapshot staging and no RO mount.

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
