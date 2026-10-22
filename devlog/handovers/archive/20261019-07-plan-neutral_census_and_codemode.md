---
date: 2026-10-19
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - the neutral census plan and codemode

## Objective

Record the neutral-census implementation plan as a design document, point a roadmap task at it, and enable codemode for the Jev probe matrix.

## Scope

A planning iteration for the reduced communication-surface filing. It produces the method and the enabling setting, and completes no M3.3.4 task.

Out of scope: running the census, which the new roadmap task owns.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The plan is a design document | `test -f devlog/discussions/20261019-design-settled-neutral_principle_census.md`; the design was removed in handover `20261020-06` | Agent [x] |
| A roadmap task points at it | read `devlog/roadmap.md`, the row `The neutral census and the communication-surface filing` | Agent [x] |
| Codemode is enabled | `jq -e '.defaultTools' $AGENT_HOME/agent/settings.json` returns `["+codemode"]` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] |

[CORRECTION -- 2026-10-19: the discussion path now carries its settled name after the status correction in handover 20261019-11.]

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The census runs four arms: baseline, blind open coding, Jev probes, adversarial | forced placement and a visible frame are the two anchoring defects; only the blind and adversarial arms can surface a category outside the frame | the design, `## Decision` |
| Jev is a probe and measurement instrument, not a classifier | a `choice` question requires the caller's `criteria`, so its labels are prescribed and it cannot induce a category | the design, `## Options Considered` |
| Code failure events, not prose lines | a principle earns its place by a real misreading; this is the delete test applied to principles | the design, `### The unit of analysis` |
| `codemode` is enabled in the config home | the `models.classify` path and the `codemode` tool are unreachable without it | `$AGENT_HOME/agent/settings.json` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The existing census forces every row to a side, so a row with no home dilutes the nearest principle. | method defect | the amended criterion is "placed, or reported as a residual with a reason" |
| The census worker saw the filed principles, so its frame was visible while it worked. | method defect | the blind arms hide the existing set |
| Codemode is off by default and no `codemode` tool is declared; no `TYPESAFE_API_KEY` is set. | blocker | enabled via `defaultTools`; the reachable Jev routes are `openrouter/typesafe/jev-1.13` and `opencode/jev-1.13-free` |
| The config change is outside the repository, so it does not ride this commit. | process | the setting takes effect at the next session start |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261019-design-settled-neutral_principle_census.md` | the four-arm census, the decision rule, Jev's role, the reduced filing, and the blocker; the design was removed in handover `20261020-06` |
| `devlog/roadmap.md` | new row `The neutral census and the communication-surface filing` under M3.3.4, pointing at the design |
| `$AGENT_HOME/agent/settings.json` | `"defaultTools": ["+codemode"]` |

[CORRECTION -- 2026-10-19: the discussion path now carries its settled name after the status correction in handover 20261019-11.]

[CORRECTION -- 2026-10-20: the neutral-census design named above was removed with its report in handover 20261020-06; the path no longer resolves and the design is not a live plan.]
