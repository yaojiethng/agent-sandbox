---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Plan
status: Closed
---

# Handover - the discussion record's lifecycle and its one owner

## Objective

One statement of when a discussion record exists, where it lives, and what becomes of it when its work unit ends: a record is opened only while in-flight knowledge must outlive the iteration, and deleted at the unit's end once its durable content is in an ADR or a handover. Every other statement of that rule cites it or is gone.

## Scope

**Grain:** one task that needs decisions before it can be worked, not a milestone scope. The task is the M3.3.3 row **State what absorbs a discussion record**, whose filed body asks only the absorption question; the operator widened it this session to the whole determination, on the ground that the rules are spread across the tree and generate more records than anything reads.

The problem as stated by the operator: "our discussion rules are all over the place, everything seems to generate one, way more than we actually need. the rules should be clear, discussion records only when in-flight knowledge needs to persist across iterations, and deletion when the work unit ends, with actually important details written back to ADR. suspect this is mixed in with other, more stale rules."

Context gathered before this session and recorded in `## Findings`: the statements of the rule and where each sits; the record that already decided part of it; and the measurement of which records anything reads.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The determination has one owner | `rg -n "lives until its task does" .agents/skills/decision-records/SKILL.md` prints the judgement, and `rg -n "owns that determination" docs/reference/documentation_taxonomy.md` prints the citation | Agent [x] |
| `work-log` states the shape and cites the determination | `rg -c "decision-records" .agents/skills/work-log/SKILL.md` prints 2 or more, and `rg -n "Two facts, not one" .agents/skills/work-log/SKILL.md` prints the section | Agent [x] |
| The state set is three states plus tenancy | the state table lists `open`, `concluded` and `rejected` and no other row | Agent [x] |
| The machine is drawn in the project record | `rg -n "rec_disc_retired" docs/reference/workflow_statechart.md` prints the diagram and the state table | Agent [x] |
| The name gate speaks the new vocabulary | `bash scripts/check_record_names.sh` is clean, and `bash tests/test_record_names_gate.sh` reports 8 passed | Agent [x] |
| The ADR records the ruling and the reason | `rg -n "determination belongs to" docs/adr/record_durability.md` prints the dated entry | Agent [x] |
| The roadmap row is rewritten and closed, and the follow-ons are filed | the source row reads `- [x]`, and `rg -n "A closed row strips its discussion links\|The discussion corpus is cleaned" devlog/roadmap.md` prints the two open rows | Agent [x] |
| Every decision this session recorded is realized in the files | the `## Decisions` table read against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A discussion record's lifetime is the lifetime of the roadmap row it serves: opened under a task, cleaned up when that row closes, or re-pointed to another open row that inherits it. No absorber document, and no `processed` state | a record may feed several documents -- an ADR for its decisions, a reference document for design and implementation notes, a handover for the operation -- so a rule anchored on one absorber cannot hold, while the row is one and already exists | the ADR entry and `work-log` |
| Deletion rests on the organizational judgement this session already merged into `principle-single-source-of-truth`, not on bookkeeping: once the ADR exists, the discussion record and the ADR serve one subject in one mode (explanation), so keeping both is a second source | the unit of ownership is a subject together with a mode; the record is in mode `reference` only while it is evidence, and the ADR takes the same subject in the same mode when the decision lands | the ADR entry, citing `principle-single-source-of-truth` |
| The roadmap row names the discussion record, and a closed row carries no such link: ownership reads from the task list, which is the sole task list, and the file that dies holds no pointer | a record naming its row would need the row's identity, and a row is prose with a title that may be reworded, so the join is on unverified text; a filename is unique and stable, and the check becomes one scan of the roadmap for a discussion path in a closed row | the ADR entry, `work-log`, and the rows |
| The status states the enquiry and existence states the task, and the two are independent: `settled` means the enquiry concluded, and whether the file remains depends on the row | `archived` existed to keep a record after its work landed; under this rule a record either lives under an open row or is gone, so `archived` goes | the ADR entry and `work-log` |
| The four types stay, and a type decides a guard and an event rather than a state: what differs is which dependent concludes the enquiry -- a story's rows written, a study's comparison decided, a design's ADR entry landed, a report's run finished | a review or audit report is in flight across iterations by the same test a study is, so no type is excluded by the criterion | the ADR entry and `work-log` |
| `work-log` owns the determination: it owns `devlog/discussions/`, so it decides when a record is opened, when it ends and what inherits it; `decision-records` owns `docs/adr/` and states only that the entry is the authority and does not restate the evidence. `documentation_taxonomy.md` keeps the classification of kinds and links to the determination | ownership follows the object, not the act: the record lives under a directory one convention owns and settles into a directory another owns, so assigning the rule to the settling convention puts it where its object is not | `work-log`, `decision-records`, the ADR entry |

## Decisions pending

| Decision | Why it is open |
|---|---|
| Whether any of the four types is excluded | `report` was read as post-action and therefore outside the criterion; the operator corrected that -- a review, audit or study report is composed across iterations, persists while it is being processed, and is deleted once processed. The criterion therefore excludes a state and not a type |
| Whether a closed row strips its discussion link | Settled in principle by the operator: the compaction survival table keeps the link and must stop; the carrier is `/milestone-close` and `roadmap-maintenance` 2.3 |
| Whether the record names its row, or the row names the record | The record is the file that dies, and a row pointing at a deleted record dangles; but the rows link design records today, and `/milestone-close`'s compaction survival table keeps those links |
| Whether a closed row strips its discussion link | Settled in principle by the operator: the compaction survival table keeps the link and must stop; the carrier is `/milestone-close` and `roadmap-maintenance` 2.3 |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The determination was first given to `decision-records`, which owns `docs/adr/`, while the object it governs is `devlog/discussions/`, which `work-log` owns | defect, ssot | the rule sat in a component that does not own its object, so a reader looking for it in `work-log` finds a shape with no rule and `decision-records` carries a duty it cannot discharge | fixed in this unit; the operator raised it |
| The first pass fixed four of the seven carriers and left the prompt surface asserting the old act -- `wrapup` B8 closed discussion docs, and `plan.md:68` and `iter.md:192` paraphrased it | defect, propagation | the runbook would close a record the rule deletes, so the next close writes the wrong act with confidence | fixed in this unit; the operator raised it |
| The taxonomy and the ADR each restated the mechanism beside the link, so the rule still had three operative texts | defect, ssot | an edit to the determination would have to be made in three files and the two copies would drift silently | fixed in this unit; the operator raised it |
| `check-in/SKILL.md` swept for "settled design docs ... with no implementation handover referencing them yet", which asks the retired state and the wrong survival test | defect, text | the sweep reports records the rule has already retired, and misses the ones whose row closed | fixed in this unit |
| The rule stands in seven places: `docs/adr/record_durability.md`, `docs/reference/documentation_taxonomy.md`, `.agents/skills/work-log/SKILL.md`, `workflow/coding-agent/prompts/plan.md`, `workflow/coding-agent/prompts/iter.md`, `workflow/coding-agent/prompts/wrapup.md` B8, and `docs/reference/workflow_statechart.md` | duplication, text | a writer satisfies one statement and violates another, and no reader can tell which governs | this session, the first pending decision |
| The convention contradicts the ADR: `record_durability.md` makes a record reference-durable and subsumable, while `work-log` says "the agent does not delete a study record" and its status table offers no delete transition | contradiction, text | the operator's rule cannot be applied without one of the two being amended | this session |
| Only one consumer of a discussion record exists in the tree: `plan.md` reads "any open stories in `devlog/discussions/`" | defect, text | a record nothing reads is not reference-durable, it is a dead file whose status field is a fiction | this session, the third pending decision |
| `record` is a bare noun for four artifacts: a handover (`work-log` "the record with the highest date and index"), a discussion document (`one record per line of enquiry`), an ADR and an ADR entry (`A file has no single status`), and a roadmap entry. `docs/reference/terminology.md` defines none of them | ambiguity, text | a rule phrased "delete the record when processed" can be read as deleting a handover or an ADR entry, which is the opposite of the intent | this session, by naming the artifact in the rule and in `work-log`'s prose |
| The statechart work was deferred to M3.3.6 this session ("also move statechart to M3.3.6"), and this plan needs a state model of the discussion record to write the rule | scope, record | the deferral and the need agree only if the model is recorded here as that row's first piece, or the row absorbs it | this session, on the operator's ruling at the scope gate |
| The compaction survival table keeps a design-document link in a closed row, so a record deleted at task close leaves the row pointing at nothing | contradiction, record | `/milestone-close` and `roadmap-maintenance` 2.3 both require the link to survive, which is the opposite of the deletion the same close performs | this session, in the ADR entry; the two carriers become follow-on rows |
| Of 38 records, 16 are referenced by no maintained document and 22 only by `devlog/roadmap.md` or a draft, most of which compaction removes; 12 are `report`-typed, five of them still `draft` | evidence, tree | measured with a walk over every `.md`, `.mjs`, `.sh`, `.json` and `.yml` outside `devlog/discussions/`, counting inbound references per record | the second pending decision |

## Completed

| File | Action |
|---|---|
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | the exploration record owns the determination, states two regions, three states, the deletion rule and the legacy-name cutover, and points at `decision-records` for the ADR side |
| [`.agents/skills/decision-records/SKILL.md`](../../.agents/skills/decision-records/SKILL.md) | gains the determination as a judgement, with its ground and its two citers |
| [`docs/reference/documentation_taxonomy.md`](../../docs/reference/documentation_taxonomy.md) | the durability classification keeps the kinds and points at `decision-records` for the determination |
| [`docs/adr/record_durability.md`](../../docs/adr/record_durability.md) | the dated entry recording the split, the state set, the SSOT ground and the rejected alternatives |
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | `## The discussion record` draws the two-region machine; the chart's two discussion nodes take the new ids |
| [`scripts/lint/record-name.mjs`](../../scripts/lint/record-name.mjs) | the state vocabulary and the cutover move forward, and the wrapper stops holding a second copy of the cutover |
| [`tests/test_record_names_gate.sh`](../../tests/test_record_names_gate.sh) | the fixtures speak the new vocabulary and the new cutover |
| [`devlog/roadmap.md`](../roadmap.md) | the row is rewritten and closed, two follow-on rows are filed, and the M3.3.6 statechart row notes the out-of-order model |
| [`workflow/coding-agent/prompts/wrapup.md`](../../workflow/coding-agent/prompts/wrapup.md) | B8, the Scope line, the description, the anti-pattern and B10 speak the retirement rather than a close, and B8 names the deletion and the re-point |
| [`workflow/coding-agent/prompts/plan.md`](../../workflow/coding-agent/prompts/plan.md), [`iter.md`](../../workflow/coding-agent/prompts/iter.md) | both carried the close-step phrase that B8 changed |
| [`workflow/coding-agent/skills/check-in/SKILL.md`](../../workflow/coding-agent/skills/check-in/SKILL.md) | the stale-state sweep looks for a record whose roadmap row closed, not for a `settled` one no handover references |
