# Documentation Quadrants

**Current:** 2026-11-02

## 2026-11-02 -- Four quadrants name the four corpora

**Decision:** Each text corpus serves one of the four quadrants an outside documentation framework names, and the mapping is stated rather than left to be inferred from examples. Learning is `docs/development/`. A how-to is the instruction surface, not a document. Understanding is `docs/adr/`. Information is `docs/reference/`. The framework is Diataxis, recorded as [`.agents/registry/citations/diataxis.json`](../../.agents/registry/citations/diataxis.json). The mapping is owned where a writer chooses a corpus: `.agents/skills/project-documentation/references/organization.md` states the documentation half beside the folder table, and `.agents/skills/work-log/SKILL.md` states why the records sit outside the four.

**Rationale:** The repository arrived at the same four independently, as a folder taxonomy, an instruction surface and a record set, so the frame names a boundary that was already being enforced at four places without a name. Naming it makes the boundary checkable at a fifth: a text whose quadrant cannot be named is a text whose reader cannot be named, and that is the defect a placement argument keeps rediscovering.

The how-to quadrant is the one the frame changes. A procedure written for a reader who must be present goes stale under an agent workflow, because the reader who needs it invokes a skill and never opens the document; the instruction surface is where that quadrant is occupied, which is why no folder holds runbooks. The `prompt-authoring-conventions.md` that retired on 2026-11-02 was a how-to living in `docs/development/`, and it had drifted from the skills it described, which is the failure the frame predicts.

**Rejected alternatives:**

- *Keep the implicit taxonomy and name no frame.* Insufficient rather than wrong: the four corpora were already distinct in practice and had drifted into each other twice, and without a named frame the next placement argument re-derives the boundary from examples.
- *Rename the folders after the quadrants* (`tutorials/`, `how-to/`, `explanation/`, `reference/`). Rejected on intent: a folder name states where a file sits, and the four quadrant names would drop the distinction the current names carry between a shipped reference and a contributor procedure. The rename would also touch every link in the tree and change no reader's decision.
- *State the frame in the `project-documentation` convention alone.* Rejected on intent: that convention's scope is `docs/`, so a frame stated there alone could not place the `devlog/` records or the instruction surface. Each corpus's owner states its half, and the documentation half sits beside the folder table a writer has just read, in that convention's `references/organization.md`.

**Edge cases / drivers:** Two corpora sit outside the four, and the frame does not force them in. The `devlog/` records are read by a later session continuing the work, which is neither a learner nor a practitioner following a procedure. The principle corpus states judgements applied mid-work and consulted by nobody, so it is neither information nor a how-to.

`docs/reference/iteration_protocol.md` is information rather than a how-to, because it states the invariants the loop's runbooks must not break while the runbooks perform the steps.

`docs/development/` sits in the learning quadrant because its reader is a person building a model of the repository before their first change; the procedure that reader eventually runs is the instruction surface's, not the folder's.

The frame organizes and does not gate: nothing checks a document's quadrant, and `docs/reference/documentation_taxonomy.md` states the view.
