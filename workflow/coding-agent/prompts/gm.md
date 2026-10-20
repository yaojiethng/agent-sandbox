---
description: Check-in. Survey the project state and present the work inventory with options to choose from; add "be thorough", "deep dive" or "full audit" to run the record auditors as well.
argument-hint: "[intent - optional, e.g. back after a break, easy start] [thoroughness - optional: be thorough | deep dive | full audit]"
---

> $@

## Project conventions

Read each convention below at `.agents/skills/<name>/SKILL.md`. If one is absent or holds the seeded stub, state the failure and hand control to the agent, which decides with the steering it has loaded; the workflow prescribes no fallback.

- `task-list`, `work-log`

gm is a check-in. Run it from the [`check-in`](/opt/workflow/agent/modules/coding-agent/skills/check-in/SKILL.md) skill, given from the repository root. That skill owns the check-in rule, the arguments, the survey, the inventory and its axes, the record-report contract and the commit.

The rule on what a check-in may change is stated in the skill, and the iteration policy at `docs/policies/iteration_policy.md` holds the same rule from the iteration side. Read it there rather than here.
