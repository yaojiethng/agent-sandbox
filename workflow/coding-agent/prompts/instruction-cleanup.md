---
description: "Settle the faults in one instruction surface -- rules that harm, duplicate, contradict, or read ambiguously -- with the operator ruling on each. Use when a surface's prompts, skills or `AGENTS.md` files have grown coupled: overlapping rules, contradictions between them, or wording a reader cannot act on."
argument-hint: "[the surface whose rules have grown coupled - a folder, a prompt family, or a group of audits]"
---

> $ARGUMENTS

# Instruction Cleanup - An Operator-Directed Pass

**Scope:** one pass over one instruction surface, run as an iteration whose deliverable is the cleaned surface. The operator names the surface, and the pass touches nothing else. [`/iter`](iter.md) and [`/wrapup`](wrapup.md) keep the handover, the gates, the commit and the close.

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`; if one is missing or holds the seeded stub, raise it to the operator.

- `project-documentation` - where the surface's files belong, and what an instruction document may contain.
- `task-list` - the row this pass files its outcome into.
- `work-log` - the handover that records its rulings.

A `principle-*` or `communication-principle-*` skill named anywhere below is read at `src/reasoning/providers/pi/config/agent/skills/<name>/SKILL.md`, the one root that carries them.

## The pass

The faults the pass goes looking for are five: harmful instructions, redundant instructions, ambiguous wording, ambiguous procedure and unneeded instructions, and a harmful condition inside an otherwise good rule belongs to the first of them. They are where most cleanup lives, not a closed list: a fault that fits none of them is raised with its own justification, and if it recurs it is named here, the same rule the census carries for its kinds. The pass removes the absolute crap first; it does not rank what is sound, and it does not try to reach a final set.

It starts from a census of every instruction in the named scope. The census is what tells us which instructions are duplicated, which are unique, what invokes each one, and the provenance of each. It is an instrument rather than a deliverable: a session sheet in `.scratchpad/`, produced by a throwaway script, committed never, and given no repository gate in this pass.

The instructions are then sorted by human judgement into runbooks, grouped by use case rather than by file, because the files are filed by history rather than by purpose. The same judgement decides whether an additional prompt is needed, either conducting the review from a different angle or attacking the review surface from a different direction; a gap the surface has is reported rather than filled here, and filed as a roadmap row naming the uncovered class and the census evidence. A rule belongs to one home, so the duplicated and the unique are separated by subject and not by wording.

Then the operator reads. The candidates go up one screen at a time in three sets: the proposed candidates, each carrying its fault and its provenance; the flagged candidates, one line each, where the agent cannot yet name the fault; and the rejected candidates, one line each. No rule is removed that the operator has not seen.

Finally the fold. Each file is handled once and the file set at the end is exactly the set we intend to maintain going forward: a base `prose-review` and a base `code-review` skill, each maintaining the set of prompts or runbooks its use cases need, onto which the prompts known to be working well are filed. The pass then stops, states what it removed, what it left and why, and files what it did not fix.

**The order of work, which the steps above follow:** census, categories, provenance, judgement, screen, fold. Decisions run top-down and application runs bottom-up, because they are keyed by different things. A ruling needs its whole use case in view, and the category is that unit. A file must never be half-migrated, and the file is that unit. So the category exists before any rule is placed in it, and a category is folded whole before the next begins.

## The census

One row covers one unit of logic: the smallest span that can be ruled on alone  --  removable or replaceable without changing whether its neighbours hold, and checkable by one read. The kinds are requirement, step, edge or gate, definition, contract, rationale, and pointer. A condition, an exception, a literal and a term are parts *inside* a unit: they are named by the ruling that covers the unit, never rows of their own.

The row is keyed by its site, not by its kind, and carries the text, the kind, the site, what invokes it, and the provenance register `## The provenance` defines. A kind that turns out to be missing is then a re-labelling of the rows on the boundary rather than a re-read of the corpus. The census holds what is written; a missing step or gate is found at the screen, not here.

**A fault that lands in no kind adds a kind.** Record the addition with the fault that forced it.

Calibrate before committing to the corpus: census one file, apply the kinds to it, and see whether a unit fits none or two fit one. The operator rules on the kinds there, and they hold for the rest of the surface.

## The categories

A category is a use case, and a use case becomes one runbook.

The shared body is what every runbook must agree on -- what a finding is, what provenance a removal needs, what a report states. It is not a category: the census surfaces it as text repeated across runbooks. It is decided first, because every runbook after it is written against it.

A rule that looks shared is placed by counting its consumers, and no second consumer named means it belongs to the category it was found in; one consumer stays where it is. Two sites are then placed by asking whether one change must land in both:

- **It must.** They state one meaning, so it is promoted -- a principle if it is a judgement applied while writing, a `docs/reference/` contract if several surfaces read it, a `docs/reference/` procedure if it is the method every runbook runs.
- **It need not.** They share a shape over different content, one class omitting a step another needs, so each keeps its copy: a generalised shape costs a framework and reads worse than the repetition.

A rule that already has a home is a pointer, never a copy.

The map of categories is ratified once for the base skills, from the census of the largest surface, and re-cut only when a surface proves it wrong, with the reason recorded. A map per surface produces a different taxonomy per surface, which is the fragmentation this pass removes.

## The provenance

One entry records why an instruction stands, or why it should change, in this shape:

```text
source:  path:line -- the record itself
entry:   ruling | decision | failure | comparison | run | duplication | conflict
quote:   the sentence the record states
date:    the record's own date
```

A register is the entries that bear on one unit, and the census row carries it. An empty register is recorded as empty: that an instruction has nothing behind it is a finding about the surface, not a gap in the pass.

**A reason raises an item; a proof settles one.** A ruling, a decision or a comparison explains why an instruction is there, which is a reason for it and, read the other way, a reason to look again. A failure, a run or a conflict shows it failing, and a fault shown failing needs no argument: the ruling is on the remedy alone.

Provenance is the looser word on purpose. An operator ruling is not a proof that a rule is sound, and two readings written out are not a proof that a rule is ambiguous: each is a reason, and the operator judges what it is worth. Only a record supplies a proof.

These are the kinds that have counted. An entry naming another kind is an entry when it names a source and quotes it.

| Entry | What it is | Grade |
|---|---|---|
| **ruling** | an operator decision | reason |
| **decision** | a design session or an audit that settled it | reason |
| **comparison** | a design the surface kept over the ones it dropped | reason |
| **failure** | a feedback entry, a session log or an incident | **proof** |
| **run** | a pass, an eval or a checked dispatch | **proof** |
| **duplication** | another instruction on the same surface that states the same rule | reason |
| **conflict** | another instruction on the same surface that states the opposite, which proves a set inconsistent and never which member is wrong | **proof** |

Quote the source. A summary is processed information: checking it against the source costs the reader the work the pass was meant to do, and a paraphrase that drops a qualifier reads exactly like a faithful one.

## The judgement

A register shows what was decided and what was observed. It does not show that the instruction is sound: a rule can be deliberate, recorded and old, and still fail all four faults, which is why the register is kept apart from the judgement that reads it.

Every proposal is a raise. The operator rules, and the agent applies only what the operator has ruled on.

Four faults, and what each one has to show. The examples are illustrative, not exhaustive: a fault the agent can justify is a fault, whatever raised it.

| Fault | What usually raises it | What settles it |
|---|---|---|
| **a harmful instruction**, including a harmful condition inside an otherwise good rule | a ruling or a decision naming what it costs | a failure entry in which it caused the damage |
| **a redundant instruction**  --  one rule with two sites | a duplication entry, where the agent judges that both sites state one rule, or a conflict entry, where they disagree. Either way, a change to one must land in the other | a conflict entry. A duplication is a judgement, so there is no proof to read and the operator's ruling settles it |
| **ambiguous wording** | the two readings, each a sentence a reader could act on; a reading nobody could act on is vagueness, not ambiguity | a failure entry in which it was read the wrong way, or a conflict entry of two instructions that mean opposite things |
| **ambiguous procedure** | the trace: walk the steps in order, name the first that stops, and the input nothing reads or the condition nothing observes | a run entry in which the step did stop someone |
| **an unneeded instruction** -- a rule whose behaviour survives its absence | no procedure step references it, no proof-grade entry backs it, and its removal changes nothing observable | a deletion run in which nothing goes wrong |

**A deletion run is one dispatch.** Remove the rule, change nothing else, run the procedure it governs once, and read the result. A run that goes wrong is a proof-grade `failure` entry: the rule stays, now with a reason recorded. A run that goes right is a proof-grade `run` entry, and the removal is settled. Some rules no procedure exercises. There the fault is raised as a judgement and the operator rules on it, exactly as a duplication is.

Provenance cannot settle this fault. The register shows why a rule was written, and never whether it still earns its line, which is why this one reads a run.

Every proposal is one item in this shape:

```text
rule:           the quoted clause, or both sites of a two-site fault
site:           path:line
fault:          one of the five, and what proves it
recommendation: "removal - <the operator's reason>", the replacement text quoted from the site that already states it, or "enforce - <what now holds it>"
carrier:        for a removal, where the rule lives now: a site, or the check, gate or error that holds it
```

Where no site states the replacement, the recommendation is the agent's own text and is marked as such.

**`enforce` applies when the failure is cheaper to detect than to describe.** A rule forbidding a non-ASCII dash is one check and no prose. A rule asking for the smallest change that works has no check, so it stays prose. The carrier names the artifact, and the check lands in the same commit as the deletion: a rule removed before its check exists is a rule lost.

Where the register holds a conflict, the set is presented with its contradiction or contradictions and **two to four resolution options**, each with its cost, and with a recommendation where the agent has one. Not every contradiction resolves by one member dying: a specific case contradicting a general rule may resolve by narrowing the specific, widening the general, or splitting the general in two.

## The screen

One screen per category, split by fault when the category holds more than one fault. Ids are numbered per screen and die with it: the handover records each ruling by the rule it names.

A candidate the agent can justify is proposed, in the shape `## The judgement` gives it. One it cannot justify yet but still reads wrong is **flagged**: one line naming the site and what bothers the agent, with nothing else required, and the operator rules on it or leaves it. A candidate the agent judges unsound is rejected and shown in one line: rejected means the agent proposes no change, never that the rule is fine.

The screen is a convenience over the census, not a filter on it. Each unit is already in front of the operator as a row with its text and its register, so a rule that never became an item has still been read, and a screen proposing nothing is a claim about the pass rather than about the surface.

Two shapes, and which one applies is decided by the handling rather than by how strong the case is:

- **The advice shape.** The case is settled and the handling is binary  --  the comparison of the rule present and the rule absent settles it. The batch is presented as removals, and **no objection removes them**, provided the batch holds removals only, the comparison is settled on provenance already accepted, and nothing is owed: the rule's job is covered by a named site or vacuous.
- **The option shape.** The harm is proven and the handling is not binary: an edit, a rephrase, a removal or a subsumption. The item carries a recommendation, and the operator's `accept edit 3` applies it. The recommendation is easy only where it is one of the presented options, the replacement text already exists at a site, and no live preference is at stake. An item failing any of the three goes to the discussion instead, as a pending decision or a scope-gate question.

## The fold

Every ruling for a category is applied before the next category starts, and each file is migrated whole; the pass stops early rather than leave one half-migrated. A folded file is deleted in the same commit as the edit that absorbs it, so the surface never carries both.

## The runbooks

**Dispatch** makes a file a runbook: a fresh context is given a scope and asked to judge it, and returns findings and a verdict. A procedure the working agent runs over its own records is a check skill, and it stays where it is.

**Every runbook declares the scopes it accepts.** Two kinds, both fixed before the run starts:

- **A delta** is a commit range, and it reads the diff. It answers what changed.
- **A set** is named paths -- a module, a component, or a set of either, resolved to paths -- and it reads what is there now. It answers what is structurally true.

A runbook that accepts no scope is a fault, whatever its wording: a whole-tree sweep with no declared boundary is a dispatch nobody can repeat. Which scope a runbook can carry follows from what it already reads, which is why a structural sweep cannot be given a commit range and a change review cannot be given a module set.

Beside the scope, an optional **focus** narrows what the runbook looks for. It may only subtract: it names paths inside the scope, or a subset of the classes the runbook declares. A focus naming a path outside the scope, or a class the runbook does not declare, is a refused dispatch rather than a reinterpretation. Anything else the operator wants to say -- a concern, a suspicion, an example -- is brief context, and it steers the run without narrowing what it reads.

**A focused run returns findings only and no verdict.** A narrowed run's verdict would be a claim about the subset presented as a claim about the runbook, and a false assurance is worse than no review. The verdict requires the runbook's full class set over its declared scope.

## Creating the shells

The pass creates the two base skills, `prose-review` and `code-review`: the shell, a pointer to the shared body in `docs/reference/`, and the scopes each runbook declares. Where a use case needs a runbook and no file holds one, it is filed as a coverage gap and not written here -- creating a shell is structural, and writing a review prompt is improvement.

## The end state

What the pass leaves is something that can be run peacefully, open to future iterative improvement, that does not plant landmines or cause active harm: a good starting point for improving the review workflows in the future.

## Non-goals

No token intensive workflow runs in this pass, and no prompt is dispatched or evaluated. Evals are a separate step that comes after we have an eval pipeline, and before we have an eval pipeline we clean up the coupled instruction corpus; this pass is that cleanup. It is also the prompt side of the separation between review dispatch and review prompt, so it does not answer what the dispatcher does, who processes a seat's result or who assigns the verdict: that is the dispatch seam's, and its rows live with the dispatch command surface.

## The wording

An instruction this document writes is held to `communication-principle-rewrite-syntax-never-semantics`: syntax is the agent's and semantics is the operator's. The agent may join, reorder, restructure, add headings and cut a restatement. It may not change a quantifier, a negation, a modal, a logical connective, an actor, a condition, an exception or an anchored keyword.

Where the operator's words do not exist for something the pass has to say, the item carries the agent's text as a suggestion under a raise, and the operator supplies the words. Where the agent judges a clause wrong, unclear or weak, the same raise applies: the clause, what it appears to require, and the rephrase offered as a suggestion, never applied.
