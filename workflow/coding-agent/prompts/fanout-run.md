# Read-Through Fan-Out - Run (Main-Agent Template)

**Status:** draft

**Scope:** how to divide one read-through pass across parallel subagents: when to fan out, the frozen snapshot, file ownership, suite serialization, the findings block, the scripted integrity check, and the failure modes the fan-out must avoid.

## Purpose

This brief expands the `## Fan-out protocol` section of [`read-through-run.md`](read-through-run.md). Run that pass; use this brief when the pass is too large for one context. The resource a fan-out conserves is the primary agent's context. A single agent running the pass must hold the register, the source of every unit, and the accumulated mutation evidence at once; past a certain size the register is truncated or an earlier row is lost, and the pass degrades into a partial read. A fan-out moves each file group's source and mutation evidence into a fresh subagent context and leaves the register, the numbering, and the verdicts in the primary.

The primary still owns: the scope and the file partition; the frozen snapshot; the register and its row numbering; the mapping from provisional keys to row numbers; the cross-batch dedup; claim verification against the tree; the scripted integrity check; the presentation; and the close. A subagent owns one file group's read, its mutations, its BDD blocks, and its deliverable. The split is by artifact, not by convenience: a subagent must not number rows, because only the primary sees the whole register.

## When to fan out

Fan out when the pass covers many independent units and a single agent's context cannot hold the register plus the source. Independent means a unit's evidence does not depend on another unit's mutation. Two files that must be mutated together, or a library and its orchestrator whose seam is the finding, are one unit and cannot be split across subagents.

Use a batch for the dispatch, not a single subagent. A batch is the set of file groups read, mutated, and delivered in parallel before the next dispatch. Do not fan out a single-iteration diff; that is the review pass's job. Do not fan out a pass small enough for one context either: the batch's setup, collection, and integrity cost is real, and it buys nothing when the register already fits in one context.

## The frozen snapshot

Cut one archive of the tree per batch and hand every subagent in the batch the same frozen tree. This project's subagents share one container and one working tree, so the snapshot is what makes isolation real: a subagent's edits live in its own extraction and cannot be seen by a sibling, and the whole batch reads one byte-identical state, so the batch is reproducible and a later re-run starts from the same tree.

```bash
git archive --format=tar HEAD -o "$SNAPSHOT_DIR/tree.tar"
```

A private copy of the live tree is not a snapshot. The live tree can be mid-edit while the copy is made, so a subagent can inherit another subagent's uncommitted change and then reset it by accident. A `git archive` of the committed state removes that race. The subagent brief states the archive command and forbids any edit outside the subagent's own extraction.

## File ownership

Each brief names the exact files its subagent owns and forbids every other tree edit. Build the partition before dispatch and check it for collisions: two units must never own one file. Two mutation streams over one file cannot be ordered, and each stream restores from its own backup, so one restore overwrites the other stream's mutation or the other stream's repair. A file assigned to two subagents is a dispatch error to fix before dispatch, not a runtime race to detect afterward.

## Serialize the test suite

The liveness gate and the per-file deadline are load-sensitive: a gate that is deterministic on an idle host aborts under concurrent suites, and a per-file deadline counts wall time, so load turns a passing file into a timeout. Only one subagent may run the suite at a time. State the rule as a scheduler rule in the briefs -- a mutex, a lock file, or a staggered start with a stated interval -- not as a footnote in a method section. Mutation work parallelizes; the suite does not. A verdict measured while another suite runs is not a verdict, and every bite baseline measured under that load is qualified.

## The subagent brief

Pre-assign the vocabulary and the output format in the preamble, once, before dispatch. The preamble is shared; the ownership assignment is per subagent. Fix the bite identifier form, the verdict words (proven, survived, read-assessed, probe-verified), the sectors, the dispositions, and the register's column shape in the preamble, and do not renegotiate them during collection.

Negotiating the format per subagent is what the primary spends its time on instead of verification. A format agreed late also makes the deliverables incomparable, so the primary loses the script that would have mapped them.

## The findings block

Each subagent emits a machine-readable findings block beside its prose: one JSON Lines object per finding, in the register's schema (`id` or provisional key, `title`, `sector`, `class`, `action`, `action_kind`, `files`, `status`, `refs`). The `id` holds a provisional key of the subject file plus a one-line title, never an invented number. The schema table and its query commands live in the register-format design note; [`read-through-run.md`](read-through-run.md) is the companion brief.

Beside the block, the subagent supplies its own `## Verification` section: the commands run, the baseline suite count, the number of mutations, and one line confirming every mutated file was restored byte-identical. The primary maps the provisional keys to row numbers in one pass with a script and appends the rows with a script. Never append a row by an `edit` anchor copied from a previous round: an anchor that matches the wrong row duplicates it.

## The integrity check

After every batch, check the data file in one scripted pass: every `id` appears exactly once, the ids ascend, and every provisional key from the batch is mapped to a number. Check separately that every expected test file carries a BDD block, and that the number of files carrying a block equals the number the report states, because that one is a stated count and stated counts drift.

Running the check only at the close is what let the register accumulate defects: a duplicated row reached the operator's read, the table tail sat out of order while the row set stayed contiguous, and a fragmented table hid the unescaped pipes and code-span defects from the lint gate. The data file removes the last of those by construction, because it has no table to fragment and no prose to interleave. Run the check after the batch, while the batch's author can still fix its rows.

## Overlapping the batches

Presentation is serial because the operator reads one file group at a time. Start the next batch's compute when the current batch's deliverables land, not when the presentation finishes. The two phases use different resources, and gating dispatch on presentation throws the parallelism away. Run the integrity check alongside presentation and dispatch the next batch behind the check, so collection never idles on a human read.

## Observed failure modes

Each mode below has occurred in a fan-out. Treat each as an explicit warning, and carry its rule into the subagent briefs.

(a) **One defect, two row numbers.** Two subagents recorded the same defect, and each searched only its own file rather than the accumulated register, so one defect proposed two rows. The rule: search the register for the finding itself, not for its class, and when a row already records it, extend that row with the new evidence instead of proposing a new row.

(b) **A mutation that cannot change behaviour counted as a bite.** A no-op mutant (for example `&& false` inside `[[ ... ]]`, where the second operand is a non-empty string) changed nothing, the suite stayed green, and the green run read as a surviving mutation. The rule: compare the mutant against its backup before the suite runs; a mutant that does not differ is not a mutation.

(c) **A non-assertion abort counted as a proven bite.** A suite that aborted for a reason unrelated to the mutation -- a flaky liveness gate -- was read as the mutation turning a named unit red. The rule: a proven verdict requires a named failing unit file and a re-run that excludes the gate; a non-zero exit alone is not proof.

(d) **An incomplete BDD write-back.** The number of test files carrying a BDD block did not match the number the report stated, and test files that should have carried a block carried none. The rule: the integrity check counts the blocks against the subject list, and every count in the report and the register is generated from that check.

(e) **A fragmented register table.** Blank lines and prose inside the findings table split it into fragments, so it was no longer one table. The same fragmentation hid unescaped pipes and code-span padding from the lint gate and made every scripted selection over the table unreliable. The rule: keep the table contiguous, with no blank line and no prose inside it, and treat a lint-clean table as a table the gate actually parsed.

(f) **A leaked spin-loop process.** A test file leaked spin-loop processes; the runner's per-file deadline killed the test file but not its descendants, which were reparented and kept burning CPU. The load inflated the host and distorted the timing of every suite that ran beside it. The rule: a deadline kill must reap the descendant tree, and a batch checks for leaked processes after a suite before reading any timing.

## What would settle this brief

This brief stays a draft until the next fan-out records these. Each item closes one inference the draft currently makes.

- The wall-clock and token cost per batch, so the fan-out's cost model stops being an inference from file modification times.
- Whether the scripted integrity check caught a defect a human check would have missed, and which defect.
- Whether the frozen snapshot and the file partition held: no cross-owned edit, no restore collision, no subagent reading a sibling's extraction.
- Whether serializing the suite removed the liveness flake and the deadline timeouts, or only reduced them.
- The primary's own turn count during collection, to test the premise that the primary's context is what the fan-out conserves.

## Invariants

- The live shared tree is neither an input nor an output of a subagent; the frozen snapshot is both.
- One file has one owner among concurrent subagents.
- One suite runs at a time.
- A subagent never invents a row number; the primary assigns numbers from provisional keys.
- The integrity check runs after every batch, not at the close.
- The register is the source of truth; the prose is generated from it.
- The chat presentation is a digest. Records state, not session history.
