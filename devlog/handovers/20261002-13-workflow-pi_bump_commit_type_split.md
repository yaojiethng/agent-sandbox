# Handover - The pi-bump commit type split by what a slice touches

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

[CORRECTION -- 2026-10-02: The record carried no Date, Milestone, Type or Status field and stated its status as `Complete.` under a `## Status` heading. The metadata block above carries the values the record already stated.]

## Objective

Make the `pi-bump` skill state which commit type each kind of bump slice takes, instead of one type covering every case.

## Why

The skill's step 7 required a single `workflow: bump pi to <NEW> and codify the bump procedure` commit wrapping the configuration changes and the new skill together, on the reasoning that a skill file is governance and so the whole slice is a workflow commit. Applying that rule to a pin-only bump gave the wrong instruction: the slice touched `base.dockerfile` and the `lastChangelogVersion` field only, changed no governance, and was committed as `chore:` against the skill's own instruction. The rule also bundled extension changes into the bump commit, which hides a governance change inside a pin move.

## Decisions

- A pin-only slice is one `chore:` commit, `chore: bump pi to <NEW>`, with no handover.
- Extension changes are their own `workflow:` commit carrying their own handover, never folded into the bump commit.
- A skill-text change under `src/reasoning/agent/` is `workflow:`, its own commit with its own iteration and handover.
- A bump needing extensions and a skill edit is three commits: `chore:` for the pin, `workflow:` for the extensions, `workflow:` for the skill.

## Changes

| File | Change |
|---|---|
| `src/reasoning/agent/skills/pi-bump/SKILL.md` | step 7 rewritten as three named cases, with the incident recorded |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | Step 7 names three cases and does not commit a bump as one commit | read step 7 | pass |
| 2 | The pin-only case states `chore:` and states that no handover rides it | read step 7 | pass |
| 3 | The extension case states `workflow:` and its own handover | read step 7 | pass |
| 4 | The three-commit shape is stated explicitly | read step 7 | pass |
| 5 | Lint clean; suite green | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | pass |

## Findings

- The bump that prompted this change is `98cb9cb`. The pin-only rule now matches it.
- The skill previously could not express a bump that needs no skill change, which is the common case.

## Deferred

- Whether the pi-bump procedure belongs in a `workflow/coding-agent/` prompt rather than an agent skill. Deferred to M3.2.3, which owns the sole-prompt tidy for the `-work` family.
