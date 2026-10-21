---
date: 2026-10-21
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - The seeded convention corpus covers both shipped surfaces

## Objective

Remove every shipped pointer to a project-scoped convention path, give the reference judgement a home that ships, and hold the corpus to the shipped handoffs with a check rather than by hand.

## Scope

The roadmap row **The seeded convention corpus is short of the project's own**, closed on its second ending: the difference between the seeded set and this project's set is stated where a receiving project reads it, and no stub is added. The design is [`20261021-design-draft-initialize_corpus_boundary.md`](../discussions/20261021-design-draft-initialize_corpus_boundary.md), which decides the split between the judgement and the project's structure.

Ruled out of scope with a reason each. The reach axis of the documentation taxonomy is its own row, because it delivers an outcome of its own and would take a value for the two document bundles while the open row **Drop the policy bundle** disputes whether they ship. The unit that ships the wiki is its own row, blocked on what M3.3.2's retirement leaves behind. Checks on the wording of a project convention are not written here: the rule reads the corpus's directory names and its stub marker, not its prose.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No shipped document names a `.agents/skills/<name>/SKILL.md` for a name the seeded corpus lacks, while a seeded name and the generic `<name>` form still pass | `bash scripts/check_markdown.sh` prints `markdownlint: 0 finding(s)` over the whole tree, and the four fixtures in `bash tests/test_linking.sh` hold the rule's branches | Agent [x] |
| The rule is not vacuous: a fixture naming an unseeded convention fails it, a fixture naming a seeded one passes, and a fixture using the generic form passes | `bash tests/test_linking.sh` | Agent [x] |
| The reference judgement resolves for a receiving project: the principle is in the repository source and the installed copy, and the project's `linking` convention points at it rather than restating it | `diff -r src/reasoning/providers/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open /home/agentuser/.pi/agent/skills/communication-principle-link-what-the-reader-can-open` prints nothing, and `grep -c "link a target the reader may open" .agents/skills/linking/SKILL.md` prints `0` | Agent [x] |
| Zero pointers remain: the two concrete paths have no carrier under the shipped roots | `grep -rn 'skills/numbering\|skills/linking' workflow/ docs/policies/ docs/reference/ src/reasoning/` returns nothing | Agent [x] |
| The corpus row closes on its second ending without a stub: the corpus stays at seven, and the intention is stated where a receiving project reads it | `ls workflow/coding-agent/skills/initialize/assets/conventions/ \| wc -l` returns 7, and `grep -n 'project-scoped' docs/reference/documentation_taxonomy.md` finds the boundary sentence | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Remove the six shipped pointers rather than seed the two stubs | the shipped carriers outnumber the local ones, and seeding grows every project's convention set to answer two documents this project wrote for itself | `devlog/discussions/20261021-design-draft-initialize_corpus_boundary.md` |
| Ship the reference judgement as `communication-principle-link-what-the-reader-can-open`, and keep the structure in the project's `linking` convention | the split criterion of M3.3.4: a judgement is a principle and resolves wherever it ships, a structure stays with the project convention that holds it | the same record |
| `.agents/` holds project-scoped content only, and a wider-reach document names a path there only where a mechanism that ships guarantees it | operator ruling; it makes the rule decidable, and `.agents/prompts/` already satisfies it because its cell's runtime path stays inside this project's tree | the same record, and `docs/reference/documentation_taxonomy.md` `## Boundary` |
| Reach is named by the declaring unit, not by shipping. `agent-sandbox` is the default module - the always-enabled unit that defines the container, whose wiki `/agent-sandbox` already points at `/opt/sandbox/docs/` - and a plugin module is the same kind of unit enabled by its own `packages` entry. Enablement is a second property, not a scope | a module is a class the tree declares and gates, and `scripts/check_container_layout.sh` refuses a module root no settings entry enables, so naming the default module describes the system as built. `ships` stays a verb | the design record; the axis row owns the definitions |
| File the scope axis as its own row instead of writing it here | it delivers an outcome of its own, and it would take a value for `docs/policies/` and `docs/reference/` while the open row **Drop the policy bundle** disputes whether those bundles ship | `devlog/roadmap.md` at close |

| The remaining workflow and policy milestones are ordered on the record. M3.3.4 phase A, M3.3.2's retirements, M3.3.4 phase B, M3.5, M3.3.3, M3.2.2, M3.2.3, with M3.1.2 interleaved and M3.6.3 in parallel | subtraction precedes addition, and the reach premise is decided before the instance repairs that assume it | `devlog/roadmap.md`, one `Sequencing:` line per milestone section and ordering clauses on five open rows |
| Three sub-milestones move to `Not started`: M3.2.2, M3.2.3 and M3.3.3 | 58 open rows across five in-progress sub-milestones is the set-nobody-holds-whole defect this iteration removed from the shipped text | `devlog/roadmap.md` Milestone Summary |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The corpus is declared by two surfaces, and the shipped provider layer hands off to `numbering` and `linking` while the corpus seeds neither | design gap, verified by grep over the shipped roots | a fresh project meets a handoff to a skill no seeding step creates, and no message says why | the design record; closed by this iteration removing the six pointers |
| The declaration lives in prose, so nothing detects the next surface that hands off to a convention the corpus lacks | defect class, the hand-listed-subject-set pattern `devlog/AGENT_FEEDBACK.md` records from 2026-10-15 | the gap returns silently at the next convention | the rule this iteration added to `scripts/lint/linking.mjs` |
| The row's premise inverts the carrier split: six pointers in five shipped files name the two project-scoped paths, and the project-scoped carriers of the same paths are five files of this repository. A fresh project misses nothing until it reads a shipped document, so seeding two stubs covers a defect the pointers cause | design gap, raised by the operator at the scope gate | seeding the corpus grows every project's convention set to answer two documents, where removing the pointers leaves both conventions project-scoped | raised as a decision pending, resolved by the operator ruling; the design record carries the outcome |
| The documentation taxonomy has no scope axis, so no reader can tell a document that ships to every project from one this project owns | record defect in a shipped document | the layer question, this corpus row and the six pointers are three symptoms of one missing axis, and each is re-derived separately | a filed roadmap row, whose first design option is a view derived from the interface manifest |
| The census finds two shipped documents naming an unreviewed project draft: `iteration_policy.md:73` points at `.agents/drafts/sequential-work.md` for the work-unit table's definition, and `history-cleanup.md:59` points at `.agents/drafts/history-cleanup/inversions.mjs` | design gap, the same class as the six pointers | a shipped rule whose definition lives in a draft can be changed by an unshipped edit, and the guarantee behind a draft is a task rather than a mechanism, so the convention-name rule cannot reach it | the filed roadmap row **A shipped rule's definition lives in an unreviewed draft**, added when the record check found the destination named no existing unit |
| Twenty-five mentions of a concrete `.agents/` path sit across thirteen shipped files; the seeded conventions and the skill that writes `model-recommendations.md` are sound, and the unreachable classes are the six pointers plus the two draft citations | measurement | the census sizes the class the operator's ruling covers, and separates the paths a shipped mechanism guarantees from the ones nothing does | this record, and the rows filed from it |
| `module` carries two senses in the tree: the payload toggle unit, `workflow/coding-agent/` with `prompts/` and `skills/` and a `packages` entry, and any directory under `workflow/`, of which `knowledge-vault/` holds scripts and a changelog and `vscode/` holds one image config file | terminology defect, raised by the reach vocabulary | a scope value named `module-scoped` would inherit the ambiguity and cover content that ships nowhere | the reach-axis row, whose definitions must name the payload unit |
| `docs/reference/` and `docs/policies/` land in every provider image by a dockerfile `COPY`, so they are wider than any module and gated by none, and the open row **Drop the policy bundle** disputes whether they should ship at all | undeclared reach | the axis has no value for them, and the operator's default-module framing resolves it: the wiki is the default module's content, and what remains is a content question | the reach-axis row |
| The default module's content is spread over three placements: its prompt and skill payload at `src/reasoning/agent/`, its wiki at `docs/reference/` and `docs/policies/`, and its libraries at `src/libs/`. `/agent-sandbox` already names the wiki, so the framing is real, but no single directory is the default module | structural gap, raised by the operator's default-module ruling | an axis that names the default module describes a unit whose files no manifest row groups, so the view must render it from three placements or the framing stays prose | a filed roadmap row, **The unit that ships the wiki** |
| `docs/reference/documentation_taxonomy.md` lists `devlog/`, `docs/adr/` and `docs/development/`, and `docs/reference/agent_workflow.md` maps this repository's documents, while both land in every provider image | design gap, raised by the `.agents/` intention | a mounted project reads another project's folder tree as if it were its own | a filed roadmap row, **Two shipped reference documents describe this project** |
| `.agents/skills/docs/SKILL.md` forecast a policy move no task held, and the installed provider `AGENTS.md` predates the `## Communication Standards` section, so the two `AGENTS.md` copies are not byte-identical whatever the closed row says | record defect, both single edits | a forecast in a convention reads as a plan, and a stale installed layer states older rules | the forecast cell is corrected in this iteration; the installed copy refreshes at image install. The record check found the closed row **The two AGENTS.md copies disagree** asserting `diff -q` returns nothing, which is false again, and that row was corrected in place as a single-edit record defect |
| The whole-tree record checks found six more record defects, three of them mine: the closed corpus row's landing note still carries the pointer count, the draft-citation row named `path:NN` references, the reach-axis row stated a derived citation total, the unit row stated five counts the tree can falsify, three open rows carried a `Blocked on` marker, and the changelog preamble pointed at the retired `roadmap_policy.md` | record defects, found by `roadmap-maintenance` and `handover-maintenance` at pre-close | a derived count in a row goes stale silently, and a pointer to a retired document governs the next reader | all six corrected in this iteration; `Settle the split criterion and prove the template` stays uncompacted because compaction at task grain is `/wrapup`'s at the close, which the pre-close summary states |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261021-design-draft-initialize_corpus_boundary.md`](../discussions/20261021-design-draft-initialize_corpus_boundary.md) | the design record: two surfaces declare the corpus, the six pointers are the defect, and the reach vocabulary |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-link-what-the-reader-can-open/SKILL.md` | new shipped principle: the reference judgement in the exemplar's shape, plus its `MAINTENANCE.md`, installed to the agent config home |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the numbering and reference pointer line names the two principle skills and no project path |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-one-addressing-axis/SKILL.md` | the scheme clause names the project's convention instead of the repository path |
| `docs/policies/documentation_policy.md` | `### Reference handling` and `### Numbering` name the judgements and leave the structure to a project convention; the ledger rows reclassified |
| `docs/reference/documentation_taxonomy.md` | the numbering line names the convention rather than the path, and `## Boundary` states the `.agents/` reach for every project |
| `docs/reference/agent_workflow.md` | the document-references row names the principle and the project's convention |
| `.agents/skills/linking/SKILL.md` | loses the judgement to the principle and keeps the structure, the four stories and the gate pointer |
| `.agents/skills/docs/SKILL.md` | the `Ships` cell states the current fact instead of a forecast move |
| `scripts/lint/linking.mjs` | one rule: a shipped document may not name a convention the `initialize` corpus lacks, with the names derived from the corpus |
| `tests/test_linking.sh` | four fixtures for that rule, and the covers list extended |
| `scripts/lint/norm-ownership.tsv`, `scripts/lint/norm-judgements.tsv` | regenerated and regrouped for the two edited policy lines |
| [`devlog/changelog.md`](../changelog.md) | the preamble names the `task-list` convention instead of the retired `roadmap_policy.md` |
| [`devlog/roadmap.md`](../roadmap.md) | the corpus row closed on its second ending, its premise corrected; four rows filed; three `Blocked on` clauses rewritten as ordering clauses; the closed `AGENTS.md` row's false claim corrected in place; the accepted milestone ordering written as nine `Sequencing:` lines, five row ordering clauses, three parked milestones and one decision line |
