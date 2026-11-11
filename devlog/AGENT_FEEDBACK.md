# Agent Feedback

A persistent record of the coding agent's experience and recurring mistakes. Entries record friction points, poor stack design, poor operator prompting, and this-needs-reinforcing notes, plus agent mistakes and code smells. Written by the agent. Reviewed and addressed by the operator.

**Writer:** agent. **Reviewer:** operator. An entry is written when the experience happens, not at the close.

Entries are point-in-time records. The **A/O tag** names who raised the entry: `[A]` for an entry raised by the agent, `[O]` for an entry raised by the operator. Reconcile an entry against the current tree before acting on it. If the tree has outgrown an entry, mark it probation; if the entry is superseded  --  its lesson already carried by another entry or record  --  it jumps to probation as well. Either way, follow the normal procedure: wait to see whether it resurfaces; drop it if it does not.

Catalogue a recurrence on its existing entry. Before writing a new entry, grep the file for an entry on the same topic. If one exists, record the recurrence on it instead of creating a new one: set `state` to `open`, note the prior fix in `legacy:` (or, if already present, add to the resurfacing evidence), and fold the new failure mode into the entry. A recurrence re-opens and extends its entry. This keeps the count of recurrences rising on one entry so the operator can see the pattern and scope a durable fix. Do not open a sibling entry for the same topic.

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/archive/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## [O] 2026-10-31  --  The review runbook lost the sentence that fixed its commit range

```text
state: mitigated
scoped: M3.3.3 - The skill maintenance pipeline
legacy: none
mitigation: the `code-review` shell's input row now owns the range -- the operator's when named, otherwise the branch point the session started at, `.git/SESSION_STATE`'s `init_sha`, proposed for the operator to confirm -- and `references/loop.md` cites it; handover `20261103-02`
```

The `code-review` shell says a review is given "a scope to read", its `references/loop.md` says "Name the range", and the `thermo-nuclear-code-quality-review` runbook says "the current branch's changes". None of the three states where the branch point comes from. The instruction that did was lost when the skill moved to the runbook format, so the range is now inferred at the call site, by the party that has the least evidence for it.

On this branch the inference has two defensible answers eleven commits apart: `init_sha a6b24204` in `.git/SESSION_STATE`, whose range is 6 commits and 42 files, and the skill-pipeline unit's own base `d1d5b636`, whose range is 17 commits and 86 files. A loop that must name its range before it spends a seat stopped to ask instead, and the round trip cost a turn of the operator's attention on the question the loop exists to settle.

The fix belongs where the range is named: one sentence in the runbook or its shell, naming the branch point's source, so the range is derived rather than asked for.

---

## [A] 2026-11-01  --  A report was built before checking that the loader already prints one

```text
state: open
scoped: M3.3.3 - The skill maintenance pipeline; any task whose premise is that a surface nobody reads already holds the fact
legacy: none
mitigation: before building a report over another party's data, run that party's own surface and read what it prints; a handoff's claim that a diagnostic is unread is a claim to check, not a premise to build on
```

The task asked for a session-start report naming a skill name held twice, on the premise that pi records the collision "in a diagnostic nobody reads". pi renders a `[Skill conflicts]` block at every session start, naming the winner and each skipped path, and a quiet startup still shows it. Two versions of a script were written, tested and corrected before anyone ran the loader's own output. Both are deleted and the task closed with no code.

The pattern is not "read the docs first". The premise arrived inside a task, in the operator's voice, and that is the voice an agent is least likely to check. The same session had written the rule for it two commits earlier: name the party that already answers the question, and hand the question to it. Writing that rule was easier than applying it to a task handed over with confidence.

---

## [A] 2026-10-31  --  The review runbook grades structure without the artifact's purpose

```text
state: open
scoped: workflow/coding-agent/skills/code-review/runbooks/thermo-nuclear-code-quality-review/SKILL.md (vendored verbatim from cursor/plugins), and the brief the loop writes for each seat
legacy: none
mitigation: the brief states what the artifact is for and who reads it, and a blocker must name a wrong answer or a cost that shows under a named consumer; a "could be simpler" that no consumer can feel is a note, not a blocker
```

The runbook is a generic maintainability standard: eight non-negotiable rules, thirty-odd things to flag aggressively, sixteen preferred remedies, and an approval bar of "presumptive blockers". It never asks what the artifact is for. On the skill graph that gap ran fifteen rounds: rule 5 ("prefer explicit typed models or shared contracts over loosely-shaped ad-hoc objects") demanded the schema, rule 5 again ("ask whether the boundary should be made explicit") demanded a reader for the schema, and round 15's seat then applied the runbook's own "delete a whole layer of indirection" to the validator those earlier rounds had required. Each reading was faithful; the standard carries no line that could settle between them, because the artifact's readers - an agent querying the graph, an operator reading the render - appear nowhere in it.

Two properties make the drift structural rather than accidental. A fresh seat holds no memory of the earlier rounds' remedies, so it cannot see that it is asking for the opposite. And "assume there is often a code judo move available" plus "end each round on a verdict" is a mandate to find something every round, so convergence has to come from outside the standard - from the purpose, which it does not name.

What the loop did buy is real and worth keeping: a link resolved against the shell's directory, a malformed graph walked after being reported, two readers of one store, 49 test assertions with their arguments reversed, and five gates that printed a pass over input they had failed to read. Those were wrong answers, and the runbook's own pressure is what found them. The fix is not a weaker standard but a bound one: the intent goes in the brief, and a blocker has to name a consumer.

---

## [A] 2026-10-29  --  Two prose principles could not fire while a document was being written, only once it existed

```text
state: probation
scoped: src/reasoning/agent-runtime/pi/config/agent/skills/communication-principle-*/SKILL.md, the description of each; .agents/skills/instruction-authoring/SKILL.md and docs/adr/principle_skill_shape.md; .agents/skills/project-documentation/SKILL.md `## Drafting`; .agents/skills/skill-fork/SKILL.md `## Which half`; .agents/skills/skill-fork/patterns/vendor-bump.md `## Register an edge`
legacy: none
mitigation: a description names the situation the agent is in, so a rule that governs what to write triggers on the act of writing and a rule that governs a reading triggers on what the reading finds. Ten descriptions that govern a draft now open on writing or revising, both prose paths read their own draft back against the two judgements that catch this failure, and the rule sits where a principle skill is authored. Nothing observes whether selection actually fires, which is why the entry is on probation rather than mitigated.

reopened 2026-11-03, same class, different door: the rule was in context and the deciding document was not on the read path. A routing table now names every task the store serves, so a task with no home is a visible gap, and the section a store field is written in names the ADR that decides the field set. Measured on the read-set from the session log and two cold probes; see handover `20261103-04`. The prior mitigation stays, and it did not cover this door: no description rewrite reaches a file the reader never opens.
```

Asked for a reference page on writing a document, I wrote one that opened by describing the gap it filled, then carried a heading per step and a closing section: 33 lines against the 14 that already covered the same five steps in the tree. The two judgements that forbid exactly that were named in the file I was editing and quoted in the layer loaded at session start, and neither fired.

The cause is the shape of the trigger, not the address of the rule. A skill is selected on its `description` alone, and both of those descriptions named a property the finished text has: "a sentence that needs your session", "apply to sediment". A property can only be read once the text exists, so the two principles could fire on a revision pass and no authoring path asked for one. What the description says now is the act: writing or revising prose.

The second half of the fix is the one that does not depend on selection. Both paths that produce prose now end on a read-back step against those two judgements, beside the draft, after it exists.

This is the same class as the 2026-10-27 entry below, a rule held and not applied while drafting, with a different mechanism: there the sentence carried an argument the reader was not in, here the trigger could not be evaluated until the sentence was finished. What would settle it is a recurrence in the same form, a draft whose subject is the document or the session rather than the thing the document is about.

Cross-references: `docs/adr/principle_skill_shape.md` and `.agents/skills/instruction-authoring/SKILL.md`; handover `20261029-01`.

**Recurrence, 2026-11-03.** Writing a store edge, the agent proposed a schema field (`absent`) whose job the bump's three-way merge already does, and the principle now `principle-single-source-of-truth` (then `principle-delegation-over-machinery`, whose description named "a schema, a second record of someone else's guarantee") was in the loaded layer and did not fire. The trace from this session's tool-call log: 231 calls, and of the nine rules bearing on the decision, three were read; the two that settle it (`vendor-bump.md` steps 2 and 7, and the ADR's R3) were opened only after the operator objected. `fork-and-strip.md`, which registers an edge at steps 1 and 5, was never opened, because the artifact was already in the tree and no routing row named that task.

Two probes say what the fix is and is not. A cold agent asked to "catch a stale record" found R3 in the ADR and rejected its own hash proposal, so the failure is not reproducible from a cold start: it was a narrow goal inside a long session, not a wording defect. A second cold agent given the narrow task now reads `vendor-bump.md`, `skill-fork/SKILL.md`, `skill_source_catalog.md` and `source_tracking.md` before writing. The fix is a routing row and a named decision, not a reminder; a reminder would have been unfalsifiable.

**Maintained at M3.7.1 close, 2026-11-09:** no recurrence during the milestone; the description and routing fixes stand, and probation continues.

---

## [A] 2026-10-27  --  An instruction line carried its own argument, twice, an hour after the rule against it

```text
state: open
scoped: none
legacy: none
mitigation: state the rule and put the reason where the decision was taken, which is the handover's Decisions table. The drafting agent is the one agent that cannot make this separation, because it holds the argument the reader was not present for.
```

Asked for the rule that keeps an instruction set lean, I landed 49 words: the rule, then its reason, then a restatement of what the measuring script prints. The operator's own three-line statement of the same thing was shorter and complete. Cut to 23 words, I then folded a second judgement into the same sentence, that an instruction states the rule while its argument stays in the record that decided it, and that was cut too. It appended a clarification about not appending clarification, inside the sentence that names the defect.

The rule was not missing. It had been installed earlier in the same session, in the layer I was editing, and I had read it. What was missing was the reader: an `AGENTS.md` is loaded by a fresh agent with almost no context, and a line that carries its reason charges that reader for a conversation they were not in. The drafting agent is present when the argument is made, so the argument feels like part of the rule, and no rule about the separation changes that, because the rule is read by the same agent holding the same argument.

The meta-level is where this fails, and that is structural rather than a gap in the corpus. Rules-versus-arguments is a drafting-phase judgement, the drafting phase is a higher level than the surface being drafted, and every attempt to encode awareness of the inherited argument adds a third level that needs the same treatment. Filed as a capability limit, not a task: what remains available is the cold-read criterion in the `prose-review` family, and `scripts/report_instruction_growth.sh` as the residue signal.

Cross-references: `## Write Discipline` in the provider layer; handover `20261027-04`.

---

## [O] 2026-10-26  --  A discussion record was named and shaped like a handover

```text
state: mitigated
scoped: .agents/skills/work-log/SKILL.md, the filename rule and the four types
legacy: open from 2026-10-26 until the same day's recurrence, which made the check mechanical
mitigation: when writing into devlog/discussions/, take the name and the frontmatter from the work-log convention rather than from the handover next door: YYYYMMDD-{type}-{status}-{description}.md with no ordinal, and a report's status starts at draft and moves straight to settled. scripts/check_record_names.sh now refuses the shape at the lint gate, so the reading habit is no longer the only guard.
```

Three report records under `devlog/discussions/` took the handover's shape in one session. `20261026-04-report-ablation_problems_found.md` and `20261026-05-report-eval_inputs_required.md` carry the handover's ordinal in the filename and the handover's `status: Active`, which a report never passes through. The third, `20261026-report-settled-census_six_carriers.md`, wrote hours earlier, kept the type and status in the name but still claimed `active` and `type: Discussion`, a type the convention does not have.

Both record kinds live in `devlog/`, and the handover is the one written most often, so its shape is the shape at hand when a report is opened. The naming rule is a section of the work-log convention that a session opens for the handover's section set, not for the discussion's, which is why reading the convention for one record kind leaves the other kind's rule unread.

**Recurrence, same day.** A fourth and fifth record took the ordinal, after this entry was written: `20261026-06-report-carrier_fates.md` and `20261026-07-report-pattern_provenance.md`. The cause was upstream of the habit. The handover's index row read "the two-digit per-day index, reset daily: `max + 1` over the day's existing records", so the number was defined over every record in `devlog/` rather than over handovers, and the exploration-record section named no exclusion. The row now counts the day's handovers, the exploration record's constraint line carries "no per-day index", and `scripts/check_record_names.sh` is a lint gate over the live folder, with eight tests. Two records already written were also renamed: the status joins the description with a hyphen, which the underscore form had broken.

---

## Preamble  --  length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

## [O] 2026-10-24  --  A roadmap measurement note became an artifact and a gate

```text
state: open
scoped: none
legacy: none
mitigation: before designing for a roadmap row, separate what the row measured from what it proposed. Name what reads the artifact besides the check that would keep it true; when the answer is nothing, the row is retired rather than built.
```

The M3.6.3 row **The model-catalog track** carried two kinds of text in one paragraph: measurements (the free tier is one shared 200-request pool per IP per day, and `opencode-go`'s `429` meters a model family) and a proposal ("the per-model declaration and its staleness check"). The agent read the proposal as a requirement and designed a reference document, a structural gate with its test, an ADR, two reserved terms and a roadmap retitle.

Every column the row asked for was already answered: preference by the role line's order, cost by M3.6.2's ledger, a rate limit by the route record's cooled-until with its reason, provenance by the provider's sentence plus the scope, and the model list by `pi --list-models` and `opencode models`. The document's only consumer would have been the gate written to keep it true, which is the registry-nobody-reads class the 2026-10-23 derived-artifacts census recorded.

The operator's correction: the mental model of the algorithm is clean and its capabilities are clean, and the agent keeps adding constraints or features that affect neither correctness nor performance. The row was retired, and the one residue is a line in `dispatch.md` naming the listing command.

## [A] 2026-10-21  --  A vocabulary was chosen for flavour and reverted

```text
state: mitigated
scoped: W2 - Communication Domain Taxonomy
legacy: none
mitigation: choose a leading word only where the word already carries the judgement and the body already says it. Where no such word is evident, leave the field blank and record the deferral, rather than declaring a word the record has to defend afterwards. The definition now states this rule in `communication-principle-maximize-conceptual-leverage`, handover `20261028-06`.
```

One iteration set `metadata: leitwort:` on all twenty-five principle skills in a single pass. The operator rejected the set as poorly chosen and asked for a revert. Two declarations stand, `proximity` and `leverage`, each of which names its own skill's subject and was already committed.

The class is a name chosen because it sounded right rather than because the artifact already uses it. `mapping`, `train`, `delete` and `artifact` each acquired a defence in prose written after the choice, and a defence written after the choice cannot fail. The corpus states the test that was skipped: the word that leads is the word the body teaches, and a candidate the body never says is the wrong word. The one honest signal in the pass was the swap from `carry` to `delete`, and it read as an exception rather than as evidence that the rest were guesses.

The cost was a reverted unit and a row returned to open with its deferral recorded. The durable fix is the destination, not the discipline: the judging pass belongs to the communication-principle consolidation, where the territory is settled before anyone names a part of it.

## [A] 2026-10-19  --  A mining brief asked for a source the records could not supply

```text
state: open
scoped: none
legacy: none
mitigation: before asking a mining dispatch for a share of the corpus from a source, run one grep over that source and count the candidate rows; ask for what the source demonstrably holds, and state the shape the rows take.
```

The census mining brief asked for at least five failure events from the `## Findings` sections of handovers. Six candidates came back and every one was a phrase fragment -- "resume", "Keeping a subagent alive" -- with no sentence and no stated misreading, so the source contributed nothing and the corpus leaned on the other two. The Findings sections state defects about work; they rarely quote the prose that failed. The brief asked for an extraction the source does not carry, and the dispatch answered with the nearest thing it could find instead of an empty result.

## [A] 2026-10-17  --  A dispatch that hits its timeout leaves a half-applied tree

```text
state: open
scoped: T2 - Perf
legacy: none
mitigation: after a dispatch returns rc=124 with a short log, treat the worktree as dirty, not as untouched: run `git status`, diff every changed file against the brief, and only then decide whether to re-dispatch or finish the work in the main thread. Give a script-editing brief a timeout well above the edit size; a 300-line script rewrite and a six-section census both hit 900s on the free tier, and neither finished.
```

Two of four workers dispatched in one parallel call returned rc=124. Both logs held only the model banner, so the failure had no report to read. One of them had nonetheless created `scripts/stop_probe.sh` and modified `tests/stubs/docker`, so the tree carried a partial change set that no worker claimed and no summary described. The other had written nothing.

The class is a timeout that reads as "nothing happened". The mitigation for an empty log already exists in the provider layer, which treats a `rc=0` with an empty log as failure; the same rule is missing for a non-zero rc with an empty log, where the log proves nothing about the tree. Trust no summary over the artifact cuts both ways: a timed-out run has no summary, so the artifact is the only evidence, and it must be read before the work is re-planned.

Raised by the agent during handover `20261017-01`.

## [A] 2026-10-16  --  A deviation from a ported source is not a regression

```text
state: open
scoped: M3.4.2 - Environment declaration seam
legacy: none
mitigation: when a delegated worker's artifact differs from the source it was ported from, measure the property the difference drops before naming it. A difference is evidence of a deviation, not of a lost check; the two claims need separate measurements, and "the source line still passes" answers only the first.
```

A delegated worker ported a green commit from a parked branch. It returned one line changed for no stated reason, `assert_file_exists "$(kv "$state" record)"` to a hard-coded path. I confirmed the source line still passed on this tree, 22 of 22, and reported the change as a weakened assertion.

It was not. The hard-coded string is the value the state's `record` key holds: the test's own `_run_probe` writes `record=$rec` with `rec="${OUTPUT_DIR}/dryrun.<probe>.record"`, and the probe base name resolves to `capability`. Both forms assert the same path, so the worker's line dropped no check. What it did do was hard-code a value the source derived, which breaks the file's idiom and loses generality if the test is reused for another probe.

Two testable claims sat in one sentence. "The worker deviated" is answered by a byte diff. "The deviation weakens the check" is a second claim about what each form evaluates, and a byte diff cannot answer it. Reverting was right, but for the port's attribution rule  --  every line differing from the source needs a checkable reason  --  not for safety.

Raised by the agent during handover `20261016-03`.

## [A] 2026-10-15  --  The decomposition of a task into work units has no owner for a manual run

```text
state: open
scoped: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
legacy: the manual half of [O] 2026-09-25 "An autonomous scope proposal must assign the work to units and commits"; that entry keeps the autonomous half, which this entry does not resolve.
mitigation: `/scope` emits the work-unit table that `iteration_policy.md` `### Unit and scope invariants` defines -- the unit, its commit type, the owned files, its handover -- and files no roadmap row; the session close files it per the project's `task-list` convention. `/plan` gives up its "scoped unit at its stated grain" and hands the decomposition to `/scope`, and the four-move workflow handoff pattern gets one named home so `/scope` can hand off the way `/iter` does.
```

The decomposition has four writers and no owner. `/plan` writes what it calls "the scoped unit at its stated grain". `/iter` invents the granularity of its own single row. `/wrapup` files deferred items as it finds them. `/scope`, drawn before a run, wrote rows for a brief that had not run. All four point at the project's `task-list` convention `**Task granularity**`, which asks for the file and the nature of change, and nothing reads the result.

Measured 2026-10-15 over 151 open rows in `roadmap.md` and `roadmap_future.md`: 87, or 58%, name no file at all, and 17, or 11%, exceed 900 characters against a median of 284 and a maximum of 1645.

The same measurement found no duplicate task rows, zero exact duplicate titles and zero duplicates on the first 45 characters, so the list does not repeat itself. The repetition the operator sees is across `roadmap.md`, `roadmap_future.md` and `changelog.md`, which the churn study measured as six duplicated subjects. That is a property of the three-file record shape rather than of the filing owner, and it belongs to the task-list mechanism milestone.

One owner plus one check. The owner is `/scope`. The check is the record-shape gate that milestone stages, which fails a row carrying neither a file nor a nature of change.

## [A] 2026-10-14  --  A parallel suite run flaked one unit, and no cause was found

```text
state: open
scoped: none
legacy: none
mitigation: when a full suite run reports a failure, re-run the failing file in isolation before trusting the run; a single parallel-run failure that does not reproduce is recorded, not chased.
```

The full-suite run reported `test_prune.sh: test_unknown_args_rejected` failed. The file then passed 22 of 22 units in isolation, and the next full run was clean at 1126 of 1126. The failure carried a partial `UNIT:` report, so it was a unit assertion and not the deadline-expiry mode of the 2026-09-25 entry; `test_unknown_args_rejected` asserts that `scripts/prune.sh --stale=fresh` exits non-zero and names the bad kind, under the default 8-worker run. No reproduction, so no cause is claimed. The points to keep are the triage and the re-run, not a mechanism.

Raised by the agent during handover `20261014-03`.

**Recurrence, 2026-11-07.** The same file flaked again under the parallel run: `test_prune.sh: test_dry_run_preview_names_rule2_orphans_of_removed_records` failed, and the file then passed 22 of 22 alone and the next full run was green at 1496 of 1496. A different unit in the same file each time, which is the same shape as the 2026-10-14 entry: the fixture is shared across the file's units, so a unit that reads another's leftover state fails only under scheduling. No cause is claimed beyond that.

**Recurrence, 2026-10-19** (handover `20261019-12`, a documentation iteration whose change set touched no test): the full run failed `test_git_hook.sh: test_entrypoint_copy_keeps_matching_identity`. The file passed 16 of 16 in isolation, and the next full run passed 1232 of 1232. The same shape as the first entry, a second file, and still no cause.

**Recurrence, 2026-10-24** (handover `20261024-12`, the dispatch refactor): the full run failed `test_interactive_session_select.sh: test_select_session_patch_count_shown`, which passed 37 of 37 in isolation. A third file, the same shape, and still no cause.

**Recurrence, 2026-11-01** (handover `20261101-06`, a change set in the container interface and the link rule): the full run failed `test_providers_pi_preflight.sh: test_bind_mount_warns_on_missing_prompts`, which passed in isolation, and the next full run passed 1424 of 1424. A fourth file, the same shape, and still no cause.
---

## [A] 2026-10-03  --  A heavy test file's own deadline fails it under parallel load

```text
state: open
scoped: none
legacy: none
mitigation: when a full-suite run reports only tests/test_runner_contract.sh as failed, re-run before treating it as a defect; the file takes about 7s alone against a declared 10s deadline.
```

`tests/test_runner_contract.sh` carries `# TEST_DEADLINE: 10` and takes about 7 seconds alone. Two full-suite runs on a loaded container timed it out; a third run passed at 97 seconds. The runner counts a deadline expiry as a failed file, so a load spike reads as a red run.

**Recurrence, 2026-10-05.** Two consecutive full-suite runs each reported exactly one failure, and each named a different file: `tests/test_start_agent.sh` (`test_wizard_picker_abort`) in the first, `tests/test_resume.sh` (`test_interactive_shows_current_branch_hint`) in the second. Both files pass alone, 32 of 32 in the first case, and a third full run was green. The moving name is the diagnostic: a defect does not migrate between files, and a load-dependent one does. Both files drive an interactive picker, so the shared exposure is a wait on a prompt under parallel scheduling rather than a deadline the file declares.

**Recurrence, 2026-10-14.** One full-suite run reported two deadline expiries at once, `tests/test_dry_run_probe.sh` and `tests/test_lint_umbrella.sh`; both passed standalone and the next full run was green at 1126 of 1126. `test_lint_umbrella.sh` runs the real gate in-test and measured 6 to 10 seconds across the session, so its declared 10s budget sits on the expiry. Two expiries in one run is the load signal, and it repeats the 2026-09-25 entry's finding: the per-file deadline is a shared budget sized near the honest runtime, so the container's parallel load decides which files cross it.

**Recurrence, 2026-11-07.** Four expiries in one run: `test_dispatch.sh` at 40s, `test_doc_wrap_legacy_gate.sh` at 45s, `test_dry_run_probe.sh` and `test_skill_map.sh` at 10s each, reported as 1385 of 1389 passed. All four passed alone (22s, 4s, 4s and 30s), and the next full run was green at 1480 of 1480 in 124s, so the count of expiries and not their names is the load signal here: `test_doc_wrap_legacy_gate.sh` now scans the tree in 22s against a 45s budget, and `test_dispatch.sh` takes 30s against 40s, so both sit near their expiry and a loaded host pushes them over.

---

## [A] 2026-10-02  --  A capacity claim was stated as a fact with no signal behind it

```text
state: open
scoped: none
legacy: none
mitigation: before claiming to be out of room, budget or context, check for a signal. If there is no signal, the claim cannot be made -- name it as an inference, or do not make it.
```

After nine work units in one session the agent reported that it had run out of room and would stop short of the remaining six files. It had not run out of room. It had inferred exhaustion from the conversation's length and from a compaction note earlier in the session, and stated the inference as a fact.

The operator asked why. A search for a signal found none: the environment exposes `PI_PROVIDER`, `PI_MODEL`, `PI_SESSION_ID` and `PI_REASONING_LEVEL`, and no budget, token or context variable. There was nothing to check, so the claim could not have been checked -- which is the point. A claim about a state the agent cannot observe is not a report, and the communication standards' ban on hedging pushes toward flat declaratives rather than away from them.

The cost was one turn. The operator asked why, and the work resumed immediately and finished all six files.

**Prevention, in two parts.** The available part is a rule: stopping work early is a decision, and like any other it needs a reason the reader can check. The structural part is a signal -- expose remaining context or budget so an agent reads it instead of inferring it. Filed as a roadmap row.

---

## Entry format

Each entry follows this structural template.

````markdown

## [<A|O>] <date>  --  <short title>

```text
state: open                        // open | probation | mitigated
                                   // probation = durable fix applied, or the tree has
                                   // outgrown the entry; kept for monitoring, dropped on no resurfacing
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```
````

The field block is fenced, so the `doc-wrap` rule reads it as code rather than as one wrapped paragraph.

`[A]` marks an entry raised by the agent. `[O]` marks an entry raised by the operator.

An entry is dropped when monitoring confirms the fix durable  --  a probation entry is kept for monitoring and dropped when it does not resurface. A durable fix is also recorded in the changelog and the roadmap. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Consolidated (M3 cleanup 2026-09-21)

Frame the merged entries below; each replaces the member entries that shared its roadmap solution. Members were consolidated per the cleanup-pass policy in `devlog/discussions/archive/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`; their originating handovers carry a `[CORRECTION]` note.

### [A] 2026-09-21  --  Review-pass framing: directive wording (T1)

```text
state: mitigated
scoped: M3.2.2 -- review-pass framing fixes
legacy: open from 2026-09-21 until the loop moved into `code-review`'s reference
mitigation: the review loop is `workflow/coding-agent/skills/code-review/references/loop.md`. The directive names the base commit and the explicit range, and converts any other scope format; a seeded/runtime copy pair is named by full path with the authoritative copy stated; the round cap is gone, replaced by a check-in on the operator's cadence that reports the round count, cumulative tokens and dollars, the open blockers with their rounds, and the trend. Source session `20260918-10`.
```

### [A] 2026-09-21  --  Evidence before a conclusion: verification discipline (T1)

```text
state: open
scoped: M3 T1 -- evidence-validation (verification) discipline
legacy: none
mitigation: validate evidence before trusting a conclusion, four sub-cases. (1) Treat reviewer remedies as hypotheses; verify each with a repro before applying (a proposed `cmd | mapfile` was worse than the bug). (2) After a negative-test mutation, check syntax (`bash -n`) and that it fails for the intended reason, not a side effect. (3) A filtered summary that gates a conclusion must be validated against unfiltered output (`diff -rq` bare). (4) An in-place suite-claim correction carries a certified rerun recorded beside it.
```

### [A] 2026-09-28  --  Advisor re-run has low marginal value after a clean consensus (U4)

```text
state: open
scoped: M3.2.1 -- advisor-usage criteria
legacy: none
mitigation: a second advisor run that only re-confirms a single mechanical correction adds little over the first run's defect list. In U4 the first run (deepseek-v4-flash) found one real defect (commit-type guidance); the second run merely re-verified the fix and returned a clean bill. The high-value re-run is when a fix touched multiple coupled files or changed the design -- then a fresh reviewer on the changed state earns its cost. Re-run sparingly: prefer one thorough advisor pass, fix, and only re-run when the change was structural or cross-file. Do not re-run to confirm a one-line correction against an authoritative table.
```

### [A] 2026-09-21  --  Install and staleness family (T4)

```text
state: open
scoped: M3 T4 -- self-contained install, atomic replacement, semantic versioning
legacy: none
mitigation: installed CLI staleness is hard to detect and masquerades as a code regression. A new subcommand surfaces as `Unknown subcommand` with no hint that `make install` is needed; diff the installed CLI's valid subcommands against the source before assuming the implementation is wrong. A symlinked CLI resolves to whichever checkout the link points at -- check `readlink -f "$(which <cmd>)"` and that checkout's feature presence before touching project source. The durable fix is the T4 self-contained install + semantic versioning.
```

### [A] 2026-09-21  --  Library and test-harness migrations (T4)

```text
state: open
scoped: M3 T4 -- library migrations
legacy: none
mitigation: tooling and harness notes for the library-migrations track. Use bash-native tools (sed, awk, perl) for text mutation; do not reach for python3 without checking it is present. Exec-style scripts need a `BASH_SOURCE[0] == "$0"` dual-use guard so unit seams can extract functions. A production flag added to a docker/compose call that tests exercise must update the test double's argument parser in the same commit, or the stub misparses and the suite hangs on the record timeout.
```

## Bash

Canonical bash coding rules: the pattern set beside the `code-review-bash` runbook, [`patterns/`](../workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/README.md).

Bash friction entries migrated from `devlog/discussions/20260809-story-active-bash_complaints.md` (deleted).

### [A] 2026-09-19  --  A prose comment starting with the word `shellcheck` becomes a Directive

```text
state: mitigated
scoped: M3.1 -- ShellCheck gate (directive-parse warning)
legacy: none
mitigation: word the line so `shellcheck` is not the first token after `#` (for example "the shellcheck tool absent"). The shell gate now flags a prose directive rather than dropping it silently.
```

ShellCheck parses any comment line whose first token after `#` is `shellcheck` as a directive. A prose comment that begins with the word -- for example a test-file header line reading `#   shellcheck absent  --  rc 1` -- makes the tool emit `SC1073`/`SC1072` parse errors against the file, so the ShellCheck gate fails on the repository's own scripts. The trap fires twice in one file in this iteration because the natural way to start a line about the tool is the tool's name. The failure is loud and the fix is trivial, but it looks like a false positive until the directive rule is known.

Scope: ShellCheck directive parsing. Cross-reference: `p-33` in [`shellcheck.md`](../workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/shellcheck.md).

### [A] 2026-10-26  --  A rule recorded a mechanism nobody had run, and the guard it doubted holds

```text
state: mitigated
scoped: M3.3.2 -- pattern-set migration
legacy: the `[A] 2026-09-19` entry "A sourced-lib while read < file aborts a set -e caller on a missing file" (added `ddc1e76f`, removed by `677b4d8a` when rule 4.4 landed) stated that a surrounding `|| ...` does not rescue the abort "because the abort happens inside the command substitution, not at the call"
mitigation: a guarded call survives a missing file, and what escapes the guard is the shell's own expansion under `set -u`. `p-31` in the pattern set states the case that reproduces and drops the one that does not
```

Rule 4.4 reached the conventions document from the 2026-09-19 entry, and both said an unguarded read inside a sourced function aborts the call site "even if the call is wrapped in `||`". Nothing had been run to establish that. Measured on this container's bash, each case a fresh `bash -c` under `set -euo pipefail`:

| Case | Result |
|---|---|
| a function with a read from a missing file, called with `\|\| true` | survived, rc 0 |
| the same read as a compound command, `\|\| true` | survived, rc 0 |
| the same function called with no guard | rc 1, and the statements after it did not run |
| the function called with `$1` unset under `set -u`, guarded by `\|\| true` | rc 1, the guard did not hold |

So the recommendation was right and the reason was invented: a missing file is an ordinary failure that the guard catches, while an unset parameter fails during expansion, before any command runs, and no `||` on the call can see it. The wrong mechanism is the expensive half, because a reviewer holding it reports a guarded call as still broken and has a citation for saying so.

This is the second rule in one session found asserting a mechanism rather than a behaviour. The other was `${VAR:-default}` keeping an empty value, which it does not, and whose stated right form was the wrong form written the long way. Both were carried across a migration unchanged, so neither was introduced by it, and neither could have been caught by reading: each needed one command run against the shell.

A third instance came from the pass 2 seat that re-read the swept pattern set. `p-10` said an `a && b` chain "reports only `b`'s result", so "the chain returns success". Measured: `f(){ false; }; f && echo b; echo $?` prints `1`, and a function returning 3 leaves 3. The chain carries `a`'s status all along; what goes missing is that nothing reads it before the script runs its next command. The same pass found `p-26` saying an edge is "`source` or `exec`, which runs the target inside the caller's process", when `exec` replaces the caller's process image. Both are now stated as measured.

The shape recurs because a rule is written from a plausible story about the failure rather than from the failure re-run. One command per claim is the whole check.

Scope: how a rule states a mechanism. Cross-reference: `p-31` and `p-6` in `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/`, and `devlog/discussions/20261026-report-draft-pattern_provenance.md`, which records the scan that found both.

## Node

### [A] 2026-11-02  --  A scripted splice on a heading string matched the prose that named the heading

```text
state: open
scoped: M3.3.3 -- the authoring surface
legacy: none
mitigation: anchor a splice on the heading line (`\n### Name\n`), assert it occurs once, and read the surrounding lines back after writing. A bare `indexOf(message)` finds the first mention, and a document that names its own headings in prose has one before the heading itself.
```

Rewriting `### Instruction modality` in `docs/reference/agent_workflow.md` by slicing at `indexOf("### Instruction modality")` cut from a sentence one section above that links to the heading by name, and took the heading line with it: the section lost its title and the paragraph that pointed at it lost its tail. The lint gate passed, because a file with a broken heading is still well-formed Markdown.

This is the second time on this file. The 2026-11-02 handover `20261102-04` records the same failure from a different script, which is what makes it a class rather than a slip: the file names its own sections in prose in at least two places, so the first occurrence is never the heading.

---

## Gotchas  --  operator-raised entries

Entries raised by the operator (tagged `[O]`), migrated from the former `devlog/GOTCHAS.md` (deleted in the unification).

### [O] 2026-08-12  --  Library functions must `return`, not `exit`

```text
state: mitigated
scoped: M3.1 -- sourced-lib / library lint rules
legacy: not swept, fixed on contact
mitigation: library functions sourced by entrypoint scripts must use `return 1`, not `exit 1`. All entrypoints run under `set -euo pipefail`, so a non-zero return triggers script exit identically. Bare `exit` in a sourced function is a latent bug if the function is ever called from a different context (e.g. test harness, sub-shell, interactive use). Entrypoint scripts (`scripts/*.sh`) may use `exit` legitimately. Canonical rule: `p-13` in [`failure-handling.md`](../workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/failure-handling.md). Now gated by `scripts/check_lib_contract.sh`, which runs in the lint gate.
```

### [O] 2026-09-25  --  An autonomous scope proposal must assign the work to units and commits, not only name the deliverables

```text
state: open
scoped: M3 T1 -- Workflow + Policy Organization (iteration and handover policy; roadmap row under T1)
legacy: recurring form of [A] 2026-09-21 "Process improvement: gate-release and scope-first discipline"; that rule covered scope and acceptance criteria but not the commit decomposition of a multi-lane autonomous iteration.
mitigation: for an autonomous iteration, the scope proposal carries a work-unit table naming each unit, its commit type, its file ownership, and its own handover, and the operator confirms that table at Gate 1 before any file is written. One commit per unit. A batch of four fix lanes is four commits, not one. Draw the boundaries by concern, not by file class or commit type: one concern that touches a data file, a dockerfile and a policy clause is one unit, and several concerns that happen to share one commit type are several units. The rule covers a reassignment of the plan wherever it lands, not only the scope proposal: before writing a roadmap write-back that moves or re-bins existing rows, present the exact rows and every row moved, and await the operator's confirmation, whatever grant covers the surrounding implementation. A grant has a lifetime as well as a scope: a divergence ends it, and the two tracker prompts now state that a push or a pop invalidates any grant.
```

The read-through close was released as "follow through everything autonomously", and the agent then landed three workflow briefs, a 661-line lesson plan, the register repair, and 87 fix rows across four lanes as a single commit with one handover. Each sampled change reviewed fine; the aggregate was unreviewable as a unit of work. The operator expected six commits - one per workstream and one per fix lane, each with its own handover - which is the decomposition the scope proposal should have offered and awaited release on. The gate asked what would be delivered and named the lanes, but it never bound the lanes to commits, so autonomy collapsed them.

**A second occurrence, 2026-10-15.** Mid-collaboration, the operator asked whether to re-file the install and layer rows and said "lets collaborate". The agent edited `devlog/roadmap.md` and committed it in the same turn, then presented its two deviations from the operator's mapping as notice after the commit. The operator had opened the exchange for a confirmation, and the autonomy grant covered the implementation units, not a task-list reassignment. The agent read the grant's wording, "review at the end of the milestone, all together", as covering a plan change it did not name. The operator caught it only by reading the reply, and the commit was amended after the assignment was confirmed. The general shape: an autonomy grant is bounded by the artifacts it names, and a change to the plan is not among them unless the operator says so.

**A third occurrence, 2026-10-15.** The agent held a standing grant to proceed on autopilot through a milestone and review at its end. The work then diverged, through a `/tree` and a `/fork`, and the grant was never lifted because it was never written down; it lived only in the conversation. When a return prompt said to resume, the agent read the standing grant as the missing instruction to execute, and began implementing the next node before the operator asked for it. The return prompt lacked a terminal stop, and the grant supplied it. The durable fix is structural and lands in the two tracker prompts: a push or a pop invalidates any grant, so a divergence and its return run with autonomy off until the operator re-grants. The general shape: a grant has a lifetime as well as a scope, and a divergence ends it.

**A missed pop, and why git cannot show it.** The tree also moved because a pop was missed, an operator error, and the commit was amended at the operator's direction. Git cannot show you a missed push or pop. A `/tree` moves inside one session file and a `/fork` creates a new one, so neither appears in the repository. The tracker is the only signal: a live frame whose work item is done, or a HEAD the tracker does not record. That makes the tracker's own freshness a diagnostic, not only a map.

A second form recurred one turn after the first fix. The agent applied the rule and then split the structured-data work into three commits by file class - a `refactor` for the data and its documentation, a `build` for the `jq` package, a `workflow` for the policy clause - and the operator collapsed them into one, because they are one concern: the register moves to JSON Lines, and the tooling and the references it needs travel with it. The counter-case sits in the same session: four fix lanes shared the `fix` type and were correctly left as four commits. The distinguishing test is not the kind of file but the unit of approval - would one reviewer accept or reject these changes together? The JSON change is accepted or rejected as a whole; one fix lane is accepted or rejected on its own.

### [O] 2026-09-29  --  Review prompts: convergence must be optional and the subagent budget echoed

```text
state: open
scoped: M3 T1 -- prompt authoring; `.agents/skills/instruction-authoring/SKILL.md`; review prompts `src/reasoning/agent/prompts/advisor.md` and `workflow/coding-agent/skills/code-review/runbooks/thermo-nuclear-code-quality-review/SKILL.md`
legacy: the review-loop-entry guidance on re-runs ("re-run sparingly", AGENT_FEEDBACK `[A]` 2026-09-28 advisor re-run value) covers when a re-run earns its cost, not whether convergence is optional.
mitigation: a review prompt must not hard-mandate "work to consensus". The convergence loop is one mode; a single-pass review is a legitimate invocation and must be allowed. Advisor-style prompts should be invokable as a single consultation without being forced to converge. Thermo-nuclear-style review prompts should be invokable with or without the convergence constraint. Every review prompt should echo a subagent invocation budget -- the prompt states how many subagent runs the loop may use, so the cost is bounded and visible before dispatch. Put the budget in the brief and the invocation. Raised 2026-09-29 when the operator observed advisor "work to consensus" is a hard constraint and thermo-nuclear carries no budget; record in handover `20260929-11`.
```

## Agent experience  --  session 20260809-04

### [A] 2026-08-10  --  git operations touching the index/worktree revert uncommitted session work

```text
state: open
scoped: M3 T7 -- sandbox persistence (protect uncommitted session work from git ops)
legacy: none
mitigation: negative-test mutation was reverted with `git restore scripts/stop.sh`, which
reverts to HEAD  --  destroying the session"s uncommitted array refactor in that file (the
mutation check itself passed: the test failed as expected; only the revert was wrong).
The generalized form surfaced the same session: a `git stash` + `git checkout
tests/test_trace_start.sh`, since merged into `tests/test_run_agent.sh`, (a) normalized the stub"s working-tree exec mode to the index
mode  --  16 tests failed with "Permission denied"  --  and (b) reverted the test file"s
uncommitted session edits. Root cause of the mode churn was a host/container
`core.fileMode` mismatch (host `false` vs container `true`), not a repo defect; resolved
on the host by bringing `core.fileMode` to parity and normalising host tree exec bits.
Lesson: ANY git operation that touches the index/working tree (stash, checkout, restore,
switch) can revert uncommitted edits and normalize untracked-in-git modes. For
negative-test mutation reverts and debug-patch removal, use temp copies (`cp file
/tmp/x.bak` before mutating, `cp /tmp/x.bak file` after), never git, while the session
has uncommitted changes in that file. To re-assert a lost executable bit regardless of
`core.fileMode`: `chmod +x file` + `git update-index --chmod=+x`.
```

---
[Post-edit annotation -- 2026-09-01]: corrected misdiagnosis. The container mode churn was due to a host-side `core.fileMode` mismatch (host `false` vs container `true`), not a repo defect. Exec-bit issue resolved on the host by bringing `core.fileMode` to parity (`true`) and normalising host tree exec bits.

### [A] 2026-08-21  --  Knowledge/diagnostic tests outside `make test` rot silently

```text
state: mitigated
scoped: none
legacy: none
mitigation: `make test-smoke` / `scripts/check_test_smoke.sh` (20260823-07)
syntax-checks every excluded script non-gatingly; the 20260823-06 audit
also removed the three scripts that had already rotted.
```

`tests/knowledge/`, `tests/integration/` and `tests/eval/` are excluded from the runner glob by documented policy (testing_policy.md), which is correct for non-deterministic seams  --  but nothing ever executes or even lint-checks them, so they rot unnoticed. Precedent: `tests/test_dirs.sh`"s header records that its coverage previously lived in "a broken manual knowledge test that sourced a nonexistent libs/dirs.sh path"  --  rotted until noticed by accident. Cheapest fix: a non-gating `make test-knowledge-smoke` running each script under `bash -n` (syntax only) plus shellcheck, catching structural rot without asserting on their nondeterministic behavior.

### [A] 2026-09-02  --  Non-conforming test prefix introduced (`discovery_` vs `knowledge_`)

```text
state: mitigated
scoped: M2.6
legacy: none
mitigation: 2026-09-04 -- both `discovery_tar_*` probes were deleted with the legacy seed pipeline they probed (handover `20260904-06`), resolving the prefix defect by removal. The entry's deeper failure mode -- a `run_test` registration lost to rename-without-grep, silent because unregistered tests never run -- is now caught mechanically by `scripts/check_test_liveness.sh` (`make test-liveness`), which verified both directions on its first run.
```

The tar feasibility probes landed in `tests/knowledge/` as `discovery_tar_*.sh`, a prefix the testing policy does not list. Their content (external-tool behaviour) is the knowledge category, so the defect is the name, not the placement. Cleanup: rename to `knowledge_tar_*.sh`. Cross-reference: the same change introduced the rename-without-grep pattern -- a `run_test` registration was renamed by `sed` and briefly went missing before the suite caught it.

## Agent experience  --  session 20260904-01 (seed transport redesign)

### [A] 2026-09-04  --  Record-layer documents drafted as reasoning traces needed a full rewrite

```text
state: open
scoped: M3 T8 -- STE-clean sweep / record-layer drafting discipline
legacy: none
mitigation: First drafts of the seed-transport ADR and concept doc mirrored the session's reasoning: narrative history, transient identifiers (session ids, commit hashes, handover names), implementation command dumps, and rationale-as-argument instead of rationale-as-mapping. The operator steer (records follow `communication-principle-write-for-the-reader`; problem / solution / rejected-with-failure-locus / follow-up; requirements as behavioral contracts in concept docs; interface-level descriptions, commands only for external interactions) required full rewrites of both. Mitigation for next time: before writing a record-layer document, propose its skeleton (section list + what each section holds) in chat and get the structure confirmed; write prose only against the confirmed skeleton. Findings F8-F14 in handover 20260904-01-design-start_resume_rsync_stall.md carry the policy-amendment candidates.
```

## Agent experience  --  session 20260918-10 (thermo-nuclear review pass)

### [A] 2026-09-20  --  A subagent review pass is expensive and unmeasured

```text
state: open
scoped: M3 T2 -- the subagent run telemetry and subagent liveness rows
legacy: none
mitigation: postponed to the M3 T2 telemetry rows, which own the instrument for both halves (liveness and per-run metrics). Verbosity guidance until then: seed each round with the prior round's blockers and state the scope narrowly, because a fresh reviewer re-derives context that a measured, resumable run would not need to. Two cheap measures worked in the 2026-09-27 parallel-track trial and are the interim mitigation: wrap the dispatch in a shell that echoes the exit code and the elapsed seconds, and poll the worktree for liveness rather than the log.
```

The thermo-nuclear review pass over this iteration ran two models per round across ten rounds in two tranches. Each round is a fresh `pi -p` context, so no round inherits the previous round's reasoning, and the log stays empty until the run flushes: neither the main agent nor the operator can see whether a round is progressing, stalled on the provider, or merely slow. There is no per-run accounting of wall-clock, tokens, throughput, latency, tool-call time, or agent turns, so the cost of a review tranche cannot be compared against its yield. The concrete cost of that blindness: a round that reports nothing new still consumes a full model pass, and the operator cannot tell from the outside whether a silent log means "thinking hard" or "network died".

Scope: harness-wide measurement gap, not a bash or skill trap. Cross-reference: the consolidated `edit`-tool failure entry in the `## Consolidated (M3 cleanup 2026-09-21)` section routes to the same M3 `perf`/T2 task, which instruments failed tool calls by cause.

## Agent experience  --  session 20260922 (test-harness isolation, M3.1 U1-U7)

### [A] 2026-09-22  --  A condition on an always-true helper is a vacuous assertion; a masked rc hides real defects

```text
state: open
scoped: M3.1 -- final per-assertion sweep (U7)
legacy: ties to [A] 2026-09-20 "A subagent review pass is expensive and unmeasured" -- the fresh-subagent sweep is the yield side of that entry; resurfaced 2026-09-25 in a second form, a mutation that leaves its guard always true (see the `[[ ]]` entry in Bash)
mitigation: `if trace_grep "..." > /dev/null` always took the pass branch because `trace_grep` ends in `|| true`; the traced operation was never gated. Any conditional on a helper that always returns 0 is a vacuous assertion -- use the `grep -q` variant. The sweep found six such assertions and one silent-green (an empty failed `docker compose config` satisfied its own grep). The reverse face: a masked invocation rc hid a real production defect (`scripts/prune.sh` committed without its exec bit, so `stop --prune` returned 126); the same masks that U4 documented as load-bearing also conceal genuine failures, so assert the rc of any success-expected command.
```

---

## Agent experience  --  session 20260924 (test-suite read-through, phase 4)

### [A] 2026-09-25  --  The probe shell persists its exports between tool calls, so a probe can test the wrong environment

```text
state: open
scoped: none
legacy: none
mitigation: `unset` every variable a probe assumes absent, and pass the environment the probe depends on explicitly instead of relying on the caller's state. When a mutant's result looks identical to the pristine run, check for ambient values before concluding equivalence.
```

The bash tool keeps one shell across calls, so an `export` from an earlier fixture survived into a later probe: `PROVIDER_NAME=pi` from a run_agent fixture made a resume mutant - which passes `$PROVIDER_NAME` where the recovered value belongs - behave exactly like the pristine run, and the mutant looked equivalent. Its real behaviour is an abort under `set -u` at the point where the provider is consumed. The same risk applies to any probe that reads a variable it did not set, and the general form is worth keeping: an identical result is evidence of equivalence only if the environment was controlled.

Scope: agent harness (the persistent tool shell). Cross-reference: [A] 2026-09-22 "Test subshells run `set +e`..." documents shell state leaking from a sourced script into its caller; this entry is the same family one level up, between tool invocations.

### [A] 2026-09-25  --  A finding re-found by a later file pass was recorded as a second row instead of checked against the log

```text
state: open
scoped: none
legacy: none
mitigation: before numbering a new finding row, grep the findings table for the finding itself, not for the class it belongs to. When the defect is already recorded, add the new pass's evidence to that row and name the new row as the same finding; do not give it a second disposition. The read-through's own Format section carries the rule.
```

The phase-4 `confirm.sh` pass probed `eval` on a `.draft-state` field, demonstrated the execution, and filed it as row 242. The phase-2 `draft_state.sh` pass had already recorded the same defect as row 38, with both call sites and an end-to-end chain probe, and row 22's KV-family entry already named `.draft-state` as the family's colon-delimited member with eval'd readers. The duplicate was invisible to the per-file workflow because each pass greps the subject file, not the accumulated log, and the finding arrived from a different direction: a chain from the exporter in phase 2, a direct record in phase 4. A class-level grep would not have caught it either, since the class (persisted record formats) has 17 rows. The operator caught it by asking whether the `.draft-state` entry was consolidated with the KV entry.

A second, purely mechanical form recurred during the `guards.sh` integration. Rows 275 to 283 were appended with an `edit` anchor copied from the previous round, `list \`--interactive\` on the two lines |`, which is row 266's tail rather than the tail of the row just added. The anchor still matched, so the new block landed after row 266 and duplicated row 274. The sorting check showed one extra row (`GAP 275` onward, 284 slots for 283 numbers), which is how it was caught. Anchor on the row you just inserted, not on the one you used last time, and run the contiguity check after every append. The report's Format section already states the rule.

Scope: the read-through's findings log and any long-running review whose rows are numbered. Cross-reference: the report's Format section, numbering policy; row 22, row 38, row 242.

The same class recurred on 2026-09-27 inside a dispatched subagent's output, one level up from the findings log. A unit that replaced two tolerant-mode tests with strict-mode coverage defined a test function whose name already existed in the file and registered it a second time. Bash's last-definition-wins made the first body disappear without an error, the registration liveness gate passed because it checks both directions of the registration contract and not for a name used twice, and the suite's unit count came out one higher than the units actually added. The count is what a reviewer compares against a baseline, so an inflated count is not a cosmetic defect: it is an unverifiable number. The durable fix is a duplicate check in `scripts/check_test_liveness.sh`, filed as a T1 roadmap row (the duplicate test name check in the registration gate); the mitigation until it lands is to account for the arithmetic of the count growth after every dispatched return rather than reading the count as a fact.

**Recurrence, 2026-10-26.** A `replace` whose anchor was the line it meant to insert above consumed that line. The assessment entry of `docs/adr/closed_record_corrections.md` was added by replacing the `## 2026-10-18 -- ...` heading with the new section, so the older entry lost its date heading and its four blocks sat under the newer date for a week, where its decision to defer the assessment read as the opposite of the assessment above it. Every gate stayed green, because a heading that disappears leaves valid Markdown and no gate counts headings per record. Re-read the anchor's own text after an insertion, and diff the heading set before and after: a drop of one is the signal.

### [A] 2026-09-25  --  A heavy test file flakes against the shared deadline, and a timeout hides the whole file's unit count

```text
state: mitigated
scoped: M3.1 - Backpressure
legacy: none
mitigation: declare the budget in the file's first ten lines (`# TEST_DEADLINE: <seconds>`) instead of raising `TEST_TIMEOUT` for every file. The runner reads the declaration and names it when the file expires. The runner reads `TEST_DEADLINE`, and three test files declare one.
```

One 5s default is a single budget for test files whose honest runtimes differ by more than an order of magnitude. A harness file that spawns 20+ probe invocations (`tests/test_dry_run_probe.sh`, 3.4 to 5.4s) or runs the real umbrella gate repeatedly (`tests/test_lint_umbrella.sh`, 4.0 to 5.8s) sits on the deadline, so the 8-way parallel suite run expires it at random as the container loads up. The failure mode is worse than a red test: the file prints no `UNIT:` report, so the aggregate silently drops every unit in the file. `tests/test_dry_run_probe.sh` expired once during a mutation run and the suite read 764 units against a 783-unit baseline, with one timeout and no other sign - which also made the mutation's verdict unreadable, since a timeout is not a proof of anything. Two files now declare 10s (`tests/test_lint_umbrella.sh`, `tests/test_runner_selftest.sh`) and the third is added with this entry. Three more files measured above 5s standalone on a loaded container (`test_start_agent.sh`, `test_runner_selftest.sh`, `test_dry_run_probe.sh`), so the declaration is a pattern, not a one-off.

Scope: `scripts/run_tests.sh` and every test file whose honest runtime is near the default. Cross-reference: [`docs/development/test_harness_mechanism.md`](../docs/development/test_harness_mechanism.md) (The gates, The selftest); the mutation-suite roadmap row, which reads the aggregate to judge a survivor.

## Agent experience  --  session 20260927-04 (parallel tracks experiment)

### [A] 2026-09-27  --  A subagent brief's file list must be closed under the test surface

```text
state: open
scoped: M3 T1 -- the brief-construction roadmap row (derive a unit's owned-file set from the tree)
legacy: none
mitigation: before writing a brief, compute each changed file's test closure by searching the test tree for its basename, and put the result in the brief. State the track's whole owned-file set in the brief rather than a per-unit list, and tell the subagent that its working directory is the worktree, so the harness boundary rule maps onto it instead of contradicting it.
```

The first dispatch of the parallel-track trial produced a unit that changed `scripts/macos_bootstrap.sh` and did not own `tests/test_macos_bootstrap.sh`, because the brief named the script and not its test. The subagent verified the two test files the brief named, quoted its counts, reported `done`, and was wrong: the primary's own full-suite run in that worktree read two failures. A subagent cannot see a defect in a file its brief kept it out of, and the ownership rule that produced the clean report is the same rule that hid the defect. The closure is not a naming convention: `scripts/X.sh` maps to `tests/test_X.sh` for most files and misses `src/libs/cli.sh`, which is covered by `tests/test_cli_lib.sh`, so the closure has to be computed by searching the test tree for the basename rather than by pattern.

Two sub-cases from the same trial. A per-unit file list invents a boundary that does not exist: a repair subagent found a defect in a file its own track already owned, declined to fix it because that unit's list omitted the file, and reported it instead - the right call under the brief it was given, and a wasted dispatch under a track-level one. And a subagent working in a worktree outside the canonical sandbox directory needs the brief to remap the boundary rule explicitly, because the provider-layer instruction not to modify files outside the sandbox is a contradiction until the brief says which directory is the project root.

Scope: brief construction for every dispatched subagent, not only the parallel case. Cross-reference: the trial's design record [`20260927-design-draft-parallel_auto_experiment.md`](discussions/archive/20260927-design-draft-parallel_auto_experiment.md), findings F3 and F4; the unit and brief contract in [`sequential-work.md`](../.agents/drafts/sequential-work.md).

### [O] 2026-10-02  --  The policy forbids task lists in non-active milestones, and the roadmap contradicts it every day

```text
state: open
scoped: none
legacy: none
mitigation: M3.1.2 is planned with its task list and a `Not started` status, and the `task-list` convention states the invariant the practice relies on -- a milestone holding open rows is never `Complete`
```

The retired roadmap policy `### Record shape` stated: "Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active." The roadmap has not followed that for months. M3.2.2 carries four rows and reads `Not started` until this session made it `In progress`; M3.2.3 carries nine; the T tracks carry their work as rows; and this session creates M3.1.2 with two tasks and two moved rows against the same line. The alternative the policy names -- a milestone whose work lives in prose and no task list -- is the shape that produced the eighteen deferred items dropped from the handover chain, which were filed nowhere and surfaced only when a survey looked for them. The `task-list` convention now carries the rule and permits task rows on a non-active sub-milestone.

The line protects something real: a reader scanning for unchecked work at the top level should find the active milestone, and a milestone reading `Complete` while holding open rows is a status that lies. But the line as written forbids the one thing that keeps work reachable, and the practice it forbids is what the roadmap depends on. The fix is not to restore the line; it is to replace it with the invariant the practice actually relies on, which is that a milestone holding open rows is never `Complete`, and that a milestone's rows move with it.

Raised by the operator during plan session `20261002-23`.

### [O] 2026-10-02  --  A workflow document restated the instructions the workflow already prints

```text
state: mitigated
scoped: T1 - Workflow + Policy Organization
legacy: none
mitigation: `.agents/skills/instruction-authoring/references/body.md` and `patterns/handoff.md` carry the workflow-document shape; the apply flow is recorded in `diff_packaging.md` and each step prints its own next hop.
```

`/package-branch` carried a `How to apply` section naming `make draft`, `make confirm`, `make reject`, and the soft-reset sequence. Every one of those is printed by a host script, and the section had drifted: it described only the fast-forward route, while a rebased bundle needs `make confirm TARGET_BRANCH=<new-branch> NEW=1`. The drift was silent, because nothing compared the prompt's copy against the scripts'.

Two costs, not one. The reader had no way to tell which copy was current, and the agent could not have told either: it cannot test whether the target fast-forwards, so any route it named would have been a guess from a hash. `make draft` answers it with `merge-base --is-ancestor` and now prints the matching direction.

The rule that persists it: when a workflow hands off to a script, it relays that script's output and adds only what the script cannot know. An instruction the next command prints belongs to that command, and a multi-step flow belongs in the ADR that owns the pipeline rather than in the prompt that starts the first step.

Raised by the operator during handover `20261002-24`.
