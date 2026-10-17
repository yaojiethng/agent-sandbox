---
date: 2026-10-17
milestone: Unrouted - the dispatch CLI's failure channel
type: Implementation
status: Closed
---

# Handover - The dispatch CLI's failure channel and the model fallback

## Objective

Make a refused dispatch observable in about a second and give the role's next model a turn, so a spent free tier costs seconds and never mixes two workers' edits.

## Scope

No roadmap row names this work, which is why the milestone line reads `Unrouted`. It continues the dispatch seam of M3.6.1 and serves M3.6.2's outcome instrument, but the rows there describe measurement, not this defect. The work is one seam flag set, one runner state machine, and their tests. Out of scope: the free tier's quota policy, the upstream CLI's missing exit, and the pin sweep.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The seam puts the CLI's error channel on stderr | `bash tests/test_dispatch.sh`, the built command carries `--print-logs --log-level ERROR` | Agent [x] |
| The title model's own failure is not read as the run's failure | `bash tests/test_opencode_dispatch.sh`, `test_reports_every_failed_candidate_at_the_end` reports `quota`, not `capability` | Agent [x] |
| A refused attempt advances to the next model | `bash tests/test_opencode_dispatch.sh`, `test_falls_back_to_the_next_candidate` | Agent [x] |
| An attempt that adds changes stops instead of advancing | `bash tests/test_opencode_dispatch.sh`, `test_a_changed_failure_does_not_fall_back` | Agent [x] |
| The caller's own uncommitted work does not block the advance | `bash tests/test_opencode_dispatch.sh`, `test_the_callers_own_edits_do_not_block_the_fallback` | Agent [x] |
| Every failed candidate and its class is reported at the end | `bash tests/test_opencode_dispatch.sh`, `test_reports_every_failed_candidate_at_the_end` | Agent [x] |
| A refusal is detected in seconds, not on a timeout | `bash tests/test_opencode_dispatch.sh`, `test_a_refused_model_is_stopped_early` | Agent [x] |
| The live path refuses, falls back and reports in one run | a dispatch against the spent free tier: attempt 1 `quota` at 3s, attempt 2 on `opencode-go/deepseek-v4.1-flash`, `failures: 1`, exit 0 at 7s | Agent [x] |
| The lint and ShellCheck gates pass | `bash scripts/lint.sh`, `bash scripts/check_shell.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The role's line carries an ordered model list, and the runner advances on a failed attempt | the seam already derives the backend from the provider prefix, so no invoke-method field is needed; the list alone was inert because the seam keeps only the first entry | `model-recommendations.md`, the skill's `## The fallback` |
| Advance only when the attempt added no change of its own | a second model over a first model's half-finished edits produces a change set no one can attribute | `dispatch.sh`, the before-and-after change set |
| Report the failures even when a later candidate succeeds | the run's cost and the reason for it are part of the result, not a diagnostic to discard | `dispatch.sh`, the closing `failures:` block |
| Keep a silence backstop, lowered to 15 seconds | the refused CLI prints its error only with the logging flags, and an attempt that prints nothing at all is still indistinguishable from a slow start | `dispatch.sh`, `OPENCODE_DISPATCH_STALL` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| Should the runner keep a per-attempt timeout equal to the whole run budget, or a shorter one per attempt with a longer final attempt? | how long a genuinely slow model may run before the fallback takes over | one limit for every attempt; a shorter non-final limit; no limit but the stall backstop |

## Findings

| Finding | Type | Impact | Destination |
|---|---|---|---|
| The pinned CLI does not exit after a failed prompt: `run.ts` subscribes to `client.event.subscribe()` in the non-interactive path and returns on the error without closing it, so `process.exitCode = 1` never terminates the process | defect, upstream | every refused dispatch hangs, and a caller that waits for exit waits indefinitely; this is the root cause of the 45-second and 1788-second waits measured earlier | report upstream; the runner's refusal detection is the local remedy |
| The CLI discards the response's `retry-after` and the response type, so the only class signal is the provider's message text | defect, upstream | a caller cannot know when the quota resets, which the server does send | report upstream; the runner classifies on the text and names the class |
| The free tier is a per-IP daily quota, reset at UTC midnight (`getRetryAfterDay` in the console's `ipRateLimiter.ts`), which is why both free models fail together | fact, measured in source | a spent tier is unavailable for the rest of the UTC day, not for a minute | recorded here; it revises the earlier note that the reset was unknown |
| `--format json` emits no event for a failed prompt, because the error event is emitted only when the session loop completes | defect, upstream | the structured channel the design assumed does not exist for the failure path | the runner reads the ERROR log instead; recorded here |

## Completed

| File | Change |
|---|---|
| `src/libs/dispatch.sh` | the opencode command carries `--print-logs --log-level ERROR` and a fixed `--title`, so the error channel is on stderr and the title model does not run |
| `src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/dispatch.sh` | ordered candidates from the role line, per-attempt change-set comparison, refusal classification, end-of-run failure report, silence backstop at 15 seconds, and the flags inserted when the baked seam predates them |
| `src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md` | states the fallback rule and the measured CLI behaviour it compensates for |
| `tests/test_dispatch.sh` | the built command's flags and title, on both the role path and the override path |
| `tests/test_opencode_dispatch.sh` | the fallback, the changed-attempt stop, the caller's-own-edits case, the class report, and the silent-attempt case |
