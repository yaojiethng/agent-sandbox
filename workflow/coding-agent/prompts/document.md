---
description: "Run a documentation session. An iteration whose deliverable is a document rather than runtime behaviour defines the acceptance criteria as read- and lint-observable deltas, aligns the rewrite requirements before the rewrite begins, and runs the standards check on each produced document. Use when the session creates or rewrites a policy, concept, architecture, prompt, skill, or record document; /iter replaces this prompt for runtime-behaviour work."
argument-hint: "[documentation goal or target document - optional]"
---

> $ARGUMENTS

# Document - The Documentation Session

**Scope:** one runbook for an iteration whose deliverable is a document. The in-scope targets are a policy, concept, architecture, prompt, skill, or record document. It owns what the shared prompts do not supply - the type test that names the rule set a target document is written against, acceptance criteria the operator checks by reading or linting the produced document, the alignment step that settles what a rewrite must change before the rewrite begins, the propagation checklist a cross-cutting change requires, the standards check each produced document takes before the close, and the review-advisor dispatch for a rule other sessions depend on. The handover, the scope gate and the release gate, the commit discipline, and the close stay with [`/iter`](iter.md) and [`/wrapup`](wrapup.md).

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `project-documentation` - the document tree.
- `decision-records` - the architecture decision records.

## Purpose

A documentation session has no runtime to run. The acceptance criteria of [`/iter`](iter.md) ask the operator to run the system and observe an output, which a documentation session has no way to produce.

A documentation session is one iteration, closed by [`/wrapup`](wrapup.md) and committed by [`/commit`](commit.md).

## When to run

Run this prompt when the iteration produces or rewrites a document.

- **Not runtime-behaviour work.** Code, shell, or configuration that runs belongs to [`/iter`](iter.md), which replaces this prompt.
- **Not a milestone or sub-milestone record close.** The compaction, the changelog entry, and the record cascade belong to [`/milestone-close`](milestone-close.md), which replaces this prompt.
- **Not a design negotiation held open across sessions.** When the rewrite requirements are still open, plan them first with [`/plan`](plan.md), then run this prompt on the confirmed plan.

## Input contract

| Input | Meaning |
|---|---|
| documentation goal or target document | What the session must produce, or the document it rewrites. Both are optional; with neither, the session takes its target from the active roadmap task read in Step 1. |

## The procedure

Each step ends on an exit condition.

### Step 1 -- Orient

Find the most recent handover and the active roadmap task, exactly as [`/iter`](iter.md) `## Orient` does. Read the target document's own policy before anything else.

Exit condition: the prior handover, the active roadmap task, and the governing policy document for the target are read, and any superseding record for the target is named.

### Step 2 -- Identify the document type

A document an agent consumes is one of three types, and each type is written by a different rule set. Apply the two tests in `prompt-authoring-conventions.md` `## Identify the document type`. A document that fails the workflow-document test is a policy document or a reference document.

Name the document type in the handover `## Scope` section before the scope gate. The type selects the standards the produced document is checked against in Step 6.

Exit condition: the target's type is named in the handover `## Scope` section, with the test that classified it.

### Step 3 -- Align the rewrite requirements

When a rewrite changes what an existing document means to the sessions that read it, settle the requirements before any prose is written. Pass the session context -- the recorded goal and problem, the gathered context, and the confirmed scope -- to the `grill-me` skill for this interview. The interview resolves each branch of the decision tree: what the document must say after the session, what it must stop saying, and which readers depend on the part that changes.

Record the settled requirements where the work lives, per the record-state rules in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `## Iteration Invariants`. A meaning change to a settled design edits its ADR in place, per the `decision-records` convention.

Exit condition: every requirement the rewrite must satisfy is written down, each meaning change to an existing document is recorded in the handover Decisions table with the record that holds it, and the handover Decisions pending table holds its canonical marker.

### Step 4 -- Scope gate, with read- and lint-observable criteria

Present the scope gate as [`/iter`](iter.md) `## Scope gate` presents it. The acceptance criteria table is where a documentation session differs.

Every criterion names a delta that is false or absent before the session and true or present after, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `## Principles`. The delta is observed by a command the operator runs on the produced document:

| Criterion shape | Command the operator runs |
|---|---|
| A section the document gains | `grep -n "^## <section title>" <path>` returns the heading line |
| A phrase the document must stop carrying | `grep -c "<phrase>" <path>` returns 0 |
| A rule the document now states | `grep -n "<rule anchor>" <path>` returns the section |

Three rules hold for the table, carried from [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `### Acceptance-criteria invariants`. A criterion is observable, so it names a command or a line range the operator runs, never a judgement such as "the document is accurate". The lint gate is a universal precondition. Every session runs it, so it is not a criterion. Mark the `Result` column `Agent [x]` for a criterion that passes now, `Agent [ ]` for one that fails in the pre-state as expected, and `Operator` for a criterion the agent cannot run.

Every session that touches an architecture document carries the criterion [`/iter`](iter.md) `### Step 5` makes mandatory - "Architecture documents in scope describe the system as built". Beside it, add the command that settles each claim the document makes about the system, such as `grep -n "<claim anchor>" <path>`. Run the lint gate now and show its output, then mark the table.

Exit condition: the operator released the gate, the handover holds the confirmed criteria with no `Not yet defined.` row left, and every criterion names a command or a line range the operator runs.

### Step 5 -- Produce the documents

Write the documents against the confirmed scope. A prompt or a skill takes the authoring rules in `prompt-authoring-conventions.md`. That document owns the two kinds the `project-documentation` convention disclaims when it states that skill files and prompt templates are not documentation. A policy, concept, architecture, or record document takes the writing standards in the `communication-principle-*` corpus and the form rules in the `project-documentation` convention, `.agents/skills/project-documentation/SKILL.md`.

When the session applies a naming or structural change across more than two files, or uses "all", "every", "throughout", or "wherever X appears", produce the propagation checklist the [`propagation-check`](/opt/workflow/agent/skills/propagation-check/SKILL.md) skill requires, before the first file is written. Record every row as you complete it.

Correct the policy and concept documents the moment the work makes them wrong, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `## Principles`.

Exit condition: every in-scope document is written, every propagation row carries a status, and every policy or concept document the session made wrong is corrected.

### Step 6 -- Run the standards check

The standards check reads each produced document against the standard its type selects.

- **A workflow document.** Read `prompt-authoring-conventions.md` first, then check the document against its structure rules, its subject scoping, and the kind test that decides each rule's source of truth, per `### Norm kinds` in `agent_workflow.md`. Record each change with the specific rule it answers, per `prompt-authoring-conventions.md` `## Compliance`.
- **A policy, concept, or architecture document.** Read the `project-documentation` convention, `.agents/skills/project-documentation/SKILL.md`, and check the folder placement, the header format, and the section map.
- **A record document.** Check it against the record-state invariants in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `### Record-state invariants`, and against the project's `work-log` convention for a handover or a discussion record, or the `decision-records` convention for an ADR. For a discussion or design record, confirm that no question-and-reply pair remains, that every question still listed is still open, and that the designs considered and rejected are a short section carrying the reason for each. An answered question belongs in the body at the place its answer belongs, not in a reply, so fold it there when it closes.
Fix the findings and re-run `bash scripts/lint.sh`. The diagnostic register a produced document is read against is `## The diagnostic register` in the project's `doc-maintenance` runbook, at `.agents/skills/project-documentation/runbooks/doc-maintenance/SKILL.md`.

Exit condition: each produced document has been read against its governing standard, every finding is fixed or recorded as a finding in the handover, and the lint gate is clean.

### Step 7 -- Dispatch the review advisor

Dispatch a fresh review subagent when either trigger fires. The first is a rule other sessions depend on - the produced document is a policy, concept, or workflow document that downstream work reads. The second is a meaning change - Step 3 moved what an existing document says.

Build the brief per `prompt-authoring-conventions.md` `## Runbook versus advisor versus skill`. Name the document, the question the reviewer answers, and the brief's length. Run the subagent per the provider-layer `$AGENT_HOME/agent/AGENTS.md` `## Fresh Subagent Invocation`, with the role tag read from `model-recommendations.md`. The reviewer returns findings; it does not edit. Triage each finding through the ordinary iteration discipline and record its disposition. A finding that names a defect in what this session produced is fixed here, not filed: [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `### Close invariants` `Defect resolution` says so, and the deferred rule does not apply to it.

When neither trigger fires, say so in one line and skip the dispatch.

Exit condition: each fired trigger produced a dispatched reviewer or a recorded decision to skip it, and every returned finding carries a disposition in the handover.

### Step 8 -- Pre-close verification and the release gate

Run Step 7 of [`/iter`](iter.md) `## Step 7 -- Pre-close verification`, unchanged. It applies to a documentation session as it stands. The operator's forward signal on that summary is the release gate, per the gate invariants in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md).

Exit condition: the operator released the pre-close summary, and every acceptance criterion is marked accepted or pushed.

### Step 9 -- Close

Run [`/wrapup`](wrapup.md), which owns the close steps. Its acceptance criteria verification step B1 re-runs each criterion's command against the committed tree. [`/commit`](commit.md) then prepares the handover, lands the delivery commit and runs the post-commit check.

Exit condition: the delivery commit landed, the handover is closed, and the roadmap write-back is in that commit.

## Output shape

- **The handover is the record of the criteria.** It follows the project's `work-log` convention.
- **At the scope gate**, present the intent restatement, the in-scope files, the acceptance criteria table the project's `work-log` convention states, with the pre-verification output, the deferred items, and the open questions. This is the table [`/iter`](iter.md) `### Step 5` requires.
- **At pre-close**, present the same table with `Result` carrying the marking.
- **At the close**, one delivery commit carries the documents, the closed handover, and the roadmap write-back, per the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`.
- **Findings and deferred items** carry their destinations before the handover closes, per the close invariants in [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md).

## Non-goals

- **Not the document-maintenance sweep.** The `doc-maintenance` runbook owns the review sweep and reports what it finds; this prompt owns the document it produces. Do not hand-run an improvised sweep inside a session and record the result as this prompt's work.
- **Not runtime-behaviour work.** That belongs to [`/iter`](iter.md).
- **Not the milestone-record close.** That belongs to [`/milestone-close`](milestone-close.md).
- **Not the shared close procedure.** [`/wrapup`](wrapup.md) owns the close and [`/commit`](commit.md) owns the commit.
- **Not the per-prompt standards checks for the loop prompt family.** Each of those is a separate roadmap task. The standards check in Step 6 applies to the document this session produced.
- **Not a rule's source of truth.** A rule that governs documents lives in a policy document under `docs/` or in a project convention-skill. This prompt names such a rule by link. Where the body carries a copy of one, the copy is a fast path and the linked home governs.

## Failure modes and invariants

Failure modes:

- **A criterion states a judgement.** "Accurate", "clear", and "complete" are not observations. The operator cannot run them, so the criterion is rewritten around the command that settles it.
- **A criterion verifies by reading source.** The iteration-policy rule against source-reading criteria still holds for a documentation session. The operator runs a command on the produced document; the agent does not read a token and report it as verification.
- **A rewrite changes meaning with no record.** Step 3 settles the requirements and records the change in the handover Decisions table, and in an ADR when it moves a settled design.
- **A borrowed rule is stated without its source of truth.** A produced document states a rule its own workflow does not produce without naming that rule's source of truth, per `### Norm kinds` in `agent_workflow.md`. A prompt keeps a pointer to every rule it borrows.
- **A workflow document is written without the type test.** A prompt written against the wrong rule set is reworked at Step 6, not left for the reader.

Invariants:

- Every acceptance criterion names an observable delta the operator checks by running a command, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `## Principles`.
- The handover holds the canonical acceptance criteria, and no criterion lives only in the conversation, per [`iteration_protocol.md`](/opt/sandbox/docs/reference/iteration_protocol.md) `### Acceptance-criteria invariants`.
- One iteration is one unit, landing as one delivery commit per the `git-discipline` convention, `.agents/skills/git-discipline/SKILL.md`.
- Each rule this prompt copies inline names the source of truth that governs it, per `### Norm kinds` in `agent_workflow.md`.
