# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Housekeeping
**Status:** Closed

## Objective

Stop a prompt from being dropped silently at load time because its frontmatter does not parse, and correct the authoring rule that was supposed to prevent it.

## Scope

The roadmap row "Prompt frontmatter parse gate". The operator reported that `/sequential-work` was missing from the command list and asked for the authoring conventions to be fixed.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Every prompt and skill frontmatter block in the tree parses | `bash scripts/check_prompt_frontmatter.sh`, 34 blocks clean | accepted |
| 2 | The gate fails on a block that does not parse, and names the file, the line, and the offending text | a deliberate break on `sequential-work.md` line 2, rc 1 | accepted |
| 3 | A deliberate break is restored byte-identical | `cmp` against the backup | accepted |
| 4 | The umbrella lint runs the new gate as a fourth gate | `bash scripts/lint.sh`, 4 gates, clean | accepted |
| 5 | The conventions rule states the measured failure set, not the assumed one | read of `## Structure of a workflow document` | accepted |
| 6 | The gate's own branches are covered, including the fail-closed path | four cases in `tests/test_lint_umbrella.sh` | accepted |
| 7 | The whole suite is green | `bash scripts/run_tests.sh`, 1012 of 1012 | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/sequential-work.md`](../../workflow/coding-agent/prompts/sequential-work.md) | the prompt that was dropped, and the only broken block in the census |
| [`scripts/lint/prompt-frontmatter.mjs`](../../scripts/lint/prompt-frontmatter.mjs) | new, the parse |
| [`scripts/check_prompt_frontmatter.sh`](../../scripts/check_prompt_frontmatter.sh) | new, the gate |
| [`scripts/lint.sh`](../../scripts/lint.sh) | the umbrella the gate joins |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | holds the rule that was missed and was wrong |
| [`tests/test_lint_umbrella.sh`](../../tests/test_lint_umbrella.sh) | the gate's cases, and the assertion that broke on a fourth gate |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Enforce the rule with a gate rather than restating it | the rule was already in the conventions document, named this exact error, and the file shipped broken anyway. A second sentence would not have caught it | extension of `principle-encode-lessons-in-structure`; recorded here because the principle is not a project record |
| A prompt with no frontmatter block is skipped, not flagged | five prompt drafts open on their title. A gate that fails the tree on every known open item is a gate nobody runs, and the missing block is a different defect from the silent parse failure this gate catches | this handover; the open item is a roadmap follow-on |
| The `yaml` package is resolved out of pi's install tree rather than declared | adding a dependency to a repository with no Node dependency tree is a larger decision than this iteration's scope. The gate fails loudly when the parser is absent, so the failure mode is a red build and not a silent pass | this handover; deferred to the decisions-pending row |
| The gate-count assertion reads the `GATES` array instead of a literal | adding a gate broke a test about lint rather than about frontmatter. A hardcoded count invites deleting the check next time | `tests/test_lint_umbrella.sh` |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Should `yaml` become a declared repository dependency rather than being resolved from pi's install tree? | the gate's portability. It is currently tied to a global npm layout, and a package-manager change breaks it | declare it, which adds a Node dependency tree to a repository that has none; or keep the resolution and accept that a global-layout change turns `make lint` red, which is loud but is still a red build on an unrelated change |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The quoting rule named the apostrophe as a trigger, and a plain scalar with an apostrophe parses | contradiction | the rule was wrong in the direction that misleads an author into quoting harmlessly, and silent in the direction that breaks a prompt | corrected in `docs/development/prompt-authoring-conventions.md`; no roadmap entry, the correction landed here |
| A leading dash and a trailing colon also fail to parse, and neither was named | contradiction | same | same correction |
| `path.resolve` on the `pi` binary never reaches the package, because the binary on PATH is a symlink | bug | the gate could not find the parser and would have failed closed on every run | fixed in `scripts/lint/prompt-frontmatter.mjs` |
| Five prompt drafts carry no frontmatter at all, so pi loads them with no description and the model cannot discover them | scope change | a real defect, out of this iteration's scope | `devlog/roadmap.md`, the follow-on on the row for this gate |
| The gate printed the YAML line number, which is relative to the block body and not to the file | bug | the operator would have been sent to the wrong line | fixed in `scripts/lint/prompt-frontmatter.mjs` |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/sequential-work.md` | the description quoted, so the block parses |
| `scripts/lint/prompt-frontmatter.mjs` | new, parses every prompt and skill frontmatter with the `yaml` package pi ships |
| `scripts/check_prompt_frontmatter.sh` | new, the blocking gate, failing closed when Node or the parser is absent |
| `scripts/lint.sh` | the gate added as a fourth concurrent entry |
| `docs/development/prompt-authoring-conventions.md` | the quoting rule corrected to the measured failure set, and pointed at the gate as its enforcement |
| `tests/test_lint_umbrella.sh` | four behavioural cases for the new gate; the gate-count assertion reads the `GATES` array |
| `devlog/roadmap.md` | the row, and the follow-on on the frontmatter-less drafts |

## Propagation replay

| File | Change planned | Status |
|---|---|---|
| `workflow/coding-agent/prompts/sequential-work.md` | quote the description | completed |
| `src/reasoning/providers/pi/config/agent/prompts/pi-agent.md` | parse-checked, no change needed | completed |
| `src/reasoning/agent/skills/*/SKILL.md` | parse-checked, 54 blocks clean, no change needed | completed |
| `/opt/workflow/agent/prompts/*.md` | parse-checked at the installed copy, one broken file, same source | completed |
| `scripts/lint/prompt-frontmatter.mjs` | new, four prompt and skill roots | completed |
| `scripts/check_prompt_frontmatter.sh` | new gate, wired into the umbrella | completed |
| `scripts/lint.sh` | fourth gate | completed |
| `docs/development/prompt-authoring-conventions.md` | rule corrected | completed |
| `tests/test_lint_umbrella.sh` | four cases, count assertion de-hardcoded | completed |
| `devlog/roadmap.md` | row plus follow-on | completed |
| the five frontmatter-less prompt drafts | add frontmatter | deferred, roadmap follow-on on this row |

## Deferred items

The five frontmatter-less prompt drafts, and the dependency decision. Both are named in the records above and both have a roadmap or decisions-pending home, so neither is re-listed here.

## What's Next

M3.2.1 - Loops as Workflows, and it stays in progress. The four units of this run closed together; the roadmap carries their follow-ons.

**Conclusions from this iteration.** A prose rule that an author must notice and remember will be missed, and this one was missed with the error string written into the document. A rule whose failure is silent needs a mechanism, not a restatement. Separately, the rule was wrong in both directions at once, which is the argument for measuring the failure set rather than reasoning about it: an apostrophe in a plain scalar is legal YAML and a leading dash is not, and neither fact is obvious without running it.

**Watch out.** The `yaml` resolution is tied to a global npm layout, so a change to how pi is installed turns `make lint` red with nothing in this repository having changed. The failure is loud by design, not silent, and the loudness is the whole mitigation until the dependency question is answered.
