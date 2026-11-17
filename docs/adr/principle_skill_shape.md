# Principle Skill Shape

**Current:** 2026-11-16

## 2026-11-16 -- The principle frontmatter is one gate, and the body shape is a convention

**Decision:** The document-shape gate keeps the frontmatter parse, the `disable-model-invocation` boolean and the shipping reader declaration. The principle body shape leaves the gate and stays a convention in `skill-conventions.md` and the exemplar. One provider-root gate, `scripts/check_principle_frontmatter.sh`, owns the principle frontmatter: `name`, `description` and `metadata.neighbours` are required; `metadata.leitwort`, `intent` and `mechanism` are validated when present; `disable-model-invocation` is rejected. This supersedes the gate clause of the 2026-10-21 entry; the shape itself stands.

**Rationale:** The frontmatter is what a parser reads: pi's loader, the inventory lever and the admission field row. The body is what a reader and an author judge. A gate belongs where its evidence exists and its decision is cheapest, and the body's observer is the review and the exemplar. The 2026-10-28 entry is the precedent: the claim field went because no consumer acted on it and no check could falsify it. The split also ends the label collision the role-based entry fixed, because the gate no longer reads a body label at all.

**Rejected alternatives:**

- *Keep the body gate and add a second frontmatter gate.* **Execution failure**: two walks of the same corpus, and the frontmatter's fields split across gates.
- *A data-driven schema over the body.* **Intent failure**: the rules are a handful of labels and an order; a schema is more machinery for the same rule.
- *Require `leitwort`, `intent` and `mechanism` now.* **Execution failure**: the corpus does not carry them uniformly; the field row makes them required.
- *Gate the frontmatter but leave the body as it was.* **Neither**: the machine contract is the part with a parser, and the body rule is what the operator asked to trim.

**Edge cases / drivers:** The gate is provider-only, matching the principle definition in the terminology registry; a project `principle-` skill is outside the corpus. The body can drift with no mechanical check, and the review and the exemplar carry it; that is the accepted cost. The conditional fields are checked for presence and type only, because the operator's value lives in the admission record. The gate rename keeps the document gate's name, `check_document_shape.sh`, because the frontmatter is still a shape, and its header states which one.

## 2026-11-16 -- The principle body gives its parts roles, not fixed labels

**Decision:** The rule part is the first bold lead-in and the card names it. It carries the general rule, whether that rule is a pattern, a test or a principle. `**Why.**` and `**The test.**` keep their labels because they are the rationale and the check. Any named part may follow the rule, and a boundary part may follow the test.

**Rationale:** The literal `**The pattern.**` forced one card's label onto every card. A card whose rule is a deletion test had to call it a pattern, and a card with acceptable and unacceptable examples had to put both under one heading. The labels belong to the card, and the gate checks that the parts exist in a workable order.

## 2026-11-16 -- A principle records its operator's intent and mechanism

**Decision:** A principle declares `metadata.intent` and `metadata.mechanism`. Both are operator-led: the operator writes them when the skill is created or ratified, and the agent reads them rather than inferring them from the body. `intent` is the judgement the skill serves. `mechanism` is the way that judgement expresses itself, or the specific way the principle exerts influence on the workflow. The admission record that holds the case is the provenance. The five reader-context principles carry the pilot values; the remaining corpus declares the fields as the operator ratifies each skill.

**Rationale:** The intent is obvious to the operator and not to the agent, and the agent re-derives it wrong when it categorizes the corpus. The judgement is expensive to get back after the fact, because it lives in the admission conversation and the body's prose. Recording it at creation is cheap, and it gives the label a provenance. The field differs from the removed `metadata.claim`, which was agent-led: here the operator authors the value, so the field records a decision rather than a categorization the agent guessed.

**Rejected alternatives:**

- *An agent-derived label from the body.* **Intent failure**: it repeats `metadata.claim`, which was removed because the agent's categorization had no gate and drifted.
- *A prose section in the survey report.* **Execution failure**: it is a second source, and the agent reads the skill's frontmatter before the report.
- *A gate that validates the value.* **Neither**: the gate can check presence and provenance, not whether the intent is right; that judgement is the operator's.
- *A third field for provenance.* **Execution failure**: the admission record already holds the case, and a second pointer drifts.

**Edge cases / drivers:** `write-for-the-reader` and `link-what-the-reader-can-open` carry the same intent and differ in mechanism, so the intent is a family and the mechanism is the axis. The mechanism's name is qualified: a task's `Mechanism:` names its delivery mode, and this field names how the judgement exerts influence; the two are read in their own context. `single-train-of-thought` carries its own intent and is a neighbour of the context family, not a member. The legacy corpus has no recorded judgement, so its values are ratified by the operator; the survey map's provisional value is not the field. An absent field means the operator has not ratified the skill yet, not that it declares nothing.

## 2026-11-16 -- The corpus declares no neighbour, and the gate holds without a baseline

**Decision:** Every principle carries `metadata.neighbours`, and a missing field fails the gate. The existing corpus declares `[]`, meaning "no neighbour declared"; "surveyed, none" is carried by the survey map, not by a third field value. The baseline and the gate's `--update` are deleted. The gate's remaining rules are presence and liveness: a declared name resolves, and a duplicate, a self name or a malformed value fails.

**Rationale:** The migration the baseline served was withdrawn. Without a case, the neighbour relation is not decidable per skill: "neighbour" degrades to "shares a subject", a conflict has no state to be parked in, and unresolved edges propagate into a tangled group. The existing corpus cannot declare real neighbours before the survey, so `[]` is the honest declaration. The baseline's only purpose was the pre-migration corpus, so it has nothing left to hold.

**Rejected alternatives:**

- *Keep the baseline as a permanent exception list.* **Intent failure**: it hides a missing field indefinitely, and the gate's presence rule becomes unenforceable for the corpus it covers.
- *Delay the gate until the survey fills the fields.* **Execution failure**: it blocks the gate on a survey that may produce a map rather than edges, and the presence check works today.
- *Give the field a third value for "not surveyed".* **Neither**: a third state needs a gate, a reader and a migration of its own; the survey map carries the distinction with no schema change.

**Edge cases / drivers:** `[]` means "no neighbour declared", not "has no neighbour". A principle the survey finds with no neighbour is recorded on the survey map; the procedure is [`corpus-survey.md`](../../.agents/skills/instruction-authoring/references/corpus-survey.md), and the field stays `[]`. The gate reads the repo-owned provider root; `$AGENT_HOME` carries extras and stale duplicates. The gate cannot judge whether a named neighbour is the right one; that is the admission decision.

## 2026-11-14 -- A principle declares its neighbours, and admission is by case

**Decision:** A principle skill declares the principles nearest to it in `metadata.neighbours`, a list of full skill names. Handoffs remain in prose and are not neighbours. A new or changed principle is admitted by a decision that names the nearest existing principle, the distinction, and the case that demanded it. The admission step is a pattern under `instruction-authoring`, cited from step 1 and from the `scope` prompt's `## Check the boundary`. A deterministic lever reads the repo-owned provider root and extracts the field; the gate checks that every name resolves and that every principle carries the field or is named in a baseline of the existing skills, which must only shrink. The body's scope statement carries the meaning; a contested distinction belongs in the admission record, not in every skill. The artifact and the norm are separate axes: `docs/reference/terminology.md` defines the principle skill, and `instruction_modality.md` holds the judgement it carries.

**Rationale:** A corpus-wide semantic pass is neither affordable nor reliable: the operator becomes the ground truth for every classification, and the cost repeats. The semantic decision is cheap only at admission, on the new case and its nearest neighbours. The field makes orphanhood a checkable property instead of counting arbitrary links, which conflate a handoff ("apply this next") with a neighbour ("a similar application under a different domain"). It has three consumers -- the lever, the gate and the admission pattern -- so it is not the metadata field the 2026-10-28 entry removed for having no consumer. The baseline lets the gate land before the existing-skill migration and forces the exception list to shrink.

**Rejected alternatives:**

- *A periodic whole-corpus pass.* **Intent failure**: the semantic decision is unreliable at that grain, the operator will not adjudicate every rule, and the cost repeats.
- *Reuse any Markdown link as the edge.* **Intent failure**: it conflates handoffs with neighbours, so orphanhood is a false proxy.
- *A canonical `**Neighbours.**` body part.* **Neither**: it is correct and keeps one carrier, but the machine index was chosen independent of prose; the body part would put the edge in the text the lever parses and give up the field's explicit shape.
- *Reciprocity.* **Intent failure**: it forces a link into the neighbour for every one-way distinction, manufacturing edges to satisfy the gate.
- *No baseline; gate the corpus at once.* **Execution failure**: it forces a corpus-wide semantic review before the gate can land.
- *An eval of model categorization.* **Intent failure**: nondeterministic under the current infrastructure, and it measures the model rather than the mechanism.

**Edge cases / drivers:** `neighbours: []` declares that no neighbour is declared; a principle the survey finds with no neighbour is recorded on the survey map. An absent field is undeclared and is a baseline entry, so the two states are distinguishable. The lever reads the repo-owned provider root (`src/reasoning/agent-runtime/pi/config/agent/skills/`), not `$AGENT_HOME`, which carries extras and stale duplicates. The gate cannot judge whether the named neighbour is the right one; that is the admission decision. The baseline is a gated copy: the gate fails if a baseline entry gains the field and the baseline is not updated. The passthrough rule is the first admission; its restated test is the retired `principle-delegation-over-machinery` test. The case replay is the check that the mechanism surfaces the right neighbour on the four direct cases; a miss is reported and the mechanism is revised or narrowed.

## 2026-11-07 -- The communication corpus stays installed, and this entry states where it is read

**Decision:** The communication principle corpus is the set of `communication-principle-*` skills installed at `$AGENT_HOME/agent/skills/`. It is not shipped in this tree, and [`skill_source_catalog.md`](skill_source_catalog.md) holds its source and why it stays installed rather than vendored. Three judgements the migration settled are stated here, because the corpus is read where it is installed and no document in this tree states them. The three sentence-level lines it retired, active voice, noun before command and no thin subject with a dash clause, are one stratum: the reader builds structure left to right, attaches each phrase to what is already built, and spends one budget of integration cost across all three. A section is read against proximity, so a caveat placed away from its rule costs working memory, a mental-model repair and attention. And a judgement two or more documents state becomes a principle, while a judgement stated in one document is reviewed on its own and filed by no chain. A principle's own derivation is not kept: the installed skill is the artifact.

**Rationale:** The migration is finished and its design records are not. Each of them settled a decision whose subject is a skill that now exists outside this repository, so the record cannot serve as a carrier and the lifecycle rule calls it a deletion that has not run. Naming the corpus and the three judgements it does not make visible keeps the retrieval path where a reader of this ADR set meets it, and the derivation whose conclusion the installed skill carries is spent. `skill_source_catalog.md` already records why the corpus stays installed, so this entry does not restate it.

**Rejected alternatives:**

- *Keep the per-principle design records.* **Execution failure**: a settled record whose subject is installed text is a deletion that has not run, so the next reader cannot tell a live carrier from a spent one, and the corpus is read in the config home rather than by opening a design record from October.
- *Vendor the corpus into the tree.* **Intent failure**: the source catalog's empty row already decided this for every project that installs the layer, and a vendored copy would be a second edition of the corpus with no bump path.
- *State each principle's derivation in the shipped principle, which has the space.* **Boundary failure**: a principle states the judgement and the test a writer applies, and an account of how it was chosen is history that a reader under time pressure takes for a rule.

**Edge cases / drivers:** Three principles left the corpus for `instruction-authoring` on 2026-11-05, in the entries above, so a deletion here never means a judgement vanished, only that its carrier moved. The installed tree is the fact for which principles exist and `skill_source_catalog.md` is the pointer, so no count is stated here: a number in this file would be a derived value the ADR does not own. A principle whose subject is this repository's own conventions rather than a text is not in the corpus, which is the boundary decision that kept `numbering` and `linking` project-scoped.

## 2026-11-05 -- The cut test is the document's purpose, and the principle is renamed

**Decision:** `communication-principle-cut-what-serves-nothing` replaces `communication-principle-cut-what-carries-nothing`. A document's purpose is fixed by its Diataxis mode, so the question a sentence answers is whether it serves that purpose, not whether it carries information. A sentence serving another mode's purpose is cut and pointed at, because the document of that mode is the authority for that job and a copy here drifts from it unseen -- `principle-single-source-of-truth`'s unit, one subject in one mode, applied across documents.

**Rationale:** Carrying nothing was defined against no purpose, so the test presupposed a reader who acts: in a document whose reader came to understand or to consult, every informing sentence passed, and an explanation inside a how-to was invisible to the rule that exists to remove it. The mode is the purpose, and it makes the two failures one: a sentence true anywhere and a sentence belonging to another document both answer the same question, and fail it. Diataxis is where the corpus already takes its mode vocabulary from, recorded at `docs/adr/documentation_quadrants.md`, so the principle names the framework instead of restating a taxonomy.

**Rejected alternatives:**

- *Keep the name and widen the definition.* **Intent failure**: the name states the old test, and a reader who routes on it applies the information test whatever the body says.
- *Carry the framework's quadrant map in the principle.* **Boundary failure**: the mapping from quadrant to this repository's corpus is `documentation_quadrants.md`'s, and a shipped principle repeating it drifts from the ADR.
- *Treat the mode mismatch as a principle of its own.* **Execution failure**: it is one question reached two ways, so a second principle would answer it twice.

**Edge cases / drivers:** The rename moved eight carriers -- the seed and installed copy, the shipped index, four principle cross-references, `project-documentation`, `scope.md`, and the `writing-for-agents` fork's inline names -- which is the cost of a name that states a test. The fork's registry record carries the divergence.

## 2026-11-05 -- A judgement about writing an instruction is a pattern, and the corpus keeps judgements about any text

**Decision:** `principle-prose-entrypoint-over-mechanism` retires, and the judgement lives at `instruction-authoring/patterns/prose-entrypoint.md`. Its subject is the instruction artifact -- a skill or a prompt -- and its object is a script, a library or a service with a fixed call shape: two surfaces over one utility, where the mechanism is what can be designed and tested and the instruction is the human-friendly surface that turns an intent into a call. Which surface carries the entrypoint stays step 2's decision, cited from the pattern and not restated in it. `SKILL.md` step 2 now states the complement of its own criterion: a judgement that applies to any text makes a principle skill, and a judgement about the writing of an instruction is a pattern in that skill. The installed copy is removed.

**Rationale:** Every term of the judgement needs an instruction artifact before it has a referent. A caller is an agent firing the instruction, an invocation is the command line the instruction emits, and the disposition it recommends -- split the artifact into a prose surface and a mechanism that keeps the call -- is a decision about what an instruction is made of. A reference document, an ADR or a README that mentions a script has no caller and no invocation, so it can neither satisfy the judgement nor violate it, and its five withholding conditions are not one of them decidable on a document that is not an instruction. Strip the authoring residue and what remains -- two surfaces holding one call drift apart with nothing reporting it -- is `principle-delegation-over-machinery`'s own `**Why.**`, with `principle-single-source-of-truth` behind it, so a principle version would restate two members and claim a universality it cannot support. Left in the corpus it spends a loaded description in every session that is not writing an instruction over a mechanism, and it makes the corpus's own definition false.

**Rejected alternatives:**

- *Keep it in the corpus and narrow the description.* **Intent failure**: the corpus is defined by applying to any text, so a scoped member falsifies the definition rather than correcting it -- the same ruling this ADR records for the handoff judgement.
- *Delete it, since two principles already carry the general part.* **Information failure**: the residue is not in the corpus -- which surface the entrypoint is, and where its body stops -- so a deletion drops the part only an author needs.
- *State the skill-or-prompt choice in the pattern.* **Boundary failure**: step 2 already decides it by whether the artifact carries files beside its body, and a second statement of one criterion is the duplication `principle-single-source-of-truth` forbids.
- *Fold the judgement into `references/skill-conventions.md` as prose.* **Form failure**: three prerequisites, five withholding conditions and an answer that can be "write no instruction" are declinable, and a convention paragraph reads as a rule for every skill, most of which wrap nothing.

**Edge cases / drivers:** The pattern landed on 2026-10-22 under `skill-scaffolder/`, and the scaffolder's consolidation into `instruction-authoring` carried it there without closing its roadmap row; the installed principle stayed behind and the two copies diverged in one cell -- "a fixed run's values" against "a run's values" -- which is the drift the pattern's own `## Why` predicts. The pattern keeps its name: `prose-entrypoint` names the mechanism, and widening the subject leaves the mechanism unchanged. No repository file ever carried the principle, so the retirement removes a mounted copy and ships nothing: `$AGENT_HOME/agent/skills/` is a bind mount, and `git ls-files` names no copy.

## 2026-11-05 -- The handoff judgement is scoped to an invoked unit, and lives in the authoring sheet

**Decision:** `communication-principle-hand-off-by-naming-the-boundary` retires into `instruction-authoring`, at `patterns/handoff.md`, and the principle corpus stops carrying it. The judgement is in force for a unit that is **invoked and whose end continues into another run**; code, a reference, a tutorial and an ADR each fail that criterion, the ADR for a second reason, that `decision-records` already owns its supersession field. `references/forms.md` is renamed `references/body.md`, and its runbook section and its shared-shape slot cite the pattern rather than carry it.

**Rationale:** The previous entry widened this judgement to any handoff, on the ground that the seam exists at every level. That ground is real and it is not the test: the four moves name what a continuing job owes the job after it, so a text with no run to continue, or no run at all, meets them by accident. Left in the principle corpus, a judgement about one document class claimed the standing of a judgement about any text, which costs every session a loaded description and every reader a claim that does not hold for their file. The pattern form keeps the instruction available to the writer who needs it without asserting it as a rule everywhere: a runbook that ends inside its own scope omits the handoff, so the sheet may cite a pattern and may not impose a step.

**Rejected alternatives:**

- *Keep it in the corpus and scope the description.* **Intent failure**: the corpus is defined by applying to any text, so a scoped member makes the corpus's own claim false rather than correcting it.
- *Leave the four moves in the runbook section of the body sheet.* **Boundary failure**: the sheet states the body's shape for every form, so a four-move procedure there reads as required of an advisor and a reference too, and the file already carried three forms it could not impose on all of them.
- *Repoint `principle-match-precision-to-stakes` at the new pattern.* **Layer failure**: a shipped principle may not name a project path, and the two judgements shared only the word "stop".
- *File a new roadmap row instead of reopening the closed one.* **Record failure**: the superseded ruling would have sat beside the replacement with no mark on it, so a reader would find two closures of one question.

**Edge cases / drivers:** The pattern is offered, not required, so no gate holds its four moves; the shipped index loses its entry and gains nothing, because the subject is no longer a whole-artifact judgement in that corpus. `prose-review` cites the body sheet from another module, so the rename was found by grep and not by the sheet's own carried-file table. Closed records keep the old filename, since they describe what happened then.

## 2026-11-05 -- The unit is a subject and a mode, and a principle claims no moment

**Decision:** `principle-own-the-scope-you-declare` retires into `principle-single-source-of-truth`, which becomes the one home of the organizational judgement. The unit of ownership is a **subject together with a mode** -- tutorial, how-to, reference, explanation, from the Diataxis frame `docs/reference/documentation_taxonomy.md` records. One subject may be served by four documents, one per mode; two documents serving one mode for one subject are a second source. Content of one mode sitting in a document of another is out of place, and the four handling methods are link, move, remove, and widen. The agent may link and move; removing, or widening a unit to take material another unit carries, is the operator's. A rule is the same unit at its smallest grain.

A principle claims no moment. It is in force whenever the work is in front of the reader, and the `**Fires on.**` habit is replaced by a part that says where a reader meets it. A description names a situation for selection only, which is a routing fact and not a claim about the principle's reach; `references/skill-conventions.md` states the difference.

**Rationale:** The two files stated one judgement and no reader could tell which governed. The cause was an undefined unit: "a document owns the scope it declares" never said what a scope is, so any document could claim any content, and a second document of a different mode read as a duplicate when it was not. Defining the unit as subject and mode makes the duplicate decidable and leaves a subject's four documents legitimately distinct. The merge also removes the over-narrow reading: the retired file's description said "a workflow document", while its judgement holds for a module, a folder, a namespace and a rule alike. Removing the moment claim follows the same reasoning: a principle stated as belonging to a moment is not called up at the others, which is a plausible cause of the violations rather than a description of them.

**Rejected alternatives:**

- *Keep two files and cut only the duplicated sentence.* **Intent failure**: the unit stays undefined, so the duplicate regrows with the next edit, which is how it arrived.
- *Widen the scope file and leave SSOT alone.* **Intent failure**: two homes for one judgement, and the reader still cannot tell which governs.
- *Scope the handoff principle to skill authoring.* **Neither**: it is the seam at every level, so it stays in the general corpus, widened rather than narrowed. That is reversed by the entry above: the judgement is in force only for a unit that is invoked and whose end continues into another run, and it now lives in `instruction-authoring` as `patterns/handoff.md`.
- *Sweep `**Fires on.**` across the corpus now.* **Out of scope**: the rule is stated here and applied to the files this unit touches; a corpus-wide pass is its own task.

**Edge cases / drivers:** The five-item account the retired file carried -- input, decision, output, directions, evidence -- is not a checklist and does not survive as one. Its content is material of four modes, and the placement rule sends each to its own: the conditions a workflow runs under stay with the workflow, why they exist goes to the record of the decision, the contract its output must meet goes to the reference. `references/body.md` carries the worked splits. The four mode names are public, so the principle carries them with a one-clause gloss of each, which is what its unit of ownership needs. The folder mapping and the authoring guidance for each mode are this repository's, in `references/organization.md`, which names the principle for the classification.

## 2026-10-28 -- The principle shape carries no claim field

**Decision:** A principle skill carries the body shape and nothing else. The `metadata.claim` declaration is removed from every principle, the authoring convention's claim table is replaced by five question headings that group the corpus, and the gate drops the claim rule and its `--map` mode. The 2026-10-21 entry's Edge cases clause declaring the field is retired; the entry otherwise stands. The five questions live in `docs/development/prompt-authoring-conventions.md` `## The five questions`: can this sentence be checked, is this the source or a copy, does this name resolve where it is read, can the reader build the model the text assumes, who owns this decision. Each carries a linked member list, and the convention states that the lists are navigation and that no gate reads them.

**Rationale:** The field was a stored classification that nothing decided on. The gate checked that a claim was named and that the table held it, never that the filing was right, so swapping two filings passed and a mis-filing was undetectable. The five names were not exclusive either: `scope` and `authority` both bounded a text, and `evidence` and `source` both traced where a fact came from. A stored judgement that no check can falsify and no reader acts on charges a declaration per file and teaches an author to classify rather than to write. The tests are the useful part, and a reader meets them in one place, so the labels go and the tests stay.

**Rejected alternatives:**

- *Give the field a consumer.* **Intent failure**: the consumer would inherit the overlap, because `scope` and `authority`, and `evidence` and `source`, would each claim the same principle, so it would need a tie-break the field cannot supply.
- *Re-derive the axis bottom-up from the twenty-seven tests.* **Neither**: the tests were already written per skill, so a re-derivation would land near the same five, and it would still need a reader to be worth storing.
- *Gate the member lists for coverage.* **Intent failure**: the lists are navigation for a writer using the conventions and the description is the routing surface, so a missing name costs a reader nothing and a gate would guard a copy the text does not need.

**Edge cases / drivers:** The rule that no skill or prompt declares a claim is prose only, with no detector: it is verified once at the close that removed the field, and nothing guards it after that. The five questions name where a decision fails to cross from the writer to the reader-agent, and the fourth is deliberately stated as whether the model gets built rather than as one technique for building it. A principle may bear on more than one question, and the index does not adjudicate.

## 2026-10-21 -- A principle skill carries six parts in one shape, and a gate holds it

**Decision:** Every skill whose directory name carries `principle-` carries the same body: a sentence-case title, one sentence stating the judgement, `**The pattern.**`, `**Why.**`, zero or more named parts, each a bold label ending on a period and labelled for what it carries, and `**The test.**`. The pattern states the wrong form beside the right one, and its vehicle follows the material: a table where a contrast exists, a list where the parts are steps. The title is the file's only heading. `scripts/check_document_shape.sh` reads those rules off every such skill and fails the gate on a departure, so the shape is a rule with an observer rather than a judgement. A writer copies the shape from the `instruction-authoring` convention's `references/skill-conventions.md` `## A principle skill`.

**Rationale:** The corpus held two shapes for the same parts, so the exemplar that M3.3.4 measures a new principle against was one of two answers, and a writer copying it met a third answer in the next file. Adopting the exemplar's own form keeps the roadmap's exemplar sentence and the acceptance criterion built on it unchanged. The shape is a rule by the test in [`instruction_modality.md`](instruction_modality.md): it asserts structure and asks the author to follow it, and a gate detects a departure, so it needs a home in the authoring convention and an observer in the lint umbrella. The gate's subject is derived from the name instead of listed, so a new principle is covered the day its directory exists.

**Rejected alternatives:**

- *Convert the corpus to `##` headings.* Ten files already used them, and a rendered skill gains a table of contents and named anchors. The exemplar would be the non-conforming file until it converted, so the acceptance criterion could not be read mid-iteration, and the roadmap's exemplar sentence needed rewriting.
- *State the shape and leave the files.* A statement with no observer is a model, and the drift returns at the next author, which is how it arrived.
- *Require the pattern table.* Ten of the 22 state the pattern as a list, and a table there would assert a contrast the judgement does not draw. The required part is the contrast, not the vehicle.
- *Exempt `principle-guard-the-context-window`.* Its body is a bulleted procedure under `**Why:**` and `**Pattern:**`. An exemption is a second shape, which is the defect the decision removes.

**Edge cases / drivers:** A principle declares the claim it applies in the frontmatter's `metadata` key, as `metadata:` then `claim: <name>`, and the claim names are declared once in `docs/development/prompt-authoring-conventions.md` `## The principle claims`. The gate reads the set from that table and fails a principle that declares none or names one the table lacks, while which claim a given skill picks stays a judgement. A part is any bold label ending on a period, not the `Where ...` form alone, because the corpus labels parts for what they hold as well as for when they apply. A title that needs an acronym or a proper noun fails the rule until a non-first word may begin uppercase, and that widening is one edit to the rule rather than a per-file exception. A skill whose subject is a procedure rather than a judgement keeps the runbook shape and sits outside the rule's subject, which the `principle-` segment of the name draws.
