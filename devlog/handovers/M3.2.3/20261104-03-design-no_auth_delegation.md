---
date: 2026-11-04
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Design
status: Closed
---

# Handover - provider auth stays with the provider

## Objective

Resolve the no-auth placeholder row by withdrawing it and recording the provider-auth delegation as an ADR.

## Scope

The T12 row **A start with no provider authenticated selects the `unknown/unknown` placeholder**. The operator rejected the harness guard: agent-sandbox passes the provider environment variables and starts the provider inside the sandbox, while pi resolves its own credentials and offers `/login` after startup. A harness check would shadow pi's resolution with no added benefit.

This iteration withdraws the row rather than restating it as a closed task. A closed row in a milestone that is not started is read by no one. The ruling is an ADR, because it is a standing principle with rejected alternatives; a reference document describes the machinery and does not carry the why. The M3.2.3 parent beside the durable settings row cites the ADR. The existing selection report is amended to point at the ADR; no new discussion document and no new task row are opened.

It changes no code, no configuration, and no startup behavior.

Ruled out of scope: a preflight auth check, a resolver in the entrypoint, a startup warning, and any inspection of `auth.json`. The upstream pi report stays with the T12 **pi upstream** row. The durable settings row stays open at M3.2.3.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The T12 row is gone, no replacement task row exists, and the M3.2.3 parent cites the ADR | `grep -n "A start with no provider"` prints nothing; `grep -n "auth boundary is settled"` names the parent; read the parent | Agent [x] |
| The ADR states the harness passes the environment and starts the provider, does not inspect `auth.json` or resolve keys, and the provider owns `/login`; the rejected guard, resolver and warning are present | read `## 2026-11-04` and the requirements table | Agent [x] |
| The report no longer recommends a startup guard and its Outcome records the withdrawal | `grep -n "would have to be added"` prints nothing; read the paragraph and Outcome | Agent [x] |
| Every decision in the handover is realized in the files | read `## Decisions` against the tree | Agent [x] |
| The iteration changes no code or configuration | `git diff --stat` and `git status --short` name only records | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| No harness auth guard; provider credential resolution and `/login` belong to the provider runtime | The harness passes the environment and starts the provider. Resolving keys would shadow the runtime's own resolution with no added benefit | the ADR; the M3.2.3 parent note |
| Withdraw the row rather than close it | A closed task row in a `Not started` milestone is read by no one. The ruling belongs in the ADR and the open config question | `devlog/roadmap.md`; the ADR |
| Record the ruling as an ADR, not a reference section, and amend the existing report rather than open a discussion document | A reference states what the harness does; the rationale and the rejected guard belong in the explanation corpus. The report already carries the measurement and the wrong recommendation | `docs/adr/provider_auth_resolution.md`; the settlement report |
| M3.2.3 stays `Not started`; the row is withdrawn out of order | No sub-milestone work opens. The parent note records the boundary without adding dispatch work | this record; `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The selection report recommends adding a startup guard for the no-auth case; the operator rejected it | defect (record) | the report would send a later session to build a shadow resolver | corrected in this iteration |
| The no-auth row sits in T12, whose blurb owns pi dependency and extension upkeep, not the config boundary | defect (record) | a later session would look for the ruling in the wrong milestone | withdrawn in this iteration; the parent note records the boundary |
| The no-auth row asked for a closed task; a closed row in a `Not started` milestone is read by no one | steering | the ruling would sit where no reader goes | filed in the ADR and the M3.2.3 parent; no task row |
| The ruling was first placed in `provider_lifecycle.md`; a reference describes the machinery, not why a principle beat its alternatives | defect (placement) | the rationale would sit in a corpus that does not carry rationale | moved to `docs/adr/provider_auth_resolution.md` |
| AC 3 named `grep "startup guard"`, which matches the corrected negation; the check was retargeted to `grep "would have to be added"` | defect (record) | the criterion would fail on a correct implementation | corrected in this record |
| The handover names M3.2.3, the row group, while `active-milestone` stays M3.3.3 | deliberate deviation | the record is grouped with the out-of-order row rather than the active milestone | this record; the roadmap frontmatter is unchanged |

## Completed

| File | Change |
|---|---|
| `docs/adr/provider_auth_resolution.md` | new ADR: the provider resolves credentials; the harness passes the environment and does not guard startup |
| `devlog/roadmap.md` | no-auth row withdrawn; the M3.2.3 parent cites the ADR; roadmap-maintenance check clean |
| `devlog/discussions/20261104-report-settled-enabled_models_scope_head.md` | guard recommendation removed; Outcome points at the ADR |
| `devlog/handovers/20261104-03-design-no_auth_delegation.md` | this work-unit record |
