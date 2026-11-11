# The eval harness contract

**Current:** 2026-11-11

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | A case is its intent | One case file names the subject, the instruction and the rubric; an experiment names the fixture, the configurations, the measure and the decision, and the declaration is generated from the two. |
| R2 | The fixture is pinned | The subject is a dated, hashed copy, never the live tree, and a result names the copy it was measured on. |
| R3 | One isolation root per run | A run reads the fixture copy and writes outside the repository; its worktree does not outlive it, and its change comes back as a bundle plus a patch. |
| R4 | One variable per comparison | Two configurations differ in exactly the entry under test: a package root, a skill, or one file's text. |
| R5 | Grading is mechanical or blind | A mechanical assertion is checked by script; anything else is graded in one pass by a grader that sees sanitized labels only, and the label map lives outside the grade directory. |
| R6 | Every cell carries provenance and a denominator | The model, the fixture copy, the tokens, the wall clock and the valid/invalid split are recorded per cell, so a claim states what it was counted over. |
| R7 | A run stops legibly | A stop has a declared class, and a stopped run names the cells that ran and the cells that remain. |

## 2026-11-07 -- A behaviour eval runs from its declaration and grades blind

**Decision:** A behaviour eval is a case file plus a harness that reads it. The case names its fixture, its fixture hashes, its per-configuration overlays or package roots, its measure script, its prompt and its decision block; the harness validates that declaration before any run, mounts only the declared fixture, launches one isolated run per configuration through the role resolver, and grades each run under a sanitized label before assembling the benchmark. The harness owns no subject of its own: a case that a maintainer cannot re-run from the repository is a driver in a temp directory, not a case. The case set lives under `tests/eval/cases/`; a case recorded as an observation carries no harness block, and the run path refuses it.

**Rationale:** A round that is not a declaration can move its subject between runs, grade one prompt against another, read an empty or refused turn as completion, and lose the difference between a truncated run and a small one. Each requirement above closes one of those gaps, and the pattern is the repository's own: state the input once as data, and have one reader that cannot quietly substitute another. The grader's separation from the label is the blinding discipline the `eval` skill inherits from the poteto-mode playbook, expressed as a directory boundary rather than as an instruction to the grader, because a grader that knows the label can read the intent out of the prompt. The evidence is handover `20261107-01` and the restart's design record, [`20261014-design-draft-doc_maintenance_eval_restart.md`](../../devlog/discussions/20261014-design-draft-doc_maintenance_eval_restart.md).

**Rejected alternatives:**

- *One script per case.* **Intent failure**: every case carries its own copy of isolation, provenance and grading, and each copy drifts; a case that needs a new script is a case nobody re-runs.
- *The live tree as the fixture.* **Execution failure**: the corpus it measures is being rewritten by the milestone that builds the eval, so a later comparison measures a tree nobody chose.
- *Record the run's artifacts in the repository.* **Intent failure**: an eval run is evidence for a moment, not a document a reviewer maintains, and a committed run makes every later diff carry a number nobody re-derives.
- *Let the grader see the configuration.* **Intent failure**: a grader that knows which configuration produced the text grades the hypothesis, which is the blinding failure the external playbook names as the discipline's whole point.
- *Score a cell that produced nothing as a completed cell.* **Execution failure**: an empty turn can exit zero and be scored as a result, and a run cannot distinguish a refusal from an answer without a declared outcome.
- *Compose the provider and the model inside the harness.* **Execution failure**: the harness then holds a second copy of a routing decision the role table owns, and a model change reaches an eval run by editing a script.
- *Treat a passing case as a measured case.* **Intent failure**: a case whose contrast also passes measures the model, so the sensitivity gate is part of the contract rather than a courtesy: the configuration built to fail must fail before the subject batch is read.

**Edge cases / drivers:** A no-report run is a valid run outcome, not a stop class. R5's mechanical half is the measure script, which is per case and must print one JSON object; its blind half is the sanitized grade directory plus the external label map. A case whose configurations are both satisfied by every run is retired rather than tuned. The measure that decides a run's validity is the harness's; the rule that decides its verdict is the case's.

## 2026-11-10 -- A case is intent; the declaration is generated

**Decision:** A case file holds what the task is: its subject, its instruction, its rubric and the frozen payload. An experiment file holds how the run is built and judged: the fixture, the configurations, the measure, the prompt wiring, the decision and the design. `compile_declaration.sh` merges them into a declaration under the output root and recomputes the fixture hashes. The runner reads the generated declaration, and `--check` validates it. A case file never carries the `harness` block.

**Rationale:** The eval format evolves with the procedure - the control band, the check roles, the generated design record - while a frozen case must stay byte-identical across those changes. When the declaration was the committed case file, every format change edited every case, and the frozen layer was no longer frozen. The split keeps the intent stable and the method replaceable: the case states what is being tested, and the harness decides how it is built and judged. The generated hashes also remove a hand-maintained value that could drift from the fixture.

**Rejected alternatives:**

- *Keep the declaration in the case file.* **Intent failure**: a format change then edits a frozen case, which is the coupling this decision removes.
- *Move the declaration under the output root without generating it.* **Execution failure**: the declaration still carries hand-maintained hashes and a fixture path that a person must keep current.
- *Generate the declaration from the case alone.* **Intent failure**: the configurations, the measure and the decision are the experiment, not the task; a case that carried them would be an experiment again.

## 2026-11-11 -- The skill states the procedure; this record states why

**Decision:** The `evals` skill describes an **experimental process**, not a measurement system. The process bundles the instruments that produce the evidence with the method that reads it, and those together are the measurement system. The skill states their assumptions and their limits, because the reader is an agent loading context to design an experiment, and a limit the skill leaves out becomes a fault in the design.

The domain section near the top states the mapping from the traditional experimental frame to this one, since that mapping is what makes this an agentic-engineering process rather than a generic one. The detail of each concept sits with the stage that uses it. What a run must record is reference, in `references/`. The reason each rule exists, the basis of the domain mapping, and the sources are this record's. The skill cites this record and names no handover as evidence for a rule.

**Rationale:** An instruction is durable and a handover is transient, so the dependency runs one way. A record may cite the rule, and the rule may cite this record, which names the record. The skill named handovers in its rules before anyone read the rule that forbids it, and each of those rules outlived a file that may be pruned. The mode split comes from the same judgement. A how-to that also carried its own reference sent the reader to a table in one place and the step that used it in another, and a how-to that also carried its own explanation spent the reader's attention on a question this record answers. The instruction surface's mode rule is [`organization.md`](../../.agents/skills/project-documentation/references/organization.md), and the body shape is the `instruction-authoring` skill.

The instruments are the harness, which produces the evidence, and the design, which decides what that evidence supports. A strong harness with a weak design reports a difference the next batch does not reproduce, and a strong design over a harness that leaks between cells measures the leak. The measure split follows the same line. A process measure belongs to the harness and is reused across cases, while a content measure belongs to one case, because a promoted one becomes a second source of truth for a subject the case owns. The questions a run answers are the ones an operator acts on: whether to believe the delta, whether to believe the cell, whether the work was done, whether it was worth the effort, whether the machinery holds, and where the cost went. [`references/specification.md`](../../.agents/skills/evals/references/specification.md) holds the list.

**Why the honesty block belongs to the skill.** A designer sets the run count, the arm set and the decision rule from what the instruments can carry, so the limits have to be in front of the designer at design time. Stated here instead, the skill would say nothing about the facts that spoil the most designs. The first is that the grader is an agent, which makes it a second source of variation rather than an oracle. The second is that much of a case is authored judgement that no validation reaches, so `--check` reads a declaration's form and proves that a check fails its named input, and it says nothing about whether the check is the right one. The reliability boundary follows: the fixture, the hashes, the isolation root and the provenance are the parts the harness holds, while sampling, timing, the grader's judgement, batch drift, fixture fidelity and model availability are the parts it cannot, so the design controls what it can and measures the rest.

**Why the rules are co-located.** Each rule sits beside the step it constrains, because a block of invariants at the end separates a rule from the decision it governs and hides which part of the system carries no rule. The kinds of sentence belong to `instruction-authoring`, and the mode split to `organization.md`.

**Why the two artefacts take these names.** The experiment specification is `references/specification.md`, the table of questions a run must answer with the measure and field each is read from. Neither it nor the design record is a contract: a contract in this repository is an interface between two parties (`interface_contract`, the library contract, the harness contract), and these two are a scope and a description, so the older `contract.md` name was carrying a sense the word does not have elsewhere.

**Sources.** The case shape and the assertion rules follow *Evaluating skills*, `agentskills.io`, read 2026-11-11, https://agentskills.io/skill-creation/evaluating-skills. Blinding follows Lauren Tan's *pstack eval playbook*, read 2026-11-11, https://github.com/cursor/plugins/blob/main/pstack/skills/poteto-mode/playbooks/eval.md, at pstack commit `70b2dc8`: sanitize every name a run sees, keep the prompt an organic operator message, and let no run learn that a comparison is happening. The sustained-improvement loop is `playbooks/hillclimb.md` in the skill, an adaptation of Lauren Tan's *pstack hillclimb playbook* at the same commit. The loop's adaptation is the source edge in `.agents/registry/sources/pstack-skills.json`, and the other two are `.agents/registry/citations/agentskills-evaluating-skills.json` and `pstack-eval-playbook.json`.

**Rejected alternatives:**

- *Keep the why in the skill.* **Intent failure**: the how-to then carries more than one mode, and the statement exists in both, so an edit lands in one of them.
- *Write a generic `experiment` skill and leave the domain to the caller.* **Intent failure**: the treatment, the cost model, the grader and the fixture are all agentic-engineering objects, and a generic process would either state them as placeholders or leave the designer to rediscover the tradeoffs this domain fixes.
- *Specify the measurement system and stop there.* **Intent failure**: a specification of the instruments is not an experiment. The process has to say what a design does with them, or the reader holds a component list and no method.
- *Collect the invariants in one block.* **Execution failure**: a rule far from the decision it governs is read as a formality, and the block hides which part of the system carries no rule.
- *Cite the handover that measured a value from the skill.* **Execution failure**: a durable instruction then depends on a transient record, and the pointer is correct only until the record is pruned. The number stays in the record, and the rule states the variable.
- *Link this ADR from every skill file that answers to it.* **Intent failure**: the authority runs one way. This record names the rules it requires; the skill's execution does not read an ADR, and a link back is a second statement of the same requirement.

## 2026-11-11 -- A run admits only a declared experiment

**Decision:** A case is **graded** when its `decision` carries a `rule`; it is an **observation** when it does not. A graded case declares the graded triple -- `design`, `checks` and `decision.rule` -- and the runner refuses either a graded case missing the other two or a case that declares neither kind. `--check` is no longer optional at the run path: a `--case` run validates its declaration before it resolves the fixture or creates an output directory, and a `--cells` dispatch validates once at the parent, so the cost is one known-bad measurement per declared check per invocation rather than per run or per cell. The decision block keeps `control`, `rule` and `runs`, and its derived threshold `min_effect` is deleted.

**Rationale:** `--check` validated a declaration only when the operator asked for it, so a graded run could start on a declaration the same script would reject, and the `design`/`checks` pair was optional, so a case carrying a decision rule could reach a run with no design and no proven check. Making the kind explicit removes both holes with one predicate and no second marker to keep in sync: an observation says what it is, and a graded case cannot omit its evidence. Validating at the run path is what makes the existing gate mean anything. `min_effect` was validated for its type and read by no consumer, and a fixed threshold cannot survive the A/A band moving: the minimum detectable effect is `1/n` of the run count, so the rule owns it and the declaration does not.

**Rejected alternatives:**

- *Keep `design` and `checks` optional.* **Execution failure**: a case with a decision rule then reaches a run with no design and no false case, which is the hole this decision closes.
- *Require `design` but leave `checks` optional.* **Execution failure**: a check that has never failed its known-bad is an assertion of unknown sensitivity, and the design's `primary_measure` names it.
- *Infer the kind from whether `design` is present.* **Intent failure**: two signals then decide the same thing, and a case with a design and no rule reads as graded. The rule is the predicate.
- *Leave validation to an operator who remembers `--check`.* **Execution failure**: the run path stays open to the declaration the gate rejects, and the guarantee rests on a line in a skill.
- *Freeze the grader's agreement in the declaration.* **Intent failure**: the agreement is a measured output, and declaring it records a claim the next grading pass may falsify. The run record is its home, and an open row re-scopes that work.
- *Split `decision` into one file per field.* **Execution failure**: the checks are relational (`control` must be a live configuration, `aa` must not repeat it), so three files force a join and give one plan three writers with no gate gained.

## 2026-11-11 -- The eval layout is a declaration its consumers read

**Decision:** The layout an eval reads and writes is declared once, in `.agents/skills/evals/assets/layout.json`, and both consumers read it through `.agents/skills/evals/scripts/layout.sh`: `run_case.sh` and `scripts/check_eval_fixtures.sh`. An explicit argument beats the declaration, so `--out` overrides `outputRoot` and the fixture gate's root is its first argument; `--case-set=DIR` replaces `EVAL_CASE_SET`, and `EVAL_FIXTURE_ROOT` is retired. `scripts/check_eval_layout.sh` fails when the declaration does not parse, when a consumer reads a key the declaration does not carry, or when a declared key no consumer reads. The fixture is the case's `fixture_root`, not a directory under the output root.

**Rationale:** The layout had three owners - `SKILL.md` step 2, `references/harness.md`'s stores table, and constants in the two scripts - and no check compared them, so a structural change landed in one and silently missed the others. The declaration gives the layout one store and one reader, the pattern `src/build/record-layout.json` already sets for the record trees, and the gate catches a rename in either direction: a consumer reading a key the declaration lost, and a key no consumer reads. Two environment seams duplicated arguments the scripts already took, and an inherited variable is hidden state: `$1` already outranked `EVAL_FIXTURE_ROOT`, so the seam bought a second way to say the same thing and a way to change a check by accident. The output root was the clearest case: the skill stated a default, the runner required `--out`, and nothing said which governed a run; the declaration now owns the default and the argument overrides it.

**Rejected alternatives:**

- *State the layout in the convention's prose and gate the scripts' literals against it.* **Execution failure**: the prose and the constants remain two representations, and a literal check runs one direction only, so a table entry no code honours survives.
- *Keep the environment seams as test-only overrides.* **Execution failure**: an inherited variable silently redirects a check, and the argument it duplicates already covers the case; a test that needs another root passes one.
- *Put the declaration under `src/build/`, beside the record layout.* **Intent failure**: the record layout describes the repository's records, and the eval layout is the eval convention's structure; it moves with the skill a project installs.
- *Declare only the roots, and leave the directory names in the scripts.* **Execution failure**: the run's directory names are what the stores table states, so they are the half of the statement a reader consults; a root-only declaration leaves that half as prose.
- *Open a new ADR for the layout.* **Intent failure**: the layout is a property of the harness contract's reach, which this record already owns, so a second file would carry two invariants that must agree.

## 2026-11-11 -- The convention is an experiment-design workflow

The skill states the workflow a case runs through: a hypothesis, a declared case, a calibrated control, a run, a blind grade, and a decision against a rule agreed before the run. The harness reference states the contract, and the methods reference states the judgements the workflow rests on.

Rejected forms, and what broke each:

- **A judgement list.** Nothing to gate: a list of good practices cannot disagree with a case, so a malformed case passed review.
- **A procedure only.** A case could not be refused. Without a declaration there is no field a validator reads, so a run started on a case that no measure could decide -- the failure the `--check` gate now names.
- **The harness as the convention.** The skill became the script's documentation: every change to `run_case.sh` forced a prose rewrite, and the prose could not answer a question the script did not already answer.
- **An amalgamation of the quoted sources.** The skill restated its sources, and two copies of one rule drifted; the sources changed and the skill did not.

The `/gm` runs measured why the measurement itself could not carry a verdict: the token A/A band is about 25 percent over three identical batches, so a single-batch median cannot resolve the 5 to 10 percent edits the procedure accepts; alignment moves one report at eight runs, which is also the size a re-grade produces; two of the four structural assertions never discriminate; attrition is 9 of 88 scheduled runs, clustered in timeouts; and the case's declared control and its zero `min_effect` let a stale configuration and any non-zero difference through. The procedure takes `n=8`, a blind grade and a rule agreed before the run as the response.
