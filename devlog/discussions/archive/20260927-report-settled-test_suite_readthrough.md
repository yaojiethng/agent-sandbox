# Report: Test-Suite Read-Through (M3.1)

**Status:** settled
**Date:** 2026-09-27

## Context

The test-suite read-through was M3.1 task "Test-suite read-through and mechanism documentation (operator onboarding)". The stated purpose was knowledge transfer: the operator reads every shell file in the main tooling, the agent annotates the source, frames each test unit in BDD terms, runs a mutation check on the unit's claim, and records what the pass finds. The operator explicitly waived the iteration workflow for it, asked for a single output record, and said follow-up work would be scheduled only if the pass surfaced discrepancies. The pass ran across a large number of operator turns and was never committed as a sequence of implementation iterations; the delivery was a single documentation commit.

The pass ran one production file at a time, paired with its covering test file or files, from `src/libs/` through `src/build/` and `src/capability/` to the phase-4 host shell. Two surfaces were excluded by operator direction: the compose YAML and the capability dockerfile, and later `scripts/macos_bootstrap.sh`, `scripts/manual/*.sh`, and the `check_*.sh` gates.

The pass produced three kinds of output: one findings register, six draft design notes, and comment-only BDD blocks written back into the test files. The register is now a pair: this report (the reasoning record) and [`20260927-report-settled-test_suite_readthrough.jsonl`](20260927-report-settled-test_suite_readthrough.jsonl) (the machine-readable findings data). The register is the deliverable; the per-file work product was the evidence that supported it; the chat presentation was a digest.

## The brief

The read-through ran against a fixed per-file protocol, which is now the standing workflow brief [`read-through-run.md`](../../workflow/coding-agent/prompts/read-through-run.md). The protocol had six steps:

1. Present the annotated source in chat in labelled chunks.
2. Present every `test_*` unit as Given / When / Then, plus a one-line statement of what it is supposed to test.
3. Run bite checks by mutation: mutate the production file, run the suite, record which units turn red, restore from a `/tmp` backup.
4. Write the BDD comment block back into the test file.
5. Record the units, the bites, and the findings in the register.
6. Keep every harness, bash, or methodology lesson in `devlog/AGENT_FEEDBACK.md`, not only in chat.

The inventory frame was fixed per unit: the property asserted, why it matters, how it is set up and triggered, and how confident we are that the assertion bites. The output contract was fixed: a per-file deliverable in a machine-checkable shape, with the register as the durable output.

## The run, phase by phase

The run had five phases. Phase 0 was the complexity audit; phase 1 produced the mechanism write-up; phases 2 to 4 were the file reads.

### Phase 0 - complexity audit

Before reading every test file, the operator asked for an uncomplect audit of the test harness and every test file: parse the mechanism and the suite for sources of complexity, and name which findings are anomalous. The audit applied Hickey's complection table, Ousterhout's depth, and Young's deletability to the runner, the shared helpers, the self-test, the test-side gates, and a structural scan of the 58 test files. Its findings and resolutions:

F1. The order-independence gate was a landed-but-unowned leftover; it was never run by any target. Resolution: deleted, with `REVERSE_RUN` stripped. Order independence holds by construction: each test runs in its own subshell with a fresh fixture.
F2. Skipping was intentional but the mechanism was underbuilt: `skip()` did not exist while the docs listed it, and the runner hard-failed on any skip. Resolution: `skip()` implemented as a real producer; a skipped unit is counted and reported as a warning, never a failure.
F3. Two assertion idioms coexist with no governing rule. Resolution: recorded as a note; the helpers' header was reworded so it calls them "one way to assert", not "the standard way".
F4. The unit-result transport hid a silent-green hazard: counts came from re-parsing printed markers, so a marker-format drift made every count zero while the run still exited 0. Resolution: counts now ride an authoritative, self-describing `UNIT:` report; a missing or malformed report is a hard failure.
F5. The registration shape was defined in two tools. Resolution: the liveness gate owns the whole registration contract; the runner's inline scan was deleted.
F6. The worker-to-parent record was a positional protocol. Resolution: the record became self-describing key-value and the reader validates it strictly.

Verdict: the harness is more complicated locally than it needs to be for the risk it guards, but not badly so. The machinery exists to serve one invariant: a trustworthy green or red signal from a hermetic, dependency-free bash suite. The audit removed the one leftover, built the one intended-but-missing feature, and made the result path loud by construction. No finding was left open.

Known unknowns going in: the full inventory of every test file's assertions and mechanisms. That was the subject of phases 2 to 4.

### Phase 1 - mechanism write-up

The audit and phase 1 produced the mechanism documentation [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md): how the runner dispatches, how the selftest works, and the assert and alloc vocabulary of `tests/libs/test_common.sh`. This is the durable reference for the harness.

### Phase 2 - `src/libs/*`

Twenty files under `src/libs/`, read in twelve batches. The batch ledger:

| Batch | Subject | Units | Bites | Findings |
|---|---|---|---|---|
| 1 | `env.sh`, `env_resolve.sh`, `dirs.sh`, `common.sh`, `interface_contract.sh`, `export_status.sh`, `dry_run_record.sh`, `dry_run_harness.sh`, `session_state.sh` | read | all bite-checked | logged |
| 2 | `session_inventory.sh` | 24 across 3 suites | 22 mutations, 8 findings | 8 |
| 3 | `session_hints.sh` | 5 indirect | 10 mutations, 3 findings | 3 |
| 4 | `draft_state.sh` | 20 across 2 suites | 14 mutations, 4 findings | 4 |
| 5 | `cli.sh` plus the flag-parsing review | 14 | 8 mutations, 3 findings | 3 |
| 6 | `routing.sh` | 36 registrations in 7 groups | 13 mutations, 5 findings | 5 |
| 7 | `session_save_policy.sh` | 22 across 2 suites | 18 mutations, 3 findings | 3 |
| 8 | `diff.sh` plus the module evaluation | 41 across 4 suites | 18 mutations, 6 findings | 6 |
| 9 | `diff_export.sh` | 17 across 2 suites | 16 mutations, 4 findings | 4 |
| 10 | `session_env.sh` | 26 across 2 suites | 20 mutations (14 proven, 6 survived) | 5 |
| 11 | `resume_list.sh` | no unit anywhere | 17 direct probes | 3 |
| 12 | `package_branch.sh` | 23 across 2 suites | 18 mutations (6 proven, 12 survived) | 4 |

Rows 19, 20, and 22 came from the record-parsing survey, not from a single file's read: two cross-cutting recommendations, one open decision (the JSON format choice at row 20), and the consolidated KV entry. Rows 23-30 came from `session_inventory.sh`. Rows 31-33 came from the time and git-primitive survey. Rows 41-43 came from `cli.sh`. Rows 44-47 came from the follow-on CLI and env parser robustness review; row 48 records the cross-surface unification finding.

### Phase 3 - `src/build/*` and `src/capability/*`

Six shell files, plus the mechanism refactor they surfaced. The ledger:

| File | Units | Bites (proven/survived) | Findings |
|---|---|---|---|
| `src/build/image.sh` | 8 | 9 (6/3) | 86-93 |
| `src/build/compose.sh` | 11 | 22 (4/18) | 94-100 |
| `src/capability/git-hooks/pre-commit.sh` | 9 | 11 (5/6) | 101-104 |
| `src/capability/entrypoint.sh` | 5 | 15 (6/9) | 105-112 |
| `src/capability/seed_volume.sh` | 11 | 15 (6/9) | 113-115 |
| `src/capability/snapshot.sh` | 15 | 10 (6/4) | 116-119 |

Shell files only this pass; the compose YAML and the capability dockerfile were excluded by direction.

### Phase 4 - the make-workflow drivers

The host shell, read last because it is the least digestible. The ledger:

| File | Units | Bites (proven/survived) | Findings |
|---|---|---|---|
| `scripts/build.sh` | 7 | 11 (3/8) | 120-125 |
| `scripts/install.sh` | 5 | 12 (6/6) | 126-129 |
| `scripts/stop.sh` | 10 | 11 (4/7) | 130-135 |
| `scripts/prune.sh` | 18 + 4 | 14 (6/8) | 137-151 |
| `scripts/onboard.sh` | 15 | 14 (4/10) | 152-164 |
| `scripts/start_agent.sh` | 28 | 16 (10/6) | 165-173 |
| `scripts/run_agent.sh` | 31 across two families | 26 (12/13, one equivalent) | 174-186 |
| `scripts/resume_agent.sh` | 29 across two families | 31 (12/14) | 187-198 |
| `scripts/agent-sandbox.sh` | 28 | 20 (10/10) | 199-208 |
| `scripts/workflows/apply.sh` | 30 | 26 (8/18) | 209-220 |
| `scripts/workflows/draft.sh` | 30 | 40 (15/25) | 221-241 |
| `scripts/workflows/confirm.sh` | 12 | 25 (12/13) | 242-250 |
| `scripts/workflows/reject.sh` | 4 | 14 (4/10) | 251-254 |
| `scripts/workflows/interactive.sh` | 32 | 14 bites | 256-262 |
| `scripts/templates/Makefile.template` | 15 | 11 bites | 267-274 |
| `scripts/guards.sh` | 4 | 14 bites | 275-283 |
| `scripts/lint.sh`, `scripts/check_markdown.sh` | - | - | 286-291 |
| `scripts/dry_run_capability.sh` | 11 | 14 (8/6) | 292-298 |
| `scripts/dry_run_reasoning.sh` | 5 | 11 bites | 299-303 |
| `scripts/run_tests.sh` | 18 selftest lines | 14 bite verdicts | 304-312 |

The pipelining rows (57-62, 63-67, 68-71) came from `diff.sh` and its module evaluation; rows 82-85 from `package_branch.sh`; rows 255 and 272 came from follow-on probes of the diff workflows. The phase-2 "bite mutations" bullets and the phase-3/4 "bites run" bullets sum to 499 mutations across the pass.

## Mid-run adjustments

The method changed as the pass learned, and each change was written into the report's Format section so later batches followed it. In order:

1. **The `&& false` trap (Format step 3).** Appending `&& false` to an `[[ ]]` condition is not a mutation: inside `[[ ]]`, `false` is a non-empty string, so the condition stays true. Disable a guard with `if false; then`, and confirm the mutant differs from its backup before running the suite.
2. **Feedback recording (Format step 6).** Every harness, bash, or methodology lesson must land in `devlog/AGENT_FEEDBACK.md`, not only in chat; a recurrence is recorded on the existing entry rather than as a new one. Added after the probe-shell-exports incident: the shell that runs the probe scripts keeps its exports between calls, so `PROVIDER_NAME=pi` from an earlier fixture survived into a later probe and made a real mutant look equivalent. Recorded as `[A] 2026-09-25`.
3. **Numbering discipline.** A row is a stable identifier and is never renumbered once another document cites it. Before a new row is numbered, grep the findings table for the finding rather than for its class. Two rows for one finding cost a duplicate disposition and a second fix in the plan; row 242 re-recorded the eval defect as row 38 before the rule existed.
4. **The bite identifier.** Derived from the finding row: `bite <row>.<n>`. The earlier per-pass letter tags collided across passes and could not be resolved without the pass context.
5. **The probe-terminology reword (2026-09-26).** The production-check sense of "probe" was retired to "check"; the method term (probe-verified) and the dry-run-probes proper noun are kept.
6. **The computed-count rule.** Counts are read from the register's data file and never asserted in prose, because a stated count drifts from the thing it counts: the close-out reported 46 BDD-block test files against 49, 16 consolidation clusters against 31, and 49 note rows against 50. The register format decision (`20260925-design-draft-findings_register_format.md`) made the JSON Lines file the record of labels.

## Findings summary

The findings live in the register's data file, [`20260927-report-settled-test_suite_readthrough.jsonl`](20260927-report-settled-test_suite_readthrough.jsonl): one JSON object per line, one line per finding row, 319 rows numbered 1 to 319. Row numbers are stable and are never renumbered; the evidence of each finding (the failing unit name, the probe, the verdict, the measured consequence) is stored in the row's `evidence` field.

All counts below are computed from the data file. Neither they nor the perl one-liners are hand-maintained prose. The row count and the status, sector, and action distributions:

```bash
perl -MJSON::PP -ne '$n++ if decode_json($_); END {print "rows: $n\n"}' 20260927-report-settled-test_suite_readthrough.jsonl
perl -MJSON::PP -ne '$j=decode_json($_); $s{$j->{sector}}++; END {print "$_: $s{$_}\n" for sort {$s{$b}<=>$s{$a}} keys %s}' 20260927-report-settled-test_suite_readthrough.jsonl
perl -MJSON::PP -ne '$j=decode_json($_); $s{$j->{status}}++; END {print "$_: $s{$_}\n" for sort keys %s}' 20260927-report-settled-test_suite_readthrough.jsonl
perl -MJSON::PP -ne '$j=decode_json($_); $s{$j->{action}}++; END {print "$_: $s{$_}\n" for sort keys %s}' 20260927-report-settled-test_suite_readthrough.jsonl
```

Current values: 319 rows; by action 250 fix, 55 note, 7 observe, 7 docs; by status 240 resolved, 61 assigned, 12 accepted, 3 blocked, 2 needs-decision, 1 stale; by sector I 76, A 59, C 54, F 42, H 23, D 19, B 18, J 16, no sector 8, G 4. The `assigned` rows carry an `assigned_to` field naming the roadmap row that now owns them; a row moves to resolved, accepted, or blocked when that roadmap row is worked.

### High-repeat findings

The `refs` field records which rows other findings name as the same defect. The most-cited rows are the persistent design flaws of the tree:

| Row | Cited by | The finding | Home |
|---|---|---|---|
| 22 | 4 rows | The KEY=VALUE record family has four readers and two writers with divergent duplicate-key rules | roadmap row 200 (record shape: one KV read/write pair) |
| 38 | 4 rows | `draft_read_state_from_branch` and `draft_validate_branch` emit unescaped `KEY="VALUE"` for the caller to eval; record content executes as shell code | resolved 2026-09-25 (Slice F1); the KV pair is row 200 |
| 73 | 4 rows | The `.env` parser's regression tests live in its consumer's suite | resolved 2026-09-25 (campaign); the parser family is row 189 |
| 51 | 3 rows | A host requirement (`find -printf`) is both undeclared and unchecked | roadmap rows 97, 162, 207 (host requirements) |
| 242 | 3 rows | The `.draft-state` record is loaded by eval; a command substitution in any field value executes | resolved 2026-09-25 (Slice F1); the KV pair is row 200 |

Rows 79, 41, 68, 188, 171, and 285 are cited twice each; the full jointure is queryable from the data file.

### Clusters

Rows that record the same finding stay separate rows, because a row number is a stable identifier. Consolidation happens by grouping, and the group is the unit of work. A row joins a group only when the finding recurs, not when the class recurs. The consolidation map held 31 clusters; the durable ones, named by their one finding and their home:

| Cluster | Rows | The one finding | Where it is worked |
|---|---|---|---|
| Resolution and declaration | 7, 22, 38-48, 72, 78, 206 | the setting-resolution ladder is bypassed where it exists and improvised where it does not | the resolver note, `20260924-design-draft-resolver_contract.md` |
| The `--help` path across the CLI | 130, 136, 174, 199, 201, 204 | help is not a success path at any layer: the leaf parser prints usage and returns 2, callers' conversions are dead under `set -e`, and the dispatcher reads its own `--help` as a subcommand | one change in `cli.sh` closes eleven dead copies; ADR `command_flag_parsing.md` |
| Fail-open argument and failure handling | 137, 139, 140, 143, 144, 150, 168, 191 | a mistyped argument or a failed step silently removes more than the operator asked for | fix rows; rule 3.5 lands the fail-closed half |
| Overlapping guards in the four diff workflows | 209-212, 214, 277; 228-229, 235-238; 243-247; 251 | the guards overlap, so no unit attributes a refusal to one of them | one fixture per refusal; the diff-invariants note |
| Vacuous assertions | 171, 181, 188, 192, 213 | a unit's assertion is satisfied by a code path other than the one the unit names | fix (test) rows |
| Dead conditions and dead parameters | 149, 175, 222, 226, 259, 312 | a condition or `case` arm made unreachable by the code above it, or a parameter no caller populates | fix (code) rows |
| The simple-record read/write family (KV) | 22, 38, 242 | `KEY=VALUE` records with divergent duplicate-key rules; the `.draft-state` member emits unescaped output for the caller to eval | one `kv_read`/`kv_write` pair; roadmap row 200 |
| The test runner's contract as the instrument | 304-312, 262 | the runner can print `0 failed` for a run that failed, and its deadline cannot kill a SIGTERM-ignoring test | fixed in M3.1; the runner is the instrument every other verdict passed through |
| The dry-run probes' check mechanics | 292-298, 300, 303 | checks that cannot do the job they claim | fix (code) rows; the marker contract fixed 2026-09-25 |
| The Makefile template's argument surface | 267-274 | undeclared accepted-variable set, partial misuse guards, unpinned recipes | fix rows; sectors A, F, I |

## Resolution methods

The 312 rows fell into dispositions with different resolution rules. The distinction that mattered: a coverage fix edits only the test tree and can land without a decision; a contract change edits a production interface and needs the owning design note and an ADR entry at settlement.

The plan session (iteration `20260925-01`) assigned every unresolved row to a track, a campaign, or a named instance, in three lanes:

1. **In the branch, immediately.** The instrument defects (rows 135, 262, 285, 286-291, 304-312), the coverage, vacuous-assertion, dead-code, documentation, and local-logic fixes, the security fix at rows 38 and 242, and the test-organisation policy. Landed across the rectification campaign (slices U1-U9 and F1) and the failure-signalling family.
2. **In the branch, gated.** Coverage fixes whose subject contract is undecided; the bash-floor portability decisions.
3. **Out of the branch, one handover per design note.** The design-lane rows route through the six draft notes.

The conventions edits that shaped the campaign: `testing_policy.md` gained "The file and the unit" (a test file is named for its subject and holds that subject's units); `testing-conventions.md` gained Anti-Pattern 9 (the duplicate unit) and the removed-design form in Anti-Pattern 6. The campaign renamed two files to their subjects (`test_apply_count.sh` to `test_apply_workflow.sh`, `test_session.sh` to `test_session_state.sh`) and created three suites for libs that had none.

## Post-review learnings and process adjustments

### Why the read-through found what the other passes did not

This answer separates the four passes by scope, by oracle, and by what each structurally cannot see. The distinction is mechanism, not quality of attention.

| Pass | Unit under review | Oracle | Can see | Structurally cannot see |
|---|---|---|---|---|
| Implementer | the change in progress | runs the suite, owns the change | its own change and the tests it wrote | the change it did not write, and the test it forgot |
| Review pass | a committed diff range, read-only | reasoning over the diff and a seeded context block | structural quality, abstraction growth, doc-contract drift in the diff | anything that predates the diff; whether an existing test bites |
| Test-quality campaign | the test files | authoring anti-patterns, read by the reviewer | change-mirror tests, dead tests, silent-green classes | the production file each test is supposed to pin; whether a mutation is caught |
| Read-through | every shell file in the main tooling, paired with its covering test | executes a mutation and reads the suite result | pre-existing defects, unpinned behaviour, shadowed guards, cross-file recurrence | nothing in its frame by construction, but it is periodic and slow |

The review pass template reviews an exact `git diff <base>..<head>` range; a defect that landed three iterations earlier is simply outside the range. The thermonuclear skill's bar is maintainability and structural simplification; it explicitly does not run the tests. The test-quality campaign's oracle is the reviewer's judgment of an assertion, not the measured behaviour of the production file under mutation.

The read-through differed in five mechanical ways:

1. **It was whole-tree, not diff-scoped.** Every shell file in the main tooling was the subject, so a defect was in scope regardless of when it landed. Rows 1 through 312 were overwhelmingly pre-existing.
2. **The oracle was execution, not reasoning.** A bite mutates the production file, runs the suite, and names the unit that went red. The vacuous-assertion and shadowed-guard families exist only because the mutation was run.
3. **It paired the production file with the test that claimed to cover it.** A coverage claim and its measured outcome were read together.
4. **The frame was fixed and per-unit.** Property, why it matters, setup, trigger, bite confidence. That made the pass exhaustive at the unit level rather than sampled, which is how it reached files with no dedicated test at all.
5. **Findings accumulated in a stable numbered register.** Cross-file families were detectable; the consolidation map is the residue of that detection.

Two further mechanisms deserve naming. First, the operator was a second discovery channel: structural questions (why a full `.env` load per field, whether the record readers unify, whether git can replace hand-rolled operations, what invariants the diff workflows owe the operator) produced findings 7, 22, 31-33, 37, 48 and the whole diff-invariants and git-boundary notes. Second, the pass audited the instrument it was using: the runner and the gates are subjects as well as tools, so their inaccuracies surfaced when they produced wrong verdicts during the pass.

The accidents were real but secondary: the pass ran for a long time and outside the iteration workflow, on a tree the operator did not need to deliver, which made exhaustive depth affordable; the operator was available across many turns, so the question channel stayed live. The exclusions were also an accident of judgment: the `check_*.sh` gates were triaged away as "not core", and the fan-out then found 21 findings across them plus the runner. The unflattering reading is that the pass succeeded partly because it removed the usual delivery pressure; the mechanism is still real.

### The read-through as a standing workflow

The pass is too expensive to run continuously and too valuable to run once. It belongs as a periodic, whole-tree pass with a named trigger, a bounded unit, and a defined close; the standing brief is `workflow/coding-agent/prompts/read-through-run.md`, linked from the testing policy.

**Trigger.** Three triggers, in order of expected use: (a) the start of a refactor or rewrite; (b) a capability branch's close, before its invariants settle into an ADR; (c) a calendar or milestone cadence, such as one whole-tree pass per milestone.

**Unit of work.** One production file plus its covering test file or files. A tightly coupled pair or group is one unit when the seams between them are the finding. Every unit ends with all of: annotated source, a units table with a bite column, a bites table, BDD write-back, and findings rows.

**Per-file frame.** The record's six steps, kept verbatim. The frame per unit is the property asserted, why it matters, how it is set up and triggered, and the bite verdict. The pass should state the file's contract in one line before any code.

**Bite requirement.** Every unit that claims to pin a behaviour gets at least one mutation of that behaviour. A verdict of proven requires a named failing test file and a re-run to exclude the liveness gate (row 135). A surviving mutation produces a coverage finding, not a pass. The three mutation-trap families (a `&& false` inside `[[ ]]`, perl interpolation inside `\Q...\E`, and a killed-but-not-reaped test process) belong in the brief as warnings, and the backup byte-comparison is mandatory. One suite runs at a time.

**Close.** Triage every row into one sector and one disposition. Build the consolidation map and require a row to join a group only when the finding recurs. Open a design note for each design-class sector. The close produces a roadmap write-back; it does not close the milestone until the plan session has mapped the fix batches and the notes.

**Relationship to the existing passes.** The read-through does not replace them. It absorbs one thing from the review pass (the requirement to mutate the changed behaviour of a diff) and one thing from the test-quality campaign (the assertion-audit classes). It adds a whole-tree periodic sweep and a register. The review passes stay: a diff review catches a regression the moment it lands, which is exactly when it is cheap to fix.

### The churn-analysis workflow

The session ran a second, distinct survey worth naming as its own workflow: aggregating the commit history to isolate high-churn areas as refactor, redesign, or rewrite targets. The standing brief is `workflow/coding-agent/prompts/churn-analysis-run.md`.

The survey produced two tables. The first was the mechanical sweeps, convention changes that touched many files (a 527-file Markdown prose ASCII migration, a 267-file handover field-schema rename, a 209-file `devlog` relocation, a 171-file markdownlint sweep, and smaller ones). The repeats are the signal: ASCII punctuation was swept three times, the devlog directory moved twice, the libs directory moved twice. The remedy is a gate ("record the convention before a repo-wide sweep"), not a design note.

The second table was functional churn, by commit count and distinct source files: `diff` 78 commits over 49 files, `draft` 67 over 55, `flag` 58 over 57, `patch` 57 over 56, `compose` 54 over 57, `env` 32 over 43, `prune` 33 over 30, and the rest smaller. The most-touched files were `scripts/start_agent.sh` 75, `scripts/agent-sandbox.sh` 66, and `scripts/run_agent.sh` 43.

The workflow: aggregate `git log` by path and functional keyword over a stated window; separate mechanical sweeps from functional churn; rank by commits, distinct files, and repeat count; cross-reference against the register so a high-churn area with many findings rises; feed the result into the refactor-scoping session.

The limits are as important as the method. Churn is not defect density. The sweep totals and churn totals in the original survey were computed with a method the record did not state, so they were not reproducible: this review measured `scripts/start_agent.sh` at 88 commits with rename following against the record's 75. A churn survey that feeds a rewrite decision must ship its exact command and window. The standing brief pins both.

### The fan-out protocol

The operator proposed the fan-out mid-session: one subagent reads one file and produces the report, the primary collects the deliverables, presents them one at a time, and writes the findings back. Eight subagents ran on the last file groups. The standing brief is `workflow/coding-agent/prompts/fanout-run.md`.

What it achieved: eight file groups were read, mutated, and written up in parallel, 217,918 bytes of deliverables, each subagent running 6 to 23 mutations. Isolation held: the shared tree stayed at its committed state and every deliverable stated that each mutated file was restored byte-identical.

What the primary still spent time on after the fan-out:

1. **Claim verification.** Every deliverable's claims were checked against the tree. Most held; one was corrected.
2. **Reproduction attempts.** The `lint.sh` subagent reported a SIGPIPE mechanism for the liveness-gate flake; the primary could not reproduce it on an idle host and recorded it as plausible but unconfirmed.
3. **Dedup against the register.** The brief mandates grepping the register for the finding rather than the class. Row 242 still duplicated row 38, and the operator caught it.
4. **Number assignment and table surgery.** An `edit` anchor copied from the previous round matched the wrong row and duplicated row 274, and the findings table's tail ended out of order.
5. **BDD write-back.** The write-back was incomplete: two files carried no blocks, and the commit added blocks to 49 test files, not the 46 the commit message claimed.
6. **The incident.** Concurrent suites plus a leaked spin loop destabilized the workspace; a kill loop matched its own command text and killed the primary shell. The root cause was the unbounded read in the interactive picker (row 256) plus a runner deadline that kills the test file but not its descendants (row 304).

The protocol to keep, with the collection cost absorbed: a frozen snapshot per batch (`git archive` from a clean committed state); one suite at a time as a scheduler rule, not a footnote; machine-readable findings blocks in the register's schema with provisional keys; a scripted post-collection check (all row numbers present once and ascending, every provisional key mapped, BDD coverage diffed); overlap batches with presentation; pre-assign the vocabulary; fold the subagent's verification section in as the audit input.

### Glossary

The vocabulary the pass needs, defined once. **Bite**: a mutation of the production file, run against the full suite, used to test whether a named unit's claim is real. Four verdicts: **proven** (a mutation was run and the named unit failed), **survived** (a mutation was run and no unit failed; a coverage finding), **read-assessed** (no mutation run; the claim was judged from source), **probe-verified** (no unit exists, so the behaviour was observed directly in a throwaway harness; documented but unguarded, and the observation is itself a coverage finding). **Pinned**: a behaviour is pinned when a unit fails if that behaviour is changed -- the same observation as a proven bite, stated from the assertion's side. **Vacuous**: a unit runs a path without pinning any behaviour inside it. **Over-broad**: an assertion pins an outcome without its reason; the repo rule is "Assert the meaning, not the string". The original survey's per-pass bite-letter tags collided across passes and were replaced by `bite <row>.<n>`.

### Handling the findings, by class

| Class | Patch immediately? | Constraint |
|---|---|---|
| Test coverage gap | Yes | One unit per row. No production edit. Do not pin an undecided contract |
| Vacuous or over-broad assertion | Yes | Rewrite the unit to assert the intent its name claims; a rename alone is not the fix |
| Dead code and redundant guard | Yes, except portability guards | The bash-4.0 floor guard's fate rides the bash-floor decision at rows 51 and 126 |
| Documentation and text drift | Yes | Text only; correct the record to the code |
| Local logic defect | Yes | Behaviour is local and unambiguous; add the covering unit with the fix |
| Security defect | Yes | The host-side eval removal needs no design decision |
| Instrument defect | Yes, in the M3.1 branch | These are the backpressure instrument itself |
| Latent defect in an untested path | Mixed | Local and urgent, or needs the owning note |
| Interface or contract defect | No | Needs the owning design note and an ADR entry at settlement |
| Design gap | No | Each note is its own handover |
| Accepted or deferred | No | The revisit point is named on the row |

The direct answers to the operator's three questions. Test gaps can be patched immediately, in a batch ordered by file; the exception is a coverage gap whose subject contract is undecided. Logic defects can be patched immediately only when they are local and unambiguous; the moment a fix changes a caller, a record shape, or a failure contract, it is an interface change in disguise. Interface gaps cannot be patched in the branch: they land after the note settles, one handover per note, with a propagation checklist over the consumers.

### Recording versus resolving

The register preserved context well: each row carries the file, the class, the evidence, and the disposition; stable rows let design notes cite them; the consolidation map converts recurrence into a work unit. The cross-file families exist only because the rows accumulated in one place. That is the strongest argument for one register.

What the model loses is finding identity across passes, not replication detail. Row 242 re-recorded the eval defect as row 38 because each pass arrived from a different side and grepped its subject file rather than the accumulated log. The dedup rule (grep the register for the finding, not the class) was added after the duplicate. The register also drifts: the close-out and the roadmap disagreed on note rows, cluster rows, and test-file counts. Long accumulations need their own integrity check. The conclusion: keep the register, shrink what the prose has to carry, compute counts from the data file.

### Agent feedback on the process

Four classes of weakness, each with a concrete remedy.

1. **The mutation method had two false-negative families and one false-positive family, all caught only by luck or by a second look.** A `&& false` inside `[[ ]]` is a no-op; perl interpolates variables inside `\Q...\E`; and a non-zero suite exit caused by the liveness gate produced a false PROVEN verdict. Remedy: compare the mutant to its backup before running, require a named failing unit plus a re-run for PROVEN, run one suite at a time.
2. **The register's own bookkeeping failed.** A duplicated row came from an `edit` anchor; the table tail ended out of order; close-out counts disagreed with the roadmap's. Remedy: a scripted append and a scripted check, run after every batch.
3. **The write-back was declared complete before it was.** The close-out claimed BDD blocks in 46 files; 49 carried them. Remedy: a coverage diff as part of the close gate.
4. **Verification was ad hoc.** The primary checked claims by reading rather than by running a scripted checklist. Remedy: the scripted post-collection check.

The one structural criticism of the method: it does not distinguish a proved defect from a described one. The brief should require that distinction in the row title, not only in the class.

### Communication effectiveness

The operator's assessment: the pass gave a clearer picture of the parts and the seams but left them weak on implementation detail. The per-file presentation put annotated source first, so the operator read a chat window with no persistent navigation; the record held the structured form but the operator had to hold code in working memory turn by turn. The method was effective at exactly what the record values: the inventory frame, the BDD names, and the finding classes are readable and durable. It was inefficient as an implementation-detail transfer, because the medium is wrong for that goal. The pass met its stated purpose; it did not meet an unstated purpose, which is reading code.

Concrete changes for the next pass:

1. **Lead with the contract.** One line per file before any code: what it owns, what it refuses, what it leaves behind. One line per seam.
2. **Present the seam, then the finding, then minimal code.** Show only the function under discussion, not whole files.
3. **Replace passive reading with a claim to falsify.** Each file ends with two or three claims the operator marks believed, doubted, or disproved.
4. **Keep a one-line-per-file index** in the record: file, what it owns, its seam, findings count.
5. **Separate record from presentation.** The full unit table and code belong in the artifact; the chat carries the contract, the seam, the bite verdicts, and the finding titles.

### Operator gaps

Non-flattering, and specific.

1. **Definitional drift was tolerated.** "Pinned" was used across dozens of files before the operator asked what it meant, and "bite" and the numbering scheme were questioned only at the end. A glossary belongs in the first turn of any new pass.
2. **The scope exclusion was the wrong cut.** The `check_*.sh` gates were triaged away as "not core"; the fan-out then found 21 findings across them and the runner, including three gates with no self-test. The gates are the instrument that validates every other claim in the repository.
3. **Agent claims were accepted without independent reproduction.** The false PROVEN verdict, the no-op mutations, and the duplicated row were caught by the agent or by instinct, not by an operator check. Hand-verifying one bite per file would have caught the mutation traps early.
4. **Deferral saturated.** Six design notes were opened and all six remained draft; no ADR was settled. A pass that generates twelve design surfaces needs an explicit decision queue with owners.
5. **The operator's strength is system-level blame, and it should be leaned into.** The highest-yield operator turns were structural: why a full `.env` load per field, whether the record readers unify, whether git can replace hand-rolled operations, what invariants the diff workflows owe the operator. Those produced six of the design notes.

What to brush up on, concretely: bash conditional-expression semantics, `set -euo pipefail` and subshell exit-status behaviour, the unit contract in `docs/development/test_harness_mechanism.md`, and the two gates that validate the tree. The fastest exercise is to hand-run one mutation on a file already understood.

### Scope containment

The branch was backpressure: the agent feedback mechanism, including tests and linting. The read-through record was in scope because detection of a defect in the feedback loop is feedback work. The rewrite that remedies a design flaw was not: it changes a production contract in a different capability and needs its own iteration and its own ADR.

The containment boundary, stated as three lanes, is under "Resolution methods" above. The pending close split into four products: the operator review of the record, the fix-batch plan, one handover stub per design note (later assigned to tracks instead), and the churn-workflow decision.

### Designs considered and rejected

The process review considered options in six areas and adopted a recommendation in each. The also-rans, one line each: make the read-through a one-off onboarding exercise (rejected: not repeatable, the fixture will not recur); a fully scripted pipeline with no subagent judgment (rejected: the judgment is the product); an external issue tracker for findings (rejected: separates the findings from the record they cite, adds a tool); per-pass letter bite ids (rejected: collide across passes); replace the review passes with the read-through (rejected firmly: cost and coverage); one big fix batch (rejected: mixes lanes and breaks the branch boundary).

### Decision

Adopt the recommended option in every area. The adopted decisions, with their current status:

1. The read-through as a standing workflow brief. Landed: `workflow/coding-agent/prompts/read-through-run.md`, linked from the testing policy.
2. Keep the review passes; add a required mutation step to the review-pass template; retire the reasoning-only assertion audit. Open: logged as the T1 draft row "Review-pass workflow".
3. Add the churn survey as a second workflow. Landed: `workflow/coding-agent/prompts/churn-analysis-run.md`.
4. Run the fan-out on a frozen snapshot, one suite at a time, with machine-readable findings. Landed as draft: `workflow/coding-agent/prompts/fanout-run.md`.
5. Fix the bite identifier to `bite <row>.<n>`; put the glossary in the brief. Landed.
6. Keep the register, paired with a JSON Lines data file. Landed; this report and its jsonl are the pair.
7. Handle findings in three lanes. Landed.
8. Contain the branch. Followed.
9. Split the pending close into four products. Landed in the plan session, iteration `20260925-01`.

**Register format (2026-09-25).** The register is paired with a JSON Lines findings file; labels live in the data, not in tables. This supersedes the table-as-source-of-truth rule and the sector-split threshold, and it closes the stated-count defect class. Decision and schema: [`20260925-design-draft-findings_register_format.md`](20260925-design-draft-findings_register_format.md).

**Terminology note (2026-09-26).** The word "probe" is the read-through's method term (probe-verified), which is kept; the dry-run-probes proper noun is kept; the retired production-check sense is now "check", governed by rule 3.5 of `docs/development/bash-coding-conventions.md`.

### Consequences

The design makes the read-through repeatable and its yield independent of one unusually long session; it fixes the three mutation-verdict failure families by rule; it removes the reasoning-only assertion audit that the pass showed is weaker than measurement. The diff gate survives, so a regression still gets caught in the iteration that introduces it.

It changes the cost model: a whole-tree pass is a funded work item, not an iteration, and the review pass grows one required mutation step. It forecloses treating the read-through as a knowledge-transfer talk with a findings side effect; the record is the product and the presentation is a digest.

The main risk is that the workflow becomes ceremony: a brief, a fan-out, a register, and a close that cost more than the findings they produce if run on a small change. The trigger list bounds that; whole-tree passes are never for a single-iteration diff. The second risk is register growth; the schema discipline and the computed-count rule are the controls.

## Final output artifacts

The operation's durable outputs, each with its current home:

| Artifact | Location | Status |
|---|---|---|
| The findings register (data) | [`20260927-report-settled-test_suite_readthrough.jsonl`](20260927-report-settled-test_suite_readthrough.jsonl) | this report's pair; 319 rows |
| The read-through workflow brief | `workflow/coding-agent/prompts/read-through-run.md` | landed |
| The churn-analysis brief | `workflow/coding-agent/prompts/churn-analysis-run.md` | landed |
| The fan-out brief | `workflow/coding-agent/prompts/fanout-run.md` | landed as draft |
| The register format decision | `20260925-design-draft-findings_register_format.md` | draft; the schema of record |
| The mechanism write-up | `docs/development/test_harness_mechanism.md` | landed |
| The test-harness ADR | `docs/adr/test_harness.md` | landed |
| Design note: diff-pipeline unification | `20260924-design-draft-diff_pipeline_unification.md` | draft; ADR home `docs/adr/diff_packaging.md` |
| Design note: resolver contract | `20260924-design-draft-resolver_contract.md` | draft; ADR home `docs/adr/env_resolution.md` |
| Design note: CLI-to-workflow interface | `20260924-design-draft-cli_workflow_interface.md` | draft; ADR home `docs/adr/command_flag_parsing.md` |
| Design note: diff-workflow invariants | `20260925-design-draft-diff_workflow_invariants.md` | draft; ADR home `docs/adr/diff_workflow_state_contract.md` |
| Design note: interactive-command contract | `20260925-design-draft-interactive_command_contract.md` | draft; ADR home `docs/adr/interactive_command_contract.md` |
| Design note: git boundary | `20260925-design-draft-git_boundary.md` | draft; ADR home `docs/adr/git_boundary.md` |

All six design notes are draft; settling them into ADRs is the design lane's work. The test-organisation rules landed in `testing_policy.md` ("The file and the unit") and `testing-conventions.md` (Anti-Patterns 6 and 9). The BDD blocks live in the test files: 49 test files carry `# Given:` blocks.

## Resolution status

Current status is read from the data file, computed as shown under "Findings summary": 240 resolved, 61 assigned, 12 accepted, 3 blocked, 2 needs-decision, 1 stale, of 319 rows.

The open rows are the follow-up work, named by their home in the roadmap:

| Status | Count | Home |
|---|---|---|
| assigned | 61 | the `assigned_to` roadmap row on each row |
| blocked | 3 | file-boundary owners |
| needs-decision | 2 | a design choice comes first |
| stale | 1 | no longer matches the tree |

The register is closed to new findings from this pass. Rows 313-319 were added by the fix campaign after the pass; the register's remaining open rows are code work owned by the roadmap tracks (T1, T4, T7, T8, T9, T10, T11 and the M3.1 successors). Two items outside the register await a decision: the review-pass mutation step (decision item 2) and whether the churn workflow is adopted as a standing pass (decision item 9).

## Records this supersedes

This report and its jsonl replace three documents, which are deleted:

| Old document | Fate | Content now at |
|---|---|---|
| `20260923-study-active-test_suite_complexity_audit.md` | deleted | this report, Phase 0 |
| `20260924-design-active-test_suite_readthrough.md` | deleted | this report; the findings table's evidence is in the jsonl rows' `evidence` field; the per-file work product and progress bullets are the phase ledgers above |
| `20260925-design-draft-readthrough_process_review.md` | deleted | this report, Post-review learnings section; the decision items and their status are under "Decision" |

The read-through's own output is now the first instance of the `report` discussion type added to `discussion_policy.md` in this iteration. The register format decision (`20260925-design-draft-findings_register_format.md`) remains the schema of record, updated to name the new register pair and the `evidence` field.

The six design notes do not fold in: they are the deferred design work, each with its own ADR destination, and remain separate draft documents. The standing workflow briefs do not fold in: they are the repeatable form of the process, and remain in `workflow/coding-agent/prompts/`.
