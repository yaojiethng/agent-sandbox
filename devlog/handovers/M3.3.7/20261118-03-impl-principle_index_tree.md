---
date: 2026-11-18
milestone: M3.3.7 - The principle corpus admission
type: Implementation
status: Closed
---

# Handover - The principle index becomes a tree by aim

## Objective

Replace the provider layer's flat list of principle skills with a nested index that covers all 26, groups them by the aim each serves, and lets a reader stop at any depth with a whole rule.

## Scope

The operator's ask: the listing was out of date, sixteen of twenty-six skills, and silent on the ten that landed later. The section is read at every session start, so the shape is a budget decision as much as a routing one.

The families are the corpus survey's seven aims, recovered from the deleted map at `git show be5ae564^:devlog/discussions/20261116-report-concluded-principle_corpus_map.md`, plus `Agentic operation`. The map's five unratified aims stay as written and are marked here as the survey's proposal.

The carriers are the section in the provider layer `AGENTS.md`, the subject table in `docs/development/instruction-surface-conventions.md` that names one section per level-two heading, and the installed copy under `$AGENT_HOME`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every principle skill appears once, and every link resolves. | Compare the section's links against the skill directories; 26 leaves, 26 directories, none missing either way. | Accepted. |
| Every level is a whole rule when the file is flattened, since the runtime reads concatenated text. | Read each family and axis line alone: it names an aim and its failure without relying on indentation or on its children. | Accepted. |
| No family holds a single leaf. | Read the eight families: 6, 3, 5, 3, 3, 2, 2, 2. | Accepted. |
| A leaf adds what its own title does not, and the clause names the failure. | Read each leaf against its skill name: no clause restates the rule its title states. | Accepted. |
| Three recorded misses route to the skill the operator named, using the tree alone. | Replay the three cases in the Findings table against the section, without opening a leaf. | Accepted. `propagation-discipline`, `rewrite-syntax-never-semantics` and `cut-metadiscourse`, each reached from the tree alone. |
| The surface gates and the suite pass, and the installed copy matches. | `bash scripts/check_instruction_surfaces.sh`, `bash scripts/lint.sh`, `bash scripts/run_tests.sh`, and `diff` against `$AGENT_HOME/agent/AGENTS.md`. | Accepted. |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The index is a tree keyed on the aim, with the failure in each leaf clause. | The aim is the corpus's family key, and a leaf's title already names its rule, so the clause's work is the failure it catches. | This record; the section. |
| `Agentic operation` is a family, and its umbrella states the membership test. | A skill belongs when it exists only because the doer is a model in a harness: the window is finite and the context does not travel with the work. `guard-the-context-window` and `approval-writes-the-artifact` meet it, and neither is meaningful outside one. | This record; the section. |
| `cut-metadiscourse` sits under sentence context. | Its failure is attention spent across a passage, the same aim as a detour and a distant caveat. Under an instruction family it was the one leaf judging prose rather than fit. | This record; the section. |
| `Instruction scope` becomes `Communication` and `Mandate`. | `instruction` already names the corpus in this repository, so a family using it is one word for two things. The split leaves meaning and bounds as peer families, which the five leaves answer separately. | This record; the section. |
| The heading is `Principles`, and the subject table names it. | The section holds every principle, not only prose ones, and the surface gate reads the table against the headings. | This record; `docs/development/instruction-surface-conventions.md`. |
| The unslop pass applied where it costs nothing, and rule 33 was declined. | Twelve dash separators became colons, which changes no word. Expanding the 26 leaf fragments into whole sentences adds 1,332 characters and no meaning to a file a session reads before it acts. | This record. |
| A leaf's clause names its skill's failure, since the title names the rule. | A clause restating its own title carries nothing, and the failure is what a reader holding a situation recognises. | This record; the section. |
| `cut-metadiscourse` states one rule, a sentence whose subject is the text, where it listed four antipatterns. | The four were instances of the rule, and two of them were not metadiscourse at all. A rule stated once leaves nothing to keep current. | This record; the skill. |
| The buried lede leaves `cut-metadiscourse` for `keep-a-subject-near`. | Its defect is order, a point after a wind-up, which is colocation's case and not the text talking about itself. | This record; both skills. |
| No skill is dropped for being silent in the session logs. | A skill's silence is evidence only over the sessions after its own add date, and `organize-by-diataxis` landed after the last logged session. | This record. |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The operator's own naming of a principle is the only record of a routing miss, since a skill the agent reaches on its own leaves no mark. | Record | 138 operator turns name a skill across 30 sessions, and only 2 are slash invocations. A silence cannot be told from a hit, so the index's effect on routing is unmeasurable as the record stands. | A row for a close step that records the principles applied. |
| The replay found the counts case with no route, hours after `cut-metadiscourse` gained the self-count antipattern. | Carrier | The leaf clause enumerated three shapes and the skill had four, so a situation the skill judged had no way into it. The general rule removed the class of defect rather than the instance. | Fixed in this iteration: the rule, its clause, and the antipattern list cut from four to none. |
| The installed copy under `$AGENT_HOME` is not read by any gate. | Gate | `scripts/check_instruction_surfaces.sh` reads the repository's layers, so the copy a session actually loads can drift from its source with nothing reporting it. | The existing roadmap row on the installed layer copy. |

## Completed

| File | One-line change summary |
|---|---|
| [`src/reasoning/agent-runtime/pi/config/agent/AGENTS.md`](src/reasoning/agent-runtime/pi/config/agent/AGENTS.md) | `## Communication Standards` becomes `## Principles`: 26 leaves under eight families; the write-discipline duplicate and its `$AGENT_HOME` path go, and `produce-just-in-time` is named as the judgement behind the lean-instruction rule. |
| [`docs/development/instruction-surface-conventions.md`](docs/development/instruction-surface-conventions.md) | The subject table names `Principles`. |
| [`communication-principle-cut-metadiscourse/SKILL.md`](src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-metadiscourse/SKILL.md) | Four antipatterns become one rule, and the buried lede moves to `keep-a-subject-near`. 35 lines to 30. |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Two rows close with their landed summaries. |
| `devlog/handovers/M3.3.7/20261118-03-impl-principle_index_tree.md` | This record, with the replay cases. |
