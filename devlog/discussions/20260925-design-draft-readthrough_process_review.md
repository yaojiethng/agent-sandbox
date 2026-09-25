# Read-Through Process Review

**Status:** draft - first write, not yet reviewed.

**Scope:** what the test-suite read-through actually did, why its yield exceeded the existing review passes, and how to turn it and a churn survey into standing workflows. In scope: the read-through's method and output contract, the fan-out protocol, the finding vocabulary and numbering, the by-class handling of the 312 findings, the operator's gaps, and the containment boundary for the backpressure branch. Out of scope: the content of the six design notes and the fixes themselves; this note decides the process, not the remedies. It is a staging document for the read-through close, which is the operator review plus the findings-to-tasks plan session.

## Context

The read-through was opened as M3.1 task "Test-suite read-through and mechanism documentation (operator onboarding)". The stated purpose is knowledge transfer: the operator reads every shell file in the main tooling, the agent annotates the source, frames each test unit in BDD terms, runs a mutation check on the unit's claim, and records what the pass finds. The operator explicitly waived the iteration workflow for it ("we are doing a read-through, not any code changes"), asked for a single output record, and said follow-up work would be scheduled only if the pass surfaced discrepancies.

The method that emerged, and that the record now fixes as the per-file protocol, is six steps: present the annotated source in chat; present every `test_*` unit as Given / When / Then plus what it is supposed to test; run bite checks by mutation (mutate the production file, run the suite, record which units turn red, restore from a `/tmp` backup); write the BDD block back into the test file; record the units, bites, and findings in the read-through record; and keep every harness or methodology lesson in `devlog/AGENT_FEEDBACK.md`. The frame is fixed per unit: the property asserted, why it matters, how it is set up and triggered, and how confident we are that the assertion bites. The record's `## Format (per file, going forward)` section carries the protocol, the bite vocabulary, the assertion vocabulary, and the numbering rule.

The pass ran one production file at a time, paired with its covering test file or files, from `src/libs/` through `src/build/` and `src/capability/` to the phase-4 host shell. Two surfaces were excluded by operator direction: the compose YAML and the capability dockerfile, and later `scripts/macos_bootstrap.sh`, `scripts/manual/*.sh`, and the `check_*.sh` gates. The pass produced one record, six draft design notes, and comment-only BDD blocks in the test files. It ran across a large number of operator turns and was never committed as a sequence of implementation iterations; the delivery is a single documentation commit.

Validated numbers for the delivered record (methods in the appendix):

| Quantity | Value | Source |
|---|---|---|
| Findings rows | 312, numbered 1 to 312, one disposition each | `## Findings` table; `grep` count of numbered rows, restricted to the section, is 312 distinct |
| Sector totals | A 58, B 17, C 54, D 15, F 42, G 4, H 23, I 75, J 16, no sector 8; sum 312 | `## Findings triage` sector table, cross-checked against the per-row sector column |
| Dispositions | 244 fix, 50 note, 7 docs, 7 observe, 4 accepted | per-row action column; matches the close-out table, contradicts the roadmap row (which says 49 note) |
| Consolidation clusters | 31 cluster rows, not 16 | `## Consolidation map`; 24 rows in the main table plus 7 appended below an interrupting paragraph |
| Design notes | 6, all `draft`, 61 to 128 lines each | `devlog/discussions/2026092{4,5}-design-draft-*.md` |
| Bite mutations | per-pass counts sum to 499 (157 in the phase-2 "bite mutations" bullets, 342 in the phase-3/4 "bites run" bullets) | `## Progress`; the record states no grand total |
| Test files with BDD blocks | 49 carry `# Given:`; the commit message and roadmap say 46 | `grep -l '^# Given:' tests/test_*.sh` |
| Record size | 2,036 lines, 518,898 bytes | `wc -lc` |

The central observation is not in doubt: the pass found defect classes the previous implementer and the two review agents did not. The most serious finding is a host-side `eval` of untrusted record content that executes a payload on `make confirm` (rows 38 and 242, one defect from two directions), and the widest factual one is that the runner that produced every other number in the pass can print `0 failed` for a run that failed (rows 262 and 304 through 312, reproduced in the pass). Neither is a regression introduced by the work those review passes reviewed; both are pre-existing and structural.

## Why the read-through found what the other passes did not

This answer separates the four passes by scope, by oracle, and by what each structurally cannot see. The distinction is mechanism, not quality of attention.

| Pass | Unit under review | Oracle | Can see | Structurally cannot see |
|---|---|---|---|---|
| Implementer | the change in progress | runs the suite, owns the change | its own change and the tests it wrote | the change it did not write, and the test it forgot |
| Review pass (thermonuclear and the audit campaign) | a committed diff range, read-only | reasoning over the diff and a seeded context block | structural quality, abstraction growth, doc-contract drift in the diff | anything that predates the diff; whether an existing test bites |
| Test-quality campaign and the per-assertion sweep | the test files | authoring anti-patterns, read by the reviewer | change-mirror tests, dead tests, silent-green and masked-rc classes | the production file each test is supposed to pin; whether a mutation is caught |
| Read-through | every shell file in the main tooling, paired with its covering test | executes a mutation and reads the suite result | pre-existing defects, unpinned behaviour, shadowed guards, cross-file recurrence | nothing in its frame by construction, but it is periodic and slow |

The review pass template is the clearest case. It reviews an exact `git diff <base>..<head>` range, the subagent sees only the prompt and the committed diff, the constraint is read-only, and the verdict is a control signal on the delivery. That shape is correct for its job and is the reason it cannot see the defects the read-through found: a defect that landed three iterations earlier is simply outside the range. The thermonuclear skill's bar is maintainability and structural simplification; it explicitly does not run the tests, and its primary review questions are about abstraction quality, not assertion strength. The test-quality campaign reads test files and applies an anti-pattern checklist; the per-assertion sweep read all 58 test files in full and found six vacuous assertions, one provable silent-green site, and five silent-green classes, and it found a real production defect (the missing exec bit). But its oracle is the reviewer's judgment of an assertion, not the measured behaviour of the production file under mutation, and it does not read the production source as the subject.

The read-through differs in five mechanical ways, all visible in the record:

1. **It is whole-tree, not diff-scoped.** Every shell file in the main tooling is the subject, so a defect is in scope regardless of when it landed. Rows 1 through 312 are overwhelmingly pre-existing.
2. **The oracle is execution, not reasoning.** A bite mutates the production file, runs the suite, and names the unit that went red. That converts "this assertion looks weak" into "this assertion does not fail when the behaviour changes". The vacuous-assertion and shadowed-guard families (for example rows 209 through 214, 228 through 238, 243 through 247, and 251) exist only because the mutation was run.
3. **It pairs the production file with the test that claims to cover it.** The unit table and the bite table sit under one file's subject note, so a coverage claim and its measured outcome are read together. The per-assertion sweep read the tests without the production subject; the review pass read the production diff without the test's claim.
4. **The frame is fixed and per-unit.** Property, why it matters, setup, trigger, bite confidence. A fixed frame makes the pass exhaustive at the unit level rather than sampled, which is how the pass reached files with no dedicated test at all (rows 3, 34, 79).
5. **Findings accumulate in a stable numbered register.** Recurrence across files is detectable: the timestamp format (row 31), the relative-time ladder (row 32), the git-position primitives (row 33), the command-hint family (row 37), and the CLI-to-workflow boundary (row 48) are cross-file families that no single-diff review can assemble. The consolidation map is the residue of that detection.

Two further mechanisms deserve to be named because they are easy to mistake for accidents. First, the pass had the operator as a second discovery channel: the operator's structural questions (why a full `.env` load per field, whether the record readers unify, whether git can replace hand-rolled operations, what invariants the diff workflows owe the operator) produced findings 7, 22, 31 through 33, 37, 48, and the whole diff-invariants and git-boundary notes. Those questions are not in any review prompt. Second, the pass audited the instrument it was using: `scripts/run_tests.sh`, `scripts/lint.sh`, and the `check_*.sh` gates are subjects as well as tools, so their inaccuracies surfaced when they produced wrong verdicts during the pass. A review pass has no such feedback loop.

The accidents are real but secondary. The pass ran for a long time and outside the iteration workflow, on a tree the operator did not need to deliver, which made exhaustive depth affordable; the operator was available across a large number of turns, so the question channel stayed live. The exclusions were also an accident of judgment: the `check_*.sh` gates were triaged away as "not core", and the fan-out then found 21 findings across them plus the runner, including the liveness-gate flake and the coverage gate that counts a stub as coverage. The unflattering reading is that the pass succeeded partly because it removed the usual delivery pressure, not because knowledge transfer is a better review method. The mechanism is still real; the accident explains why it was affordable this time.

## The read-through as a standing workflow

The pass is too expensive to run continuously and too valuable to run once. It belongs as a periodic, whole-tree pass with a named trigger, a bounded unit, and a defined close. Proposed workflow, which should be written as a review brief in the `workflow/coding-agent/` tree beside the existing review prompts, or as a skill, and linked from the testing policy.

**Trigger.** Three triggers, in order of expected use: (a) the start of a refactor or rewrite, where the pass supplies the defect and duplication inventory; (b) a capability branch's close, before its invariants settle into an ADR; (c) a calendar or milestone cadence when neither applies, for example one whole-tree pass per milestone.

**Unit of work.** One production file plus its covering test file or files. A tightly coupled pair or group (a library and its orchestrator, a family of leaves) is one unit when the seams between them are the finding. Every unit ends with all of: annotated source, a units table with a bite column, a bites table, BDD write-back, and findings rows.

**Per-file frame.** The record's six steps, kept verbatim. The frame per unit is the property asserted, why it matters, how it is set up and triggered, and the bite verdict. The pass should state the file's contract in one line before any code, because that line is what a reader retains.

**Bite requirement.** Every unit that claims to pin a behaviour gets at least one mutation of that behaviour. A verdict of proven requires a named failing test file and a re-run to exclude the liveness gate (row 135). A surviving mutation produces a coverage finding, not a pass. Mutations that cannot change behaviour are not mutations; the three trap families the pass hit (a `&& false` inside `[[ ]]`, perl interpolation inside `\Q...\E`, and a killed-but-not-reaped test process) belong in the brief as warnings, and the backup byte-comparison is mandatory before and after every mutation. One suite runs at a time.

**Output contract.** A per-file deliverable in a fixed shape, machine-checkable: the annotated source; the units table; the bites table with the verdict per mutation; the BDD blocks; findings rows in the register's column shape. The register is the durable output; the per-file deliverable is the work product. The chat presentation is a digest, not the deliverable.

**Close.** Triage every row into one sector and one disposition. Build the consolidation map and require a row to join a group only when the finding recurs, not when the class recurs. Open a design note for each design-class sector and a policy doc for the test-organisation sector. Fix rows that need no decision are scheduled separately. The close produces a roadmap write-back; it does not close the milestone until the plan session has mapped the fix batches and the notes.

**Relationship to the existing passes.** The read-through does not replace them. It absorbs one thing from the review pass, the requirement to mutate the changed behaviour of a diff, and one thing from the test-quality campaign, the assertion-audit classes. It adds a whole-tree periodic sweep and a register. The next section argues the subsumption question directly.

## The churn-analysis workflow

The session ran a second, distinct survey that is worth naming as its own workflow: aggregating the commit history to isolate high-churn areas as refactor, redesign, or rewrite targets. The operator asked for it ("do you recall any previous change sectors with large surface area that could be consolidated?"), and the agent answered from git rather than memory. The survey produced two tables and a recommendation.

The first table is the sweeps, mechanical changes that touched many files for one convention. The record's counts are: a 527-file Markdown prose ASCII migration, a 267-file handover field-schema rename, a 209-file `devlog` relocation, a 171-file markdownlint sweep, a 133-file ASCII-punctuation sweep on the live code tree, a 79-file `libs/` move, a 74-file provider-to-`src/reasoning/` move, a 69-file repo-wide ASCII sweep, a 39-file `SCRIPT_DIR` rename that needed a second pass, a 39-file `log` to `devlog` rename, a 37-file `RUN_ID` to `SESSION_ID` rename, and a 33-file `libs/` versus `lib/` cleanup. The repeats are the signal: ASCII punctuation was swept three times, the devlog directory moved twice, the libs directory moved twice. The remedy is a gate ("record the convention before a repo-wide sweep"), not a design note.

The second table is functional churn, by commit count and distinct source files: `flag` 58 commits over 57 source files, `env` 32 over 43, `cli` 31 over 37, `diff` 78 over 49, `patch` 57 over 56, `draft` 67 over 55, `confirm` 39 over 29, `package` 41 over 43, `prune` 33 over 30, `compose` 54 over 57, `interface` 38 over 54. The most-touched files were recorded as `scripts/start_agent.sh` 75, `scripts/agent-sandbox.sh` 66, `scripts/run_agent.sh` 43, `scripts/onboard.sh` 39, `scripts/workflows/draft.sh` 34, `scripts/build.sh` 34, `src/build/compose.sh` 32, `src/capability/entrypoint.sh` 31, `scripts/templates/Makefile.template` 31, `scripts/resume_agent.sh` 26, `scripts/prune.sh` 25, `scripts/stop.sh` 24.

The workflow should be: aggregate `git log` by path and by functional keyword over a stated window; separate mechanical sweeps from functional churn; rank by commits, by distinct files, and by repeat count; cross-reference the ranked list against the read-through register so that a high-churn area with many findings rises; and feed the result into the refactor-scoping session.

The limits are as important as the method, and the survey did not state them. Churn is not defect density: a file churns because it is central, because its contract keeps changing, or because it is edited mechanically. Keyword matching is approximate and its recall is unmeasured. The sweep totals and the churn totals were computed with a method the record does not state, so they are not reproducible: this review measured `scripts/start_agent.sh` at 88 commits with rename following against the record's 75, and `scripts/templates/Makefile.template` at 54 against 31. The differences are probably rename-following and merge handling, but the record does not pin the command, so the numbers cannot be re-derived. A churn survey that feeds a rewrite decision must ship its exact command and its window. A small script under `scripts/` would fix this; none exists today.

## The fan-out protocol

The operator proposed the fan-out mid-session: one subagent reads one file and produces the report, the primary collects the deliverables, presents them one at a time, and writes the findings back. Eight subagents ran on the last file groups (`scripts/guards.sh`, the `check_*.sh` gates, `scripts/lint.sh` and `scripts/check_markdown.sh`, `scripts/macos_bootstrap.sh`, `scripts/manual/*.sh`, both dry-run probes, and `scripts/run_tests.sh`). What the fan-out achieved and what it cost are both measurable.

What it achieved: eight file groups were read, mutated, and written up in parallel. The deliverable sizes are 19,714 to 39,445 bytes, 217,918 bytes in total. The briefs were dispatched around 06:53 and the deliverables landed between 07:06 and 07:20, so the compute phase took roughly 15 to 27 minutes per subagent with a 14-minute collection window (inferred from file modification times, not a recorded metric; the record carries no wall-clock accounting, which the existing `[A] 2026-09-20` feedback entry already names as a gap). Each subagent ran 6 to 23 mutations. Isolation held: the shared tree stayed at its committed state and every deliverable states that each mutated file was restored byte-identical.

What the primary still spent time on after the fan-out:

1. **Claim verification.** Every deliverable's claims were checked against the tree. Most held; one was corrected (a proposed BDD block for the absent-`lsof` unit repeated the unit's false claim).
2. **Reproduction attempts.** The `lint.sh` subagent reported a SIGPIPE mechanism for the liveness-gate flake; the primary could not reproduce it on an idle host (0 in 20,000 isolated iterations, 0 in 12 standalone gate runs) and recorded it as plausible but unconfirmed. The primary reproduced the runner defect itself, independently of the subagent.
3. **Dedup against the register.** The brief mandates grepping the register for the finding rather than the class, and requires `TBD` rather than an invented number. This mostly worked; row 242 still duplicated row 38, and the operator caught it.
4. **Number assignment and table surgery.** The primary assigned the numbers and appended the rows. Two failures: an `edit` anchor copied from the previous round matched the wrong row and duplicated row 274, and the findings table's tail is now out of order (rows 267 through 274 sit after row 312, and row 263 is last) although all 312 numbers are present. The close-out's "findings and triage both 1..312 contiguous" is true as a set and false as an order.
5. **BDD write-back.** The fan-out deliverables supplied BDD blocks, and the write-back is incomplete: `tests/test_lib_contract.sh` and `tests/test_runner_selftest.sh` carry none, and the commit added blocks to 49 test files, not the 46 the commit message and roadmap claim.
6. **The incident.** Concurrent suites plus a leaked spin loop (`test_interactive_session_select.sh` descendants reparented to init, burning about 1.45 CPU-seconds per wall second) destabilized the workspace; a kill loop matched its own command text and killed the primary shell; the report read as absent twice and was preserved to `/tmp`. Clearing the leaks dropped load and suite time. The root cause is the unbounded read in the interactive picker (row 256) plus a runner deadline that kills the test file but not its descendants (row 304). The parallelism created the load that made the gate flake, which qualified every bite baseline the subagents measured.

The protocol to keep, with the collection cost absorbed:

- **A frozen snapshot.** Each subagent should copy a read-only archive taken from a clean committed state, not the live shared tree. One subagent had to reset its private copy because the shared tree was mid-edit. A single `git archive` tarball per batch removes the race.
- **One suite at a time.** Suites serialize across subagents. The brief mentions this only as a footnote; it must be a scheduler rule, with `TEST_PARALLEL` bounded and a mutex or a staggered start. Parallel mutation runs and parallel suites are not the same thing: the mutation work parallelizes, the suite does not.
- **Machine-readable findings.** Each subagent emits a `findings.tsv` block beside its prose, in the register's exact columns, with a provisional stable key (file plus one-line title). The primary maps provisional keys to row numbers in one pass and appends with a script, which removes the anchor-based table surgery that duplicated a row.
- **A scripted post-collection check.** Run one check after the batch: all row numbers present exactly once and in ascending order; every provisional key mapped; the BDD coverage diff between each subject test file and the deliverable's blocks. This is a script, not a manual read.
- **Overlap batches with presentation.** The operator reads one file at a time, so presentation is inherently serial. Start the next batch's compute when the current batch's deliverables land, not when its presentation finishes.
- **Pre-assign the vocabulary.** Sectors, dispositions, bite verdicts, and the deliverable shape are already in the brief; keep them there so the primary never renegotiates format during collection.
- **Fold in verification.** The subagent's own `## Verification` section (commands, baseline, mutation count, restore confirmation) is the primary's audit input; the primary should only re-check claims that fail the scripted check or that contradict the tree.

## Language alignment

The operator asked for clarification of "pinned", for a definition of "bite", for an explanation of the numbering scheme, and why bites appeared to carry an "A" prefix. The record defines the first two; the last two were never given a clean rule. This section is the glossary that should live in the workflow brief, not only in the record.

**Bite.** A mutation of the production file, run against the full suite, used to test whether a named unit's claim is real. Four verdicts. **Proven**: a mutation was run and the named unit failed. **Survived**: a mutation was run and no unit failed; this is a coverage finding. **Read-assessed**: no mutation was run and the claim was judged from source; say why. **Probe-verified**: no unit exists for the behaviour, so it was observed directly in a throwaway harness; the behaviour is documented but unguarded, and the observation is itself a coverage finding.

**Pinned.** A behaviour is pinned when a unit fails if that behaviour is changed. It is the same observation as a proven bite, stated from the assertion's side. Pinning is neither good nor bad by itself: pinning an intended contract is a regression guard; pinning an accident forces a later correct fix to break the test first. Two intermediate states are named at the unit: a **vacuous** unit runs a path without pinning any behaviour inside it, and an **over-broad** assertion pins an outcome without its reason, for example a return code without the diagnostic. The repository's rule for the second state is "Assert the meaning, not the string" in `docs/development/testing-conventions.md`.

**Finding numbering.** A row is a stable identifier and is never renumbered once another document cites it. Consolidation happens by grouping, not by relabelling: a row that records the same finding as an earlier row keeps the earlier row as canonical and records its new evidence there, or states on the new row that it is the same finding, as row 242 does for row 38. Before a new row is numbered, grep the findings table for the finding itself, not for its class. A group's single disposition lives in the document that works the finding. Contiguity and order are checked after every append.

**The bite prefix.** The letter in a bite id is the pass's file-group tag, and the number is the mutation's index within that pass. The tags observed in the record are A for the apply pass, B for the package-branch pass, D for `diff.sh`, E for `diff_export.sh`, I for the interactive pass, L for the lint pass, M for the guards and Makefile passes, R for the run/resume passes, S for the session-save pass, and V for the image-names pass. Within one file pass the tag is constant and the number varies, so a presentation of one file shows a run of ids that all share a letter; the operator saw the apply.sh block (rows 209 through 220, ids A1 through A26) and read the letter as a semantic class. It is not. The tags are also not unique: A was used for both the environment-resolver and apply passes, M for both the Makefile and guards passes, and R for both run and resume/confirm. A bare bite id is therefore not globally identifiable, and the record does not carry a tag registry.

The fix is one naming rule: derive the bite id from the finding row it supports, `bite <row>.<n>` (for example `bite 137.3`), because the row is the stable identifier. If the pass must name a bite before a row exists, use `<passtag>.<n>` and register the tag in the record's Format section in the same pass. Either rule makes an id resolvable without the pass context; the current bare-letter form does not.

## Handling the findings, by class

The 312 rows fall into classes with different resolution rules. The distinction that matters is coverage fix versus contract change: a coverage fix edits only the test tree and can land without a decision; a contract change edits a production interface and needs the owning design note, a propagation checklist, and an ADR entry.

| Class | Representative rows | Patch immediately? | Constraint |
|---|---|---|---|
| Test coverage gap | 1, 2, 5, 6, 9, 13, 21, 34 | Yes | One unit per row. No production edit. Do not pin an undecided contract; gate those behind the owning note |
| Vacuous or over-broad assertion | 8, 26, 42, 171, 181, 188, 192, 213 | Yes | Rewrite the unit to assert the intent its name claims; a rename alone is not the fix |
| Dead code and redundant guard | 4, 27, 35, 56, 149, 175, 222 | Yes, except portability guards | Row 62(c) is a bash-4.0 floor guard; its fate rides the bash-floor decision at rows 51 and 126 |
| Documentation and text drift | 12, 92, 116, 258, 290, 291 | Yes | Text only; correct the record to the code |
| Local logic defect | 11, 23, 24, 25, 26, 36, 50, 105, 106, 157, 234 | Yes | Behaviour is local and the correct behaviour is unambiguous. Add the covering unit with the fix |
| Security defect | 38, 242 | Yes | The host-side `eval` removal needs no design decision; the reader/writer pair that row 22 describes does |
| Instrument defect | 135, 262, 285, 286 through 291, 304 through 312 | Yes, in this branch | These are the backpressure instrument itself. Fixing them is M3.1 work, not follow-up |
| Latent defect in an untested path | 25, 68, 69, 137, 152, 253, 255 | Mixed | Rows 137, 25, and 69 are local and urgent; 152, 253, and 255 change an interface or a state contract and need the note |
| Interface or contract defect | 7, 22, 130, 136, 174, 203 | No | Needs the owning design note and an ADR entry at settlement |
| Design gap | 17, 19, 20, 31, 32, 33, 37, 44, 45, 48, 63, 64 | No | Each note is its own handover |
| Accepted or deferred | 14, 15, 62, 67 | No | The revisit point is named on the row; do not reopen without it |

The direct answers to the operator's three questions. Test gaps can be patched immediately, in a batch ordered by file, because each row has a unit attached and no decision is outstanding; the exception is a coverage gap whose subject contract is undecided, which would pin the wrong thing. Logic defects can be patched immediately only when they are local and unambiguous; the moment a fix changes a caller, a record shape, or a failure contract, it is an interface change in disguise. Interface gaps cannot be patched in this branch: they must land after the note settles, one handover per note, with a propagation checklist over the consumers. The sequencing rule is that the 244 fix rows are cheap and independent, while the note sectors are not; mixing them into one batch is what would break the containment boundary.

## Recording versus resolving

The operator asked whether recording all findings in a file and processing them later loses context or replication detail, or whether the accumulated awareness of repeated problems helps resolution. The evidence supports both answers, with a specific failure mode.

The register preserved context well. Each row carries the file, the class, the evidence (including the bite that proves or survives it), and the disposition. The numbered rows are stable, so the design notes cite them, and the consolidation map converts recurrence into a work unit. The cross-file families (rows 31, 32, 33, 37, 48, 209 through 214, the KV family at row 22) exist only because the rows accumulated in one place: an isolated file pass would have recorded each as a local gap. So the awareness of repeated problems did make targeting easier, and it is the strongest argument for one register.

What the model loses is finding identity across passes, not replication detail. Row 242 re-recorded the `eval` defect as row 38, because the phase-4 pass arrived at it from the consumer side (a hand-built record through `confirm_run`) while the phase-2 pass arrived from the exporter side, and each pass grepped the subject file rather than the accumulated log. The dedup rule now exists (grep the register for the finding, not the class), but it was added after the duplicate; the operator caught it by asking whether the `.draft-state` entry was consolidated with the KV entry. The register also drifts: the close-out table says 50 note rows and the roadmap row says 49; the close-out says 16 cluster rows and the map holds 31; the commit message says 46 test files and 49 carry blocks. Long accumulations need their own integrity check, and a set-contiguity check is not an order check (rows 267 through 274 sit after 312).

The practical conclusion is to keep the register but shrink what the prose has to carry. Findings belong in a machine-readable table with one row per record, and the prose sections should be generated from it or split at the sector once the count passes about one hundred rows. At 312 rows and 519 KB the single file has outgrown its structure: the consolidation map itself is two tables with a paragraph between them and seven rows appended after it.

## Agent feedback on the process

Four classes of weakness are visible in the record and the log, and each has a concrete remedy.

1. **The mutation method had two false-negative families and one false-positive family, all caught only by luck or by a second look.** A `&& false` inside `[[ ]]` is a no-op because `false` is a non-empty string; perl interpolates variables inside `\Q...\E` and turns `\n` into a literal, so a replacement can silently match nothing; and a non-zero suite exit caused by the liveness gate produced a false PROVEN verdict. The existing `[A] 2026-09-25` feedback entry records these. The remedy is already stated and must be mandatory in the brief: compare the mutant to its backup before running, require a named failing unit plus a re-run for PROVEN, and run one suite at a time.
2. **The register's own bookkeeping failed.** A duplicated row came from an `edit` anchor copied from a previous round; the table tail is out of order; the close-out's counts disagree with the roadmap's. The remedy is a scripted append and a scripted check (ascending and unique), run after every batch, not after the close.
3. **The write-back was declared complete before it was.** The close-out claims BDD blocks in 46 files; 49 carry blocks, two files whose blocks the fan-out supplied carry none, and the commit message repeats the wrong count. The remedy is a coverage diff (every unit in every in-scope test file has a block above it) as part of the close gate.
4. **Verification was ad hoc.** The primary checked claims by reading rather than by running a scripted checklist, which is why the liveness-gate mechanism was recorded unconfirmed and the order error survived to close. The remedy is the scripted post-collection check named above.

The one structural criticism of the method itself is that it does not distinguish a defect that the read-through can prove from one it can only describe. Coverage gaps are proven by a surviving mutation; a design smell is read-assessed. The record's class column and disposition carry this, but a reader of the 312 rows has to reconstruct which rows are measured and which are opinions. The brief should require that distinction in the row title, not only in the class.

## Communication effectiveness

The operator's own assessment is that the pass gave a clearer picture of the parts and the seams but left them weak on implementation detail: the code blocks blur, the functionality summary gets skimmed, and the rapid sweep across an unfamiliar language did not aid absorption, yet the pass was useful because it confirmed a non-stale functional understanding. That assessment is accurate and the evidence supports it. The per-file presentation put the annotated source first, in chunks of tens to hundreds of lines, followed by the bite results and findings. The operator read a chat window, so the source arrived as a stream with no persistent navigation; the record holds the structured form but the operator had to hold the code in working memory turn by turn. The result is the pattern the operator reports: the seam and the contract survive, the syntax does not.

The method was effective at exactly what the record values: the inventory frame, the BDD names, and the finding classes are readable and durable, and the operator's comprehension of behaviour and of inter-module seams improved. It was inefficient as an implementation-detail transfer, because the medium is wrong for that goal and the volume is far beyond working memory. Against the whole-tree sweep, the operator retained behaviour and seams, which is the stated goal, so the pass met its stated purpose; it did not meet an unstated purpose, which is reading code.

Concrete changes for the next pass:

1. **Lead with the contract.** One line per file before any code: what it owns, what it refuses, what it leaves behind. One line per seam: what crosses it. The operator keeps those.
2. **Present the seam, then the finding, then minimal code.** Show only the function under discussion, not whole files. The annotated source belongs in the persisted artifact, which the operator can open when a specific claim matters.
3. **Replace passive reading with a claim to falsify.** Each file ends with two or three claims ("the record writer is atomic", "this guard is the only thing refusing a missing project") which the operator marks as believed, doubted, or disproved. This converts reading into active recall and gives the agent a signal about what to re-present.
4. **Keep a one-line-per-file index** in the record: file, what it owns, its seam, findings count. That is the map the operator actually wants to retain.
5. **Separate record from presentation.** The full unit table and the code belong in the artifact; the chat carries the contract, the seam, the bite verdicts, and the finding titles.

## Operator gaps

Non-flattering, and specific.

1. **Definitional drift was tolerated.** "Pinned" was used across dozens of files before the operator asked what it meant, and "bite" and the numbering scheme were only questioned at the end. A glossary is cheap and belongs in the first turn of any new pass. The operator's own preference for reading over meta-discussion explains this, but the cost was a period of misreading the most frequent claim in the record.
2. **The scope exclusion was the wrong cut.** The operator triaged away the `check_*.sh` gates as "not core". The fan-out then found 21 findings across the gates and the runner, including three gates with no self-test, a coverage gate that counts a stub as coverage, and the liveness gate that aborted the suite at random. The gates are the instrument that validates every other claim in the repository; they are core by any measure. The compose YAML and dockerfile exclusion is defensible; the gates exclusion is not.
3. **Agent claims were accepted without independent reproduction.** The false PROVEN verdict, the no-op mutations, and the duplicated row were caught by the agent or by the operator's instinct, not by an operator check. The operator repeated "is that right?" only rarely. Hand-verifying one bite per file, or asking to see the mutant and the failing unit name, would have caught the mutation traps early.
4. **Deferral saturated.** Six design notes were opened and all six remain draft; no ADR was settled. Deferring the decisions was correct for the branch, but a pass that generates twelve design surfaces in one sitting needs an explicit decision queue with owners, or the notes become another register.
5. **The operator's strength is system-level blame, and it should be leaned into.** The highest-yield operator turns were structural: why a full `.env` load per field, whether the record readers unify, whether git can replace hand-rolled operations, what invariants the diff workflows owe the operator, what the interactive helper's contract should be. Those produced six of the design notes. The operator should stop trying to absorb syntax and instead ask the "why does this exist, who owns this, what is the seam" question on every file.

What to brush up on, concretely: bash conditional-expression semantics (a string test that looks boolean), `set -euo pipefail` and subshell exit-status behaviour, the unit contract in `docs/development/test_harness_mechanism.md`, and the two gates that validate the tree (`scripts/lint.sh` and `scripts/run_tests.sh`). The fastest exercise is to hand-run one mutation on a file already understood: change a guard, run the suite, confirm which units fail, restore from a backup. That one exercise teaches bite, pinned, and vacuous together, and it is the knowledge the operator most needs to audit the agent's claims.

## Scope containment

The branch is backpressure: the agent feedback mechanism, including tests and linting. The read-through record is in scope because detection of a defect in the feedback loop is feedback work. The rewrite that remedies a design flaw is not: it changes a production contract in a different capability and needs its own iteration, its own handover, and its own ADR.

The containment boundary, stated as three lanes:

1. **In this branch, immediately.** The instrument defects (rows 135, 262, 285, 286 through 291, 304 through 312), because the backpressure branch owns the runner and the gates; the test coverage, vacuous-assertion, dead-code, documentation, and local-logic fixes; the security fix at rows 38 and 242 because it needs no design decision; and the test-organisation policy doc that sectors I and the record's evidence base require.
2. **In this branch, gated.** Coverage fixes whose subject contract is undecided; the bash-floor portability decisions; anything routed through a design note that has already settled. Each lands only after the gate is cleared.
3. **Out of this branch.** The design-note work: the configuration and argument surface, the persisted record formats, the failure-signalling contract, the build-layer contracts, the CLI-to-workflow boundary, the workflow invariants, the interactive contract, and the git boundary. Each is one handover per note, in the proposed order the record gives.

The pending close task ("operator review, then a findings-to-tasks plan session") should split into four products, and M3.1 should close only when the first three exist:

1. The operator review of the record: accept the triage, its sectors, and its dispositions, and correct the counts that disagree (the note-row count and the cluster count in particular).
2. The fix-batch plan: groups of fix rows with no outstanding decision, ordered by file and by risk, each with the acceptance check "suite green and the named unit added". The instrument fixes and the security fix are their own first batch.
3. One handover stub per design note, with the note linked and the ADR home named, so each rewrite can be scheduled independently of M3.1.
4. The churn-workflow decision: whether to add the scripted survey now or name it as a future task, and with its command pinned.

After those land, M3.1's own remaining work is the instrument fixes plus the test-organisation policy; the production rewrites are successors, not part of backpressure.

## Options Considered

### Option area 1 - what to do with the read-through process

**Option A - leave it as a one-off onboarding exercise.** Smallest change. The pass is not repeatable, the fixture that made it effective (an unstaged tree, an available operator, no delivery pressure) will not recur, and the next high-churn area gets no inventory. Rejected.

**Option B - formalise it as a periodic whole-tree pass beside the existing review passes (recommended).** A written brief with the frame, the bite requirement, the output contract, and the close; triggered per capability branch and per refactor; funded as its own work item because it does not fit inside a delivery iteration. It keeps the whole-tree scope and the mutation oracle that produced the yield, and it adds a register and a close procedure.

**Option C - make the read-through the primary review and retire the diff reviews.** One pass, whole-tree, per delivery. This replaces a cheap, working gate with an expensive one and removes the diff-scoped signal that catches regressions in the change itself. Rejected; see option area 5 for the actual subsumption answer.

### Option area 2 - fan-out architecture

**Option A - sequential, one file at a time in the primary.** What the first half of the pass did. Lowest coordination cost, no suite contention, but the operator waits for each file and the pass takes as long as the sum of the files.

**Option B - batch fan-out over a frozen snapshot, with serialized suites and machine-readable findings (recommended).** It keeps the compute parallel and removes the three failure modes the session hit (mid-edit source, concurrent suite load, hand table surgery). The collection cost is bounded by a script instead of by the primary's reading.

**Option C - a fully scripted pipeline with no subagent judgment.** Fast, reproducible, and unable to write the annotated source, the units table, or the interpretation that makes the deliverable useful to a human reader. The judgment is the product.

### Option area 3 - how the findings are stored

**Option A - one register, appended by hand (status quo).** Preserves context and enables recurrence detection, but at 312 rows it has outgrown its structure and its own counts have drifted.

**Option B - one machine-readable register plus generated prose, split by sector past a threshold (recommended).** The table is the source of truth; the section prose is generated from it; a sector past about one hundred rows becomes its own file. Integrity checks (ascending, unique, every row one disposition) run after every batch.

**Option C - an external issue tracker.** Better query and dedup, but it separates the findings from the record they cite, breaks the stable-row cross-references the design notes rely on, and adds a tool to a repo that deliberately keeps its records in-tree.

### Option area 4 - the bite identifier

**Option A - keep the per-pass letters.** Short, and it collides across passes and cannot be resolved without the pass context.

**Option B - a file tag plus a registry.** Workable, and it asks a reader to look up the tag.

**Option C - derive the id from the finding row, `bite <row>.<n>` (recommended).** The row is already the stable identifier; the bite becomes resolvable from the register alone.

### Option area 5 - subsuming the existing review passes

**Option A - keep both, and add the read-through.** Three overlapping passes and no shared method; the read-through's yield still depends on an unusual amount of operator time.

**Option B - absorb the bite method into the review pass and fold the assertion audit into the read-through (recommended).** The review pass keeps its diff scope and its cheap per-iteration gate but must mutate the changed behaviour of the functions it reviews; the test-quality campaign's assertion classes become the read-through's vacuous/over-pinned finding classes. This removes reasoning-only assertion audits, which the pass proved weaker than measurement, without weakening the diff gate.

**Option C - replace both review passes with the read-through.** Wrong on cost and on coverage. The read-through is periodic and whole-tree; it cannot gate a delivery, and a diff review catches a regression the moment it lands, which is exactly when it is cheap to fix. Rejection is firm: the review passes stay.

### Option area 6 - handling the fix rows

**Option A - one big fix batch.** Highest throughput on paper, and it mixes a one-line coverage fix with a record-format change that needs an ADR, which breaks the branch boundary.

**Option B - three lanes (immediate, gated, design) (recommended),** matching the containment section. The immediate lane is ordered by file and by risk; the gated lane waits on an owning decision; the design lane is one handover per note.

**Option C - defer every row to a design pass.** Wastes the 244 rows that need no decision and leaves known defects in place while notes are written.

## Decision

Adopt Option B in every option area.

1. Write the read-through as a standing workflow brief in the `workflow/coding-agent/` tree, with the six-step frame, the per-unit inventory, the bite requirement and its traps, the output contract, and the close. Link it from the testing policy.
2. Keep the review passes. Add one required step to the review-pass template: mutate the changed behaviour of the functions a diff touches, and report the surviving mutations. Retire the reasoning-only assertion audit from the test-quality campaign and move its classes into the read-through.
3. Add the churn survey as a second distinct workflow, with its exact `git` command and window pinned, mechanical sweeps separated from functional churn, and the ranked list cross-referenced against the read-through register.
4. Run the fan-out on a frozen snapshot, one suite at a time, with each subagent emitting a machine-readable findings block and a verification section; the primary maps provisional keys to row numbers by script and runs a scripted integrity check after the batch.
5. Fix the bite identifier to `bite <row>.<n>` and put the glossary (bite, proven, survived, read-assessed, probe-verified, pinned, unpinned, vacuous, over-broad, numbering rule) in the brief.
6. Keep the findings register, but make the table the source of truth and split a sector into its own file past about one hundred rows. Run the integrity check after every batch, not at the close.
7. Handle findings in three lanes. The immediate lane lands in this branch and includes the instrument fixes, the security fix, and the coverage/doc/dead-code/local-logic rows. The gated lane waits on an owning decision. The design lane is one handover per design note.
8. Contain the branch: M3.1 keeps the instrument fixes and the test-organisation policy; the production rewrites are successors with their own handovers and ADRs.
9. Split the pending close into the operator review, the fix-batch plan, one handover stub per design note, and the churn-workflow decision.

**Register format (2026-09-25).** The register is now paired with a JSON Lines findings file and the labels live there, not in tables. This supersedes item 6's table-as-source-of-truth rule and its sector-split threshold, and it closes the stated-count defect class: counts are computed from the data file and never asserted. Decision and schema: [`20260925-design-draft-findings_register_format.md`](20260925-design-draft-findings_register_format.md).

## Consequences

This makes the read-through repeatable and its yield independent of one unusually long session; it fixes the three mutation-verdict failure families by rule; and it removes the reasoning-only assertion audit that the pass showed is weaker than measurement. The diff gate survives, so a regression still gets caught in the iteration that introduces it.

It changes the cost model: a whole-tree pass is a funded work item, not an iteration, and the review pass grows one required mutation step. It forecloses the option of treating the read-through as a knowledge-transfer talk with a findings side effect; the record is the product and the presentation is a digest. It also forecloses one big fix batch, because the design lane cannot be mixed with the immediate lane without breaking the branch boundary.

The main risk is that the workflow becomes ceremony: a brief, a fan-out, a register, and a close that cost more than the findings they produce if run on a small change. The trigger list bounds that: whole-tree passes are for refactors, capability-branch closes, and the milestone cadence, never for a single-iteration diff. The second risk is register growth; the split threshold and the scripted integrity check are the controls, and the 312-row file is the evidence that they are needed.

One consequence is deliberately left open: the six design notes stay draft. Settling them into ADRs is the design lane's work, and this note does not choose their order beyond the record's proposed order.

## Appendix - evidence and validated counts

### Validation methods

Findings count, contiguity, and duplicates: `awk 'NR>=1256 && NR<=1581' <record> | grep -oE '^\| [0-9]+ '` returns 312 rows, 312 distinct values, maximum 312. Order is not ascending at the tail (see the record-integrity table).

Sector and disposition counts: the per-row table in `## Findings triage` (lines 1600 through 1913) parsed by its sector column and action column. Sector totals are A 58, B 17, C 54, D 15, F 42, G 4, H 23, I 75, J 16, no sector 8, summing to 312 and matching the sector summary table. Action classification gives 244 fix, 50 note, 7 docs, 7 observe, 4 accepted.

Consolidation clusters: 31 rows with a cluster name in `## Consolidation map`, of which 24 are in the first table and 7 are appended after a paragraph and a blank line.

Test files: `git show --numstat <read-through delivery>` lists 49 files under `tests/test_*.sh`, each adding lines only; `grep -l '^# Given:' tests/test_*.sh` returns 49. Nine of the 58 test files carry no `# Given:` block: `tests/test_build_context.sh`, `tests/test_doc_wrap_rule.sh`, `tests/test_lib_contract.sh`, `tests/test_macos_bootstrap.sh`, `tests/test_provider_entrypoint.sh`, `tests/test_providers_pi_preflight.sh`, `tests/test_rename_apply.sh`, `tests/test_runner_selftest.sh`, `tests/test_trace_dry_run.sh`.

Bite and unit totals: `## Progress` bullets. Ten phase-2 bullets use the phrase "N bite mutations" and sum to 157; nineteen phase-3/4 bullets use "N bites run" and sum to 342. The one hundred and fifty-nine proven and two hundred and fifteen survived mentions cover only the bullets that report a split, so they are not comparable to the mutation totals. The record states no grand total; this note does not infer one.

Churn numbers: taken from the record's own survey, which states a 678-commit base. This review could not reproduce the most-touched-file counts exactly; with rename following it measures `scripts/start_agent.sh` at 88 and `scripts/templates/Makefile.template` at 54 against the record's 75 and 31. The method is unpinned in the record, so the churn numbers are reported as the record states them, not as verified.

Fan-out cost: deliverables are 19,714 to 39,445 bytes (217,918 bytes total); briefs were written around 06:53 and deliverables landed between 07:06 and 07:20 by file modification time. These are file-system inferences, not a recorded metric.

### Record-integrity findings

| Defect | Evidence | Effect |
|---|---|---|
| Findings table tail out of order | Numbered rows run 250 through 262, 264 through 266, 275 through 312, 267 through 274, 263 | The close-out claim "findings and triage both 1..312 contiguous" is true as a set and false as an order |
| Disposition count disagrees | Close-out and the per-row table say 50 note rows; the roadmap row says 49 | A planning session reading the roadmap gets a total of 311, not 312 |
| Cluster count disagrees | Close-out says 16 cluster rows; the map holds 31 | Understates the design and fix grouping work |
| Test-file count disagrees | Commit message and roadmap say 46; 49 files carry blocks | The BDD write-back is larger than recorded, and two files that should carry blocks carry none |
| Proposed-order row counts are not reconstructible | The proposed order says Note A 43 rows, Note C 15, Note F 37, Note I 44; the sector table says A 58, C 54, F 42, I 75, and the action table does not yield the stated numbers either | A planning session must not rely on the proposed-order counts |
| Consolidation map structure | Two tables and a paragraph between them, plus seven rows appended outside any table | A reader can miss the appended clusters |
| 27 findings rows carry unescaped pipes, and 18 code spans carry padding | Normalising the findings table into one contiguous table exposes 20 MD056 and 18 MD038 findings across 22 lines; the register is lint-clean only because its fragments are not parsed as tables | The register's validation is currently vacuous: a table that is not one table is not checked, so the 41 findings are hidden by the same structural defect as the order error above |

### The two passes the read-through is compared against

The review-pass template (`workflow/coding-agent/prompts/review-pass-run.md`) reviews an exact diff range, spawns a fresh subagent per round, requires a `VERDICT: APPROVE` or `VERDICT: BLOCK` control signal, and states two seeded finding classes: doc-contract drift and contract-without-mechanism. It is read-only and it does not run mutations. The thermonuclear skill (`src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md`) is a maintainability review of a diff: abstraction quality, file-size growth, spaghetti conditionals, boundary cleanliness. The test-quality campaign (`workflow/coding-agent/audits/test-quality-campaign.md`) and the per-assertion sweep brief (`workflow/coding-agent/audits/test-assertion-sweep-brief.md`) review test files against an authoring bar; the sweep read all 58 test files and found six vacuous assertions, one silent-green site, five masked-rc classes, and one production defect. None of the four reads a production file with the test that claims to cover it and mutates the production file to measure the claim; that pairing and that oracle are the read-through's mechanism.
