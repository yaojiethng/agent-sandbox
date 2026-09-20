# Container-Host Correspondence Mechanism

**Current:** 2026-09-19

## 2026-09-19 -- The full-history / flatten delivery axis does not reopen git-mediated correspondence (verification record)

**Decision:** The delivery-history axis (full history by default, `--flatten` opt-out; landed 20260912-14) does not change the correspondence mechanism. Port-back remains the diff-file pipeline for both deliveries and both history modes. The "git-based port-back" reading of the full-history mount worktree is retired: nothing implements it, and the mechanism does not need it. Verified 20260919-01: export artefacts (`patches/`, `uncommitted.diff`, `all-changes.diff`, `changed-files/`) are byte-identical across full and flatten for identical agent work; both round-trip identically into a host checkout via the stripped-diff apply; the host-side apply commands carry zero delivery or flatten awareness; the harness contains no git transport across the boundary (no push/pull/fetch/merge/remote/clone in `src/` or `scripts/`, and no `PROJECT_DIR` reference in container code).

**Rationale:** The diff pipeline's baseline (`init_sha`) is resolved inside the sandbox repository, so the pipeline is indifferent to how the tree was delivered and to how much history it carries. The full-history worktree is host-side property; ordinary host-side git against it is an operator convenience, not a correspondence mechanism. This entry confirms the 2026-09-01 decision below; it does not supersede it.

**Rejected alternatives:** None new. The 2026-09-01 rejection of git-mediated correspondence stands, now with delivery-axis evidence: a flattened delivery has no shared ancestry with the host checkout (state-based patches cover it), and a full-history delivery shares ancestry only up to materialization (treating that as a port-back channel would reintroduce the rejected topology dependence).

**Edge cases / drivers:** The roadmap's "git-based port-back becomes possible" framing (mount-worktree row) is retired by this verification; the row now records the mechanism as landed. Concept docs (`mount_delivery.md`, `sandbox_host_interface.md`) already stated port-back via the diff machinery and needed no change.

*Decision settled with the apply/draft workflow design (M2.3 era, [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md)); originally recorded 2026-09-01, extended by the 2026-09-19 verification entry.*

## 2026-09-01 -- The diff file is the correspondence mechanism; git never crosses the boundary

**Decision:** The sandbox repository and the host repository are never the same git repository -- divergent histories, different baselines, no shared object store. Git is a tool used independently inside each repo; it is not the correspondence mechanism between them. Correspondence flows through the git-agnostic unified diff file, which applies cleanly when the target files are in the expected state. The harness depends on no shared git history, commit SHAs, or object stores across the boundary. Identity factors (`HOST_HEAD_SHA`, `init_sha`) carry just enough state to scope and baseline the diff -- not to link the repositories. Host-side workflow commands (`apply`/`draft`/`confirm`/`reject`) consume the diff artefacts; their design rationale is in [diff_packaging.md](diff_packaging.md).

**Rationale:** Diff-file correspondence keeps the boundary tool-agnostic -- any tool that produces or consumes unified diffs participates in the model -- and keeps all host modification behind explicit operator review: the host repo is never modified by the container directly, and no unreviewed change becomes a commit. It also avoids the security and complexity cost of git mediation across the boundary, whose rejection as a delivery model is recorded in [sandbox_delivery_model.md](sandbox_delivery_model.md) -- the same principle applied to git plumbing rather than worktree wiring. Model:
[sandbox_host_interface.md](../concepts/sandbox_host_interface.md).

**Rejected alternatives:**

- *Git-mediated correspondence* (shared object store, worktree wiring,
  container commits landing in the host repository) -- makes correspondence depend on repository topology, requires the harness to mediate git with its attendant security cost, and violates the host-never-modified-by- container invariant. Rejected with the delivery model.
- *Stateful apply tracking* (harness records which diffs were applied) --
  rejected: the operator selects what to apply via explicit arguments; defaults cover the common case, and the harness stays stateless about application.

**Edge cases / drivers:** The diff applies cleanly only when target files are in the expected state -- baselining via `init_sha` (SESSION_STATE) and `.export-status` metadata exists to make that expectation explicit and diagnosable. Parallel sessions must produce non-colliding artefact directories (branch name as folder differentiator). One draft active per repo at a time, guarded by `draft-state`.
