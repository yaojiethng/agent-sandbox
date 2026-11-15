---
date: 2026-11-14
milestone: M3.3.6 - The instruction corpus and its map
type: Workflow
status: Closed
---

# Handover - The ladder is named in the principle that owns it

## Objective

Turn the presentation ladder from a lesson learned once into a rule in `communication-principle-cut-what-serves-nothing`: named, sourced in the field, and stated so a second editor reaches the same verdict.

## Scope

Raised by the operator during M3.7.2, after iteration [`20261114-09`](../M3.7.2/20261114-09-workflow-property_traceability.md), where six ladders were cut from `git-discipline` one at a time.

The work ran in the order the defect demanded: the instance set from the corpus, the field's name for the phenomenon, a test written for another editor, a blind application to sentences the rule was not derived from, and only then the edit. The edit lands in the principle that owns sediment inside an artifact; `cut-what-carries-nothing` exists nowhere in the tree, so the question of a second home closed itself.

A reader who acts on a passage and loses nothing when its first or last sentence goes shows the rule is right. A passage whose first or last sentence carries the only statement of a fact shows it is wrong; none was found.

Out of scope: a lint rule. The sweep found no marker that fires mechanically -- every instance needed the reader test -- so a gate would encode a judgement it cannot make.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The instance set comes from the corpus, with file and line, and a control set. | the sweep below | Agent [x] |
| The field's name for the phenomenon is recorded, with what we keep and drop. | `.agents/registry/citations/williams-style-metadiscourse.json` | Agent [x] |
| The test is written so another editor can run it. | `pi -p` blind run, 12 items | Agent [x] |
| The blind verdicts are compared with the ground truth, and the disagreements judged. | the result below | Agent [x] |
| The principle carries the rule, the test and the boundary between a pointer and a restatement. | read the ladder section | Agent [x] |
| The routing line triggers on the ladder, not only on the mode mismatch. | the `description` field | Agent [x] |
| The installed copy matches the shipped one. | `diff -q` between the two paths | Agent [x] |
| Lint passes. | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Judge the passage, not the sentence. | Every rung of a ladder is a well-formed sentence, so a sentence-level test passes all three; only the passage shows one claim made three times. | the principle |
| A pointer and a guard keep their sentence. | A pointer names a document the reader must open and a guard stops a wrong move; both change what the reader does, so deleting either costs an action rather than a word. | the principle |
| The abstract is the ladder's surviving form. | The corpus is nearly clean of ladders in body text; the shape survives where a document describes its own coverage -- *this document is X; it names Y; it covers Z*. | the principle |
| The field's word is metadiscourse. | Williams' category covers exactly this: prose that talks about the prose. Naming it recruits the reader's prior rather than coining a term. | the citation record |
| The rule states no proportion. | Williams measures metadiscourse as a share of the sentences; this repository tests what the reader loses, because a guard is metadiscourse that earns its place and a proportion cannot tell the two apart. | the citation record |
| No lint gate. | The sweep found no marker that fires mechanically; every candidate needed the reader test, and a gate over a judgement would report its own false positives. | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Corpus: 88 shipped files. Shape markers cluster at 5 `this section`, 14 `this record`, 29 `this document`, 1 `states its own`; the body text is otherwise clean. | evidence | the class is real but narrow, and the abstract carries it | the principle's *abstract* paragraph |
| Clean instances: `docs/reference/execution_model.md:107` (*this section records why the shape is what it is*), `docs/reference/sandbox_host_interface.md:9` (*it names the contract surfaces ...*), `docs/reference/documentation_taxonomy.md:7` (*read it to learn what documents exist ...*). | evidence | three shipped examples, one per shape statement | the instance set |
| Near-misses that stay: `work-log/SKILL.md:18` and `iteration_protocol.md:47` name where a rule lives, which is a pointer; `documentation_taxonomy.md:7`'s *states no obligations* is a guard. | evidence | the boundary the test must state | the boundary clause |
| The blind run agreed on 9 of 12 items, and its three disagreements were all the pointer/restatement boundary. | evidence | the test does not transfer there without a clause | the boundary clause; two of my three verdicts were wrong |
| On item D (*the chain is closed when the newest handover is Closed. A handover left Active holds the chain open.*) I said keep; the blind editor said cut and was right -- the second sentence restates the first, inverted. | record | my ground truth was wrong on the clearest case | this handover, and the entry below |
| The blind run kept H and J, where I cut. Both name a place to look, so the pointer clause covers them and their status is settled by it, not by taste. | record | a division the rule now decides | the boundary clause |
| The ladder's description line had to change, or the principle would route only on the mode mismatch. | record | a rule reachable only by reading the body | the `description` field |
| The Pope citation record still said the body is bounded *at one paragraph*, after that framing was removed from the convention. | record | a stale derived claim in a source record | this iteration: corrected to 280 characters |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-cut-what-serves-nothing/SKILL.md` | the ladder section, the passage test, the pointer/guard boundary, and a routing line that names it |
| `.agents/registry/citations/williams-style-metadiscourse.json` | metadiscourse, kept, rewritten, added, dropped |
| `.agents/registry/citations/tim-pope-commit-messages.json` | the body bound corrected to 280 characters |
| `devlog/roadmap.md` | the row under M3.3.6 closes with its outcome |
| (maintenance) | the installed copy under `$AGENT_HOME` mirrors the shipped one; `roadmap-maintenance`: 0 findings. |
