# Container-Host Correspondence Mechanism

**Current:** 2026-09-01

*Decision settled with the apply/draft workflow design (M2.3 era, [`design_apply_draft_workflow.md`](../../devlog/discussions/design_apply_draft_workflow.md)); recorded here 2026-09-01 — the original settlement date is unrecoverable from the squashed git history.*

## 2026-09-01 -- The diff file is the correspondence mechanism; git never crosses the boundary

**Decision:** The sandbox repository and the host repository are never the same git repository — divergent histories, different baselines, no shared object store. Git is a tool used independently inside each repo; it is not the correspondence mechanism between them. Correspondence flows through the git-agnostic unified diff file, which applies cleanly when the target files are in the expected state. The harness depends on no shared git history, commit SHAs, or object stores across the boundary. Identity factors (`HOST_HEAD_SHA`, `init_sha`) carry just enough state to scope and baseline the diff — not to link the repositories. Host-side workflow commands (`apply`/`draft`/`confirm`/`reject`) consume the diff artefacts; their design rationale is in [diff_packaging.md](diff_packaging.md).

**Rationale:** Diff-file correspondence keeps the boundary tool-agnostic — any tool that produces or consumes unified diffs participates in the model — and keeps all host modification behind explicit operator review: the host repo is never modified by the container directly, and no unreviewed change becomes a commit. It also avoids the security and complexity cost of git mediation across the boundary, whose rejection as a delivery model is recorded in [sandbox_delivery_model.md](sandbox_delivery_model.md) — the same principle applied to git plumbing rather than worktree wiring. Model:
[sandbox_host_correspondence_model.md](../concepts/sandbox_host_correspondence_model.md).

**Rejected alternatives:**
- *Git-mediated correspondence* (shared object store, worktree wiring,
  container commits landing in the host repository) — makes correspondence depend on repository topology, requires the harness to mediate git with its attendant security cost, and violates the host-never-modified-by- container invariant. Rejected with the delivery model.
- *Stateful apply tracking* (harness records which diffs were applied) —
  rejected: the operator selects what to apply via explicit arguments; defaults cover the common case, and the harness stays stateless about application.

**Edge cases / drivers:** The diff applies cleanly only when target files are in the expected state — baselining via `init_sha` (SESSION_STATE) and `.export-status` metadata exists to make that expectation explicit and diagnosable. Parallel sessions must produce non-colliding artefact directories (branch name as folder differentiator). One draft active per repo at a time, guarded by `draft-state`.
