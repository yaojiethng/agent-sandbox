# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Step 1 of the doc-format lint rules task, per the operator's progressive-scope ruling: introduce the doc-wrap rule in the lint workflow and commit it, without making it always-live. The conversion chore (step 2) and the enable commit (step 3) are future iterations.

## Scope

- New custom rule `scripts/lint/doc-wrap.mjs`: one paragraph per physical line (documentation_policy.md `### Line wrapping`), detecting hard-wrapped prose; fence, table, and frontmatter exempt by construction.
- Config-driven `legacyFiles` exemption seam for the conversion window, tested; never a per-file disable comment (documentation_policy.md `### Markdown lint gate`).
- Wire into `.markdownlint-cli2.mjs` with `doc-wrap` off (introduced, not live); update `check_markdown.sh` header and `documentation_policy.md` `### Markdown lint gate`.
- `tests/test_doc_wrap_rule.sh`: 6 fixture tests against the real `markdownlint-cli2`.
- Roadmap write-back: record step 1 on the Doc-format lint rules row, keep the row open.

**Deferred:** the conversion chore, the enable commit, and the feedback entry disposition (probation stays until the rule is live; disposition at the M3.1 pre-close review).

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The rule flags a wrapped paragraph, list item, and quote, naming the first line | `bash tests/test_doc_wrap_rule.sh` | Agent [x] -- three wrap classes flagged with the policy quote |
| 2 | Single-line prose, fenced code, tables, and frontmatter pass | `bash tests/test_doc_wrap_rule.sh` | Agent [x] -- three clean classes pass |
| 3 | The `legacyFiles` seam exempts exactly the named file | `bash tests/test_doc_wrap_rule.sh` | Agent [x] -- other file still flagged |
| 4 | The rule is in the workflow config but not live; the gate behavior is unchanged | `grep doc-wrap .markdownlint-cli2.mjs`; `make lint` still Clean | Agent [x] -- `doc-wrap: false`; `scripts/lint.sh` Clean |
| 5 | The tree-wide run of the rule reports zero findings (evidence for the chore size) | rule run over all 593 Markdown files | Agent [x] -- 593 files, 0 findings |
| 6 | Docs updated: `check_markdown.sh` header, policy `### Markdown lint gate`, roadmap row | read the files | Agent [x] -- all three updated |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/lint/doc-wrap.mjs`](scripts/lint/doc-wrap.mjs) | new rule |
| [`.markdownlint-cli2.mjs`](.markdownlint-cli2.mjs) | rule wired in, off |
| [`tests/test_doc_wrap_rule.sh`](tests/test_doc_wrap_rule.sh) | 6 fixture tests |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | `### Markdown lint gate` names the rule and its state |
| [`devlog/roadmap.md`](devlog/roadmap.md) | step 1 recorded, row open |
| [`scripts/check_markdown.sh`](scripts/check_markdown.sh) | header comment names both custom rules |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rule ships in the workflow with `doc-wrap: false`; the enable act is a later verify-and-flip commit | the operator's step 1: introduce in a workflow, commit, do not make it always-live | this handover; `devlog/roadmap.md` |
| The exemption is config-driven (`legacyFiles` rule option), never a per-file comment | documentation_policy.md forbids per-file disables | `scripts/lint/doc-wrap.mjs` header |
| Detection uses markdown-it inline-token maps: a text block spanning more than one physical line is a wrap | the AST is the same one markdownlint uses; fence/table/frontmatter never produce multi-line inline tokens | `scripts/lint/doc-wrap.mjs` header |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The 593-file tree-wide run of the rule reports zero hard-wrapped prose today | measurement | next iteration - the conversion chore is expected empty; step 3 is a verify-and-flip commit |
| `markdownlint-cli2` discovers and merges a repo-root `.markdownlint-cli2.mjs` even when `--config` is given | tooling | test fixtures must live outside the repo tree, or the repo config overrides the fixture config |
| Custom-rule context carries the file path as `params.name`, not `params.filename` | tooling | documented in the rule; `legacyFiles` matching uses `params.name` |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-10-impl-m3_1_doc_wrap_rule_introduction.md` | opened this handover | done |
| `scripts/lint/doc-wrap.mjs` | new rule with `legacyFiles` seam | done |
| `.markdownlint-cli2.mjs` | header names both custom rules; `doc-wrap: false` with enable-step comment | done |
| `tests/test_doc_wrap_rule.sh` | 6 fixture tests, 12 assertions | done |
| `scripts/check_markdown.sh` | header comment names both custom rules | done |
| `docs/operations/documentation_policy.md` | `### Markdown lint gate` names `doc-wrap` and its state | done |
| `devlog/roadmap.md` | step 1 recorded on the open row | done |

## Deferred items

- The conversion chore (step 2): expected empty per the zero-findings measurement; re-run the rule as its own verification instead of a conversion pass.
- The enable commit (step 3): verify zero findings with the rule live, then flip `doc-wrap` on and commit.
- `[A] 2026-09-21 Doc-format discipline via lint (T3)` probation disposition: stays probation until the rule is live; disposition at the M3.1 pre-close review.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: none pending.

The next iteration is the enable commit (step 3): run the gate with a temp config enabling `doc-wrap` tree-wide (expected zero findings given the measurement), then flip the repository config to `doc-wrap: true`, add the real-tree regression guard to `tests/test_doc_wrap_rule.sh`, and commit. If the zero-findings expectation does not hold (a file was wrapped in the meantime), the wrap fix belongs in that same iteration as a correction. Watch-outs: (1) the hook uses the same config, so staged files get doc-wrap enforcement the moment the config flips; (2) keep the `legacyFiles` seam in the rule even after enabling, for any future carve-out; (3) after the flip, the Doc-format lint rules row can mark `[x]` on that committing handover.

Feedback-entry dispositions at the M3.1 pre-close review (pending): `[O]` library return-not-exit (durable fix landed in `20260921-08`), `[A]` shellcheck-directive (durable fix landed in `20260921-07`), `[A]` doc-format (depends on the enable commit), `[A]` record-write-back and `[A]` mechanical-edit families (unchanged).
