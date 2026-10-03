# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Impl
**Status:** Closed

## Objective

Close the doc-format lint rules task: enable the `doc-wrap` rule after a zero-findings confirmation (step 3 of the progressive-scope ruling), and remove the obsolete manual unwrap tool `scripts/manual/unwrap_prose.sh` that was made dead code by the rule.

## Scope

- Flip `.markdownlint-cli2.mjs` to `doc-wrap: true`; update the config header and comment.
- Add a real-tree zero-findings regression guard to `tests/test_doc_wrap_rule.sh` (rule on, no exemptions, over the whole repository).
- Update `scripts/check_markdown.sh` header and `documentation_policy.md` `### Markdown lint gate` to record the rule as live.
- Remove `scripts/manual/unwrap_prose.sh` and confirm zero references remain in living code (docs, scripts, tests, config).
- Roadmap write-back: mark the Doc-format lint rules row `[x]`.

**Deferred:** the `[A]` doc-format feedback probation disposition (at the M3.1 pre-close review). The mount-delivery hooks decision stays open; this iteration touches none of it.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | The rule is enabled in the repository config and the gate stays Clean | `grep doc-wrap .markdownlint-cli2.mjs`; `bash scripts/lint.sh` | Agent |
| 2 | A tree-wide run with the rule on reports zero findings (regression guard test) | `bash tests/test_doc_wrap_rule.sh` | Agent |
| 3 | `unwrap_prose.sh` is removed with zero living references | `git rm`; `grep -rn unwrap docs/ scripts/ src/ tests/` | Agent |
| 4 | Docs updated: `check_markdown.sh` header, policy `### Markdown lint gate`, roadmap row `[x]` | read the files | Agent |
| 5 | No unrelated changes (mount-delivery, hook design untouched) | `git diff --stat` | Agent [x] -- only in-scope files touched |
| 6 | The host installer installs, notices missing tools (fails closed), and detects drift | run `install_host_git_hooks.sh`, `--check`, and a tool-stripped PATH | Agent [x] -- happy path, `--check` match/drift, missing-tool fail all verified |
| 7 | ADR entry and roadmap row record the host-initiated resolution | read `git_hooks.md` and the mount row | Agent [x] -- entry added, mount row closed |

## Hot files

| File | Why in scope |
|---|---|
| [`.markdownlint-cli2.mjs`](.markdownlint-cli2.mjs) | `doc-wrap` flips on |
| [`tests/test_doc_wrap_rule.sh`](tests/test_doc_wrap_rule.sh) | real-tree guard added |
| `scripts/manual/unwrap_prose.sh` | removed as dead code |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | record the rule as live |
| [`scripts/check_markdown.sh`](scripts/check_markdown.sh) | header names both custom rules as live |
| [`devlog/roadmap.md`](devlog/roadmap.md) | Doc-format row marked `[x]` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Enable the rule without a conversion chore | the tree-wide measurement reports zero hard-wrapped prose; there is nothing to convert | `docs/operations/documentation_policy.md` |
| Remove `unwrap_prose.sh` | it is dead code the rule supersedes; keeping a second, differently-scoped detector invites drift | this handover |
| Leave the two historical handovers that reference `unwrap_prose.sh` untouched | handovers are immutable records of what each session delivered; removing the tool does not rewrite history | this handover |
| The host hook install is operator-initiated, never container-planted | an agent-writable host hook is the rejected host-exposure vector; host-initiated install keeps the reviewed content under operator control | `docs/adr/git_hooks.md` entry 2026-09-21 |

## Findings

| Finding | Type | Impact |
|---|---|---|
| Zero living references to `unwrap_prose.sh` outside the two historical handovers | verification | removal is clean; no doc or test needed updating |
| `doc-wrap` live-ness is enforced by the lint gate itself (the gate runs the repo config) | design | the real-tree guard keeps the rule honest even if the config is later flipped |

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-11-impl-m3_1_doc_wrap_live.md` | opened this handover | done |
| `.markdownlint-cli2.mjs` | `doc-wrap: true`; header and comment updated | done |
| `tests/test_doc_wrap_rule.sh` | real-tree zero-findings guard registered | done |
| `scripts/manual/unwrap_prose.sh` | removed via `git rm` | done |
| `docs/operations/documentation_policy.md` | rule recorded as live | done |
| `scripts/check_markdown.sh` | header names both rules as live | done |
| `devlog/roadmap.md` | Doc-format lint rules row `[x]`; Mount-delivery hooks row `[x]` | done |
| `scripts/manual/install_host_git_hooks.sh` | new host-initiated hook installer | done |
| `docs/adr/git_hooks.md` | entry: host-initiated install resolves mount hooks without a constraint change | done |

## Deferred items

- `[A] 2026-09-21 Doc-format discipline via lint (T3)` probation disposition, at the M3.1 pre-close review.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: none pending (the two write-back discrepancies fold into the M3.1 close).

Remaining M3.1 rows: **Lint and tests take forever** - the operator picks an approach from the study's open questions (batch-parallel small, strict per-file medium with the 8-file reconciliation). After that, M3.1 closes and folds back into M3.

Feedback-entry dispositions at the M3.1 pre-close review (pending): `[O]` library return-not-exit (durable fix `20260921-08`), `[A]` shellcheck-directive (durable fix `20260921-07`), `[A]` doc-format (durable fix now live), `[A]` record-write-back and `[A]` mechanical-edit families (unchanged).
