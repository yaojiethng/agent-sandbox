---
date: 2026-10-18
milestone: M3.3.4 - The prose standards as principles
type: Workflow
status: Closed
---

# Handover - Make the git policy the single mention of the git runbooks

## Objective

Give git hygiene one entry point. The git policy names the three maintenance runbooks and nothing else does, and `AGENTS.md` says the policy is the git-hygiene document.

## Scope

Three references named a git maintenance runbook outside the policy's reference table: the post-close correction rule in `documentation_policy.md`, and the non-goal in `history-cleanup.md`, which named the porting runbook. Both now name the operation and point at the policy. The table collapses from three rows to one row that names the three, so a reader learns the set in one place.

`AGENTS.md` gains a *Git hygiene* constraint naming `git_policy.md` and linking it, with the module status stated.

Not in scope: creating a git module. `docs/adr/coding_agent_project_bindings.md` records that git is an available tool rather than a module, and the `AGENTS.md` line says so rather than promising a module that no decision authorises.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The git policy is the only place naming a git maintenance runbook | a search for `merge.md`, `rebase.md` and `history-cleanup.md` outside the policy and the runbooks themselves returns nothing | Accepted |
| The policy names the three in one row | the reference table holds one row for the set | Accepted |
| `AGENTS.md` names the policy as the git-hygiene document | the *Git hygiene* constraint, with the link | Accepted |
| The stopgap does not assert a module that no decision authorises | the sentence cites the ADR that says git is a tool | Accepted |
| The gates and the suite are green | `bash scripts/lint.sh` 10 gates; `bash scripts/run_tests.sh` 1,227 | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| One table row names the three runbooks, not three rows | The table is a registry, and a registry that grows a row per runbook invites the same list into a second document. One row states the set and its boundary. | `git_policy.md` `## References` |
| A mention outside the policy names the operation, not the file | A path in a second document is a second mention that rots on a rename. The operation's name is stable; the policy resolves it. | `documentation_policy.md`; `history-cleanup.md` |
| No module name is invented | No `git-hygiene` module exists anywhere in the tree, and the ADR states git is a tool. Naming a module would record a decision nobody made. | this record; `coding_agent_project_bindings.md` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Does git hygiene become a module, or stay a policy plus its runbooks? | where the runbooks live once the module tree grows | a `git-hygiene` module; keep the policy as the home |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `git-hygiene` appears nowhere in the tree, and the ADR says git is an available tool, not a module. | evidence | The request assumed a module name that was never chosen. The `AGENTS.md` line states the stopgap and cites the ADR, so the reader is not promised a module. |
| The policy's reference table was three rows, one per runbook. | diagnosis | A row per file is a list in disguise. One row stating the set keeps the registry from being copied elsewhere. |
| Two policy documents and one runbook named a sibling runbook by path. | evidence | Each is a mention that rots on a rename. They now name the operation and defer to the policy. |

## Completed

| File | Change |
|---|---|
| [`git_policy.md`](../../docs/policies/git_policy.md) | the three rows become one row naming the set |
| [`documentation_policy.md`](../../docs/policies/documentation_policy.md) | the port is named as an operation, resolved by the git policy |
| [`history-cleanup.md`](../../workflow/coding-agent/prompts/history-cleanup.md) | the non-goal names the porting operation, not its file |
| [`AGENTS.md`](../../AGENTS.md) | the *Git hygiene* constraint names and links the git-hygiene document |
| [`norm-ownership.tsv`](../../scripts/lint/norm-ownership.tsv) | the edited policy line reclassified `rule-reviewed` with `prompt:record-correction` |
