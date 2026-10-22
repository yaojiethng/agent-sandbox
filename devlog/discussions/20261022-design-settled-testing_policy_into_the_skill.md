# Testing policy content into the skill

**Status:** settled

## Context

`docs/development/testing_policy.md` mixes four kinds of content: rules a gate or a procedure enforces, judgements with no cheap observer, descriptions of how the harness works, and code-bearing patterns. `docs/development/testing-conventions.md` restates much of it as patterns and anti-patterns, so one rule has two homes. The `testing` convention-skill is a 16-line stub that delegates everything to the policy. The roadmap carries two items about the file: a membership row that would ship or rename it, and a `Retire testing_policy` slice whose design map names a "testing procedure" that does not exist.

The file serves only this project. The workflow's testing convention is the seam a provisioned project fills; agent-sandbox's framework, folders, runner and knowledge/integration split are its own binding. The Core Principles are judgements, not rules: true isolation needs separate environments and post-run reconciliation, which the harness does not have, so no gate can detect a breach. The `FIXTURE_DIR` convention and the registration liveness gate are the harness's current approximation, not proof of the principle.

## Options Considered

- **Classification fix: ship the file or rename it.** Rejected: the mixed content and the overlap with `testing-conventions.md` remain, and the rules stay in a document the agent must be pointed at rather than in a skill it loads.
- **Retire the membership row as a false premise.** Rejected: the agent reads the file from the working tree, so the row's stated defect does not exist, but that leaves the file untouched and the purpose unserved.
- **Family-by-family migration into the skill.** Rejected: patterns would live in two homes for several iterations, which is the duplication the work exists to remove.
- **Extract the unambiguous content, then read the remainder.** Adopted: the taxonomy postdates both documents, so assuming their content is well formed is the assumption that produced the duplication.

## Decision

**Kinds.** Rule, judgement and description stay the three kinds. Description is specialized into two subtypes. A **pattern** is "when you see X, instead do Y", especially for a specific mechanical task, and it carries the concrete form or snippet. A **convention** states criteria in prose, with remediation for the negative case. A **judgement** states a quality with no cheap observer. The specialization is used locally in the testing instruction; it is not written into `docs/reference/agent_workflow.md` `### Norm kinds` yet, because the ledger gate reads its kind list from that table and the testing documents are not in the ledger. That reference change is filed as its own unit.

**Container.** The `testing` convention-skill is the container. `SKILL.md` carries the judgements inline and an index that names each pattern file and the situation that opens it. Code-bearing patterns are siblings under `patterns/`; a fill-in file is an asset. The skill format already loads any sibling `SKILL.md` names, so this adds no mechanism. A sibling the index does not name is a file nothing dispatches to.

**Project scope.** The workflow states the operation and points at the project's `testing` convention; the project binds the framework, folders, runner and vocabulary. The shipped `iteration_policy.md` line names the convention seam, not this project's file. The `initialize` testing asset states the shape of a testing convention without naming a framework.

**Migration.** Three units. Unit 1 extracts the unambiguous patterns and judgements into the skill, removes their sections from both documents, and inventories the remainder by kind and intended home. Unit 2 reads that inventory, resolves the remainder, and lands the rules beside the gates or procedures that enforce them. Unit 3 phases the bridge out and retires the membership row. This iteration is unit 1.

**Pass 1 cut.** From `testing-conventions.md`: Patterns 1 to 3, Anti-Patterns 1 to 9, the Test Structure Template and the dispatch mock infrastructure move. From `testing_policy.md`: the code halves of Core Principles 1 to 4, the `test_common.sh` usage snippet and the shared-fixture helper table move. The rest stays for the read: Debugging Test Failures, the two checklists, When to write tests, the Shared Fixtures placement rules, Test Placement, the `make test` invariant, registration liveness, Keeping Tests Current and See Also.

## Consequences

`Retire testing_policy` becomes three rows; the membership row closes when the file is emptied, not by a rename or a manifest entry. `testing-conventions.md` becomes the bridge, and its remainder is inventoried before it is phased out. The testing skill becomes the agent's dispatch surface for test authoring. The generic shape lands in the `initialize` testing asset, and agent-sandbox's content stays project-scoped.

No ADR is created. The sibling shape is the skill format's existing loading and the durable statement is the testing skill's index, so the decision creates no new standing principle beyond the convention-skill model that `coding_agent_project_bindings.md` already records. The kind specialization returns as its own row once the testing content has proved it.

### Remainder inventory

Unit 1 removes the patterns and judgements named in the pass-1 cut. What follows is the remainder as it stood after that cut, one row per surviving section; unit 2 re-reads each row and may reclassify it.

| Document | Surviving section | Kind | Intended home |
|---|---|---|---|
| `testing-conventions.md` | Debugging Test Failures | convention: symptom, likely cause, remediation | the testing skill, as a `debugging` sibling |
| `testing-conventions.md` | Checklist for New Tests | convention: criteria | the testing skill or the template's comments |
| `testing-conventions.md` | Checklist for Lib and Script Changes | procedure, run at change completion | the change close, or the testing skill |
| `testing_policy.md` | When to write tests | judgement | the testing skill, inline with the judgements |
| `testing_policy.md` | Shared Fixtures placement rules | convention | the testing skill's `patterns/fixtures.md` |
| `testing_policy.md` | Test Placement | judgement (the decision rule), convention (paths and naming) and rule (the `make test` invariant) | the skill for the judgement and the convention; the gate or procedure for the rule |
| `testing_policy.md` | Running the Test Suite and registration liveness | mechanism and rule | `test_harness_mechanism.md` for the mechanism; the rule beside the gate that enforces it |
| `testing_policy.md` | Shared fixtures in knowledge, integration and diagnostic tests | convention | the testing skill's `patterns/fixtures.md` |
| `testing_policy.md` | Keeping Tests Current | rule and procedure | the change close, or the testing skill |
| `testing_policy.md` | See Also | pointer | removed at phase-out |
