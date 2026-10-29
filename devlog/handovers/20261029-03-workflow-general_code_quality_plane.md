---
status: Active
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# The general code-quality plane

## Objective

Settle where a language-agnostic code rule lives, so a review can cite one the way `code-review-bash` cites `p-59`, and land the rule that turns out to have content.

## Scope

- The census of what the tree already holds, and the owner decision it forces.
- `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/script-boundaries.md`: `p-61`.
- `devlog/roadmap.md`: the general-plane sub-row, and two rows under M3.1.2.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The owner is decided, with the refused options named and the reason each was refused | the record names both vendored carriers as refused and the reason | Agent [x] Agent run: `thermo-nuclear-code-quality-review` and `deslop`, both vendored, neither subsumed |
| The existing carriers are censused, not assumed | every general rule already in the tree is listed with where it stands today | Agent [x] Agent run: nine carriers, in three groups |
| The proposal with no source is labelled as one | the record says the four generated rules were never found in the tree | Agent [x] Agent run: stated, and the operator rejected the framing |
| The seam rule is an entry in the bash pattern set with a fence, a statement and `Replaces:` | `grep -c '^## p-61' script-boundaries.md` is 1 | Agent [x] Agent run: 1, and `p-61` is the maximum id across both sets |
| The seam entry lives beside the boundary subject it belongs to | it is in `script-boundaries.md`, whose opener already names handing off to another script | Agent [x] Agent run: appended after `p-15` and `p-17` |
| Nothing is added to a vendored carrier | `git diff` touches neither vendored runbook nor the installed skill | Agent [x] Agent run: neither file is in the diff |
| The gate work the census found is filed where gate upkeep lives | two M3.1.2 rows: the missing linter, and the unregistered liveness check | Agent [x] Agent run: filed, no gate count restated in prose |
| Lint, markdown and the suite are clean | `bash scripts/lint.sh`, `bash scripts/check_markdown.sh`, `bash scripts/run_tests.sh` | Agent [x] Agent run: 15 gates clean, markdown clean, 1349 passed across 98 files |

## Decisions

- **The plane is a rule set with an owner, not a document.** The milestone's criterion is that a finding cites an entry, so a rule that lives only in prose is unquotable by construction, which is the defect the census found in `thermo-nuclear-code-quality-review`.
- **Both vendored carriers are out of the question.** Operator ruling, 2026-10-29: `thermo-nuclear-code-quality-review` works and works reliably, and it and `deslop` are vendored, so neither is subsumed and neither is a home for a project rule. A rule set having nowhere else to stand is not a reason to change one.
- **Of the four proposed rules, the seam is the one with content.** Operator ruling, 2026-10-29: error propagation already exists as a bash rule and is gated; the seam and mock rule becomes a bash pattern, `p-61`; identifier naming is held until a rule states something, with the review catching the worst offenders in the meantime; dead code is answered by the liveness check rather than by a rule.
- **The seam goes in the bash pattern set, not the testing convention.** The rule is about where a script draws its boundary, and `script-boundaries.md` already owns that subject, so it sits beside `p-15`'s dual-use guard and `p-17`'s `exec` handoff rather than beside a test recipe.
- **No new document, and no new category.** The index keeps one row per category, and the language-agnostic ground is answered by the seam pattern, one policy note in `conventions.md`, and the liveness check rather than by a document of its own.

## Decisions pending

- **Whether the policy note goes into `conventions.md`.** One row naming the two `AGENTS.md` rules that apply to every language, and naming the liveness check as the one place dead code is caught.

## Findings

- **Already in prose, in this repository, citable by no finding.** The seven-rung minimum-code ladder in the provider layer `AGENTS.md`, `## When writing code`; the comment-hygiene rule in the project `AGENTS.md` `**Code comments**` with its banned list; the match-the-existing-structure rule in the same file's `**Code**` line; dependency direction in `docs/development/context_resolution.md`; the interface rules in `docs/development/interface-conventions.md`, whose eleven sections govern a script's outward behaviour rather than its shape; the defensive-check and `any`-cast judgement in the installed `deslop` skill, which is in the agent home and not in this tree; and canonical-helper reuse, which the vendored review states in its standard 6.
- **Only in `thermo-nuclear-code-quality-review`, eight numbered standards.** Ambition about structural simplification, the 1k-line threshold, spaghetti and special-case growth, cleaning the design over accepting working code, boring over magic and against thin wrappers, type and boundary cleanliness, the canonical layer, and sequential or non-atomic orchestration. Each is judgement about a change rather than a rule about code, and each is closed with the file.
- **The "unfiled" set has no source.** The four rules reported to the operator on 2026-10-29 as unowned -- dead code and unused exports, identifier naming outside the CLI's disambiguation section, error propagation in the typed modules, and purity or side-effect boundaries -- were generated rather than found: the absence check was a grep for four tokens, and a token missing from the tree says only that the rule is not written there, never that the tree holds it in some less organized form. Three of the four then resolved against the tree on the operator's reading, and the fourth was held.
- `docs/development/conventions.md` carries six categories -- interface, bash, module dependency direction, testing, prompt and skill authoring, instruction surfaces -- and none of them owns a language-agnostic code rule.
- **The dead-code check exists and runs in no gate.** `scripts/check_lib_liveness.sh` asserts that every `src/libs/*.sh` is referenced by at least one non-test file, and it is absent from the `GATES` array in `scripts/lint.sh`. Run by hand it reports `src/libs/package_eval_snapshot.sh` as orphaned, which is a false positive: its non-test consumers are `workflow/coding-agent/prompts/package-eval-snapshot.md` and `docs/reference/sandbox_host_interface.md`, and the scan roots are `src/`, `scripts/`, `test/` and `Makefile`, which omit `workflow/`.
- **Its function-level half is absent and the code is clean.** Measured across `src/libs/*.sh`: 125 function definitions, none without a reference outside its defining file and the tests. A function-level assertion is therefore cheap to add and passes on today's tree.
- **The pre-commit and gate-management rows were already under M3.1.2.** `Shorten the wall-clock cost of the gates` with its budget sub-row, `Formalize the procedure for adding, amending or removing a gate` with the `precommit-gate-runbook.md` draft, and four further gate rows. Nothing needed moving.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/runbooks/code-review-bash/patterns/script-boundaries.md` | Added `p-61`, cross the process boundary at one named seam |
| `devlog/roadmap.md` | Added two M3.1.2 rows -- the TypeScript and JavaScript sources have no linter, and the liveness check is in no gate -- and rewrote the general-plane sub-row to the outcome |
