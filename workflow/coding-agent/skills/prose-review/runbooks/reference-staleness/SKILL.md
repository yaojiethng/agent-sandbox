---
name: reference-staleness
description: Review whether reference documents still describe the system that exists. Use when a reference document or a set of them has been written or left untouched across a milestone, and someone needs to know whether it still tells a reader the truth.
disable-model-invocation: true
---

# reference-staleness

A review of documents that describe what the harness is. The subject is not whether each claim is true, which the claim-verification procedure settles, but whether the document as a whole still describes the system a reader would meet today, at one level, for one audience.

A stale reference document is an actively misleading one. A reader who finds it believes the system has a shape it no longer has, and the cost lands on whoever acts on it next.

## Scope accepted

A set is a list of named paths, and it resolves to those paths as they stand. A set holding no reference document is a refused dispatch rather than an approving review, because the review would read nothing.

The caller may hand the claim ledger written for the set alongside it. The ledger is evidence and not a substitute for reading: the review reads every document in the set and judges what the ledger cannot. It carries one line per finding, giving the document, its section, the rule applied and what the source shows instead, and a line missing any of those is refused, because a finding the review cannot place is one it cannot judge.

A ledger changes one thing. Given one, a claim it reports is evidence about the document rather than a finding of this review, and the review does not restate it. Given none, the review reports a claim it meets, and that finding promises nothing about the claims it did not meet. A ledger naming a document outside the set is a refused dispatch, because the review would be judging a document it has not read.

## Returns

One finding per line, carrying five facts:

1. the document and section
2. the quoted claim, sentence or heading
3. the fault class
4. the consequence, which is what a reader does wrong after believing it
5. the correction, or the question that must be answered before a correction exists

The report opens with the documents read, the fault classes applied, and the claim ledger it judged or the statement that it judged none. It carries the attribution, the scope and the log this environment requires.

A document that holds a claim no source decides is reported as undecidable rather than passed. An observation that fits no fault class is listed under its own heading with the reason no class covers it, because an observation is how the classes grow and a finding needs a class.

### The four fault classes

**Scope honesty.** A document must answer three questions about itself: who it is for, the one level of abstraction it works at, and whether it describes what is, what was, or what will be. A document that cannot answer all three has a scope problem, and it is named as one rather than as a style issue.

**Temporal staleness.** The document describes a shape the system no longer has, or names a target that no longer exists. Four forms: a mechanism presented as running that was replaced; a status or mode claim the document's own content contradicts; a path, document or folder named in it that is gone; a description accurate at a milestone and never revised when the shape changed.

**Vagueness.** Language that reads precise and commits to nothing. Three forms: a scope marker that names no boundary ("as needed", "where relevant", "if applicable"); false precision, a specific-sounding name for a thing that has no implementation; audience confusion, where a document switches register mid-section, or a conceptual document that a reader must open another document to understand.

**Difficulty of explanation.** A document whose core claim cannot be stated in one sentence without a dependent clause. The finding is a design question for the operator, never a request for more prose: ask whether the architecture it describes has complected things that should be separate. A difficulty in the writing is corrected by cutting. A difficulty in the design is reported as a question and not edited around.

### The closing test

Answer these before the verdict, and carry the answers into the report:

- could a reader who has not read the code describe what the system does now, from these documents
- does any document describe a component, an interface or a behaviour that does not exist
- is a difficulty in the writing or in the design
- do the documents in the set agree on names, layers and milestone state
- is any content here a forecast of work that belongs in the roadmap

A "no" or a "not sure" is a finding, not a remark.

## Verdict

One verdict per run. The family's words are `HOLD` and `APPROVE`, stated in the authoring guide; this review states its holding condition. `HOLD` when any finding is temporal staleness, or a scope problem that makes the document's true claims misleading. `APPROVE` otherwise. A `HOLD` names the finding that fails. `APPROVE` still carries its findings.

## Does not judge

- whether a claim matches its source, which the claim-verification procedure decides one claim at a time against the script, manifest or setting that holds it. That procedure owns coverage, so its report is this review's evidence and this review never restates one of its findings. The two are not alternatives: it answers whether each claim is true, and this review answers whether a document whose claims are true still describes the system a reader would meet
- which folder a document belongs to, and what a document of its type owes, which the documentation convention decides
- the wording of a sentence that is accurate but hard to read, which the prose review answers
- code, prompts and skills, which their own runbooks answer
- the roadmap, the handover chain and the feedback record, which their own procedures answer
