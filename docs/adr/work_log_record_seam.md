# Work-log record seam

**Current:** 2026-11-23

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One declaration | The record roots, the archive rule and the naming rule are stated once as data, not restated in each gate and prompt. |
| R2 | One reader | Every gate and every derived read goes through one accessor over that declaration. |
| R3 | Derived, not stored | The latest, active and current-track values are computed from git and the declaration, never kept as a counter or a scalar. |
| R4 | Identity is not order | A record's `YYYYMMDD-NN` is a unique identity allocated from a per-track reserved block; order is read from git. |
| R5 | Work-log scope | The seam covers the work-log records first: handovers, then discussions and the feedback record. The task list is not in it. |
| R6 | Residue, not a transcript copy | The record carries only what continuity cannot re-derive; recovery reads the session transcript. |

## 2026-11-23 -- The record carries the format work-log declares, and recovery reads the transcript

**Decision:** A new per-iteration record carries only what continuity cannot re-derive, in the format the `work-log` template declares. The working parts it drops are the scope list, the completed-work list and the open-question list: the scope is the roadmap's, the file list is git's, and an open question becomes a roadmap row at the scope gate. The template is the single declaration: the format gate reads its headings, and no prompt restates the set. Recovery stops treating the record as its evidence claim: the `recovery` skill reads the session transcript through a bundled `session_evidence` command that prints the files a named session wrote or edited, the write-shaped commands it ran, and its last summary. The record stays an optional claim when the caller names one. The gate relaxes the requirement rather than switching shapes: it requires the template's headings and forbids none of the parts it stopped requiring, so an old record and a new one both pass and the migration is seamless.

**Rationale:** The record has two jobs, and the audit that produced this entry sized only the second. The read window is bounded: `/gm` reads the latest ten, `/iter` the latest one, `/wrapup` the active one, and no runtime code reads content. The completed-work list (13,209 lines) and the scope list (7,753) are never read back, and the completed-work list is lossy against git. The first job is recovery, and its primary is accessible and durable: the session store is mounted into the sandbox (`container-interface.json` maps `${SANDBOX_DIR}/.pi/agent/sessions` to `~/.pi/agent/sessions`), holds 901 transcripts, and is already named by `recovery/references/evidence.md`. The Active record is therefore a cache over a readable source, and a cache that can drift and is often uncommitted. The part continuity cannot cheaply re-derive is the decision and its reason, the finding that changed the plan, and the acceptance the operator released. Deleting the rest removes the write-only majority without weakening recovery, because recovery now reads the evidence rather than the agent's summary of it.

**Rejected alternatives:**

- *Keep the working set and trim at close (two shapes).* **Execution failure**: the cache stays, it still drifts, and it adds a checkpoint rule that the transcript already makes unnecessary.
- *Remove the parts and repoint recovery without a command.* **Intent failure**: nothing would read the transcript, so recovery would fall back to a hand-read of a 986 MB store.
- *Keep the transcript command in the project's `scripts/`.* **Execution failure**: the `recovery` skill ships in the `coding-agent` module, and a project script does not travel with it; the command is bundled under the skill's `scripts/pi/` instead.
- *File this as a new ADR.* **Intent failure**: the seam already owns the work-log record's shape and read surface; a second file would govern one principle from two places.
- *Declare the format in the build layout.* **Intent failure**: the layout owns the roots and identities, and the convention owns what a record says; a second declaration in the build tree would split the owner.
- *Keep the record as it is and only correct `/gm`.* **Intent failure**: the census stands; the consumer's read contract is the smaller half of the defect.

**Edge cases / drivers:** A worker's transcript sits in the same store and is addressed by the task-queue path. A record that still carries the older parts passes; the gate sets a floor, not a shape. The acceptance part stays because the operator reads it once, at the release gate. Deleting a handover track makes the changelog the durable seat, which the track-deletion row owns, not this entry.

## 2026-11-05 -- The work-log layout is declared once, and derived reads go through one tool

**Decision:** The work-log record layer is declared once as data and read through one accessor. Handovers live under `devlog/handovers/<milestone>/`; the folder is the track, the `YYYYMMDD-NN` is a unique identity allocated from a block reserved when the track opens, and order is read from git rather than from the filename. The derived reads the workflow prompts repeat -- the latest handover, the active one, the current track, the next reserved id, the list -- are answered by one tool that reads the same accessor. `work-log` keeps the rules a tool cannot decide: what a record says, its sections, its types and its states. The seam's final scope is the work-log; the task list is a separate decision, taken only if this one works. The `archive/` stays frozen: nothing enters, no open roadmap row names a file there, and orientation never reads it. The unit rule stays: one iteration, one commit, one handover.

**Rationale:** Three serializers deny parallel milestone work while the git machinery already supports it: one `active-milestone` scalar, a per-day global handover counter, and a shared roadmap header with no named writer. The counter is the clearest case. It enforces order with `max + 1`, yet order is already carried by the commit and the merge replay that linearizes a track. The counter also carries identity: 1,142 bare references resolve by it, and the numbering gate requires exactly one match. So the fix is to separate the two jobs: identity stays with the record and is allocated per track; order moves to git. The same separation fixes the other two serializers: the folder names the track, and the shared header is a convergence point the branch writes and resolves at prepare; the trunk only accepts. The read seam follows because the alternative -- each prompt loading the folder and computing the latest -- is the same rule in eight places, each a place to drift and each a context cost. The repository already solved this shape: `container-interface.json` declares the instruction surfaces once and `container-interface.mjs` is the reader every gate goes through. This entry applies that pattern to the record layer and stops at the work-log, because task-list violations have had no measured consequence while work-log violations produce administrative churn.

**Amendment (2026-11-06):** the `active-milestone` scalar named above was deleted in M3.5.3. The active set is every Milestone Summary row reading `In progress`, so this serializer no longer exists.

**Amendment (2026-11-06):** an earlier version of this rationale named a merge role as the shared header's writer. That is superseded. A branch writes its own handover and roadmap row and resolves their conflicts when it prepares onto the head; the trunk never authors or resolves. The model is [the branching reference](../../workflow/coding-agent/skills/git-discipline/references/branching.md) and [the change pipeline](../reference/change_pipeline.md).

### The read surface

The seam answers these reads. The tool answers the handover rows; the discussion and feedback rows state the data shape, so a later kind is an addition to the declaration and a command, not a redesign. The feedback entry's own shape -- append-only, one entry per topic, a `state` and `scoped` field and a `mitigation` line -- is `work-log`'s to state; the seam answers only the open entries.

| Read | Command | Consumers | Built now |
|---|---|---|---|
| the latest handover on the track | `worklog.sh latest` | `iter`, `plan`, `milestone-start`, `milestone-close` | yes |
| the active handover | `worklog.sh active` | `commit`, `check-in` | yes |
| the current work-log track | `worklog.sh track` | `iter`, `check-in`, `backlog-triage` | yes |
| the next reserved id | `worklog.sh reserve-id --track <id>` | the agent writing a handover | yes |
| the handovers on a track | `worklog.sh list` | the `work-log` handover runbook | yes |
| the open discussion records | `worklog.sh list --kind discussion --state open` | `plan`, `check-in` | no, shape only |
| the open feedback entries | `worklog.sh feedback --state open` | `milestone-start`, `milestone-close`, `check-in` | no, shape only |

Every command reads the same declaration and the same accessor. A new kind adds a row to the declaration and a command; it adds no path literal to a gate and no `tail -1` to a prompt.

**Rejected alternatives:**

- *Let each prompt compute its own read.* **Intent failure**: it is the same rule in eight carriers, so it drifts and every prompt pays the context to load the folder.
- *State the read once in `work-log` and let the agent compute.* **Execution failure**: a rule in prose is not a gate, and the agent still loads and computes what the declaration could answer.
- *Give each folder its own id sequence and path-qualify every reference.* **Intent failure**: 1,142 bare references resolve by the id today, so the change would rewrite the corpus to buy a property that a reserved block already gives.
- *Create an `integration/` folder for the header writer.* **Intent failure**: it invents a record kind for a role, which is exactly the paperwork the seam exists to remove.
- *Use the archive as the cutoff.* **Execution failure**: an archive changes the tree and gives no fork point; a tag is the immutable line tracks fork from.
- *Drop the unit rule so git alone carries the record.* **Intent failure**: git would then own a linear order of indistinguishable commits; the unit is what attaches a reason to each commit and keeps the history bisectable.
- *Put the task list in the same seam now.* **Execution failure**: task-list violations have had no measured consequence, so the scope would grow ahead of its evidence.

**Edge cases / drivers:** A track's id block is allocated once, when the track opens, and recorded with the track. Existing ids stay valid, so the migration moves files and re-paths relative links, not the 1,142 bare ids; `numbering.mjs` already walks the tree recursively. The handover format gate must learn to walk track folders before any file moves, or the move leaves a commit where the gate scans nothing. `archive/` is the one exemption and is expected to disappear with the T5 rewrite. A record's `milestone` field matches its folder, which makes the folder the single source of the track. The tool and the declaration are the seam M3.5.3's record model replaces; the five requirements survive the replacement.
