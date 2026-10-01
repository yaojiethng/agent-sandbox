---
description: "Run a documentation session: an iteration whose deliverable is a document rather than runtime behaviour. Defines the acceptance criteria as read- and lint-observable deltas when there is no runtime to run, aligns the rewrite requirements before the rewrite begins, and checks each produced document against the documentation standards. Use when the session creates or rewrites a policy, concept, architecture, prompt, skill, or record document; /iter replaces this prompt for runtime-behaviour work."
argument-hint: "[documentation goal or target document - optional]"
---

> $@

# Document - The Documentation Session

**Scope:** one runbook for an iteration whose deliverable is a document. It owns the three things a documentation session needs and the shared machinery does not supply: acceptance criteria the operator checks by reading or linting the produced document, the alignment step that settles what a rewrite must change before the rewrite begins, and the standards check each produced document takes before the close. The handover, the two gates, the commit discipline, and the close stay with [`/iter`](iter.md) and [`/wrapup`](wrapup.md); this prompt defers to them rather than restating them.

## Purpose

A documentation session has no runtime to run. The acceptance criteria of [`/iter`](iter.md) ask the operator to run the system and observe an output, and a document produces none. This prompt names what replaces that verification, states the order of the steps a documentation session runs, and keeps the standards the produced documents must meet named by link.

A documentation session is still one iteration. It is one roadmap task, one unit, one delivery commit, one handover, closed by [`/wrapup`](wrapup.md) Part B.

## When to run

Run this prompt when the iteration produces or rewrites a document. The argument names the documentation goal or the target document.

- **Not runtime-behaviour work.** Code, shell, or configuration that runs belongs to [`/iter`](iter.md), which replaces this prompt.
- **Not a milestone or sub-milestone record close.** The compaction, the changelog entry, and the record cascade belong to [`/milestone-close`](milestone-close.md), which replaces this prompt.
- **Not a design negotiation held open across sessions.** When the rewrite requirements are still open, plan them first with [`/plan`](plan.md), then run this prompt on the confirmed plan.

## The procedure

The steps run in order. Each ends on a completion criterion.

### Step 1 -- Orient

Find the most recent handover and the active roadmap task, exactly as [`/iter`](iter.md) `## Orient` does. Do not restate those steps here. Read the target document's own policy before anything else, so the session knows which rules govern the work.

Exit condition: the prior handover, the active roadmap task, and the governing policy document for the target are read, and any superseding record for the target is named.

### Step 2 -- Identify the document type

A document an agent consumes is one of three types, and each type is written by a different rule set. Apply the two tests in [`prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) `## Identify the document type`. A prompt or skill is a workflow document when an operator invokes it, or when removing it would leave a rule unstated anywhere. Everything else is a policy document or a reference document.

Name the type in the handover before the scope gate. The type selects the standards the produced document is checked against in Step 6.

Exit condition: the target's type is named in the handover, with the test that classified it.

### Step 3 -- Align the rewrite requirements

A rewrite of an existing document is a negotiation, not a mechanical edit. When the rewrite changes what an existing document means to the sessions that read it, settle the requirements before any prose is written. Use the `grill-me` skill for this interview. The interview resolves each branch of the decision tree: what the document must say after the session, what it must stop saying, and which readers depend on the part that changes.

Record the settled requirements where the work lives, per the record-state rules in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) `## Iteration Invariants`. A meaning change to a settled design is an ADR, per [`adr_policy.md`](../../../docs/operations/adr_policy.md).

Exit condition: every requirement the rewrite must satisfy is written down, each meaning change to an existing document is recorded as a decision with the record that holds it, and no open question about the rewrite remains.

### Step 4 -- Scope gate, with read- and lint-observable criteria

Present the scope gate as [`/iter`](iter.md) `## Scope gate` presents it. The acceptance criteria table is where a documentation session differs, and the difference is the whole reason this prompt exists.

Every criterion names a delta that is false or absent before the session and true or present after, per [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) `## Principles`. The delta is observed by a command the operator runs on the produced document:

| Criterion shape | Command the operator runs |
|---|---|
| A section the document gains | `head -N <path>` |
| A phrase the document must stop carrying | `grep -c "<phrase>" <path>` returns 0 |
| A rule the document now states | `grep -n "<rule anchor>" <path>` returns the section |
| A document that must parse and lint clean | `bash scripts/lint.sh` |

Four rules hold for the table, and they restate the acceptance-criteria invariants in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) rather than adding to them. A criterion is observable, so it names a command or a line range the operator runs, never a judgement such as "the document is accurate". A criterion is not file state read as prose: reading the source for a token is not verification, and the operator-runnable command is. Universal preconditions such as the lint gate gate every session equally, so they are preconditions and not criteria. Mark the Verified by column `Agent [x]` for a criterion that passes now, `Agent [ ]` for one that fails in the pre-state as expected, and `Operator` for a criterion the agent cannot run.

Add one criterion when the session touches an architecture document: that document describes the system as built. Run the lint gate now and show its output, then mark the table.

Exit condition: the operator released the gate, the handover holds the confirmed criteria with no `Not yet defined.` row left, and every criterion was re-read as satisfiable against the confirmed scope.

### Step 5 -- Produce the documents

Write the documents against the confirmed scope. Apply the writing standards in [`documentation_policy.md`](../../../docs/operations/documentation_policy.md) `## Communication Standards`: active voice, short sentences, one term with one meaning, one paragraph per physical line, and plain ASCII punctuation.

When the session applies a naming or structural change across more than two files, or uses "all", "every", "throughout", or "wherever X appears", produce the propagation checklist the project [`AGENTS.md`](../../../AGENTS.md) `## Propagation Discipline` requires, before the first file is written. Record every row as you complete it.

Correct the policy and concept documents the moment the work makes them wrong, per [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) `## Principles`. Do not leave a correction to the close.

Exit condition: every in-scope document is written, every propagation row carries a status, and no document the session made stale is left uncorrected.

### Step 6 -- Run the quality pass

A produced document is checked against the standard that governs its type. This is the per-prompt quality pass for whichever workflow document the session produced, applied here as a procedure step rather than as a separate session.

- **A workflow document.** Read [`prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) first, then check the document against its structure rules, its subject scoping, and its canonical-owner test. Record each change with the specific rule it answers, as that document's `## Compliance` requires.
- **A policy, concept, or architecture document.** Read [`documentation_policy.md`](../../../docs/operations/documentation_policy.md) and check the folder placement, the header format, and the section map.
- **Any document.** Walk the diagnostic checklists in [`documentation-pass.md`](../audits/documentation-pass.md) and record what the walk found.

Fix the findings and re-run `bash scripts/lint.sh`. Exit condition: each produced document has been read against its governing standard, every finding is fixed or recorded as a finding in the handover, and the lint gate is clean.

### Step 7 -- Dispatch the review advisor

Dispatch a fresh review subagent when either trigger fires. The first is a rule other sessions depend on: the produced document is a policy, concept, or workflow document that downstream work reads. The second is a meaning change: Step 3 moved what an existing document says.

Build the brief per [`prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) `## Runbook versus advisor versus skill`. Name the document, the question the reviewer answers, and the brief's length. Run the subagent per the provider-layer [`AGENTS.md`](../../../AGENTS.md) subagent invocation rules, with the role tag read from the project-level model recommendations. The reviewer returns findings; it does not edit. Triage each finding through the ordinary iteration discipline and record its disposition.

When neither trigger fires, say so in one line and skip the dispatch.

Exit condition: each fired trigger produced a dispatched reviewer or a recorded decision to skip it, and every returned finding carries a disposition in the handover.

### Step 8 -- Pre-close verification and the release gate

Run Step 7 of [`/iter`](iter.md) `## Step 7 -- Pre-close verification`, unchanged. Its five sections, the AC status table, the roadmap write-back, the propagation replay, the commit message, and the decisions pending, apply to a documentation session as they stand. The operator's forward signal on that summary is the release gate, per the gate invariants in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md).

Exit condition: the operator released the pre-close summary, and every acceptance criterion is marked accepted or pushed.

### Step 9 -- Close

Run [`/wrapup`](wrapup.md) Part B. That runbook owns the close steps, so this prompt does not restate them. Its AC verification step B1 re-runs each criterion's command against the committed tree.

Exit condition: the delivery commit landed, the handover is closed, and the roadmap write-back is in that commit.

## Output shape

- **The handover is the record of the criteria.** It follows [`handover_policy.md`](../../../docs/operations/handover_policy.md). A criterion that exists only in the conversation is not a criterion.
- **At the scope gate**, present the intent restatement, the in-scope files, the acceptance criteria table `| # | Criterion | Verifiable by | Verified by |` with the pre-verification output, the deferred items, and the open questions. This is the shape [`/iter`](iter.md) `### Step 5` requires.
- **At pre-close**, present the table `| # | Criterion | Verifiable by | Status |`. It answers whether the criterion passed, not who verifies it.
- **At the close**, one delivery commit carries the documents, the closed handover, and the roadmap write-back, per [`git_policy.md`](../../../docs/operations/git_policy.md).
- **Findings and deferred items** carry their destinations before the handover closes, per the close invariants in [`iteration_policy.md`](../../../docs/operations/iteration_policy.md).

## Non-goals

- **Not the document-maintenance sweep.** No runnable document-maintenance pass exists. [`documentation-pass.md`](../audits/documentation-pass.md) is a diagnostic register, not a procedure, and distilling it into an executable sweep is a separate roadmap task. Do not hand-run an improvised sweep inside a session and record the result as this prompt's work.
- **Not runtime-behaviour work.** That belongs to [`/iter`](iter.md).
- **Not the milestone-record close.** That belongs to [`/milestone-close`](milestone-close.md).
- **Not the shared close procedure.** [`/wrapup`](wrapup.md) Part B owns it.
- **Not the per-prompt quality passes for the loop prompt family.** Each of those is a separate roadmap task. The quality pass in Step 6 applies to the document this session produced.
- **Not the rule home.** A rule that governs documents lives in a policy document under `docs/`. This prompt names such a rule by link and never states one.

## Failure modes and invariants

Failure modes:

- **A criterion states a judgement.** "Accurate", "clear", and "complete" are not observations. The operator cannot run them, so the criterion is rewritten around the command that settles it.
- **A criterion verifies by reading source.** The iteration-policy rule against source-reading criteria still holds for a documentation session. The operator runs a command on the produced document; the agent does not read a token and report it as verification.
- **A rewrite changes meaning with no record.** The session's most expensive defect is a silent meaning change. Step 3 settles the requirements and records the change in the handover Decisions table, and in an ADR when it moves a settled design.
- **A produced document becomes the only home of a rule.** The canonical-owner test in [`prompt-authoring-conventions.md`](../../../docs/development/prompt-authoring-conventions.md) `## Consumers as fast paths, never sources` rejects it. The rule moves to its policy document, and the prompt keeps a pointer.
- **A workflow document is written without the type test.** A prompt written against the wrong rule set is reworked at Step 6, not left for the reader.

Invariants:

- Every acceptance criterion names an observable delta the operator checks by running a command.
- The handover holds the canonical acceptance criteria, and no criterion lives only in the conversation.
- One iteration is one unit, landing as one delivery commit per [`git_policy.md](../../../docs/operations/git_policy.md).
- No authoritative rule lands first in a workflow document, and this prompt restates no rule it links to.
- Each produced document is read against the standard that governs its type before the close.
