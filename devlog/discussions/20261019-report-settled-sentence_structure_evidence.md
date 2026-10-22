# Sentence-structure study: raw evidence

**Status:** settled

## Context

The raw artifacts behind [`20261019-design-settled-sentence_structure_principle.md`](20261019-design-settled-sentence_structure_principle.md). This report carries the parts that document does not reproduce, which are the blind-reader transcripts and the scoring. The corpus, the standards quotes and the literature table live in the design.

## The brief

One opencode worker mined the corpus from `devlog/AGENT_FEEDBACK.md`, the prose diffs of `docs:`, `workflow:` and `fix:` commits, and the Findings sections of handovers. One worker fetched the public plain-language rule text. One worker stated the parsing mechanisms. Two readers read the eighteen sentences with no repository context and no statement of the intended meaning: reader-b on `opencode/deepseek-v4.1-flash-free`, reader-c on `deepseek/deepseek-flash`. A third reader, reader-d, read the six corrected control sentences on `deepseek/deepseek-flash`. Each reader received only the sentence list.

## The scoring

| reader | set | sentences | intended meaning recovered | failure reproduced | notes |
|---|---|---|---|---|---|
| reader-b | corpus | 18 | 1 of 18 | 17 of 18 | sentence 10 partial; the prohibition was read as complete |
| reader-c | corpus | 18 | 1 of 18 | 17 of 18 | sentence 10 partial; the garden-path row drew three readings |
| reader-d | control | 6 | 6 of 6 | not applicable | sentence 6 carried one minor scope ambiguity |

The two corpus readers agree on 17 of 18 rows, and their stated reasons agree with the failure class in every row. The control reader recovered every intended meaning.

## reader-b, corpus

```text
## 1
text: A correction to the work of a closed iteration folds into that iteration's commit, at the operator's direction, and never opens a new one; the record amendments ride with the fold.
proposition: A correction to the work of a closed iteration folds into that iteration's commit. The fold happens at the operator's direction and never opens a new one. The record amendments ride with the fold.
inference: That "one" is a new commit or iteration; that "the fold" names the folding act just described; what "the record" is and what "ride with" means (accompany).

## 2
text: A closed document is edited only at the operator's direction, and every edit carries the corresponding correction tag.
proposition: A closed document is edited only at the operator's direction. Every edit to it carries the corresponding correction tag.
inference: That "corresponding" means matching that edit, and that a "correction tag" is an existing label whose form is not stated here.

## 3
text: A hard line break falls on a sentence or paragraph boundary, never mid-thought.
proposition: A hard line break falls on a sentence boundary or a paragraph boundary, never mid-thought.
inference: What a "hard line break" is; what counts as "mid-thought."

## 4
text: The maintained tier -- policies, ADRs, concept docs, architecture docs -- is always the right link target, and linking into it freely is encouraged.
proposition: The maintained tier consists of policies, ADRs, concept docs and architecture docs. That tier is always the right link target, and linking into it freely is encouraged.
inference: That "the maintained tier" is a category within some document scheme, and that "link target" means the target of a hyperlink.

## 5
text: Do not estimate the window any more, read it
proposition: Do not estimate the window any longer. Read the window.
inference: What "the window" refers to (a span of time, or a displayed region); that "read it" is offered as the replacement for estimating.

## 6
text: Set a turn budget names nothing an agent can count
proposition: The phrase "Set a turn budget" names nothing that an agent can count.
inference: That "a turn budget" is a budget of turns; that "an agent" is a program of some kind; that the missing article makes the quoted phrase the subject.

## 7
text: the payload, not a summary, used to go in the main thread
proposition: The payload, and not a summary, used to go in the main thread.
inference: That "used to" marks a former state now changed; what "the payload" and "the main thread" are.

## 8
text: this replaces the version that said X
proposition: This replaces the version that said X.
inference: What "this" refers to; what "X" stands for; that "the version" is a prior version of the same thing.

## 9
text: avoid or re-check those patterns
proposition: Avoid those patterns, or re-check those patterns.
inference: What "those patterns" are; that both verbs take "those patterns" as their object and "or" offers a choice.

## 10
text: do not use an em-dash
proposition: Do not use an em-dash.
inference: none

## 11
text: the repository is copied
proposition: The repository is copied.
inference: That the sentence is passive, so a copying agent is left unstated; that "the repository" is a specific repository.

## 12
text: Pi drops a prompt whose frontmatter does not parse without a message in the session
proposition: Reading A: Pi drops a prompt whose frontmatter does not parse, and it does so without a message in the session. Reading B: Pi drops a prompt whose frontmatter fails to parse without a message in the session (the absence of a message is a condition of the parse failure).
inference: That "Pi" is a program or tool; that "frontmatter" is a metadata block; that "drops" means discards and "parse" means succeeds as valid syntax.

## 13
text: changelog: their shape
proposition: changelog: their shape.
inference: That the fragment asserts or describes something, a verb being supplied; that "their" refers to some previously named plural.

## 14
text: Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active.
proposition: Non-active sub-milestones carry an objective paragraph and a scope paragraph only. There is no task checklist until the sub-milestone becomes active.
inference: That "carry" means contain; that "non-active" means not currently active.

## 15
text: A skill sets it when the operator should trigger it deliberately and the agent should not reach for it unprompted, which covers every `principle-` skill, the two quality skills and the two loop runbooks that set it.
proposition: A skill sets it when the operator should trigger the skill deliberately and the agent should not reach for it unprompted. That covers every skill whose name begins with "principle-", the two quality skills, and the two loop runbooks that set it.
inference: What "it" is (a setting or flag); that "which" refers to the condition or the set of skills so covered; which skills are "the two quality skills" and "the two loop runbooks".

## 16
text: a project-level `.pi/settings.json` override takes precedence
proposition: A project-level `.pi/settings.json` override takes precedence.
inference: What it takes precedence over (a default or another settings file); that "override" names a settings value.

## 17
text: do not re-derive the tree
proposition: Do not re-derive the tree.
inference: What "the tree" is (a directory tree or a parse tree); what "re-derive" means in context.

## 18
text: option B of the three
proposition: option B of the three.
inference: That there are three options; that one of them is labelled B; that the fragment identifies that option (a verb being supplied).
```

## reader-c, corpus

```text
# Reader report - sentences.txt

## 1
text: A correction to the work of a closed iteration folds into that iteration's commit, at the operator's direction, and never opens a new one; the record amendments ride with the fold.
proposition: When the work of an iteration that is already closed needs correcting, the correction is folded into that iteration's commit rather than placed in a separate commit; this happens only when the operator directs it; amendments to "the record" are folded in the same operation.
inference: Several referents are undefined here: "iteration", "commit", "fold", "operator", "record amendments". I supplied that "fold" means amend the existing commit rather than create a sibling, and that "the record" names a set of accompanying documents. The words do not settle what "never opens a new one" denies: read one way "one" refers to the nearest noun, a new commit; read the other way "opens" carries its usual object, a new iteration. Both readings are available from the words.

## 2
text: A closed document is edited only at the operator's direction, and every edit carries the corresponding correction tag.
proposition: A document in the state called "closed" is changed only when the operator directs the change, and each such edit bears a tag that corresponds to that correction.
inference: That "closed" is a lifecycle state a document can be in, and that a "closed document" is one that has reached it. The form of a "correction tag" is not given - the words assert one exists and must be attached, without saying what it looks like. "The operator" is a role the words do not define.

## 3
text: A hard line break falls on a sentence or paragraph boundary, never mid-thought.
proposition: A hard line break occurs at a boundary between sentences or between paragraphs, and does not occur inside a thought.
inference: What a "hard line break" is - the words name it but do not define it, so I supplied "a literal line break rather than one a viewer inserts by wrapping". "Mid-thought" is not a boundary I can locate from the words; no test distinguishes the inside of a thought from its end, so the prohibition names a condition the words do not operationalise.

## 4
text: The maintained tier -- policies, ADRs, concept docs, architecture docs -- is always the right link target, and linking into it freely is encouraged.
proposition: The set of documents called the maintained tier, enumerated here as policies, ADRs, concept docs and architecture docs, is always the correct target of a link, and linking into that set without restriction is encouraged.
inference: That "tier" partitions a larger document set, so some other tier exists that is not this one - the words name the members but not the contrast set. That "link" means a hyperlink from one document to another, and "link target" means the document pointed at. The appositive supplies the enumeration, so I did not have to guess the members.

## 5
text: Do not estimate the window any more, read it
proposition: Stop estimating the window. Read the window instead.
inference: What "window" is. The words give it as an object that can both be estimated and read, but do not say what it is, where it is read from, or by what means. "Any more" marks a change from an earlier practice, and the earlier practice is not stated; I supplied only that a practice is being ended.

## 6
text: Set a turn budget names nothing an agent can count
proposition: The phrase "set a turn budget" does not name anything that an agent can count.
inference: That the sentence is a claim about an instruction being unenforceable, which the words imply but do not say. "A turn budget" I read as a limit on turns; "count" I read as measure against a quantity. The words do not say whether turns are countable in principle, so the claim is stated, not demonstrated.

## 7
text: the payload, not a summary, used to go in the main thread
proposition: At a former time, the payload went into the main thread, and a summary did not go there.
inference: That "used to" places the state in the past and asserts it no longer holds; the words mark the change but do not describe the present state or the change itself. "The payload", "a summary" and "the main thread" are all undefined: I supplied that the payload is the full content and the summary is a reduced form of it, from the contrast between them, and that a thread is a conversation channel.

## 8
text: this replaces the version that said X
proposition: This thing replaces an earlier version, and that earlier version said X.
inference: "This" has no antecedent in the sentence. "X" is a placeholder standing for content the words do not give, so no claim is made about what the earlier version said. I supplied that a replacement means the earlier version is no longer current.

## 9
text: avoid or re-check those patterns
proposition: The reader is to avoid those patterns or to check them again.
inference: Which patterns "those" names - the demonstrative points outside the sentence, and no list is given, so the instruction cannot be carried out from the words. Who the reader is. The two readings of "or": one treats the verbs as alternatives, so either action satisfies the instruction; the other reads them as alternatives by stage, avoid where the pattern is known and re-check where it is not. The words do not choose between them.

## 10
text: do not use an em-dash
proposition: Do not use an em-dash.
inference: That "em-dash" names the punctuation character U+2014. The words do not say whether the ban reaches an en-dash, a double hyphen, or a spaced hyphen used for the same purpose; I supplied that the ban covers the character named and nothing more.

## 11
text: the repository is copied
proposition: An unstated actor copies the repository.
inference: The passive withholds the actor, so I supplied that some actor exists and performs a copy; the words do not name it. The destination, the timing and the purpose are likewise unstated. "Copied" could mean cloned with version history or duplicated as files without it; the words do not distinguish.

## 12
text: Pi drops a prompt whose frontmatter does not parse without a message in the session
proposition: Reading one: when a prompt's frontmatter fails to parse, Pi discards that prompt, and it does so without writing a message into the session. Reading two: when a prompt's frontmatter fails to parse, Pi discards that prompt silently, the qualifying phrase attaching to the discard rather than to the parse. Reading three: the phrase attaches to the parse condition, so a frontmatter that fails to parse when no message is present in the session causes the prompt to be dropped.
inference: What "frontmatter" is, what "parses" means here, what "Pi" is, and what a "session" is - all four are named without definition. The attachment of "without a message in the session" is the ambiguity above; I supplied the candidates and did not choose among them, because the word order admits all three.

## 13
text: changelog: their shape
proposition: A fragment, not a sentence. It names "changelog", then a colon, then attributes "their shape" to it. It gives no predicate, so no proposition is asserted beyond that the changelog and a shape belonging to something called "their" are being placed together.
inference: That the fragment is a label for a topic, and that what the topic asserts is supplied by context outside the words. "Their" has no antecedent here; I supplied that it refers to changelog entries, which the words do not state. Read as a heading, it announces a rule about the shape of a changelog; the rule itself is absent.

## 14
text: Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active.
proposition: For a sub-milestone that is not active, include an objective paragraph and a scope paragraph and nothing else; exclude a task checklist until that sub-milestone becomes active.
inference: That this is a formatting rule for a document, and that the document holds sub-milestones on a scale from inactive to active - the words give the two states but not the document. That "carry" means "contain". That "objective and scope paragraph" may mean one paragraph covering both or one paragraph each; the singular "paragraph" with a two-part modifier leaves both readings open.

## 15
text: A skill sets it when the operator should trigger it deliberately and the agent should not reach for it unprompted, which covers every `principle-` skill, the two quality skills and the two loop runbooks that set it.
proposition: A skill sets "it" in the condition where the operator is to trigger that skill deliberately and the agent is not to use that skill without being prompted; that condition covers all `principle-` skills, the two skills called quality skills, and the two loop runbooks that set it.
inference: "It" has no antecedent, so what is set - a flag, a setting, a field - is unstated and I supplied only that it is something a skill can set. "The two quality skills" and "the two loop runbooks" give counts without names; the words do not say which skills or runbooks these are. The final "that set it" restricts the runbooks to those among them that already set it, which the words state but do not enumerate.

## 16
text: a project-level `.pi/settings.json` override takes precedence
proposition: An override written in a `.pi/settings.json` file at project level takes precedence.
inference: Over what the override takes precedence is not stated. I supplied that the loser is a settings source at a broader level, by the contrast the word "override" sets up, but the words name no such source. That "project-level" locates the file in the project tree rather than a user or system location.

## 17
text: do not re-derive the tree
proposition: Do not derive the tree a second time.
inference: What "the tree" is, and what deriving it means. "Re-" tells me a derivation already happened, so a prior result exists; the words do not say where that result is kept or how to read it instead. I supplied that the point of the instruction is to use the existing result rather than compute it again, from the prefix alone.

## 18
text: option B of the three
proposition: A fragment naming one option, "option B", out of a set of three, and asserting nothing else.
inference: Which set of three options - the words number the set but do not name it. What option B contains. Whether "B" is a label attached to this particular option by the counting set or by the sentence; I read it as the second of three in listed order.

Sentences read: 18
```

## reader-d, control

```text
## 1
text: The seeder copies the repository into the workspace.
proposition: An agent or component called the seeder performs a copy; the thing copied is the repository; the destination is the workspace.
inference: The words do not say which seeder, which repository, or which workspace; the definite articles assume the reader already knows all three. That the copy is whole, and not a selection, is supplied by the reader. Whether an existing copy in the workspace is replaced or merged is not stated.

## 2
text: Write one paragraph per physical line. A hard line break separates blocks only, and never falls inside a paragraph.
proposition: Each paragraph occupies one physical line of the file. A hard line break has one function, separating blocks, and it does not occur within a paragraph.
inference: What a block is, and that a block is larger than a paragraph, is not stated. The second clause is worded as a fact about line breaks but is read as a rule for the writer. That a hard line break inside a paragraph is forbidden rather than merely absent is supplied.

## 3
text: Name the unit and the count before you start. Do not rely on the phrase "a turn budget".
proposition: Before starting, state the unit and state the count. Do not depend on the phrase "a turn budget".
inference: Neither the unit nor the count is identified; the reader supplies that the two form a quantity stated as unit plus number. What is started is not stated: the work, the account, or the sentence. The words do not say why the phrase fails, nor what to write instead.

## 4
text: Read the active tracker file. Do not scan the repository tree for it.
proposition: Read the active tracker file. Do not search the repository tree to find it.
inference: Because searching for the file is forbidden, the reader must supply that the file's location is already known. "It" is read as the tracker file; a second reading takes "it" as the repository tree, which the words allow but which the sentence structure disfavours.

## 5
text: State the chosen behaviour by name, and list the rejected alternatives.
proposition: Give the chosen behaviour and give its name. Enumerate the alternatives that were rejected.
inference: That a choice has already been made, and that some set of alternatives was rejected, is not stated but assumed by the imperatives. That the chosen behaviour already carries a name, rather than needing one invented, is supplied. The order of the two actions is not stated.

## 6
text: Pi discards a prompt whose frontmatter does not parse. It prints no message to the session.
proposition: Pi discards a prompt when that prompt's frontmatter does not parse. Pi prints no message to the session.
inference: "Pi" is read as the agent runtime and "frontmatter" as a leading metadata block of the prompt file. That a discarded prompt does not run, and that "It" is Pi, are supplied. Ambiguous scope: the second sentence yields two readings, (a) no message at all reaches the session, and (b) no message about the discard reaches the session. Whether the discard is silent to the prompt author as well is not stated.

Sentences read: 6
```

## The corpus, as produced

```text
# A corpus of repository prose a reader misread

Prose from this repository that a reader misread, or that a writer corrected because its meaning was not recoverable from the words alone. Each row quotes the sentence as it stood, cites its source, and pairs the literal reading (what a reader who follows the words exactly, and infers no intent, would conclude) with the intended meaning. The sources mined are `devlog/AGENT_FEEDBACK.md`; the diffs of `docs:`, `workflow:` and `fix:` commits that changed prose; the Findings sections of `devlog/handovers/*.md` that describe a document defect; and `docs/policies/documentation_policy.md` with `docs/development/prompt-authoring-conventions.md`. Every source yielded at least one usable row. A sentence removed from the tree is quoted from the commit whose diff removed it, with the handover that records the correction named beside it.

| id | sentence | source | literal reading | intended meaning | failure class |
|---|---|---|---|---|---|
| 1 | A correction to the work of a closed iteration folds into that iteration's commit, at the operator's direction, and never opens a new one; the record amendments ride with the fold. | `docs/policies/git_policy.md`, removed in `6235ca4f` (handover 20261018-08) | Every correction needs the operator's direction before it can be folded. | Only a correction to a session that has ended needs the operator's direction; while the session is live, the agent folds its own correction without asking. | misattached-modifier |
| 2 | A closed document is edited only at the operator's direction, and every edit carries the corresponding correction tag. | `docs/policies/documentation_policy.md`, removed in `5e28705e` (quoted in `docs/adr/closed_record_corrections.md`) | No document may be edited until the operator first gives direction. | A closed record's correction needs the operator's direction once the producing session has ended; a live correction is folded by the agent. | unresolved-referent |
| 3 | A hard line break falls on a sentence or paragraph boundary, never mid-thought. | `docs/policies/documentation_policy.md` `### Line wrapping`, removed in `4f780ac2` (handover 20260901-11) | A hard line break is allowed to fall at a sentence boundary. | Never break inside a paragraph; hard breaks separate blocks only. | other |
| 4 | The maintained tier -- policies, ADRs, concept docs, architecture docs -- is always the right link target, and linking into it freely is encouraged. | `docs/policies/documentation_policy.md` `### Link sparingly`, removed in `27c638b0` (handover 20260930-05) | Link freely into the maintained tier; more links into it are better. | Durable documents do not decay, so their links stay valid; the defect to avoid is over-linking transient documents. | other |
| 5 | Do not estimate the window any more, read it | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:31` (former clause of `principle-guard-the-context-window`, handover 20261018-02) | A reader that has been estimating the window must stop; the sentence corrects a behaviour the reader has been doing. | Read the window with `--context` and quote the reading; the original was read by a model that never saw the "estimate" version, so it named a behaviour the reader never had. | wrong-agent |
| 6 | Set a turn budget names nothing an agent can count | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:32` | A statement about the phrase "set a turn budget", read as a claim about that phrase. | Name the unit and the count before starting; the sentence refers to an earlier formulation the reader has not met. | unresolved-referent |
| 7 | the payload, not a summary, used to go in the main thread | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:33` | A narration of where the payload once went. | The main thread keeps the summary; state the current rule, not its history. | other |
| 8 | this replaces the version that said X | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:34` | A note about a prior version, where X has no referent the reader can resolve. | The rule as it now reads. | unresolved-referent |
| 9 | avoid or re-check those patterns | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:37` (former GOTCHAS standing directive, handover 20260921-03) | A prohibition that names no action; a literal reader turns it into a free-floating task. | Apply the durable fix the entry's `scoped:` row names. | other |
| 10 | do not use an em-dash | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:37` | A prohibition; the reader must invent a permitted form. | Write a space-separated hyphen. | other |
| 11 | the repository is copied | `docs/policies/documentation_policy.md:55` | The repository is copied, by no named actor. | The seeder copies the repository; name the actor. | wrong-agent |
| 12 | Pi drops a prompt whose frontmatter does not parse without a message in the session | `docs/development/prompt-authoring-conventions.md:68` | Pi drops a prompt that does not parse and carries no message, in the session. | Pi drops the prompt silently, printing no message to the session. | garden-path |
| 13 | changelog: their shape | `devlog/AGENT_FEEDBACK.md:73` (the `description` value in `.agents/skills/task-list/SKILL.md`) | A mapping with key "changelog" and value "their shape". | A plain description string reading "changelog: their shape". | misattached-modifier |
| 14 | Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active. | `devlog/AGENT_FEEDBACK.md:733` (quoting `roadmap_policy.md` `### Record shape`) | A milestone that is not active must carry no task checklist. | The invariant the practice relies on: a milestone holding open rows is never Complete, and a milestone's rows move with it. | other |
| 15 | A skill sets it when the operator should trigger it deliberately and the agent should not reach for it unprompted, which covers every `principle-` skill, the two quality skills and the two loop runbooks that set it. | `docs/development/prompt-authoring-conventions.md`, removed in `8c9ca81c` (handover 20261019-02) | Every `principle-` skill sets `disable-model-invocation`. | The condition decides: set it on a skill the operator fires deliberately; a judgement skill does not set it. | misattached-modifier |
| 16 | a project-level `.pi/settings.json` override takes precedence | `src/reasoning/providers/pi/config/agent/AGENTS.md`, removed in the commit recorded by handover 20261015-02 | A project-level `.pi/settings.json` overrides the settings resolved elsewhere. | The clause was dropped from the provider layer, which also says to put configuration in `$AGENT_HOME`, not a project-level `.pi`. | other |
| 17 | do not re-derive the tree | `src/reasoning/providers/pi/config/agent/prompts/pop-task.md`, recorded in handover 20261015-20 | Do not recompute the tree, with no tree named. | Read only the active tracker; do not re-read the repository tree. | unresolved-referent |
| 18 | option B of the three | `src/reasoning/providers/pi/config/agent/skills/communication-principle-write-for-the-reader/SKILL.md:15` (the same defect named in `.agents/skills/numbering/SKILL.md`) | The reader must find "option B" in a list of three that they cannot see. | State the chosen behaviour, named, with the rejected alternatives stated. | unresolved-referent |

## Notes

Rows 1, 2, 3, 4, 15 and 16 quote sentences that no longer stand in the tree; the exact old text comes from the named commit's diff, and the correction is recorded in the named handover. Rows 5 to 10 and 18 quote the "instead of" forms the write-for-the-reader and numbering skills keep as the bad shape to avoid; rows 5 to 8 were real clauses of `principle-guard-the-context-window`, rewritten by commit `18eef596` and recorded in handover 20261018-02. Row 13 quotes a YAML value that a parser read as structure, so the "reader" is the frontmatter loader rather than a person. Rows 14 and 17 are quoted from the feedback and handover text that preserves the withdrawn wording.
```

## The standards, as produced

```text
# Plain-language rule text - primary sources

Extracted verbatim rule text answering three questions: actor in the subject slot (question 1), order with the familiar before the new (question 2), and a self-contained main clause (question 3). Each quote is reproduced exactly as fetched and carries the url it was fetched from. Punctuation was normalized to ASCII. The plainlanguage.gov guideline pages now redirect to digital.gov, so the per-rule text is quoted from the official GSA/plainlanguage.gov archive named by digital.gov; the current digital.gov guide carries the active-voice rule.

| question | source and url | exact quoted rule text |
|---|---|---|
| 1. Actor in the subject slot | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/conversational/use-active-voice.md | "In an active sentence, the person or agency that's acting is the subject of the sentence." |
| 1. Actor in the subject slot | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/conversational/use-active-voice.md | "Active voice makes it clear who is supposed to do what." |
| 1. Actor in the subject slot | GOV.UK content and publishing guidance, https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/clear-language/ | "Use the active voice rather than the passive voice." |
| 1. Actor in the subject slot | SEC Plain English Handbook (via Internet Archive), https://web.archive.org/web/2023id_/https://www.sec.gov/pdf/handbook.pdf | "Use the active voice with strong verbs" |
| 1. Actor in the subject slot | SEC Plain English Handbook (via Internet Archive), https://web.archive.org/web/2023id_/https://www.sec.gov/pdf/handbook.pdf | "When in doubt, choose the active voice." |
| 2. Order, familiar before new | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/organize/have-a-topic-sentence.md | "Establish a context for your audience before you provide them with the details." |
| 2. Order, familiar before new | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/organize/make-it-easy-to-follow.md | "Another useful organizing principle is to put general information first, and specialized information or exceptions later." |
| 2. Order, familiar before new | SEC Plain English Handbook (via Internet Archive), https://web.archive.org/web/2023id_/https://www.sec.gov/pdf/handbook.pdf | "First, present the big picture before the details." |
| 2. Order, familiar before new | GOV.UK content and publishing guidance, https://guidance.publishing.service.gov.uk/writing-to-gov-uk-standards/writing-guidelines/clear-structure/ | "Put the most important information first." |
| 3. A self-contained main clause | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/concise/keep-the-subject-verb-and-object-close-together.md | "When you put modifiers, phrases, or clauses between two or all three of these essential parts, you make it harder for the user to understand you." |
| 3. A self-contained main clause | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/words/place-words-carefully.md | "Keep subjects and objects close to their verbs." |
| 3. A self-contained main clause | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/words/place-words-carefully.md | "Put long conditions after the main clause." |
| 3. A self-contained main clause | PlainLanguage.gov (archived, GSA/plainlanguage.gov), https://raw.githubusercontent.com/GSA/plainlanguage.gov/main/_pages/guidelines/concise/write-short-sentences.md | "Sentences loaded with dependent clauses and exceptions confuse the audience by losing the main point in a forest of words." |
| 3. A self-contained main clause | SEC Plain English Handbook (via Internet Archive), https://web.archive.org/web/2023id_/https://www.sec.gov/pdf/handbook.pdf | "Keep the subject, verb, and object close together" |
| 3. A self-contained main clause | SEC Plain English Handbook (via Internet Archive), https://web.archive.org/web/2023id_/https://www.sec.gov/pdf/handbook.pdf | "The natural word order of English speakers is subject-verb-object." |

## Not fetched

- ASD-STE100 Issue 9 (Simplified Technical English) - not publicly fetchable; the specification is a paid, controlled document, so no rule text is quoted.
- ISO 24495-1 (Plain language - Part 1: Governing principles and guidelines) - not publicly fetchable; the standard is behind the ISO paywall, so no rule text is quoted.
- SEC direct url https://www.sec.gov/pdf/handbook.pdf returned HTTP 403 (Request Rate Threshold Exceeded); the same document was obtained from the Internet Archive snapshot cited above.
```

## The literature, as produced

```text
# Literature - parsing mechanisms

## 1. Given-new contract

The given-new contract says a sentence's new information must be linked to information the comprehender already has, and the reader's task is to find or build that link. This is a discourse-pragmatic relation: new material is anchored to an already-given referent, and the search for the anchor (e.g. a bridging inference) is itself a processing step.

Citation: Haviland, S. E., and Clark, H. H. (1974). What's new? Acquiring new information as a process in comprehension.

verification: unverified

## 2. Dependency Locality Theory

Dependency Locality Theory holds that the memory cost of a syntactic dependency grows with the distance over which a predicted dependent must be held before it is integrated, so a long-distance dependency is harder than a short one. It is a claim about within-sentence syntactic memory, distinct from the discourse linking of the given-new contract.

Citation: Gibson, E. (1998). Linguistic complexity: Locality of syntactic dependencies.

verification: unverified

## 3. End-weight and Behaghel's law of growing constituents

Behaghel's law of growing constituents states that, other things equal, shorter constituents tend to precede longer ones; end-weight is the processing-facing observation that heavy (long or complex) constituents are placed late. The ordering reduces the load of holding a heavy constituent in memory while the rest of the clause is assembled.

Citation: Behaghel, O. (1909). Beziehungen zwischen Umfang und Reihenfolge von Satzgliedern.

verification: unverified

## 4. Garden-path sentences and reanalysis cost

A garden-path sentence is one whose locally preferred analysis is disconfirmed by later input, forcing the parser to abandon it and reanalyse. Reanalysis carries a measurable cost, and that cost tends to rise with how much structure must be revised.

Citation: Frazier, L., and Rayner, K. (1982). Making and correcting errors during sentence comprehension: Eye movements in the analysis of structurally ambiguous sentences.

verification: unverified

## 5. Good-enough processing

Good-enough processing is the finding that readers frequently settle for a shallow, heuristic representation of a sentence rather than a fully detailed syntactic and semantic parse. Interpretation can therefore be incomplete or partly wrong while still feeling fluent.

Citation: Ferreira, F., Bailey, K. G., and Ferraro, V. (2002). Good-enough representations in language comprehension.

verification: unverified

## 6. Surprisal and predictability in reading

Surprisal theory holds that processing difficulty at a word is a function of its surprisal, the negative log probability of that word given the preceding context under a probabilistic grammar; low predictability therefore raises cost. Predictability effects in reading (shorter reading times for high-probability words) are the empirical face of the same claim.

Citation: Hale, J. (2001). A probabilistic Earley parser as a psycholinguistic model.

verification: unverified

## Table

| mechanism | statement | citation | verification |
| --- | --- | --- | --- |
| Given-new contract | New information must be linked to information the reader already has; finding/building that discourse anchor is a processing step. | Haviland, S. E., and Clark, H. H. (1974). What's new? Acquiring new information as a process in comprehension. | unverified |
| Dependency Locality Theory | The memory cost of a syntactic dependency grows with the distance a predicted dependent is held before integration; long dependencies are harder. | Gibson, E. (1998). Linguistic complexity: Locality of syntactic dependencies. | unverified |
| End-weight / Behaghel's law | Shorter constituents tend to precede longer ones; heavy constituents are placed late to ease holding them while the clause is assembled. | Behaghel, O. (1909). Beziehungen zwischen Umfang und Reihenfolge von Satzgliedern. | unverified |
| Garden-path and reanalysis cost | A locally preferred analysis disconfirmed by later input forces reanalysis, at a cost that grows with the amount of structure revised. | Frazier, L., and Rayner, K. (1982). Making and correcting errors during sentence comprehension: Eye movements in the analysis of structurally ambiguous sentences. | unverified |
| Good-enough processing | Readers often settle for a shallow heuristic representation instead of a full parse, leaving interpretation incomplete or partly wrong. | Ferreira, F., Bailey, K. G., and Ferraro, V. (2002). Good-enough representations in language comprehension. | unverified |
| Surprisal and predictability | Word-level processing difficulty tracks surprisal, the negative log probability of the word given context, so low predictability raises cost. | Hale, J. (2001). A probabilistic Earley parser as a psycholinguistic model. | unverified |

## Synthesis

These mechanisms share one constraint: comprehension is incremental and resource-limited, so cost rises with the distance, uncertainty, or inferential work needed to integrate the current material into what has already been built. They are not one claim, though -- given-new constraint is a discourse-linking demand (finding an anchor for new information), whereas dependency locality is a within-sentence syntactic-memory demand (holding an unresolved dependent), and neither reduces to the other. Garden-path, good-enough, end-weight, and surprisal are further facets of that same limited-budget integration process.
```
