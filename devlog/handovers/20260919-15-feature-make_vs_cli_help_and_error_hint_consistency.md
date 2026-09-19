# 20260919-15-feature-make_vs_cli_help_and_error_hint_consistency

- **Handover:** 20260919-15
- **Type:** Feature
- **Milestone:** M2.6 - Session Persistence
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Closes the intent of a stale bug report: a user invoking `make <target>` without
a required Make variable gets an error or help that speaks only in the direct
CLI idiom (`agent-sandbox <sub> --flag`), so the make-style remedy is invisible.
The original report's literal repro (passing `--name/--project/--sandbox` through
`make start`) is stale -- the current template resolves identity from `.env` --
but the underlying inconsistency (make vs direct-CLI help/error surfaces) persists
across the make-reachable command set. This iteration adds the make-style
invocation to every make-reachable `usage()` block whose direct-CLI-only surface
would otherwise mislead a make user.

## Files in scope

| File | Change | Status |
|---|---|---|
| `scripts/build.sh` | add `or, from a sandbox Makefile: make build [...]` to usage() | done |
| `scripts/prune.sh` | add `or, from a sandbox Makefile: make prune [...]` to usage() | done |
| `scripts/onboard.sh` | add `or, from a Makefile: make onboard [...] / make refresh [...]` to usage() | done |
| `scripts/workflows/draft.sh` | add `or, from a sandbox Makefile: make draft [...]` to usage() | done |
| `scripts/workflows/confirm.sh` | add `or, from a sandbox Makefile: make confirm [...]` to usage() | done |
| `scripts/workflows/apply.sh` | add `or, from a sandbox Makefile: make apply [...]` to usage() | done |
| `src/libs/package_branch.sh` | add `or, from a sandbox Makefile: make package-branch [...]` to usage() | done |
| `tests/test_dispatch.sh` | add data-driven regression: each make-reachable leaf `--help` shows the make form | done |
| `devlog/AGENT_FEEDBACK.md` | record finding: feature vs workflow classification is ambiguous | done |

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Every make-reachable command's `usage()` presents the make-style invocation alongside the direct-CLI form | accepted |
| AC2 | The make form appears in each command's `--help` output (verified per leaf) | accepted |
| AC3 | A regression test pins the make form for all 7 surfaces | accepted |
| AC4 | Full suite green (915/915) | accepted |
| AC5 | No new lint warnings introduced (baseline already red at 6; unchanged) | accepted |

## Notes

- `start_agent.sh` (the report's exact case) already carried the make-specific
  hint and is treated as the reference standard; unchanged.
- `stop.sh` and `reject.sh` were not in scope: their `usage()` surfaces are
  trivial or already make-consistent, and the report's intent concerns
  required-variable diagnostics.
- This type is Feature per operator ruling: workflow is reserved for policy and
  prompt changes; user-facing code/help-text behavior is a feature. The
  classification ambiguity is recorded in AGENT_FEEDBACK 2026-09-19 for a
  future git_policy type-description sharpening.

## Agent-experience finding (open, next-iteration item)

Task-type classification between `feature` and `workflow` is ambiguous at
classification time; recorded in `devlog/AGENT_FEEDBACK.md` (session
20260919-15). Candidate durable fix: sharpen `git_policy.md` type descriptions
to state the boundary explicitly.
