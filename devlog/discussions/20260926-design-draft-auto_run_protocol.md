# Auto Run Protocol - Design

**Status:** draft. The protocol is in use while it is a draft; see Consequences for the deviations it runs ahead of, and the milestones that formalise them.

## Context

An unattended run has to exist because a subagent is a context device, not a capability. The primary agent holds the plan, the records and the accumulated evidence at once; a fresh subagent holds one unit's source and the checks that unit owes. Dispatch exists to buy context, and nothing else.

The first version of the dispatch template took its work list from the read-through register, which made it a dispatcher for exactly one campaign: the row identifiers, the `action_kind` filter and the row language were that record's, not the method's. The operator replaced that rule with a general one (2026-09-26): the template runs any well-specified roadmap task, one or several, where well specified means that a scope confirmation would raise no open question - the design or spec is clear, the acceptance criteria are clear, and nothing is left to decide.

## Options Considered

1. **A register-driven work list** (the first shape). Rejected: it hard-codes one campaign's data file and vocabulary into a general dispatcher, so no other task can use it.
2. **A fully autonomous run, with the well-specifiedness test as the only gate.** Rejected: a mis-scoped row spends a subagent's compute before the operator has seen the plan, and the operator's release is what makes the test's calibration meaningful.
3. **One release of the multi-iteration plan, then per-unit autonomy** (chosen). The plan carries the unit split, the order, the handover per unit, and the acceptance criteria; after the release the run is unattended.
4. **Land every unit in one commit at the end.** Rejected: the review model reads per-iteration commits, and an interrupted run would leave one unreviewable blob.
5. **Discard a failed unit's work.** Rejected (operator): the partial attempt is filed through the branch packager and the tree is reset, so a later attempt can resume from it or apply it.
6. **Review the run with the existing review pass.** Rejected as the run's default: that loop is capped near six rounds and the pass it generalised from took eight, because enumerable classes - doc-contract drift, vocabulary and count reconciliation - were not swept before each round. Chosen instead: a bounded loop with an explicit verdict, capped at three rounds.

## Decision

The run protocol:

- **One release.** The run plan states, per unit: subject, commit type, owned files, handover, and acceptance criteria. Rows that would raise a question are parked with their questions, and a row that needs a decision is design work rather than run work.
- **A unit is one commit and one handover.** It is a vertical slice of one feature across the files it touches, sized so one subagent context holds its source, tests and evidence, verifiable without another unit landing, and owning files disjoint from every other unit. A feature too large for one context splits into sub-features, still vertical. Work phrased by layer is not a unit.
- **Dispatch blocks.** `timeout <budget> pi -p ... > <log>`, in the foreground. While it runs, the primary is parked and cannot touch the tree, which is what makes the subagent the only writer. No frozen snapshot is needed, because there is no sibling writer; the live tree is both the input and the output.
- **The subagent never commits or stages**, and never edits a record. It returns a report whose tail carries a file list, the acceptance-criteria results, the mutation checks, the suite counts and a stop classification.
- **The primary evaluates the stop, then verifies the tree.** A killed run cannot report, so a timeout is inferred from the dispatch's status rather than read from the report. The primary resumes at most once, from the same unit and the same tree, and lands only verified units.
- **A park files the work before it resets.** The branch packager exports the landed units' patches beside the partial attempt, under a `partial_<unit>_<slug>` summary, and the primary then resets the owned paths. Nothing partial is committed.
- **The run ends with a sweep and a bounded review.** The primary sweeps the enumerable drift classes, runs the review loop to a verdict, and presents the run: units, commits, verdict, parked units, filed bundles, open rows.

## Consequences

**Temporary deviations from policy.** The protocol runs ahead of the documents it borrows its gates from, deliberately, while it is a draft:

- Scope confirmation and acceptance-criteria confirmation collapse into one release. `iteration_policy.md` still describes two gates, and most confirmations were two acknowledgements of one decision.
- A run is several iterations under one release, and a run-level record is not an iteration's handover. No policy document describes that shape.
- The per-iteration pre-close release is replaced by the run review.

**The prompt cannot carry its own record.** A deployed prompt is image-baked into the container, so a link from it into this repository is a dead path at run time. The prompt therefore carries the procedure only, and this document carries the status, the deviations and the rationale. The two can drift, and nothing mechanical catches it: the formalisation milestone is where the prompt folds back into policy and this record closes.

**Enables.** Any well-specified roadmap row can run unattended; several rows can run in dependency order; a failed unit leaves a recoverable artifact rather than a discard; the review of a run is bounded and states a verdict.

**Forecloses.** The protocol cannot resolve a design question - no ADR, no design note, and no "reasonable choice". A row that needs a decision stops at the plan, which is the boundary that keeps a run from laundering an underspecified task into commits.

**Costs.** Each dispatch repeats the briefing cost, so a unit smaller than a fresh context is pure overhead. The primary's verification of every unit is mandatory and serializes the run.

## What would settle this document

- The formalisation milestones: the loop-to-workflow move, the workflow-versus-policy ADR, and the collapse of the minor loop's first two gates.
- The first runs' measurements: unit sizes against the context bound, the park rate, the share of stops that are `needs-decision` (each one is evidence the well-specifiedness test failed), and the rounds to a verdict under the bounded loop.
