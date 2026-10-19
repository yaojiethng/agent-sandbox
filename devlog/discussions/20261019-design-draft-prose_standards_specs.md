# The prose-standards principle spec census

**Status:** draft

## Context

Milestone M3.3.4 files the prose standards that survive as principles. Two source documents hold them: [`documentation_policy.md`](../../docs/policies/documentation_policy.md) and [`prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md). This design is the plan for that filing; it files no skill.

The norm-ownership ledger `scripts/lint/norm-ownership.tsv` classifies every prose line of both documents into one of four kinds: `rule-gated`, `rule-reviewed`, `judgement` and `model`. Its five tab-separated columns are hash, source, kind, observer, text. A `judgement` line states how a writer decides and has no observer, so it is the candidate for a principle skill; a principle carries no gate and no authority claim, and it is the judgement's only home. The exemplar is [`communication-principle-show-dont-describe`](../../src/reasoning/providers/pi/config/agent/skills/communication-principle-show-dont-describe/SKILL.md).

The census reads 80 judgement rows, 36 from `documentation_policy.md` and 44 from `prompt-authoring-conventions.md`. The rows print with `awk -F'\t' '$3=="judgement"{print $2"\t"$5}' scripts/lint/norm-ownership.tsv`. This design resolves every row to one of two outcomes, then dedupes rows that state one judgement.

A row ref is the source line in the named document: `doc-NN` for `documentation_policy.md`, `pal-NN` for `prompt-authoring-conventions.md`. Each census row quotes the opening text of its ledger line; the quoted text is the citation, and the ref locates the line in the current source.

## Options Considered

- **One principle per judgement row, no dedupe.** Rejected: several rows state one judgement, so a row-per-principle rule files duplicates and breaks the one-judgement-one-principle rule the milestone's dedupe row carries.
- **Resolve each row to a spec or a stay, then dedupe to one principle per judgement.** Adopted: it leaves no row unowned and collapses restatements.
- **Absorb every judgement into the five filed principles.** Rejected: the five do not carry plain language, progressive disclosure, guidance specificity or step ownership, so the absorb rule loses those judgements.
- **Keep every row where it is and point at a principle.** Rejected for the rows that state a judgement: a pointer is not the judgement's home, and the milestone wants a standard a writer reaches for mid-draft to be a skill, not a search.
- **Treat the ASD-STE100 block as one principle.** Rejected: the block carries three judgements a writer reaches for separately, so it files as three.

## Decision

### Resolution rule

A judgement row **becomes a principle** when it states a decision a writer makes about what to say or keep. It **stays where it is** when it states the shape a document must have, a placement, a process step, a document-type obligation, a naming or reference convention, or a restatement of a rule already owned elsewhere. A row that stays keeps its home in the convention corpus, the lint gate, or the process that dispatches it. Rows that state one judgement resolve to one principle.

### Census: `documentation_policy.md`

| Ref | Ledger line (opening text) | Resolution |
|---|---|---|
| doc-9 | "Skill files and prompt templates are not documentation." | stays: document-type scope boundary |
| doc-23 | "**Producer owns the definition.**" | spec: `communication-principle-only-derive-what-you-own` (filed) |
| doc-27 | "**Policy membership.**" | stays: process step (fold, rename or delete a rule-less file) |
| doc-33 | "Each `docs/` document belongs to **exactly one** folder" | stays: folder placement |
| doc-37 | "Architecture documents must not describe things a frozen layer does not yet do." | spec: `communication-principle-describe-only-what-is-true` |
| doc-47 | "Workflow table Action cells hold one imperative sentence plus a link to the governing section" | stays: placement of detail in a table cell |
| doc-51 | "New and changed prose meets ASD-STE100." | spec: `communication-principle-write-plainly` |
| doc-55 | "- Active voice. Name the actor" | spec: `communication-principle-write-plainly` |
| doc-56 | "- Short sentences. Aim under 20 words" | spec: `communication-principle-write-plainly` |
| doc-57 | "- One term, one meaning." | spec: `communication-principle-one-term-one-meaning` |
| doc-58 | "- Common verbs." | spec: `communication-principle-write-plainly` |
| doc-59 | "- No idioms, no metaphors, no hedging" | spec: `communication-principle-write-plainly` |
| doc-60 | "- Place the defined noun phrase before the imperative command." | spec: `communication-principle-define-before-you-use` |
| doc-61 | "- Define a term the reader has not met first" | spec: `communication-principle-define-before-you-use` |
| doc-62 | "- Avoid thin subjects that rely on a trailing dash clause" | spec: `communication-principle-define-before-you-use` |
| doc-63 | "- Keep technical nouns the reader needs." | spec: `communication-principle-write-plainly` |
| doc-73 | "**Reserved technical terms** are defined in `docs/reference/terminology.md`" | stays: reference handling (link on first mention) |
| doc-96 | "- `**Status:**` is the first line after the title" | stays: header format |
| doc-97 | "- Superseded and resolved documents carry a blockquote redirect" | stays: header format |
| doc-98 | "- Reference and policy documents carry no status line" | stays: header format |
| doc-100 | "- Top-level sections use `##`; subsections use `###`" | stays: heading format |
| doc-125 | "Prefer durable targets." | stays: reference handling |
| doc-127 | "Place handoff links at the point of use." | stays: reference handling |
| doc-135 | "When many references point to one item, move it to a heading." | stays: reference structure |
| doc-145 | "When a policy or convention states a document's section order, present it as a fenced Markdown skeleton" | stays: section-order template |
| doc-158 | "Use this shape for every document type, in every policy." | stays: section-order template |
| doc-166 | "Pick the folder category before drafting." | stays: folder placement |
| doc-170 | "Before writing an ADR or a reference document, propose the skeleton in chat" | stays: process step |
| doc-184 | "Architecture documents carry no TODO items:" | spec: `communication-principle-describe-only-what-is-true` |
| doc-195 | "Move speculative design and TODO items to `roadmap.md`, the only task list" | spec: `communication-principle-describe-only-what-is-true` |
| doc-221 | "This section holds the obligations that apply per document type" | stays: section map |
| doc-225 | "A concept document is standalone and content-complete" | stays: document-type obligation |
| doc-231 | "Restate requirements as user-observable guarantees, without seam vocabulary" | spec: `communication-principle-write-for-the-reader` (filed) |
| doc-257 | "**Archival is not amendment.**" | stays: restatement of the correction rule |
| doc-273 | "- The referencing link carries a `[REMOVED]` marker" | stays: process step (missing-document handling) |
| doc-274 | "- The referencing link has no `[REMOVED]` marker" | stays: process step (missing-document handling) |

### Census: `prompt-authoring-conventions.md`

| Ref | Ledger line (opening text) | Resolution |
|---|---|---|
| pal-19 | "**Reference** documents state facts consulted on demand." | stays: document-type scope |
| pal-40 | "Progressive disclosure is the move down the ladder" | spec: `communication-principle-disclose-by-need` |
| pal-42 | "The failure mode is sprawl" | spec: `communication-principle-disclose-by-need` |
| pal-44 | "Co-location is the within-file companion." | spec: `communication-principle-colocate-what-belongs-together` |
| pal-46 | "**Degrees of freedom.**" | spec: `communication-principle-match-guidance-to-fragility` |
| pal-52 | "A **runbook** is a prompt or skill that holds ordered steps." | spec: `communication-principle-end-a-step-on-a-check` |
| pal-56 | "An **advisor** is a prompt or skill that holds reference and judgement" | stays: document-type scope |
| pal-58 | "The advisor-role split is explicit" | stays: process step (role and brief construction) |
| pal-62 | "Subagents receive `pi -p` with a brief" | stays: process step (brief construction) |
| pal-70 | "**Argument hint.**" | stays: frontmatter structure |
| pal-72 | "**Skill frontmatter.**" | stays: frontmatter structure |
| pal-74 | "**Suggested skill name.**" | stays: naming |
| pal-78 | "1. **The opening template line.**" | stays: body-order structure |
| pal-79 | "2. **Purpose** states what the prompt or skill is for" | stays: body-order structure |
| pal-80 | "3. **When to use** states the conditions that invoke it" | stays: body-order structure |
| pal-81 | "4. **The steps or the reference region** carries the work." | spec: `communication-principle-end-a-step-on-a-check` |
| pal-82 | "5. **The handoff.**" | stays: body-order structure |
| pal-83 | "6. **Non-goals** states what the prompt deliberately does not do" | stays: body-order structure |
| pal-84 | "7. **Failure modes and invariants** close a runbook" | stays: body-order structure |
| pal-86 | "**The project conventions block.**" | stays: body-order structure |
| pal-88 | "The workflow-document presentation rules ... A prompt is never the only home of a rule." | spec: `communication-principle-a-copy-points-to-its-source` |
| pal-92 | "One subject per prompt." | spec: `communication-principle-one-document-one-subject` |
| pal-94 | "Scope earlier shapes the authoring." | stays: restatement of the prompt-scope rule |
| pal-96 | "A prompt that hands off to a sub-agent states the target's whole owned-file set" | stays: process step (brief construction) |
| pal-98 | "**Context pointers and trigger branches.**" | spec: `communication-principle-one-trigger-per-branch` |
| pal-102 | "A workflow document is a consumer of the policy documents." | spec: `communication-principle-a-copy-points-to-its-source` |
| pal-104 | "1. The rule still exists in a policy document." | spec: `communication-principle-a-copy-points-to-its-source` |
| pal-105 | "2. The inline is labelled as a convenience copy where its staleness would mislead." | spec: `communication-principle-a-copy-points-to-its-source` |
| pal-115 | "A workflow document's subject is one step of a larger workflow." | spec: `communication-principle-own-the-step-you-write` |
| pal-117 | "The test is ownership, not duplication." | spec: `communication-principle-own-the-step-you-write` |
| pal-119 | "1. **Does it own the step it describes?**" | spec: `communication-principle-own-the-step-you-write` |
| pal-120 | "2. **Does describing another step make it look like it owns that one?**" | spec: `communication-principle-own-the-step-you-write` |
| pal-123 | "The failure this rule catches is a document that is locally accurate and globally unreliable" | spec: `communication-principle-own-the-step-you-write` |
| pal-127 | "A runbook that ends by handing to another prompt does it in four moves." | stays: handoff-pattern structure |
| pal-129 | "1. **Name the next prompt and the part that runs.**" | stays: handoff-pattern structure |
| pal-130 | "2. **List what the next prompt owns, and state that this prompt does not restate it.**" | stays: handoff-pattern structure |
| pal-131 | "3. **Name what stays, with its reason.**" | stays: handoff-pattern structure |
| pal-132 | "4. **State where this prompt stops and who picks it up.**" | stays: handoff-pattern structure |
| pal-144 | "When the content behind the reference matters to the agent working in the container" | stays: reference handling |
| pal-146 | "The same rule covers the inverse" | stays: reference handling |
| pal-152 | "A workflow document's name states its subject, not its mechanism." | stays: naming |
| pal-154 | "A name changes when its scope changes." | stays: naming |
| pal-158 | "A prompt or skill that is not yet operator-reviewed is a draft." | stays: process step (draft gate) |
| pal-7 | "The per-prompt quality passes read this document" | stays: process step (compliance) |

### Proposed principle set

The census proposes 12 new principle skills. Each states a writer judgement, matches the exemplar's shape (name, one sentence, pattern table, why, test), and cites the ledger lines it absorbs.

| Proposed name | One-line statement | Ledger lines it absorbs |
|---|---|---|
| `communication-principle-write-plainly` | Write the simplest wording that carries the meaning: active voice, short sentences, common verbs, no idiom or hedge, and keep the technical noun the reader needs. | doc-51, doc-55, doc-56, doc-58, doc-59, doc-63 |
| `communication-principle-one-term-one-meaning` | Pick one word for a thing and keep it; a rotating synonym is a defect. | doc-57 |
| `communication-principle-define-before-you-use` | Define or place a term before the command that uses it, and keep the main clause independent of a trailing afterthought. | doc-60, doc-61, doc-62 |
| `communication-principle-describe-only-what-is-true` | A document that states what the system does carries no speculation and no TODO. | doc-37, doc-184, doc-195 |
| `communication-principle-disclose-by-need` | Inline what every reader needs; push the rest behind a pointer that fires only when reached. | pal-40, pal-42 |
| `communication-principle-colocate-what-belongs-together` | Keep a concept's definition, rules and caveats under one heading. | pal-44 |
| `communication-principle-match-guidance-to-fragility` | Match the specificity of the guidance to how fragile the task is. | pal-46 |
| `communication-principle-end-a-step-on-a-check` | End every step on a sharp, checkable completion criterion. | pal-52, pal-81 |
| `communication-principle-one-document-one-subject` | Give each document one subject; split a document that owns two. | pal-92 |
| `communication-principle-one-trigger-per-branch` | One branch, one trigger word; name the branch with that word. | pal-98 |
| `communication-principle-a-copy-points-to-its-source` | A copy is a fast path: it exists only while the source owns the rule, and it points back to the source. | pal-88, pal-102, pal-104, pal-105 |
| `communication-principle-own-the-step-you-write` | Own the step you write end to end, and leave another step's business to that step. | pal-115, pal-117, pal-119, pal-120, pal-123 |

Two rows resolve to a principle already filed rather than a new one. The filed skill's text already states the judgement, so the row and its carrier move to that home:

| Ledger line | Resolves to |
|---|---|
| doc-23 "**Producer owns the definition.**" | `communication-principle-only-derive-what-you-own` |
| doc-231 "Restate requirements as user-observable guarantees, without seam vocabulary" | `communication-principle-write-for-the-reader` |

### Dedupe

Seven groups state one judgement each. Each group files as the single principle named, so no judgement gets two names.

| Judgement | Absorbing principle | Ledger lines |
|---|---|---|
| Plain wording | `communication-principle-write-plainly` | doc-51, doc-55, doc-56, doc-58, doc-59, doc-63 |
| Define and place the term first | `communication-principle-define-before-you-use` | doc-60, doc-61, doc-62 |
| No speculation or TODO in a descriptive document | `communication-principle-describe-only-what-is-true` | doc-37, doc-184, doc-195 |
| Disclose by need, not by default | `communication-principle-disclose-by-need` | pal-40, pal-42 |
| End a step on a checkable criterion | `communication-principle-end-a-step-on-a-check` | pal-52, pal-81 |
| A copy points to its source | `communication-principle-a-copy-points-to-its-source` | pal-88, pal-102, pal-104, pal-105 |
| Own the step you write | `communication-principle-own-the-step-you-write` | pal-115, pal-117, pal-119, pal-120, pal-123 |

### What stays

48 of the 80 rows stay, each named with its reason in the census tables above. They keep a home in the convention corpus, a lint gate, or a dispatched process: placement and folder, header and format, reference handling, naming, the handoff pattern, a process step, a document-type scope or obligation, a restatement of a rule, and the section map. None is principle material, and none is lost between M3.3.2's split and M3.3.3's corpus.

## Consequences

- M3.3.4 gains 12 principle skills to file, one roadmap row each under the story-backed row shape, plus two rows that route their source clauses to a filed skill. The exemplar is unmeasured, so the milestone's prove-before-copy gate applies before the tranche lands.
- The 48 stay rows are named here so M3.3.2's policy split and M3.3.3's convention corpus consume the same census and no row is lost between the two.
- Dedupe keeps one judgement, one principle, one name. The two filed absorptions are proposals, and the operator confirms whether the `Producer owns the definition` and `Restate requirements as user-observable guarantees` lines move to the filed skills or keep a local statement.
- Filing a principle moves the judgement to its only home, so the source line that stated it is re-pointed or retired in the same iteration. That edit belongs to M3.3.2's split plan, which this census feeds.
- The three ASD-STE100 principles sit closest to the structure boundary. If the operator reads plain wording, term consistency and clause order as the shape of a sentence rather than a writer's decision, they move to the stay column and the spec count drops to nine.
