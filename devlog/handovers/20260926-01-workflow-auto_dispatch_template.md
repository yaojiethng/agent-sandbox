# Agent Handover

**Date:** 2026-09-26
**Milestone:** M3.1 - Backpressure
**Type:** Workflow
**Status:** Closed

## Objective

Extract the dispatch process the test-class coverage campaign used into a standing main-agent template, `/auto`: one unit at a time to a fresh subagent, the return verified against the tree, and one commit per unit.

## Scope

One new prompt template, one inventory row for the entry point, and this handover. No production file, no test, and no policy document changes.

## Carried forward

| Item | From handover |
|---|---|
| The dispatch process itself, as practised across the nine campaign units and the fix lane | [20260925-13](20260925-13-test-pin_hint_selection_and_health_gate.md) through [20260925-23](20260925-23-fix-readthrough_code_rows_and_state_allowlist.md) |

## Acceptance criteria

| Criterion | Verifiable by | Verified by |
|---|---|---|
| The template is invocable as `/auto` | the file name `auto.md`; pi takes the command name from the file name | Agent [x] |
| It appears in autocomplete with a description and an argument hint | the frontmatter keys `description` and `argument-hint`, the form used by `gm.md`, `bootstrap.md` and `rebase.md` | Agent [x] |
| The dispatch, verification and landing rules are stated once, without restating the sibling briefs | the sections `Step 1` to `Step 5`, and the links to `fanout-run.md`, `test-quality-campaign-run.md` and `read-through-run.md` | Agent [x] |
| The failure modes the campaign met are recorded | the `## Failure modes observed` section, seven modes | Agent [x] |
| The entry-point inventory lists the new template | the `## Entry point map` table in `surface-area-report.md` | Agent [x] |
| Lint clean | `bash scripts/lint.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/auto.md`](../../workflow/coding-agent/prompts/auto.md) | the template; deployed by the folder COPY into `/opt/workflow/agent/prompts/` |
| [`workflow/coding-agent/audits/surface-area-report.md`](../../workflow/coding-agent/audits/surface-area-report.md) | the entry-point map; the report is repo-side, not deployed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prompt lives in `workflow/coding-agent/prompts/`, not `src/reasoning/agent/prompts/` | both folders are COPY-merged into one deployed directory and a name collision silently overwrites, so a file belongs to exactly one; this one encodes the project's own per-unit delivery rule, like the other `-run` briefs | the deployment boundary section of `surface-area-report.md` |
| Pi-native frontmatter with `description` and `argument-hint` | the two generations coexist here; the frontmatter form is what surfaces the command in autocomplete with its hint | this handover |
| The dispatch logs to a file, not through a pipe | the campaign dispatched through a pipe, which returns the status of the last pipe stage rather than the status of the subagent and drops unflushed output on an interrupt; the provider-layer AGENTS.md already states the log-file form | the dispatch section of the template |
| No See Also row in `testing_policy.md` | that list carries the three testing passes; this template is not a pass, it is the dispatch loop those passes run under | this handover |
| Roadmap row 101 keeps the governance half | that row owns the amendments to `iteration_policy.md` Step 2 and `handover_policy.md`, which need section-by-section operator release | this handover |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The campaign's own dispatch practice used a pipe, contrary to the provider-layer instruction to capture a subagent run to a log file. The pipe hides the subagent's exit status behind `tail`. | contradiction | the template states the log-file form, and the failure-mode list carries it |
| The background dispatch leaves a half-repaired record; `setsid nohup` was killed at tool-call end and left the register repaired in part. | contradiction | recorded as failure mode (a) |
| `pgrep`, `jq`, `python3`, `make` and `docker` are absent from this image, so a brief that calls one fails at its first command. | steering | recorded as failure mode (g) |
| The surface-area report's deployment section still names `_agent_sig_sources` in `src/libs/container_sig.sh`. That file and that function no longer exist; `docs/adr/harness_versioning.md` records that a repo digest roundtrip replaced the recompute. | scope change | flagged only; the report is a repo-side audit record and the correction belongs to a documentation pass |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/auto.md` | new template: purpose, when to run this way, the five steps, seven observed failure modes, six invariants |
| `workflow/coding-agent/audits/surface-area-report.md` | one `## Entry point map` row for `/auto` |

## Deferred items

Roadmap row 101 (scope-to-unit decomposition) owns the governance half: the unit table at Gate 1 in `iteration_policy.md` Step 2 and `handover_policy.md`. The `/auto` template states the runtime side only.

## What's Next

The register's remaining open rows (3 test-class, 31 code, 46 note), roadmap row 84 (one verdict vocabulary), row 86 (the mutation suite), and rows 101/103 (the governance pair).

Read at iteration start: this handover, `workflow/coding-agent/prompts/auto.md`, and the provider-layer `AGENTS.md` sections on fresh subagent invocation and running review subagents.

**Conclusions from this iteration:** the campaign's dispatch process was reproducible enough to write down, and writing it down exposed one place where the campaign's practice was worse than the stated policy, which is the log file for a subagent run.
