---
date: 2026-10-03
milestone: M3.2.1 - Loops as Workflows
type: Workflow
status: Closed
---

# Handover - Declare the policy set and require a purpose statement

## Objective

Declare the policy set as every `docs/**/*_policy.md` file, give every policy file a `description` and a `scope` in frontmatter, and record a membership criterion that avoids the arbitrary threshold the policy map rejected.

## Scope

The M3.2.1 row `Policy-file membership review`. The policy map found that `milestone_policy.md` failed as a policy because 13 of its 19 rules pointed at or restated another document, but rejected a completion test whose threshold would be arbitrary. The question stood: the policy set was undeclared, and five of the eight policy files stated no purpose or scope.

| In | Out |
|---|---|
| The membership and header rules in `documentation_policy.md` | A numeric or percentage threshold; the map rejected it as arbitrary |
| The declaration of the policy set in `documentation_taxonomy.md` | Re-opening the deletion of `milestone_policy.md`; it stands |
| The frontmatter of the eight policy files | The rule content of any policy file |
| The frontmatter gate's scan root and its test | Renaming `check_prompt_frontmatter.sh`; the name now undersells its scope, and the rename is filed |
| The M3.2.1 row | The three non-policy documents in `docs/operations/`; they state no rules |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The policy set is declared as every `docs/**/*_policy.md` file, in any folder | `grep -c "docs/\*\*/\*_policy.md" docs/concepts/documentation_taxonomy.md docs/operations/documentation_policy.md` returns 2 for each | Agent [x] |
| 2 | Every policy file carries frontmatter with `description` and `scope`; no inline `**Description.**`/`**Scope.**` block remains in one | a loop over `find docs -name "*_policy.md"` reports `desc=1 scope=1` for all 8; the inline-pattern grep over `docs/*/*_policy.md` returns nothing | Agent [x] |
| 3 | The membership criterion landed without a threshold | `grep -n "Policy membership" docs/operations/documentation_policy.md` names the set, the ownership requirement, and "never a count" | Agent [x] |
| 4 | The header-format rule names the policy frontmatter form | `grep -n "Policy files (\`docs/\*\*/\*_policy.md\`)" docs/operations/documentation_policy.md` | Agent [x] |
| 5 | The frontmatter gate scans policy files, and a malformed one fails | `bash scripts/check_prompt_frontmatter.sh` reports 35 files; `tests/test_lint_umbrella.sh` `test_frontmatter_gate_scans_policy_files` passes | Agent [x] |
| 6 | The two cleared legacy wrap entries are removed | `grep -n "testing_policy\|operations/handover_policy" .markdownlint-cli2.mjs` returns nothing; `bash scripts/check_doc_wrap_legacy.sh -- <the two files>` is clean | Agent [x] |
| 7 | Gates and suite green | `bash scripts/lint.sh` clean across 6 gates; `bash scripts/run_tests.sh` 1048 passed | Agent [x] |
| 8 | The roadmap row is closed | `grep -n "Policy-file membership review" devlog/roadmap.md` reads `[x]` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | home of the membership and header rules; a policy file itself |
| [`docs/concepts/documentation_taxonomy.md`](../../docs/concepts/documentation_taxonomy.md) | declares the set |
| [`docs/operations/adr_policy.md`](../../docs/operations/adr_policy.md) | its `## Purpose` section folds into the frontmatter |
| [`docs/operations/discussion_policy.md`](../../docs/operations/discussion_policy.md) | frontmatter added |
| [`docs/operations/git_policy.md`](../../docs/operations/git_policy.md) | frontmatter added |
| [`docs/operations/handover_policy.md`](../../docs/operations/handover_policy.md) | inline block moves to frontmatter; its wrap debt cleared |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | inline block moves to frontmatter |
| [`docs/operations/roadmap_policy.md`](../../docs/operations/roadmap_policy.md) | inline block moves to frontmatter |
| [`docs/development/testing_policy.md`](../../docs/development/testing_policy.md) | frontmatter added; its wrap debt cleared |
| [`scripts/lint/prompt-frontmatter.mjs`](../../scripts/lint/prompt-frontmatter.mjs) | gains the policy collection |
| [`scripts/check_prompt_frontmatter.sh`](../../scripts/check_prompt_frontmatter.sh) | header states the wider scope |
| [`tests/test_lint_umbrella.sh`](../../tests/test_lint_umbrella.sh) | the gate's new policy branch |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the row this iteration closes |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `description` and `scope` live in YAML frontmatter, not an inline block | the frontmatter leaves the body untouched, and the repo already uses frontmatter for prompts and handovers | this handover |
| `scope` is a single-line YAML flow list | the `doc-wrap` rule walks markdown-it tokens; a block-style list can present as a multi-line paragraph, a flow list cannot | this handover |
| The frontmatter gate scans `docs/**/*_policy.md` too | a policy block is never loaded at runtime, so a typo has no symptom; the gate is the only check | this handover |
| `adr_policy.md`'s `## Purpose` section folds into `description` | it was a preamble with the same purpose as the frontmatter, which the format replaces | this handover |
| The two policy files edited here leave the `legacyFiles` wrap exemption | editing a legacy file is the commit that clears its wrap debt | this handover |
| `check_prompt_frontmatter.sh` keeps its name | a rename ripples through `lint.sh`, the tests and the conventions; the name now undersells its scope, and that is filed rather than fixed here | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| `tests/knowledge/knowledge_pi_config_cycle.sh` line 30 cites `docs/operations/testing_policy.md`; the file lives at `docs/development/testing_policy.md` | contradiction | out of scope; a stale comment path, recorded for a later record pass |
| `scripts/check_prompt_frontmatter.sh` now scans policy files, so its name undersells its scope | steering | the rename candidate for a later unit |

## Completed

| File | Change |
|---|---|
| `docs/operations/documentation_policy.md` | frontmatter added; `### Document header format` gains the policy frontmatter rule; `## Rule authority` gains the membership criterion |
| `docs/concepts/documentation_taxonomy.md` | the policy row keys off `docs/**/*_policy.md`; the set is declared; the `operations/` folder row names the guides and SOPs |
| `docs/operations/adr_policy.md` | frontmatter added; `## Purpose` folds into `description` |
| `docs/operations/discussion_policy.md` | frontmatter added |
| `docs/operations/git_policy.md` | frontmatter added |
| `docs/operations/handover_policy.md` | frontmatter added; inline block removed; the two-line paragraph joined |
| `docs/operations/iteration_policy.md` | frontmatter added; inline block removed |
| `docs/operations/roadmap_policy.md` | frontmatter added; inline block removed |
| `docs/development/testing_policy.md` | frontmatter added; the two-line paragraph joined |
| `docs/development/prompt-authoring-conventions.md` | the gate's scope reads prompt, skill and policy |
| `scripts/lint/prompt-frontmatter.mjs` | the policy collection and the wider message |
| `scripts/check_prompt_frontmatter.sh` | the header names the policy scan |
| `.markdownlint-cli2.mjs` | the two cleared legacy entries removed |
| `tests/test_lint_umbrella.sh` | the policy-scan test added; the clean-verdict string updated |
| `devlog/roadmap.md` | the M3.2.1 row closed with its landing note |
