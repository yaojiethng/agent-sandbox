---
name: doc-maintenance
description: "Checks the documentation set against documentation_policy.md and reports what the tree contradicts: a claim the implementation no longer holds, a link whose target does not say what the citing line claims, and a fact two documents state differently. Use at a loop or milestone close, or when the operator asks for a documentation pass. Writes no document."
---

# doc-maintenance

<!-- Merge provenance: the diagnostic register of `.agents/audits/documentation-pass.md` (the checklist, with its two empty code spans repaired) is the substance of `## The diagnostic register`; the review method of `.agents/audits/documentation-audit-comparison.md` (claim extraction, the implementation cross-reference, the cross-document pass, and the output contract) is the substance of `## Procedure`. Both files are superseded by this skill. `documentation-pass.md` was removed by handover 20261006-09; `documentation-audit-comparison.md` stays until the folder is dissolved, because the milestone scope names it. -->

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`. If one is absent or holds the seeded stub, state the failure and hand control to the agent, which decides with the steering it has loaded; the workflow prescribes no fallback.

- `docs` - the document tree.

## Purpose

Checks the documentation set and reports the claims the tree contradicts. The method is per-document claim extraction followed by an implementation cross-reference, then a cross-document consistency pass, then the diagnostic register below.

The method is the point. A term-driven sweep finds only the staleness whose wording it already knows: it cannot find a claim about a term nobody listed as stale, and it cannot see two documents that contradict each other. A claim checked against the implementation finds both classes, at the cost of a read per claim.

The rules live in [`documentation_policy.md`](/opt/sandbox/docs/policies/documentation_policy.md), and the authoring bar for a prompt or a skill is in `docs/development/prompt-authoring-conventions.md`, which does not ship. The policy owns the rules; this runbook is a copy of the checks that apply them, and the policy wins a disagreement.

This pass writes no document and applies no correction. It reports.

## When to run

| Trigger | Scope |
|---|---|
| A loop close, per `workflow/coding-agent/prompts/iter.md` | the documents the iteration changed, plus every document that cites them |
| A milestone close, per `workflow/coding-agent/prompts/milestone-close.md` | the shipped set: `docs/reference/` and `docs/policies/` |
| The operator's request | the set the operator names |

The pass is not an iteration and does not close one. It is a review sweep with its own scope, and it may run inside a session that owns another outcome.

## What the gates decide, and what this pass decides

| Check | The gate | What it does not decide |
|---|---|---|
| A link resolves | `scripts/lint/linking.mjs`, over the shipped set in the image's path space | whether the target says what the citing line claims it says |
| A shipping document declares its reader | `scripts/lint/frontmatter.mjs` | whether the declared reader matches who reads it |
| One paragraph per physical line, plain ASCII | `scripts/lint/doc-wrap.mjs`, `scripts/lint/doc-ascii.mjs` | anything about meaning |
| The heading anchors a link names | `scripts/lint/linking.mjs` | whether the section carries the fact |

The split is the standing rule for a check: a decidable check belongs in a gate, where it fails the build, and a check that needs a reading belongs here. Do not report what a gate already catches; run the gate first.

## Procedure

Each step ends on a completion criterion.

### Step 1 - Scope the set

Name every document in scope and give each one a reason for being there.

- The trigger's own scope column decides the starting set.
- Add every document that cites a document in the set, and every document a document in the set cites. A stale claim travels along the references that depend on it.

Completion criterion: the set is named, each member has a reason, and the set is closed under citation within the depth the trigger allows.

### Step 2 - Extract the claims

For each document in scope, read it and write down each claim it makes about the system. A claim is a statement a reader could check: a path, a filename, a command, a flag, an environment variable, a count, a sequence, a state, a status, a mode, an interface name, or a statement of what a component does.

Take the claims in document order. Do not summarise, and do not judge while extracting: the judgement belongs in Step 3, and a claim judged too early is a claim looked for and found.

Completion criterion: every document in scope has a claim list, and each claim carries its section.

### Step 3 - Verify each claim against the implementation

For each claim, find the source that decides it, and read it. The source is the script, the dockerfile, the compose file, the manifest or the settings file the claim describes -- not another document. A claim verified against a document is verified against a copy.

Report each claim the source contradicts, with four facts: the document and section, the quoted claim, the source and what it shows, and the correction. A claim no source can decide is reported as such, not passed.

The failure modes this step catches, in descending order of how often they occur:

- A path or a filename that moved.
- A counted set that changed size, for example an invariant count or a root count.
- A mechanism that was replaced, stated as though it still runs.
- A status claim -- "not yet implemented", "wired, not runnable" -- that another document states the other way.
- A future-language row in a shipped document: `will`, `plan`, `eventually`, `reserved for`.

Completion criterion: every claim either matches the source that decides it, is reported, or is reported as undecidable.

### Step 4 - Follow each link

A link is a claim that the target exists and says what the citing line says it says. The gate decides the first half. This step decides the second.

For each link whose display text or surrounding line asserts something about the target, open the target and read the section the link names. Report a link whose target does not carry the fact the citing line leans on, and a link whose anchor names a section the claim has left.

Completion criterion: every link that carries an assertion has been followed and either carries it or is reported.

### Step 5 - Cross-document consistency

Read the claim lists from Step 2 against one another. Two documents that state one fact differently is one defect, and no per-file read finds it.

Compare, in this order: names and paths; counts and sets; the sequence of a process described in two places; a status or mode claim; a branch, tag or filename pattern; and a term spelled more than one way.

Completion criterion: each fact stated in more than one document is stated identically, or the difference is reported with both sites named.

### Step 6 - The diagnostic register

Run the register below over the set. It names what has gone wrong, not what to write instead: the prescriptive form of each is in [`documentation_policy.md`](/opt/sandbox/docs/policies/documentation_policy.md).

Completion criterion: every register item is either applied or skipped with a reason.

### Step 7 - Report

Write the report in the form `## Output shape` fixes, and print the one-line summary.

Completion criterion: the report covers every document in scope, every finding, and every check that produced no finding.

## The diagnostic register

**Canonical owner test.** When one rule appears in two documents, ask which document an agent reads when it needs the rule. That document owns it; the other links to it and does not restate it. The test is stated in both registers on purpose -- the policy states it to prescribe, this register to diagnose.

**Signs of duplication.** The same constraint in a workflow table cell and in a child policy section. An exit condition in one policy that restates a rule in another. A rule in a skill or a prompt with no home in a policy: a consumer is a fast path to a rule, never its source.

**Signs of misplaced content.** Future language in a shipped document. A TODO item in a shipped document. A prescriptive rule with no policy entry. A record argument restated in a shipped document, where the record is the place the decision is argued.

**Signs of a structural problem.** A section a reader would need to find in isolation with no heading. A document that must be read whole to extract one fact. A bridge document, which exists only to connect two documents that could cite each other directly. A document-level reference carrying a section anchor, which implies a narrower scope than it means. A table cell or a row a reader cannot act on without opening another document.

**Signs of a stale claim.** A quoted output string a change altered. A command, flag or exit code a change altered. A count or a shape contract a change altered. A "reserved", "planned" or "future" row whose day has arrived.

**Signs of a wasted sentence.** A sentence a reader can delete without losing required meaning. A sentence that restates what the heading already says. A no-op instruction the agent obeys by default.

## Output shape

The report is the JSONL file described in [`/opt/workflow/agent/modules/coding-agent/skills/check-in/report-schema.md`](/opt/workflow/agent/modules/coding-agent/skills/check-in/report-schema.md), written at the path the dispatcher sets, outside the repository tree. It is never committed. This skill writes to that schema and does not restate it.

Print a one-line summary to stdout when the run ends: the findings count, the skip count, and the path. A finding count of zero is reported as zero, never as silence.

## Non-goals

- Does not write a document, apply a correction, or commit. The dispatcher applies the report.
- Does not restate a rule. A finding whose correct form no policy sentence determines is a gap to report, not a rule to invent here.
- Does not check the roadmap, the handover chain, or `AGENT_FEEDBACK.md`. [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) and [`handover-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/handover-maintenance/SKILL.md) own those.
- Does not report what a gate already catches. Run `bash scripts/lint.sh` first, and report a gate finding only when the gate is not run in the caller's environment.
- Does not decide a design question. A contradiction that needs a decision is an escalation, not a finding with a fix.

## Failure modes

- **The pass runs as a term sweep.** Grepping for terms already known to be stale finds only those. Extract the claims instead; that is the step the sweep cannot replace.
- **A claim verified against a document.** Two documents that agree on a stale fact read as a clean pass. The deciding source is the implementation.
- **A skip reported as silence.** A check that did not run reads as a check that found nothing. Report the skip and its reason.
- **A cross-document contradiction split into two findings.** One fact stated two ways is one finding that names both sites, so the dispatcher does not fix one site and leave the other.
- **The report carries a severity.** Severity belongs to a work item. The report carries the recommendation, and an escalation is the whole expression of severity it has.
- **A gate finding reported again by hand.** A gate runs in the build. A hand copy of it goes stale and buries the findings that need a reading.
