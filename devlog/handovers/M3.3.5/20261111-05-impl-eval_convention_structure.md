---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Implementation
status: Closed
---

# Handover - The eval convention holds the layout

## Objective

Give an eval's layout one owner: the convention entry declares where a case and a run's artefacts live, and the harness reads that declaration instead of carrying a second copy of it.

## Scope

The M3.3.5 row *The eval convention holds the project's structure*, re-derived before it is worked, because its problem statement names a skill path and a snapshot export that `20261111-03` removed and `20261111-01` had already cut.

A declaration under the eval skill names the layout: the case root, the case-set directory, the output-root default, and the grade, grade-raw, cell and case name prefixes. `layout.sh` reads it, `run_case.sh` and `scripts/check_eval_fixtures.sh` consume it, and a lint gate fails when a consumer reads a key the declaration lost or a declared key no consumer reads. The environment seams on the fixture gate drop, and an argument beats the declaration everywhere.

The ADR entry extends `docs/adr/eval_harness_contract.md`, which is compacted where entries restate each other and whose `**Current:**` date is corrected.

Out of scope: the eval procedure itself, which landed at `20261111-04`; the case content; the stored experiments under the output root; the decision-records convention's ordering rule for a cumulative ADR, which is filed as a roadmap row rather than settled here.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The layout is declared once and both consumers read it. | `test -f .agents/skills/evals/assets/layout.json`; `grep -c layout_get` on each consumer | Agent [x] |
| Neither consumer carries a declared value outside the declaration. | `tests/test_eval_layout.sh` case `test_the_consumers_carry_no_layout_literal` | Agent [x] |
| The environment seams are gone; a caller redirects through arguments. | `grep -rn 'EVAL_FIXTURE_ROOT\|EVAL_CASE_SET' .agents/skills/evals scripts tests` prints nothing; `tests/test_eval_fixtures.sh` passes a root and `--case-set` | Agent [x] |
| A changed declaration changes the path a consumer uses. | `tests/test_eval_layout.sh` reader cases; `tests/test_eval_fixtures.sh` case `test_a_named_case_set_is_reported` | Agent [x] |
| `--out` defaults from the declaration, and an explicit `--out` still wins. | `tests/test_eval_harness.sh` case `test_run_case_defaults_the_output_root` | Agent [x] |
| The drift gate fails on a consumer literal and passes on the tree. | `tests/test_eval_layout.sh`; `bash scripts/check_eval_layout.sh` | Agent [x] |
| The harness reference cites the declaration and the skill cites the reference; neither keeps a second copy of the layout. | `grep -n 'layout.json' .agents/skills/evals/references/harness.md`; `grep -n 'the-layout-of-one-run' .agents/skills/evals/SKILL.md` | Agent [x] |
| The ADR carries the entry, the corrected `Current:` and the compaction. | `grep -n '^\*\*Current:\*\* 2026-11-11' docs/adr/eval_harness_contract.md`; the new entry read against the diff | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table read against the diff | Agent [x] |
| Architecture documents in scope describe the system as built. | the ADR entry read against `layout.sh`, `run_case.sh` and the gate | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The eval layout is a declaration its consumers read (option A), not convention prose plus a drift gate. | One statement that the scripts read cannot drift from itself; option B keeps two representations and checks one direction only. The precedent is `src/build/record-layout.json`, read by `scripts/worklog.sh` and the lint gates. | this table; the ADR entry at implementation |
| The declaration lives at `.agents/skills/evals/assets/layout.json`, read by one small `scripts/layout.sh` sourced by both consumers. | `assets/` is where a skill ships non-prose, as `work-log` ships its handover template; one reader keeps the `jq` call and its error handling in one place. | this table |
| The environment seams on `check_eval_fixtures.sh` are dropped: the root is `$1`, the case set is `--case-set=DIR`. | `$1` already has highest precedence, so `EVAL_FIXTURE_ROOT` is a duplicate of it, and an inherited variable is hidden state. The precedence becomes argument > declaration. | this table |
| The ADR entry extends `docs/adr/eval_harness_contract.md`, and the file is compacted where entries restate each other. | The layout is a property of the harness contract, whose reach already owns it. The file is 87 lines; the defect is sediment, not length. | this table; the ADR entry at implementation |
| The fixture is the case's `fixture_root`, not a directory under the output root. | The skill placed it under the output root's `fixture/`, a directory no consumer creates, so a designer following the step would stage a fixture nothing measured. The case already owns the path. | this table; `SKILL.md` step 2 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The roadmap row's premise names a state the tree no longer has: `SKILL.md` names neither a harness path nor the snapshot export. | record | Working the row as written would edit a statement that is already gone, and would leave its real defect untouched. | fixed at close: the row text is rewritten to the real defect |
| The layout has three owners -- `SKILL.md` step 2, `references/harness.md` `## The stores`, and the constants in `run_case.sh` and `check_eval_fixtures.sh` -- and no check compares them. | architecture | A structural change lands in one owner and silently misses the others, so the documented layout and the executed one drift apart with nothing reporting it. | this iteration: the row under work |
| The layout is settable three ways with different precedence: `--out` is a required argument, `EVAL_FIXTURE_ROOT` and `EVAL_CASE_SET` are environment overrides, and the skill states a default output root. | architecture | A caller cannot tell which statement governs a run, and a second harness invocation in one shell inherits the first's environment. | fixed in this iteration: the seams drop, precedence is argument > declaration |
| `eval_harness_contract.md` carries `**Current:** 2026-11-07` three decisions stale, and its entries are append-ordered while the decision-records convention puts the newest at the top and calls the rest historical. The entries are cumulative refinements, not supersessions. | record | The `Current:` date is a derived value with no gate, so it will go stale again; the ordering rule does not fit a cumulative record. | `Current:` fixed here; the convention's fit for a cumulative ADR is filed as a roadmap row |
| The skill's step 2 placed the fixture under the output root's `fixture/`, a directory no consumer creates; the fixture is the case's `fixture_root`. | record | A designer following the step stages a fixture the run never mounts, so the run measures the live tree or nothing. | fixed in `SKILL.md` step 2 |
| `scripts/check_eval_fixtures.sh` reads `$1` before the environment variable, so the argument already redirects the gate without touching the environment. | test | Dropping the seams is a surface change, not a loss of capability. | evidence for the decision above |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/assets/layout.json` | The layout declaration: case root, case-set directory, output-root default, and the run's directory names. |
| `.agents/skills/evals/scripts/layout.sh` | The only reader: `layout_get`, the default declaration path, and `expand_home`. |
| `.agents/skills/evals/scripts/run_case.sh` | Sources the reader; reads the five run-layout keys once; `--out` defaults to the declared root under the case's directory. |
| `scripts/check_eval_fixtures.sh` | Reads the case root and case-set keys; `$1` is the root, `--case-set=DIR` replaces the environment seams. |
| `scripts/check_eval_layout.sh` | The drift gate: declaration shape, sourced reader, and a key read/declared mismatch in either direction. |
| `scripts/lint.sh` | Registers the eval-layout gate. |
| `.agents/skills/evals/references/harness.md` | The stores table names the declaration keys; the run layout is rendered from the declaration. |
| `.agents/skills/evals/SKILL.md` | Step 2 stages from the case's `fixture_root`; steps 2 and 6 cite the declaration for the run's directories and the output root. |
| `docs/adr/eval_harness_contract.md` | New entry; `Current:` corrected; the 2026-11-07 status narration and a duplicated sensitivity sentence removed, two rationales tightened. |
| `tests/test_eval_harness.sh` | Adds the default output root case. |
| `tests/test_eval_fixtures.sh` | The root is `$1` and the case set `--case-set=DIR`; the environment seams are gone. |
| `tests/test_eval_layout.sh` | The gate's verdicts, the reader's value and `$HOME` expansion, and the no-literal check on the consumers. |
| `devlog/roadmap.md` | Closes the row with its landing note; files the decision-records ordering row. |
| `devlog/roadmap.md` (maintenance) | Checked before the handover opened: no change needed. M3.3.5 reads `In progress`, its closed rows carry landing notes, and the rows closed at `20261111-04` agree with the section. |
| `devlog/handovers/M3.3.5/20261111-05-impl-eval_convention_structure.md` | This record. |
