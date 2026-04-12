# Investigation — Unified Versioning and Governance Model

**Status:** Open Discussion
**Date:** 2026-04-12
**Context:** Research into the [Image Staleness Regression](investigation_staleness_and_interactivity_regression.md) revealed a "Documentation Paradox": features marked as "Complete" in the [Changelog](../../devlog/changelog.md) were intentionally deleted or refactored away during later milestones (specifically M2.1) without being updated in the historical record. This has created a "Source of Truth" conflict between the Changelog, the Architecture docs, and the actual Code.

---

## 1. Problem Statement

The current project governance lacks "Temporal Parity." A feature can be marked as complete in a milestone, but its implementation can be removed in a subsequent refactor without any notification to the operator. This leads to:
- **Regressions:** Assuming a safety feature (like Staleness Detection) is active when it has been deleted.
- **Confusion:** Handovers referencing defunct milestones or logic.
- **Onboarding Friction:** New projects being built against old images because the "Harness" version is not tracked.

---

## 2. Components of the Proposed Versioning System

To achieve parity, the following five artifacts must be synchronized:

| Artifact | Role | Proposed Change |
|---|---|---|
| **`VERSION` File** | The Root of Truth | A single file in the repo root (e.g., `0.2.1-M2.3`) representing the Harness state. |
| **`libs/` Signature** | The Runtime Check | A hash of the `libs/` directory, baked into Docker images as a label. |
| **Milestone (Roadmap)** | The Plan | Milestones must explicitly state if they "Deprecate" or "Supersede" previous M-tasks. |
| **Changelog** | The Record | Must include `[SUPERSEDED]` or `[REMOVED]` tags for historical features no longer in the core. |
| **Handovers** | The Context | Must record the `VERSION` at the start and end of each session. |

---

## 3. Considerations for Implementation

### A. The "Harness Signature" vs. Semantic Versioning
The `VERSION` file provides a human-readable anchor (e.g., `v0.2.4`), but the "Harness Signature" (a hash of the core scripts) is what prevents the staleness bug. The system should:
1. Compare the image label `harness.sig` against the current `libs/` hash.
2. If they mismatch, check the `VERSION` file.
3. If the `VERSION` has changed, force a `make refresh` and `make build`.

### B. Milestone Scoping (The "Trigger B" Problem)
Currently, "Trigger B" on the roadmap compacts a milestone and appends to the changelog. This process is too automated. 
- **New Rule:** Trigger B must include an "Audit Step" where the agent checks if the new milestone's changes invalidate any previous changelog entries.

### C. Parity between Sandbox and Project
When a project is onboarded, it "pins" a version of the harness. We need a way for the project-side `Makefile` to detect that the **Harness Repo** is ahead of the **Sandbox Workspace**.

---

## 4. Final Diagnosis & Proposed "Protocol"

The documentation flaw is "trivial" to fix in text, but the underlying "Major Flaw" is the lack of a versioning lock between the host and the container.

**The Proposal:**
1.  **Introduce `VERSION`:** Create a root-level versioning file.
2.  **Add `[SUPERSEDED]` Tags:** Audit the M1.x changelog entries and flag those (like Staleness Detection) that were removed during the M2 refactor.
3.  **Cross-Link Investigations:** Ensure the [Staleness Investigation](investigation_staleness_and_interactivity_regression.md) and this [Versioning Investigation](investigation_versioning_and_governance.md) are linked in the Roadmap under "Known Limitations" or a new "Governance" section.

---

## 5. Next Steps
1.  Apply the urgent "Historical Correction" to `changelog.md`.
2.  Link these investigations to `roadmap.md`.
3.  Close Milestone M2.3 (Current Task) once the documentation is finalized.
4.  Initiate the "Versioning Implementation" as a new sub-milestone (M2.7) or early M3 task.
