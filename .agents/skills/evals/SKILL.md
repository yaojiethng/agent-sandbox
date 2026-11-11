---
name: evals
description: "The experiment on behaviour: measure the control's band, test one treatment against it, grade blind and decide. Use when a skill, prompt or policy claims a behaviour change and a run is the proof."
disable-model-invocation: true
---

# evals

This skill describes one experiment on an instruction set: a claim, a control, a treatment, and the verdict the numbers support. The process bundles the instruments that produce the evidence with the method that reads it, and it states what each instrument can carry.

## The domain

The treatment is an instruction surface, such as a prompt, a skill or a policy sentence, and the outcome is what an agent does with it. One experimental unit is one agent run against a pinned repository, so a run costs context: tokens, turns and wall clock. The grader is an agent as well, because the artefact is prose.

| The traditional frame | Here |
|---|---|
| treatment | the instruction edit under test |
| control | the same instruction set without it, run in the same batch |
| experimental unit | one agent run against one fixture |
| outcome | a blind grade, or a mechanical assertion |
| nuisance variation | sampling, timing, and the grader's own judgement |
| blocking | the paired batch |
| blinding | sanitized labels, with the map kept outside the grade directory |
| pre-registration | the decision rule, declared in the case before the run |
| attrition | invalid runs, reported beside the planned n |
| resolution | one report per n runs, so a difference of one report is often the smallest readable effect |

A run is expensive, so n stays small. The protocol therefore removes the variation it can control and reports the rest.

## The inventory

An experiment runs on a test case and a set of tools. Each is listed with what it comprises and what it cannot carry.

### The test case

**Comprises.** The intent and the subject, the instruction under test, the expected output or rubric, the defect planted in the fixture, a check per assertion with its role and its known-bad input, and the decision rule with its threshold. A machine checks none of these for meaning, so all of them come from the designer.

**Cannot carry.** Whether the rubric grades what the claim asserts, whether the planted defect is the representative one, and whether a check fails for the reason the designer intended. `--check` reads the declaration's form: the paths resolve, the hashes match, the configurations and the decision are well formed, and each check fails its input. It reads no instruction, rubric or expected output.

### The tools

**The runner**, `scripts/run_case.sh`. Gives one cell per configuration, a `--cells` fan-out capped by `EVAL_MAX_PARALLEL`, and a stop class per run. It records the tokens, turns, wall clock and stop class per cell, and writes the benchmark with the analyst read over it. The model it records is the one the session used, not the one requested, so the run step reads that back from the session file. `scripts/check_eval_entrypoint.sh` keeps its callers to this skill and the suite.

**The generator**, `scripts/compile_declaration.sh`. Merges the case and the experiment and recomputes the fixture hashes, so no hash is hand-maintained. It validates nothing, which is `--check`'s job.

**The measures.** `measure_commit.sh` and `measure_report.sh` read a run's artefact, and `measure_session.mjs` reads its transcripts. Each measure prints one JSON object on stdout. A content measure belongs to one case, is hashed with the fixture and dies with it, so the harness holds no library of them.

**The fixture worktree.** A dated copy of one commit, with the bundle and patch hashes compared before the run, and the change returned as a bundle plus a patch. It pins the repository and the overlay, not the model, the tool set or the network.

**The isolation root.** Each run gets its own clone, config directory and `TMPDIR`, and [`patterns/isolation.md`](patterns/isolation.md) states the root's name and reach. The harness detects an escape and invalidates the run rather than preventing it.

**The blind grade.** The assembler shuffles each run into `grade/` under a label-free name and keeps the label in `grade-map.json`, outside that directory. The label is hidden and the grader's judgement is not: the grader is an agent, so it stays a second source of variation that the design measures.

**The stop record.** A stopped dispatch names its stop class and the cells that did not run, so a truncated batch cannot read as a smaller one.

Fields, stores and layout are [`references/harness.md`](references/harness.md); the methods and the validity threat each closes are [`references/methods.md`](references/methods.md); the questions a run must answer are [`references/specification.md`](references/specification.md); what runs taught is [`antipatterns/README.md`](antipatterns/README.md) with its rules in [`patterns/`](patterns/), and a climb over a series of batches is [`playbooks/hillclimb.md`](playbooks/hillclimb.md).

## The workflow

A run is designed by one party and executed by another, so the work is an agreement before it is a run. Five phases, and each opens when the one above it is agreed.

| Phase | Produces | Whose |
|---|---|---|
| scope alignment | the four parts below: intent, enforcement, deliverables, delivery | the operator agrees, and the agent proposes |
| design | the case, the declaration, one mechanism per invariant, the formats | the agent |
| hand off | the declaration, the harness and the baseline, as the run's input | the design, to the run |
| run | cells, graded artefacts, the benchmark | the run |
| close | the verdict, read against the scope alignment | the agent |

Scope alignment settles two things before it builds anything. Whether a run is necessary at all, since a read, a suite run or nothing may answer the claim, and a run is spent only where none of them does. And which method answers it, since a single batch, a paired batch, a factorial, a screen and a climb close different threats, which [`references/methods.md`](references/methods.md) states.

Scope alignment has four parts, and the agent supplies the mechanism under each while the operator agrees it is the right one.

| Part | Holds | The agent supplies | Checked by |
|---|---|---|---|
| the intent | the claim, and the invariants that hold whatever the numbers say | the case, and a check per assertion with its known-bad | the operator's reading, and `--check` for the form |
| the enforcement | how each invariant is judged: a measure, a gate, a score, or a reading | the mechanism, and its proof | the proof, and the gate that runs the mechanism |
| the deliverables | what comes back: the verdict, the benchmark, the log and the cost | the artefacts, named and placed | `## Close` |
| the delivery | the format of each artefact, and how the format is validated | the schema, and the check that reads it | the check where one exists, and the reader otherwise |

The operator agrees the four and the agent builds under them. The design is not agreed while the two disagree, and a run does not start on one.

Scope alignment is not the experiment specification: this section settles what is built and what comes back, and [`references/specification.md`](references/specification.md) states the questions each number a run reports must answer.

## The protocol

The protocol is the experiment's plan: what a run is compared with, what counts, and what decides. It is written before the run and carried as the declaration, and one that cannot state the following is not yet a protocol.

1. **The claim.** The effect the edit is meant to have, with X the outcome and Y the gate, and which side of the trade the verdict reports.
2. **The measures.** A role per measure. A gate says the run is valid, and a discriminator is the outcome that separates the arms ([`references/methods.md#admitting-a-check`](references/methods.md#admitting-a-check)).
3. **The checks.** A known-bad input per assertion, which that assertion must fail. A gate that passes in every arm is a validity floor, and a discriminator that passes in every arm is dropped.
4. **The control and its band.** The configuration the treatment is compared with, the spread over its runs before the treatment ran, and the threshold that spread sets. The band belongs to the instrument that measured it, and the number stays with the run.
5. **The arms and the run count.** The arms, the run count, the minimum detectable effect, and which counts are confirmatory. The run count and the control's band are agreed before the treatment runs; an arm or a count added after the data is seen is exploratory.
6. **The grading standard.** How each output is judged, how independent the judgement is from the arm it scores, and how a disagreement between passes is settled. Several grading procedures exist; which one this eval uses is agreed with the operator at scope alignment, and the case states the answer.
7. **The attrition.** An invalid run stays in the table and leaves the means, so the verdict reports the valid n beside the planned n and names the stop class ([`references/methods.md#attrition-and-valid-n`](references/methods.md#attrition-and-valid-n)).
8. **The decision rule.** The predicate that makes an arm eligible and the band it must clear, agreed with the operator with the rest of the design. Anything else is inconclusive, and inconclusive is a result ([`references/methods.md#the-verdict`](references/methods.md#the-verdict)).
9. **The verdict.** Keep, revert or inconclusive, with the numbers, the band, and the validity threat the protocol leaves open.

The declaration carries these in `decision`, `design`, and each check's role and known-bad. A case that carries a decision rule is graded and carries all three; a case with no rule is an observation, states why in `observation`, and carries no design or checks. A run admits only a declaration `--check` accepts, and `--check` measures every check against its known-bad before the run starts. The order is part of the protocol, because the close reports in it. An eligibility that cannot be read from the declaration without the run is a gap in the protocol, not in the run.

### Invariants

Each item above states a value. An invariant is a property of one value or a relation between several, and a relation no component can enforce on its own is held by a tool or by the reader.

| Invariant | Over which components | Held by |
|---|---|---|
| one variable per comparison: identical case set, fixture and prompt, with one entry differing | the arms, the case, the fixture | the reader, since `--check` cannot see that two overlays differ in one entry |
| the control the rule names is a declared configuration, and the valid n is at most the runs | the decision, the configurations, the benchmark | `--check` for the control, the benchmark for the n |
| each check fails its known-bad, so an assertion is only graded against a case that defeats it | the checks, the measure | `--check` |
| the case file carries no `harness` block | the case, the declaration | `scripts/check_eval_fixtures.sh` |
| the label lives outside the grade directory | the grader, the output root | the grade assembler |
| a run writes nothing inside the fixture's project tree | the cell, the fixture | the escape measure, which marks the run invalid |
| one cell has one isolation root, with no path to another cell or to the experiment's own notes | the cells, the work root | the runner, and `scripts/check_eval_entrypoint.sh` for its callers |
| a worktree does not outlive its run | the cell, the work root | the runner |
| no artefact lands in the repository, and a graded artefact stays at the path the benchmark names | the output root | the reader |
| the model a verdict names is the model the session recorded | the cell, the verdict | the run step's read-back |

A row held by the reader is a reading rather than a gate, and a protocol that relies on one says so in the verdict.

## The run

The run is the handoff: it executes the protocol and returns artefacts rather than opinions, and every judgement the protocol left open is recorded here with the evidence it was made from.

1. **Declare the case.** A case file holds what the task is: its subject, its instruction and its rubric. An experiment file holds how the run is built and judged. `compile_declaration.sh <case.json> <experiment.json> --out=<declaration.json>` merges them and computes the fixture hashes, and `--check=<declaration.json>` validates the result and exits 2 on a malformed one. A case file never carries the `harness` block, so a format change never edits a frozen case ([`references/harness.md#the-stores`](references/harness.md#the-stores)).
2. **Pin the fixture.** One project per case per configuration, staged from the case's `fixture_root`. The subject is a dated, hashed copy, never the live tree. Inject the case's defect, then commit the fixture so the run sees a clean tree. A configuration's overlay is a tree whose relative paths land on the same paths in the project. The change comes back as a bundle, plus a patch for any remainder. The run's own directories are [`references/harness.md#the-layout-of-one-run`](references/harness.md#the-layout-of-one-run).
3. **Isolate.** Copy the pi config directory and set `PI_CODING_AGENT_DIR` per configuration. That copy stays under the run's output slug, and only the worktree moves to the work root. The configurations differ by one entry: a package root, a skill, or the fixture's copy of the policy text. Each cell's root and its reach are [`patterns/isolation.md`](patterns/isolation.md)'s.
4. **Run.** One `pi -p` subagent per case per configuration, in the foreground of the call that owns them, each with its own log, session file and timeout. Take the provider, model and thinking level from the `_ORCHESTRATOR` role in `model-recommendations.md`, then read the model back from the session file, because the cell records what the session used and not what was requested.
5. **Grade.** Grade mechanically where the assertion is mechanical. Otherwise the outputs are graded blind, by sanitized label, after establishing ground truth from the fixture itself, in the procedure the agreed standard states. No assertion is graded without the evidence that satisfies it: a quote or a line reference, and a report silent on an assertion fails it. The harness shuffles the raw files into `grade/` and records the label only in `grade-map.json`, outside the grade directory. A `--cells` dispatch assembles one grade dir from the cells' raw dirs after they finish.
6. **Benchmark.** The benchmark carries the pass rate, the valid and invalid rate, mean wall clock and mean tokens per configuration, then the analyst read: the non-discriminating assertions, the cells without spread, and the failed assertions ([`references/harness.md#what-the-benchmark-carries`](references/harness.md#what-the-benchmark-carries)). The measures, logs and session files live under the output root, which `--out` names, defaulting from `outputRoot` in the layout. `--cells` dispatches several configurations at once, at most `EVAL_MAX_PARALLEL` concurrent, and a stopped dispatch names its stop class and the cells that remain.
7. **Stop or iterate.** A case whose assertion passes in every arm measures the model, not the instruction, so drop the assertion or retire the case. A failure in the subject is a finding with evidence, reported rather than fixed inside the run. Stop when the case set stops changing the answer.

## Non-goals

- **Not a general experiment framework.** The experimental unit, the cost model and the grader come from agentic engineering, and a claim about a different kind of system belongs to a different process.
- **Not a statistics layer.** The band and the granularity bound what a small n can say. A smaller effect needs more runs or a different outcome, not a stronger claim.
- **Not proof of causality beyond the band.** One variable per comparison licenses a difference. The fixture, the model and the n bound what it generalises to.
- **Not a fixer of the subject.** A defect the run finds is reported with evidence; the instruction edit is a separate iteration with its own design.
- **Not a substitute for reading the instruction.** Naming a mechanism for a run to test does not replace reading the instruction.

## Close

Report the band, the valid n, the effect against the band and the verdict, in that order. An eval that taught nothing about the instruction set is a result too: the report names the assertion that failed to separate, or the band that was wider than the effect.
