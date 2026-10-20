---
date: 2026-10-19
milestone: M3.6.3 - Route and decide
type: Documentation
status: Closed
---

# Handover - the free-tier quota in the dispatch skill

## Objective

Record the free tier's measured request quota in the `opencode-dispatch` skill, at the point of use, and note in the roadmap that the skill owns the fact until the model catalog carries a rate-limits field.

## Scope

A small documentation iteration. It changes one clause in two copies of one skill and appends one sentence to a roadmap row.

Out of scope: the catalog rate-limits field, and the requests-per-completed-task metric.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both skill copies carry the quota | `grep -c "200 requests/day" src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md $AGENT_HOME/agent/skills/opencode-dispatch/SKILL.md` returns 1 for each | Agent [x] |
| The copies agree | `diff` of the two `SKILL.md` files | Agent [x] |
| The roadmap names the owner | read `devlog/roadmap.md`, the row `The model-catalog track` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh`, `bash scripts/check_handover_format.sh`, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The skill is the point-of-use home | a reader dispatching a free-tier worker is the reader who needs the number | the skill, `## The fallback` |
| No standalone constrained-resources document | the fact already has two homes, and a third would be the duplication the milestone is removing | this record |
| The roadmap names the skill as the current owner | the catalog row plans the rate-limits field, so the handover point needs to be visible | `devlog/roadmap.md` |
| One clause, not a section | the fact is four values; a section would outweigh it | the skill diff |

## Decisions pending

| Decision | What resolves it | Whose call |
|---|---|---|
| Whether to file the requests-per-completed-task metric | the M3.6 outcome instrument already measures cost and outcome per request, so the gap is small | operator |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The 200/day figure is the console's UI copy (`i18n/en.ts:400`), while the enforced value is the deployed `ZEN_LIMITS` secret's `dailyRequests`. The two can drift. | measurement | the skill states the quota as the console states it; the enforced value is unreadable from the repo |
| A fresh IP gets a 2x grace. The limiter throws at `dailyCount >= dailyLimit * 2` while `lifetimeCount < dailyLimit * 7`, then at `dailyCount >= dailyLimit`. | measurement | a new IP can reach 400/day before settling to 200 |
| All default free models share one daily bucket, because the daily key carries the model id only when the model sets its own `rateLimit`. | measurement | one pool covers the free tier, so a Jev probe competes with a coder run |
| `403 FreeTierError` is a client check by design; quota exhaustion is `FreeUsageLimitError`; `429 GoUsageLimitError` is the paid opencode-go tier. | measurement | the three are different resources and route differently |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/opencode-dispatch/SKILL.md` | the quota clause in `## The fallback` carries the number, the shared pool, and the grace |
| `$AGENT_HOME/agent/skills/opencode-dispatch/SKILL.md` | the same clause, so the installed copy does not diverge |
| `devlog/roadmap.md` | the `The model-catalog track` row names the skill as the current owner and the measured source |
