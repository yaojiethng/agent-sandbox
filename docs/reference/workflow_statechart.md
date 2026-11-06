---
reader: [agent]
---

# The Workflow Statechart

This is the app's workflow surface as one statechart: every state an agent rests in, every slash command that moves it, and every maintenance check a procedure invokes. The change flow has its own command table below, because it is a separate machine. The loop's concept document, [`autonomous_agent_loop.md`](autonomous_agent_loop.md), explains why the loop is split into workflows; this document draws the whole of it, and that one point at the chart.

A node is a state the loop rests in. A gate is a node where the loop waits for the operator, and the arrow out of a gate is a decision. An arrow is a command, or the operator releasing a gate.

**A story is a path.** A behaviour this app supports is a route through these states, and writing that route down is how the behaviour is declared. `sess_oriented -> it_open -> it_scope_gate -> it_implementing -> it_acceptance_gate -> it_closed -> it_committed` is the story of one delivered unit. A declared path resolves when every id in it is a state here and every consecutive pair is an edge, which is the cheapest test this map offers of its own completeness.

The chart models one handover track. `it_open` means no `Active` handover on this track; another track may hold one while this unit waits for a directive.

**An id is the name.** A state's id is what a story cites, and it does not change when the label beside it is rewritten. Ids carry no colon, so that a path is readable in a Mermaid diagram and in a shell command alike. The labels in the diagram carry the reading; the id carries the identity.

The diagram is Mermaid 12.1.0, `stateDiagram-v2`, in the conservative subset: composite states, labelled transitions, notes, and no experimental directives. A render capability is planned and the intended target is Pele, at `https://pele.run/compatibility`; that page cannot be read from this container, so the chart is written to standard 12.1.0 syntax rather than to guessed restrictions. The version is stated so that a rendering difference has a version to blame.

## The chart

<!-- snippet: illustrative -->
```mermaid
stateDiagram-v2
    state "Entry and orientation" as entry {
        [*] --> sess_start
        state "sess_start -- a session begins, nothing read" as sess_start
        state "sess_initialized -- the project's convention corpus is installed" as sess_initialized
        state "sess_oriented -- a check-in has run, the tree is inventoried" as sess_oriented
        state "sess_triaged -- the open rows are sorted into runnable and questioned" as sess_triaged
        sess_start --> sess_initialized : /bootstrap
        sess_start --> sess_oriented : /gm
        sess_initialized --> sess_oriented : /gm
        sess_oriented --> sess_triaged : /backlog-triage
    }

    state "Maintenance checks" as checks {
        state "chk_orientation -- the check-in skill runs" as chk_orientation
        state "chk_roadmap -- the roadmap-maintenance skill runs" as chk_roadmap
        state "chk_record -- the handover-maintenance skill runs" as chk_record
        state "chk_docs -- the documentation pass runs" as chk_docs
        state "chk_history -- the history-cleanup skill runs" as chk_history
        state "chk_corpus -- the initialize skill runs" as chk_corpus
        state "chk_close -- both record checks rerun over the rows the close wrote" as chk_close
    }

    state "Milestone grain" as milestone {
        state "ms_none -- no active milestone" as ms_none
        state "ms_active -- one milestone is active, iterations run against it" as ms_active
        state "ms_close_gate -- compaction and changelog presented, awaiting release" as ms_close_gate
        state "ms_closed -- the close is recorded, its bookkeeping commit landed" as ms_closed
        [*] --> ms_none
        ms_none --> ms_active : /milestone-start or the operator promotes a successor
        ms_active --> ms_close_gate : /milestone-close
        ms_close_gate --> ms_closed : operator releases the close
        ms_closed --> ms_active : the next milestone is promoted
        ms_closed --> ms_none : the next milestone is shaped first
    }

    state "Unit grain" as unit {
        state "it_open -- no Active handover on this track, awaiting a directive" as it_open
        state "it_scope_gate -- scope table and acceptance criteria presented" as it_scope_gate
        state "it_implementing -- work is landing in the tree, findings appended" as it_implementing
        state "it_acceptance_gate -- the six-section summary presented, awaiting release" as it_acceptance_gate
        state "it_closed -- the handover reads Closed, the write-back applied" as it_closed
        state "it_committed -- the unit's delivery commit landed" as it_committed
        it_open --> it_scope_gate : /iter or /sidequest opens the unit
        it_scope_gate --> it_implementing : operator releases the scope
        it_implementing --> it_scope_gate : a design question reopens the scope
        it_implementing --> it_acceptance_gate : /iter reaches its pre-close summary
        it_acceptance_gate --> it_implementing : a defect is fixed rather than filed
        it_acceptance_gate --> chk_close : operator releases, /wrapup writes its rows
        chk_close --> it_closed : both reports clean, the close hands off to /commit
        it_closed --> it_committed : /commit
        it_committed --> it_open : the operator picks the next unit
    }

    state "Sidequest" as sidequest {
        state "sq_running -- the open unit is paused for operator-directed work" as sq_running
        state "sq_committed -- the sidequest's own delivery commit landed" as sq_committed
        it_implementing --> sq_running : /sidequest, when the work cannot wait
        sq_running --> sq_committed : /commit
        sq_committed --> it_implementing : the paused unit resumes
        sq_running --> it_implementing : the sidequest is ruled in scope, no run
    }

    state "Planning and publishing" as planning {
        state "plan_scoping -- the milestone is being cut into units" as plan_scoping
        state "plan_interview -- the grill-me skill probes the design" as plan_interview
        state "plan_released -- rows, stories and ADRs are written back" as plan_released
        ms_active --> plan_scoping : /plan or /scope
        plan_scoping --> plan_interview : the design is probed
        plan_scoping --> it_open : the operator releases the brief to a run
        plan_interview --> plan_released : operator releases the scope
        plan_released --> chk_close : /wrapup writes its rows
    chk_close --> ms_active : both reports clean, no delivery commit
    }

    state "Recovery" as recovery {
        state "rep_partial -- the record's intent and the disk disagree; the unit is rebuilt" as rep_partial
        state "rep_absent -- the record claims a commit the repository lacks; it is rebuilt" as rep_absent
        it_implementing --> rep_partial : /recovery, the description is partial
        rep_partial --> it_committed : rebuilt from the record
        it_committed --> rep_absent : /recovery, the description is absent
        rep_absent --> it_committed : rebuilt, one commit per iteration
    }

    state "Correction" as correction {
        state "cor_bad -- the commit is wrong; it is amended or dropped" as cor_bad
        state "cor_messy -- the series is noisy; history-cleanup rewrites it" as cor_messy
        it_committed --> cor_bad : /record-correction, the commit is wrong
        cor_bad --> it_closed : the fix folds into the closed commit
        it_committed --> cor_messy : the series is noisy
        cor_messy --> chk_history : the operator runs history-cleanup
    }

    state "Records at rest" as records {
        state "rec_handover_active -- the unit's record is open" as rec_handover_active
        state "rec_handover_closed -- the unit's record is closed" as rec_handover_closed
        state "rec_roadmap_open -- a row is open" as rec_roadmap_open
        state "rec_roadmap_closed -- a row is closed with its outcome" as rec_roadmap_closed
        state "rec_discussion_open -- an enquiry is in flight" as rec_discussion_open
        state "rec_discussion_concluded -- the enquiry concluded, its row still open" as rec_discussion_concluded
        state "rec_adr_accepted -- a decision record is current" as rec_adr_accepted
        it_scope_gate --> rec_handover_active : the handover is opened
        rec_handover_active --> rec_handover_closed : /commit lands the status flip
        plan_released --> rec_roadmap_open : a row is filed
        it_closed --> rec_roadmap_closed : the write-back closes the row
        plan_interview --> rec_discussion_open : a design or study opens
        it_closed --> rec_discussion_concluded : an enquiry reaches its result
        plan_released --> rec_adr_accepted : a settled decision gets an ADR
        rec_handover_closed --> sess_oriented : the next iteration reads the prior record
        rec_roadmap_open --> it_open : the operator picks the row
        rec_roadmap_open --> plan_scoping : the milestone's rows are read
        rec_roadmap_closed --> chk_roadmap : the closed rows are the compaction's input
        rec_discussion_open --> it_scope_gate : the record is the scope's input
        rec_discussion_concluded --> it_scope_gate : the concluded record is the design
        rec_adr_accepted --> it_implementing : the decision constrains the work
    }

    sess_oriented --> it_open : the operator names a roadmap row
    sess_triaged --> it_open : a runnable row is picked
    it_open --> ms_active : no milestone is active and the row needs one

    sess_oriented --> chk_orientation : /gm runs the check-in skill
    ms_active --> chk_roadmap : /milestone-close runs the compaction pass
    it_implementing --> chk_roadmap : /iter runs the roadmap record check
    it_implementing --> chk_record : /iter runs the handover record check
    it_implementing --> chk_docs : /iter's information-gathering pass
    sess_initialized --> chk_corpus : /bootstrap installs the corpus

    chk_corpus --> sess_oriented : the corpus is installed
    chk_orientation --> sess_oriented : the report is applied
    chk_roadmap --> chk_record : the two reports meet at one gate
    chk_record --> it_acceptance_gate : the findings queue carries the report
    chk_docs --> it_implementing : the report is applied
    chk_history --> it_committed : the series is clean
```

## States

The id and region columns are generated from the chart's declarations: edit the chart, then run `bash scripts/check_statechart.sh --write`. The gate `bash scripts/check_statechart.sh` fails when a state is declared on one side only, or when a region moves in the table alone. The gloss column is authored prose and is not compared, so it may say more than the chart's label.

| Id | Region | The state it names |
|---|---|---|
| `sess_start` | entry | a session begins and nothing has been read |
| `sess_initialized` | entry | the project's convention corpus is installed |
| `sess_oriented` | entry | a check-in has run and the tree is inventoried |
| `sess_triaged` | entry | the open rows are sorted into runnable and questioned |
| `chk_orientation` | checks | the `check-in` skill runs |
| `chk_roadmap` | checks | the `roadmap-maintenance` skill runs |
| `chk_record` | checks | the `handover-maintenance` skill runs |
| `chk_docs` | checks | the documentation pass runs |
| `chk_history` | checks | the `history-cleanup` skill runs |
| `chk_corpus` | checks | the `initialize` skill runs |
| `chk_close` | checks | both record checks rerun over the rows the close wrote |
| `ms_none` | milestone | no milestone is active |
| `ms_active` | milestone | one milestone is active; iterations run against it |
| `ms_close_gate` | milestone | compaction and changelog presented, awaiting release |
| `ms_closed` | milestone | the close is recorded and its bookkeeping commit landed |
| `it_open` | unit | no `Active` handover on this track; awaiting a directive |
| `it_scope_gate` | unit | scope table and acceptance criteria presented |
| `it_implementing` | unit | work is landing in the tree and findings are appended |
| `it_acceptance_gate` | unit | the six-section summary is presented, awaiting release |
| `it_closed` | unit | the handover reads `Closed` and the write-back is applied |
| `it_committed` | unit | the unit's delivery commit landed |
| `sq_running` | sidequest | the open unit is paused for operator-directed work |
| `sq_committed` | sidequest | the sidequest's own delivery commit landed |
| `plan_scoping` | planning | the milestone is being cut into units |
| `plan_interview` | planning | the `grill-me` skill is probing the design |
| `plan_released` | planning | rows, stories and ADRs are written back |
| `rep_partial` | recovery | the record's intent and the disk disagree; the unit is rebuilt |
| `rep_absent` | recovery | the record claims a commit the repository lacks; it is rebuilt |
| `cor_bad` | correction | the commit is wrong; it is amended or dropped |
| `cor_messy` | correction | the series is noisy; history-cleanup rewrites it |
| `rec_handover_active` | records | the unit's record is open |
| `rec_handover_closed` | records | the unit's record is closed |
| `rec_roadmap_open` | records | a row is open |
| `rec_roadmap_closed` | records | a row is closed with its outcome |
| `rec_discussion_open` | records | an enquiry is in flight |
| `rec_discussion_concluded` | records | the enquiry concluded, its row still open |
| `rec_adr_accepted` | records | a decision record is current |

## The discussion record

One record is one instance of a two-region machine. What its enquiry has established, and whether a roadmap row still names the file, are independent facts: the first is the record's state, carried in its name and its `**Status:**` line, and the second is its tenancy, read from `devlog/roadmap.md`. The record dies only where the two meet.

<!-- snippet: illustrative -->
```mermaid
stateDiagram-v2
    state "Tenancy -- who names the record" as rec_disc_tenancy {
        [*] --> rec_disc_owned
        rec_disc_owned --> rec_disc_orphaned : the last naming roadmap row closes
        rec_disc_orphaned --> rec_disc_owned : an open row takes the record over
    }
    state "Enquiry -- what the record has established" as rec_disc_enquiry {
        [*] --> rec_disc_open
        rec_disc_open --> rec_disc_concluded : the result lands
        rec_disc_open --> rec_disc_rejected : the operator decides against
    }
    rec_disc_concluded --> rec_disc_retired : the file is deleted
    rec_disc_rejected --> rec_disc_retired : the file is deleted
    rec_disc_retired --> [*]
    note right of rec_disc_tenancy
        The regions are orthogonal: tenancy moves when a roadmap row opens or closes, the enquiry moves when the evidence lands. Deletion fires only from a concluded or rejected enquiry whose tenancy has become orphaned.
    end note
```

| Id | Region | Label |
|---|---|---|
| `rec_disc_owned` | tenancy | an open roadmap row names the record |
| `rec_disc_orphaned` | tenancy | no open roadmap row names it, so the file is a deletion candidate |
| `rec_disc_open` | enquiry | the enquiry is in flight |
| `rec_disc_concluded` | enquiry | the enquiry reached its result, and the record is evidence for it |
| `rec_disc_rejected` | enquiry | the operator decided against |
| `rec_disc_retired` | -- | the file is deleted, and the row that outlives it names no file |

The four types differ in what makes `rec_disc_concluded` true -- a story's approach agreed and its rows written, a study's comparison decided, a design's ADR entry landed, a report's run finished -- and in which dependent sends that event. They do not differ in their states, so there is one machine and four guards.

**Invariants.**

- State: a record at rest is `rec_disc_owned` unless the sweep has not yet run; `rec_disc_orphaned` is observed by the gate, never held on purpose.
- State: a live record carries exactly one enquiry state and one tenancy state.
- Transition: a record reaches `rec_disc_retired` only from `rec_disc_concluded` or `rec_disc_rejected`.
- Guard: deletion fires only while tenancy is `rec_disc_orphaned`, so a record whose row is open is never swept.
- Guard: an enquiry opens only while in-flight knowledge must outlive the iteration, which is the `work-log` convention's determination.

**The checks.** `scripts/check_record_names.sh` holds the state vocabulary and the naming shape, and `scripts/check_record_lifecycle.sh` holds the deletion guard and the closed-row rule. The per-transition cases, and the mapping check that every transition here has one, are not written; the row is named in `## Gaps`.

## Commands

Every prompt in the unit loop is an event here, and the command table's row set is held to `workflow/coding-agent/prompts/` by the `Command coverage` query below, which is read by hand. The change flow's three commands are in the next table, so the query reads both.

| Command | Fires from | Leaves the agent in | Dispatches |
|---|---|---|---|
| `/bootstrap` | `sess_start` | `sess_initialized` | `initialize` |
| `/gm` | `sess_start`, `sess_initialized` | `sess_oriented` | `check-in`, `roadmap-maintenance`, `handover-maintenance` |
| `/backlog-triage` | `sess_oriented` | `sess_triaged` | none |
| `/milestone-start` | `ms_none` | `ms_active` | none |
| `/plan` | `ms_active` | `plan_released` | `grill-me`, `/wrapup` |
| `/scope` | `ms_active` | `plan_scoping` | none - suggests a run, or a saved brief in `.agents/drafts` |
| `/iter` | `it_open` | `it_committed` | `roadmap-maintenance`, `handover-maintenance`, `doc-maintenance`, `/wrapup`, `/commit` |
| `/sidequest` | `it_implementing` | `sq_committed` | `/iter`'s orient steps, `/commit` |
| `/milestone-close` | `ms_active` | `ms_closed` | `roadmap-maintenance`; its own bookkeeping commit, not `/commit` |
| `/recovery` | `it_implementing`, `it_committed` | the repaired state | none |
| `/record-correction` | `cor_bad` | `it_closed` | `/prepare-rebase` when the fold needs a port |
| `/read-back` | `rep_partial` | `rep_partial` | none |
| `/wrapup` | a released gate | `chk_close` | `roadmap-maintenance`, `handover-maintenance`, `/commit` |
| `/commit` | a closed unit | `it_committed` | none |
| `/package-eval-snapshot` | any settled state | the same state | `eval` |

`/auto` and `/goal` are reserved by the ADR for M4 and drive no transition here. A draft is not a command: a prompt that exists only under `.agents/drafts/` appears in no row of this table and in no node of the chart.

## Change-flow commands

The change flow is a separate machine: the mergeability of a branch against the trunk, not the unit's progress. Its three commands are listed here so the prompt set has one coverage check.

| Command | Reads | Emits | Hands off |
|---|---|---|---|
| `/prepare-rebase` | a branch and the trunk head | a `ready` branch | `/merge-queue` or `/accept-fast-forward` |
| `/merge-queue` | the ready branches | an order | `/accept-fast-forward`, or `/prepare-rebase` when nothing is ready |
| `/accept-fast-forward` | a ready branch and the head | the trunk advanced | `/prepare-rebase` when the branch is not ready |

## Stories

Each row is a behaviour, written as a path. A path resolves when every id is a state above and every consecutive pair is an edge in the diagram.

| Story | Path |
|---|---|
| One delivered unit | `sess_oriented -> it_open -> it_scope_gate -> it_implementing -> it_acceptance_gate -> chk_close -> it_closed -> it_committed` |
| The next unit after a commit | `it_committed -> it_open -> it_scope_gate` |
| A milestone closes and the next promotes | `ms_active -> ms_close_gate -> ms_closed -> ms_active` |
| A milestone closes and the next is shaped | `ms_active -> ms_close_gate -> ms_closed -> ms_none -> ms_active` |
| A sidequest interrupts an open unit | `it_implementing -> sq_running -> sq_committed -> it_implementing` |
| Planning a milestone | `ms_active -> plan_scoping -> plan_interview -> plan_released -> chk_close -> ms_active` |
| The close checks the rows it wrote | `it_acceptance_gate -> chk_close -> it_closed` |
| Recovering partial work | `it_implementing -> rep_partial -> it_committed -> it_open` |
| Recovering a wrong commit | `it_committed -> cor_bad -> it_closed -> it_committed -> it_open` |
| A project bootstrapped and oriented | `sess_start -> sess_initialized -> sess_oriented -> it_open` |
| The record checks before a release | `it_implementing -> chk_roadmap -> chk_record -> it_acceptance_gate` |

## Checks

Each check is a query a reader makes on the chart and the defect the query finds. They are read by hand today, except legend drift, which `scripts/check_statechart.sh` runs. A script for the rest is the next rung of the maturity chain, and the working document in the session output records what such a script would read.

| Check | The query | The defect it finds |
|---|---|---|
| Unreachable state | every state has an inbound path from a `[*]` and from a region's entry | a command or check no path reaches |
| No dispatcher | every `chk_*` state has at least one incoming edge labelled with a command | a maintenance skill nothing runs |
| Unchecked record write | every edge whose effect writes a `rec_*` state is followed, on every path to a gate, by a `chk_*` state or a gate the chart marks as checked | maintenance work with no check on its path |
| Dangling dispatch | every dispatch named in the command table resolves to a file under `prompts/`, `skills/` or the reference layer | a dispatch to something that does not exist |
| Dead end | every state outside the records region has an outbound edge; a record state in the records region is terminal by design | a command that strands the agent |
| Unsatisfied entry | a command's input contract holds in the state it fires from: `/commit` requires an open handover, `/milestone-close` requires an active milestone | a runbook's precondition the chart violates |
| Guard collision | no state has two outbound edges on one event whose guards can both hold | an ambiguous transition |
| Orphan record | every `rec_*` state has an inbound write edge and an outbound read edge | a record kept and never consulted |
| Path resolution | every path in `## Stories` resolves id by id: each id is a declared state, and each consecutive pair is an edge | a story the map does not support |
| Legend drift | the `## States` id and region columns equal the chart's declarations, in the chart's order | a state declared on one side only, or a region moved in the table |
| Command coverage | every prompt file under `workflow/coding-agent/prompts/` appears in `## Commands` or `## Change-flow commands` | a command the map does not know |

## Gaps

- **Story coverage.** The stories cover the main paths, not every edge: the recovery and records edges are drawn and no story routes them. The query is the edge set minus the pairs the stories use.
- **`/auto` and `/goal`.** Reserved for M4 by `docs/adr/coding_agent_loop_workflow.md`, which is repository-only and cannot be linked from here; no transition, and no node.
- **`history-cleanup`.** The operator dispatches it by hand, naming the units to target, when a draft series holds an inversion or before the branch is packaged. The drawn edge is the correction case; the packaging invocation is the same operator event and is not drawn separately. No prompt dispatches it, so `## Commands` does not name it.
- **Drafting a document.** No command and no state of its own: a document is written inside `it_implementing` under the project documentation convention's drafting reference, and the publishing path this map once drew was `/document`'s, removed with that prompt. `chk_docs` is the check that reads the result.
- **The render capability.** Not built. The chart targets Mermaid 12.1.0, and the intended render target, Pele's compatibility page, could not be read from this container.
