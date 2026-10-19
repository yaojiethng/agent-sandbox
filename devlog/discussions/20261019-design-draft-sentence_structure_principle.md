# Sentence structure: the attach-as-you-read principle

**Status:** draft

## Context

Three lines in `documentation_policy.md` `### Simplified Technical English` prescribe sentence structure, and a writer cannot tell whether they are three rules or one. The lines are active voice with a named actor, the defined noun phrase before the imperative command, and no thin subject that depends on a trailing dash clause. Each names a different surface fact. A writer who wants the reason behind them has no single statement to apply.

This design answers three questions. At what stratum do the three lines live. Whether they collapse into one principle. And what the principle is, so a writer can apply it at the moment of drafting and reject a sentence that violates it.

The trigger is an operator observation that the three lines "grasp at linguistic concepts around sentence structure" without naming the concept. The design is a study under M3.3.4, whose plan row `Plan the communication standard into principle specs` files the judgement rows of `documentation_policy.md` as principle skills. This design produces the principle for these three lines and no skill.

## Options Considered

- **Three separate principles, one per line.** Rejected. The three share one cause, so three principles state the same test three times and a writer meets the mechanism three times. It is the duplication the canonical-owner test forbids.
- **One principle that restates the three lines as one imperative.** Rejected. "Write sentences that are easy to read" names no decision and changes no draft. It is a no-op, the class `prompt-authoring-conventions.md` names.
- **One principle at the reader-processing stratum, with the three lines as its pattern table.** Adopted. The principle states the mechanism; the table keeps the three surface moves distinct, because they are distinct processing costs.
- **Defer to the field and cite the standards alone.** Rejected. The public standards keep the three as separate rules and never state why, so citing them leaves the writer where the three lines left them.

## Decision

### The stratum

The three lines live at different descriptive strata.

- Active voice is argument-structure alignment. It maps the actor to the syntactic subject, so the reader meets the actor first.
- Noun before command is information structure. It places given material before new material, so the reader anchors the new term.
- No thin subject with a dash clause is syntactic weight and closure. It keeps the main clause complete, so the reader does not hold a dependency open.

They share one stratum below all three. Reading is incremental and resource-limited. The reader builds structure left to right, attaches each phrase to what is already built, and holds unresolved material in a limited memory. Each line lowers a different integration cost, and each cost is a drain on the same budget. The unifying claim is that the reader integrates as they go, so a sentence is hard when it forces the reader to hold material or revise an expectation.

### The principle

**Keep the reader attaching.** Write so a reader who attaches each phrase as it arrives never holds material in memory or revises an expectation.

### The pattern table

| Instead of | Give |
|---|---|
| a passive that hides the actor | the actor in the subject slot |
| a term used before the reader has met it | the term established, then used |
| a modifier that splits the subject from its verb | the main clause whole, the modifier after it |
| a long condition ahead of the main clause | the main clause first, the condition after |
| a clause the reader must reanalyse at the end | the reading that holds from the first word |

The test. Read the sentence left to right. At each phrase, can it attach to structure already built? If the reader must hold a word for a later attachment, supply an antecedent the sentence never gives, or abandon an analysis already built, rewrite it.

### The boundary

The principle is a default, and each of these overrides it.

1. A passive is correct when the agent is unknown or unimportant, or when the patient is the topic. "The sample was contaminated" should not invent an actor.
2. End-weight can override given-before-new. A short given element usually precedes a long new one, but a heavy constituent may move first when the alternative creates a longer dependency.
3. A longer, explicitly marked construction can beat a shorter garden path. "The horse that was raced past the barn fell" is longer than "The horse raced past the barn fell" and is unambiguous.
4. Deliberate fronting for emphasis is a rhetorical choice. It violates the default and pays the integration cost on purpose.
5. Quoting a source verbatim keeps its wording even when that wording violates the principle. Fidelity outranks the default.

### The corpus and the failure classes

Eighteen sentences of this repository's own prose that a reader misread, mined from `devlog/AGENT_FEEDBACK.md`, the prose diffs of `docs:`, `workflow:` and `fix:` commits, and the Findings sections of handovers that describe a document defect. Each is classified by the integration cost it imposes. Rows 1, 2, 3, 4, 15 and 16 quote sentences that no longer stand; the old text is from the commit diff named by the source, with the correcting handover.

| id | sentence | failure class |
|---|---|---|
| 1 | A correction to the work of a closed iteration folds into that iteration's commit, at the operator's direction, and never opens a new one; the record amendments ride with the fold. | misattached-modifier |
| 2 | A closed document is edited only at the operator's direction, and every edit carries the corresponding correction tag. | unresolved-referent |
| 3 | A hard line break falls on a sentence or paragraph boundary, never mid-thought. | other (vague predicate) |
| 4 | The maintained tier -- policies, ADRs, concept docs, architecture docs -- is always the right link target, and linking into it freely is encouraged. | other (appositive splits subject and verb) |
| 5 | Do not estimate the window any more, read it | wrong-agent |
| 6 | Set a turn budget names nothing an agent can count | unresolved-referent |
| 7 | the payload, not a summary, used to go in the main thread | other (narration, no current state) |
| 8 | this replaces the version that said X | unresolved-referent |
| 9 | avoid or re-check those patterns | unresolved-referent |
| 10 | do not use an em-dash | other (prohibition names no permitted form) |
| 11 | the repository is copied | wrong-agent |
| 12 | Pi drops a prompt whose frontmatter does not parse without a message in the session | garden-path |
| 13 | changelog: their shape | misattached-modifier |
| 14 | Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active. | other (scope ambiguity) |
| 15 | A skill sets it when the operator should trigger it deliberately and the agent should not reach for it unprompted, which covers every `principle-` skill, the two quality skills and the two loop runbooks that set it. | misattached-modifier |
| 16 | a project-level `.pi/settings.json` override takes precedence | unresolved-referent |
| 17 | do not re-derive the tree | unresolved-referent |
| 18 | option B of the three | unresolved-referent |

### The measurement

Two blind readers, on two different models, read the eighteen sentences with no repository context and no statement of the intended meaning, and reported for each the proposition they gathered and any inference they supplied. The raw transcripts are the run outputs of this study.

Against the intended meaning, the blind readers reproduced the failure on 17 of 18 sentences. Each chose the reading the writer did not intend, and reported the same cost the class names. The wrong-agent sentences drew "the passive withholds the actor". The garden-path sentence drew three readings. The unresolved-referent sentences drew "the demonstrative points outside the sentence". The misattached-modifier sentences drew the modifier on the wrong controller. The two readers agree on 17 of 18 rows, and their reasons agree on the class in every row. Sentence 10 is the partial row. Both readers gave the prohibition and neither noted that it names no permitted form, which is the defect; a prohibition is read as complete by a literal reader.

A control set of six corrected sentences was read the same way. The readers recovered the intended meaning on six of six, with one minor scope ambiguity. The two sets separate on the comprehension predicate, which is whether the recovered proposition matches the one the writer intended.

A length proxy does not separate the sets. The eighteen corpus sentences average 13.6 words and the six corrected sentences average 15.2. Word count is not the mechanism. The integration structure is. This is the expected result and it rules out the crude fix of shortening sentences.

A Universal Dependencies parse was not run. The container carries no `python3` and no parser, and none was installed. The dependency-distance claim therefore rests on the mechanism in the literature and on the blind-reader outcome, not on a measured mean dependency distance. This is the study's largest gap and it is named rather than hidden.

### The reconciliation

Every one of the three surface moves is a published rule, and the field keeps them separate. The quotes are fetched from the public guidance.

| Move | Source | Rule text |
|---|---|---|
| Actor in the subject | plainlanguage.gov (GSA archive) | "In an active sentence, the person or agency that's acting is the subject of the sentence." |
| Actor in the subject | GOV.UK | "Use the active voice rather than the passive voice." |
| Actor in the subject | SEC Plain English Handbook | "When in doubt, choose the active voice." |
| Given before new | plainlanguage.gov (GSA archive) | "Establish a context for your audience before you provide them with the details." |
| Given before new | SEC Plain English Handbook | "First, present the big picture before the details." |
| Given before new | GOV.UK | "Put the most important information first." |
| Main clause whole | plainlanguage.gov (GSA archive) | "Keep subjects and objects close to their verbs." |
| Main clause whole | plainlanguage.gov (GSA archive) | "Put long conditions after the main clause." |
| Main clause whole | SEC Plain English Handbook | "Keep the subject, verb, and object close together" |

Two primary sources were not fetched. ASD-STE100 Issue 9 and ISO 24495-1 are not publicly available, so no rule text is quoted from them. The three lines in `documentation_policy.md` derive from the ASD-STE100 tradition, so the absent quote is a genuine gap.

The reconciliation is the design's load-bearing claim. The field states three rules and does not say why they are one family or what to do when they conflict. The principle supplies the why and the boundary supplies the conflict rule. So the principle does not replace the field's rules; it ranks them.

The literature supplies the mechanism. The given-new contract says new information is anchored to what the reader already has, so a missing anchor is a processing step. Dependency Locality Theory says the cost of a dependency grows with the distance the dependent is held, so a split main clause is costly. End-weight says heavy constituents go late. Garden-path work says a disconfirmed analysis forces a costly reanalysis. Surprisal says cost rises with unpredictability. Good-enough processing says a reader may settle for a shallow reading, which is why a misread is silent rather than felt. Each citation is recorded from memory and is marked unverified.

### The classification

`bash scripts/check_norm_ownership.sh --check` reports clean, 166 rows, 22 gated, 20 reviewed, 80 judgement, 44 model. The principle is a judgement with observer `none`. No gate can detect that a passive is wrong in this sentence, and no dispatched reading procedure names this check, so the ledger records it as a judgement and the evidence is the comprehension result, as the ledger requires of a judgement.

## Consequences

- The three lines resolve to one principle, `communication-principle-attach-as-you-read`, with the three moves as its pattern table. The plan row `Plan the communication standard into principle specs` consumes this design for those three lines.
- No skill is filed and `documentation_policy.md` is not edited by this study. The principle files when the operator settles the plan.
- The length proxy is retired as a fix. A later session that tries to satisfy the principle by shortening sentences will not move the outcome.
- The largest gap is the absent dependency parse. A follow-up can measure mean dependency distance on the corpus and the control if a parser is installed, and the design predicts the corpus carries the longer dependencies.
- The boundary is the part a gate cannot hold. If the principle is ever to become a rule, the observer must exempt the five override cases, which is itself a judgement.
