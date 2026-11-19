# Change a principle

Write the judgement only once the discussion has settled it. A principle written ahead of its discussion is rewritten within the week, and the rewrite costs the reading that the discussion would have saved. So run the change as a discussion, a butler pass and a write: the operator dictates the judgement, and the agent writes the file under [`communication-principle-rewrite-syntax-never-semantics`](../../../../src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-rewrite-syntax-never-semantics/SKILL.md).

- **Call it** from `/iter` when a row changes a principle, or from the operator at any time. A change arriving from elsewhere names this file to the operator.
- **Read the corpus** with `node scripts/principle_inventory.mjs`, and **read what a skill carries** in [`../references/principle-skills.md`](../references/principle-skills.md).

## Write discipline

- **An approval writes the artifact**, so a settled part lands in the skill file in the same unit of work and the file carries an incomplete principle while the gaps remain (`principle-approval-writes-the-artifact`).
- **The record keeps the evidence**, written as each decision lands, so a lost context resumes from it (the `work-log` convention's handover shape).

## Settle the judgement in discussion, in any order, and reopen a decision when a later one moves its ground

State back your understanding of the intent, take the correction or the research question the operator answers with, and repeat until the decision is settled.

- **Ask the operator for the purpose**, `metadata.intent` and `metadata.mechanism`, with the row's provenance, the operator's own words quoted from the logs, and the corpus's neighbouring intents.
- **Ask for the domain**: the field the judgement takes reference from, the terms it borrows, and the verdict on the research. Bring the field's primary sources, the candidate terms with their definitions, and what the corpus already borrows.
- **Ask for the scope and the body**: what the test inspects, the test, and the `**Why.**`. Bring the exemplar, the friction the test must catch, and the cost recorded where it landed.
  - **Write the `**Why.**` motivation first.** It answers what applying the judgement wins, in the operator's words or the operator's own communications, and a reader who sees the win applies the judgement.
- **Ask for the placement**: which action intent stands, and which neighbours it declares. Run the scan below and propose.
- **Ask for the action**: the title, the description, the leitwort, and the go-ahead. Bring the corpus's names, the routing rule, the gate's rule per field, and the diff the action would make.

## Converge on a presentation the operator can release

Restate the judgement in the operator's words, name the domain and the borrowed terms, state the scope and the test, and propose a placement with its evidence. A reader who can evaluate the skill from that presentation has what the gate needs. Releasing it makes the file the proto-skill, from which the operator answers the gaps, and a decision that moves the proto-skill reopens the discussion.

## Evaluate the proto-skill to find what the presentation left open

Check every part the shape demands against the conversation, gather the placement evidence the proto-skill now makes possible, and return a gap list.

- **Mine the discussion first.** Use each answer already given, in the operator's words, and ask again only for a part the discussion never reached.
- **Gather the scan.** Run one case from the record against each artefact near it, take the carrier census for the intent, and read the name as a cold reader meets it.
- **List the gaps.** Carry the evidence already in hand into each question and name what is missing, so the operator decides rather than searches.

## Take the supplement, and hold the finished file for review

Take the operator's words for each gap and write the part into the file, keeping the word choice, the semantics and the implementation details as they were said, and taking the keys, the bold lead-ins and the order from the shape.

- **Send a part back as a question** when it misses the shape's requirement.
- **Hold the finished file for review.** Run `bash scripts/check_principle_frontmatter.sh` and `bash scripts/lint.sh`, and check the skill's words against the conversation.

## Place the judgement by scanning one case against every artefact near it

Every intent answers the same question from the same comparison, so carry one case from the record into each scan and let its outcome name the intent.

- **Add** when nothing live claims the case: state the judgement in one sentence.
- **Consolidate** when two artefacts claim the case and reach one determination: name the survivor.
- **Split** when one artefact claims the case and answers it two ways: name each judgement with its own test.
- **Rename** when the name predicts a different test from the one the skill passes: name the replacement.
- **Remove** when the carrier census returns empty for owner rows, live pointers, tests and gate entries.

**Rerun the scan** when the operator names an intent it missed. The intent names the change; the doer proposes the method, ruled at the gate.

## Read the edge from the comparison, and settle a conflict as a case

The comparison names the edge, and a shared subject only tells you where to look. Record a conflict as a case and settle it by precedence.

- **Name the kind.** USE and UF are two names for one judgement and become a merge case. BT and NT are one judgement narrowing another and become a hierarchy case. RT is the same subject with a different judgement and becomes a neighbour. See-also is a handoff, so write it as prose. A contested pair is provisional and stays in the docket.
- **Declare the field on every skill.** `metadata.neighbours` holds the neighbours only, as a symmetric list of full skill names; write `[]` when no neighbour is declared, and the gate fails an absent field.
- **Separate by axis.** **Defect** is what fails. **Grain** is what the judgement inspects: term, sentence, passage, document, artifact, corpus. **Moment** is when it fires: propose, write, revise, review, admit. Two artefacts sharing a facet are co-located; read the comparison for the relation.
- **Settle the conflict by precedence.** Record the id, the parties, the issue as a question, the evidence, the status and the disposition. Try *lex specialis* when a BT/NT edge changes neither body, then *lex posterior* when the later decision was made with the earlier in view, then a scope note on each artefact, and stay the case last. Keep a conflict pair-local, since RT does not carry.

## Record each decision with the evidence it rested on

The record is what the next reader checks the skill against, so it holds the reasoning: the five decisions with the evidence each rested on, the presentation as released, the scan with the case and what each artefact determined about it, the gap list with what filled each gap, the edge when the change adds or moves one, and a witness for every finding.
