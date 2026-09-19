# Agent Handover

**Date:** 2026-09-18
**Milestone:** M2.6 - Session Persistence
**Type:** Workflow
**Status:** Closed

## Objective

Create the branch-port prompt template that replays a stale branch's iterations onto a target branch.

## Scope

Operator-directed workflow-asset continuation, same pattern as the bootstrap prompt delivery (`20260917-04`). One new template in the deployed prompt surface, plus its registry row. The template encodes the procedure exercised in the two-port session: topology mapping, intent collection from iteration handovers, supersession check, one-commit-per-iteration replay, and artifact exclusion.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| 1 | The template takes the fixed input contract: stale branch, target branch, port intent | Argument hint names all three; Mandate defines each | done |
| 2 | The template mandates intent replay, never verbatim diff copying | Mandate rule one and the Replay section state it | done |
| 3 | The template preserves one commit per iteration, original messages, no port commit | Mandate rule two and the Replay section state it | done |
| 4 | The template stops and asks on real architectural divergence | Mandate rule three names the only stop condition | done |
| 5 | The template excludes pipeline artifacts (`.draft-state`, `.rej` remnants, strays) | Exclude section covers all three; `.rej` realization is explicit | done |
| 6 | The template meets the prompt-surface conventions and documentation-policy writing rules | Frontmatter plus `> $@` slot, STE wording, ASCII-only, one paragraph per line, registry row added | done |

## Hot files

| File | Why in scope |
|---|---|
| [`workflow/coding-agent/prompts/rebase.md`](../../workflow/coding-agent/prompts/rebase.md) | New branch-port prompt template, deployed via the folder COPY of the prompts directory |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Registry row for the new template |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The template lives in the prompts folder, not as a skill | The operator asked for a prompt in the prompt surface; skills live in the audits folder | This handover |
| The five-way supersession classification (present, superseded, merged, live, divergent) is the template's core check | It is the classification that resolves every case the two-port session hit; divergent is the only stop condition | `rebase.md` Check supersession |
| The port leaves no commit and no scaffolding | One commit per iteration is the record; the port session is the record of the port | `rebase.md` Replay |

## Findings

None.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/rebase.md` | New template: input contract, topology map, intent collection, artifact exclusion, five-way supersession check, one-commit-per-iteration replay rules, verification, close |
| `docs/development/project_index.md` | Added the `prompts/rebase.md` registry row |

## Deferred items

None.

## What's Next

Sub-milestone: M2.6 - Session Persistence.

The template deploys at the next image build, like the other prompt templates. The env-precedence resolver task, generated into the roadmap by study `20260917-06`, is the named next feature; its P4 baseline-tests step is the entry point.

Watch-outs:

- The template is untested against an actual port beyond the session that produced it; a future port run is the field test.
- Prompt deployment needs an image rebuild; the repo copy is the source of truth until then.

**Conclusions from this iteration:** the two-port session showed a stable procedure: topology first, intent from handovers, supersession classified five ways, replay one commit per iteration with no scaffolding. The template records that procedure as the prompt surface's third operator-facing run template.
