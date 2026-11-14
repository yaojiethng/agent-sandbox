---
date: 2026-11-14
milestone: M3.7.2 - The change model and its refinements
type: Implementation
status: Closed
---

# Handover - The delivery commit message is checked

## Objective

Turn the convention's message table into a mechanical check, so a non-conforming
delivery commit is caught by a tool instead of a reader.

## Scope

Works the row *The message shape is enforced by a check*, under *The convention
leads from history as a commons and owns the primitives* (handover
[`20261114-02`](20261114-02-design-git_discipline_reframe.md) records the
verdict). The check reads the active type set from
[`references/commit-types.md`](../../../.agents/skills/git-discipline/references/commit-types.md),
so a new type is added in one place. Out of scope: the subject and body budgets
as *numbers* (their substantiation is a separate row); a `commit-msg` hook, which
a fresh clone does not carry; rewriting the convention's table, which stays the
rule the check implements.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The check accepts a conforming delivery message. | `tests/test_commit_message_check.sh` case `passing`. | Agent [x] |
| It rejects an unknown type, a subject over 72, a scope field and a body over 280, each with a named reason. | The same test's four failing cases. | Agent [x] |
| The active type set is read from `references/commit-types.md`, not restated. | The fixture test adds a type to a fixture table and the check accepts it there; the script names no type of its own. | Agent [x] |
| The hook checks every commit, so a commit outside `/commit` is covered too. | `tests/test_commit_hook.sh`: refused, passed, and inert without the path. | Agent [x] |
| The convention points at the check without restating it. | `grep -n 'check_commit_message' .agents/skills/git-discipline/SKILL.md`. | Agent [x] |
| The standard is a citation record, cited from the check's row. | `test -f .agents/registry/citations/conventional-commits.json`. | Agent [x] |
| The check's rules and the convention's table agree on every cell. | Read the table against the check's assertions. | Agent [x] |
| Every decision this iteration records is realized in the files. | Read the Decisions table against the diff. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The check is `scripts/check_commit_message.sh <message-file>`, not a lint gate. | A tree gate has no message to read; a file argument serves `/commit`, a fixture and a hook equally. | this record |
| `/commit` runs it before `git commit`; no `commit-msg` hook. | A fresh clone carries no hook, and `core.hooksPath` is local state the harness does not seed. | this record |
| The type set is parsed from `references/commit-types.md`. | The table is already the single source; a hard-coded list is the drift this check exists to catch. | this record |
| The check fails over 72 and does not enforce the 50 target. | The rule is 72 at most; 50 is a target a check cannot judge without a human's reason for the length. | this record |
| The convention gains one pointer sentence; the table stays the rule. | One source: the prose states the rule, the script enforces it. | this record |
| The table steers, the check audits, `/commit` points. | A message written from the table passes first time, the check catches the miss, and `/commit` carries neither rule twice. | the convention, the check, `commit.md` |
| `commit.md` B2 drops the rule restatement and B3 drops the two hand-checks the check now owns. | Two copies of one rule at the call site are the duplication the check exists to remove. | `commit.md` |
| An unknown type lists the active set. | The refusal is the steering that keeps a second turn rare; a bare refusal only says no. | the check |
| The hook is the audit; the runbook no longer calls the check. | The operator preferred the hook, and a commit outside `/commit` is then covered too. | `.githooks/commit-msg`, `commit.md` B2 |
| Seeding `core.hooksPath` is the entrypoint's job, filed as a row. | The tree can carry the hook but not the clone's config; without the seed the hook is inert, which the test states. | the seeding row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The convention says "the nine active types" but never lists them; the list lives only in the reference, so the count in the prose goes stale when a type is added. | record | a stale count in the rule the check reads | this iteration, the pointer sentence |
| The check had no input contract; `/commit` builds the message in B2, so B2 writes it to a file and runs the check before committing. | design | the wiring point now has a home | this iteration, `/commit` B2 |
| `commit.md` restated the message rules the convention and the check now own. | record | three copies of one rule | this iteration, B2 and B3 |
| `commit.md` carried admission rules and a machine contract, and named a Part B that did not exist. | record | a prompt mixing the close with the commit | cut `Called from` and `Input contract`, renamed C to B; the three-operation rewrite is a new row |
| The hook is inert until `core.hooksPath` is set in the clone, which the tree cannot do. | record | an unseeded container checks nothing | the seeding row |

## Completed

| File | One-line change summary |
|---|---|
| `scripts/check_commit_message.sh` | the two-layer check; the active types parsed from the reference |
| `.githooks/commit-msg` | the hook: the same check, on every commit |
| `tests/test_commit_hook.sh` | refused, passed, and inert without the path |
| `.dockerignore` | `.githooks/` excluded from the build context, which no Dockerfile reads |
| `tests/test_commit_message_check.sh` | nine cases: one passing, six refusals, the breaking marker, the fixture set |
| `tests/test_lint_umbrella.sh` | the check is classified as invoked by `/commit`, not the umbrella |
| `workflow/coding-agent/prompts/commit.md` | B2 points and checks; B3 delegates the type, scope and length to the check; `Called from` and `Input contract` cut, C renamed B; B2 no longer calls the check |
| `.agents/skills/git-discipline/SKILL.md` | the pointer sentence, and the stale "nine" count links the reference |
| `.agents/registry/citations/conventional-commits.json` | the standard and its adaptation |
| `devlog/roadmap.md` | the row closes |
| (maintenance) | `roadmap-maintenance`: not triggered; no completed sub-milestone reads `In progress`. |
