# Work-log record seam

**Current:** 2026-11-05

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One declaration | The record roots, the archive rule and the naming rule are stated once as data, not restated in each gate and prompt. |
| R2 | One reader | Every gate and every derived read goes through one accessor over that declaration. |
| R3 | Derived, not stored | The latest, active and current-track values are computed from git and the declaration, never kept as a counter or a scalar. |
| R4 | Identity is not order | A record's `YYYYMMDD-NN` is a unique identity allocated from a per-track reserved block; order is read from git. |
| R5 | Work-log scope | The seam covers the work-log records first: handovers, then discussions and the feedback record. The task list is not in it. |

## 2026-11-05 -- The work-log layout is declared once, and derived reads go through one tool

**Decision:** The work-log record layer is declared once as data and read through one accessor. Handovers live under `devlog/handovers/<milestone>/`; the folder is the track, the `YYYYMMDD-NN` is a unique identity allocated from a block reserved when the track opens, and order is read from git rather than from the filename. The derived reads the workflow prompts repeat -- the latest handover, the active one, the current track, the next reserved id, the list -- are answered by one tool that reads the same accessor. `work-log` keeps the rules a tool cannot decide: what a record says, its sections, its types and its states. The seam's final scope is the work-log; the task list is a separate decision, taken only if this one works. The `archive/` stays frozen: nothing enters, no open roadmap row names a file there, and orientation never reads it. The unit rule stays: one iteration, one commit, one handover.

**Rationale:** Three serializers deny parallel milestone work while the git machinery already supports it: one `active-milestone` scalar, a per-day global handover counter, and a shared roadmap header with no named writer. The counter is the clearest case. It enforces order with `max + 1`, yet order is already carried by the commit and the merge replay that linearizes a track. The counter also carries identity: 1,142 bare references resolve by it, and the numbering gate requires exactly one match. So the fix is to separate the two jobs: identity stays with the record and is allocated per track; order moves to git. The same separation fixes the other two serializers: the folder names the track, and the shared header has one writer, the session doing the merge, a role rather than a folder. The read seam follows because the alternative -- each prompt loading the folder and computing the latest -- is the same rule in eight places, each a place to drift and each a context cost. The repository already solved this shape: `container-interface.json` declares the instruction surfaces once and `container-interface.mjs` is the reader every gate goes through. This entry applies that pattern to the record layer and stops at the work-log, because task-list violations have had no measured consequence while work-log violations produce administrative churn. The evidence is [`20261105-design-concluded-handover_tracks.md`](../../devlog/discussions/20261105-design-concluded-handover_tracks.md).

**Rejected alternatives:**

- *Let each prompt compute its own read.* **Intent failure**: it is the same rule in eight carriers, so it drifts and every prompt pays the context to load the folder.
- *State the read once in `work-log` and let the agent compute.* **Execution failure**: a rule in prose is not a gate, and the agent still loads and computes what the declaration could answer.
- *Give each folder its own id sequence and path-qualify every reference.* **Intent failure**: 1,142 bare references resolve by the id today, so the change would rewrite the corpus to buy a property that a reserved block already gives.
- *Create an `integration/` folder for the header writer.* **Intent failure**: it invents a record kind for a role, which is exactly the paperwork the seam exists to remove.
- *Use the archive as the cutoff.* **Execution failure**: an archive changes the tree and gives no fork point; a tag is the immutable line tracks fork from.
- *Drop the unit rule so git alone carries the record.* **Intent failure**: git would then own a linear order of indistinguishable commits; the unit is what attaches a reason to each commit and keeps the history bisectable.
- *Put the task list in the same seam now.* **Execution failure**: task-list violations have had no measured consequence, so the scope would grow ahead of its evidence.

**Edge cases / drivers:** A track's id block is allocated once, when the track opens, and recorded with the track. Existing ids stay valid, so the migration moves files and re-paths relative links, not the 1,142 bare ids; `numbering.mjs` already walks the tree recursively. The handover format gate must learn to walk track folders before any file moves, or the move leaves a commit where the gate scans nothing. `archive/` is the one exemption and is expected to disappear with the T5 rewrite. A record's `milestone` field matches its folder, which makes the folder the single source of the track. The tool and the declaration are the seam M3.5.3's record model replaces; the five requirements survive the replacement.
