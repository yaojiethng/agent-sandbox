# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Subsume the general writing rules into a provider-global Communication Standards shadow so every agent output meets them, with `documentation_policy.md` as the canonical organizational home.

## Scope

The roadmap task "Writing-conventions section extraction or subsume" (subsumed into `AGENTS.md`, requested by the operator). The redistribution touches both AGENTS layers and the doc-policy section name.

## Carried forward

None.

## Acceptance criteria

1. The provider-layer `AGENTS.md` carries a `## Communication Standards` section governing all agent prose, named `Communication Standards`, with no documentation-scoped enumeration.
2. The provider `## Communication Standards` shadow adds the numbering rule (one indexable axis) and the target-document-conventions rule.
3. The repo-root `AGENTS.md` `## Output Format` enforces the Communication Standards across all output classes and no longer restates the STE100 subset.
4. `documentation_policy.md` names its prose section `## Communication Standards`, and no file carries a stale `## Writing Rules` reference.
5. The repo-root `AGENTS.md` does not link to the provider `AGENTS.md`.
6. Lint gate clean.

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | home of the general Communication Standards shadow |
| [`AGENTS.md`](../../AGENTS.md) | project layer; Output Format enforces the standards |
| [`docs/operations/documentation_policy.md`](../../docs/operations/documentation_policy.md) | canonical home; section rename |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | task registration |
| [`devlog/AGENT_FEEDBACK.md`](../../devlog/AGENT_FEEDBACK.md) | toxic-framing entry |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| General Communication Standards are canonical in the provider-layer `AGENTS.md` | loaded first on every session; rules there bind the provider, not one project | provider `AGENTS.md` |
| Repo-root `AGENTS.md` does not link the provider file | the harness claims multiple providers; delivery of the layer differs between them | `AGENTS.md` Output Format |
| Doc-policy section renamed to `## Communication Standards` | one term, one meaning with the shadow | `documentation_policy.md` |
| No STE100 shadow in the repo root | the general core already reaches context through the provider layer; a shadow re-introduces the triple copy | `AGENTS.md` Output Format |
| Toxic framing kept as a feedback entry, not encoded as a style rule | it is a remedy, not a prose rule | `devlog/AGENT_FEEDBACK.md` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The roadmap already carried an open task naming this objective ("Writing-conventions section extraction or subsume", raised 2026-09-28) | steering | current iteration - registers the redistribution and closes it here |
| Toxic framing of writing-rule discoverability (raised 2026-09-30) | steering | `devlog/AGENT_FEEDBACK.md` `[O]` entry; durable fix is this redistribution |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | renamed section to `## Communication Standards`; concise lead; added numbering and target-document-conventions rules |
| `AGENTS.md` | `## Output Format` enforces the standards across all output; dropped the STE100 restatement |
| `docs/operations/documentation_policy.md` | renamed prose section to `## Communication Standards` |
| `devlog/roadmap.md` | task `Writing-conventions section extraction or subsume` marked resolved |
| `devlog/AGENT_FEEDBACK.md` | added the `[O]` toxic-framing entry; retargeted references to `## Communication Standards` |

## Deferred items

None.

## What's Next

Next sub-milestone: M3.2.2 - Audit and Review Workflow Cleanup.

No sub-milestone completed this iteration; roadmap maintenance done for the closed task.

When the provider `AGENTS.md` deploys, the installed copy (`~/.pi/agent/AGENTS.md`) must be refreshed to match the tracked source so the running context and the shipped config do not diverge.
