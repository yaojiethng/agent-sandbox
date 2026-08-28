# Agent Handover

**Date:** 2026-08-23
**Milestone:** M2.6 - Session Persistence
**Type:** Implementation
**Status:** Closed

## Objective

Resolve the four naming/header contradiction one-liners queued on the roadmap (bullet "Naming/header contradictions"). Each is expected to be a small documentation/header correction; if investigation shows any item actually needs a behavior change, it is split out and flagged rather than fixed here.

## Items

1. **`src/build/image.sh` provider-lowercase claim** -- header claims provider is lowercased; verify against `agent_image_name` and correct whichever side is wrong.
2. **Compose template self-referential `{{VAR}}` docs** -- template documents its own placeholders in a way that pollutes substitution checks; rephrase so documented examples do not match the substitution pattern.
3. **`template_version` unknown-version ambiguity** -- returns empty string with rc0 when the marker is absent; document the contract at the definition and call sites (or flag if a behavior change looks warranted).
4. **`apply.sh` header-vs-guard** -- header says "Sourced by agent-sandbox.sh -- not executed standalone" yet carries a `main()` guard and IS exec'd by the dispatcher; fix the header to describe the dual-use reality.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| AC1 | All four items resolved or explicitly split out with rationale | per-item notes below | accepted |
| AC2 | No stale references remain (grep sweep across scripts/ src/ tests/ docs/) | sweep clean; remaining `{{VAR}}` mentions are in non-template files where they cannot pollute output | accepted |
| AC3 | Suite green and deterministic x2 | 634 tests / 39 files / 0 failed x2 | accepted |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The "not executed standalone" claim was false in ALL FOUR workflow scripts (apply, draft, confirm, reject) -- the dispatcher execs each; sourcing happens only in test suites. Fixed as one class per propagation discipline | scope extension | All four headers corrected; pure lib `draft_state.sh` keeps its (true) sourced-only header |
| The generic `{{VAR}}` mention survived substitution into generated compose files because it matches no specific sed rule; specific placeholders in template comments substitute fine. Only docker-compose.yml line 9 needed rephrasing; the test's comment filter stays as harmless defense-in-depth | root cause | Single-line fix |
| `template_version`'s empty-return contract was already documented in the body comment (-08); added it to the function header and the .env-refresh call site so readers at both levels see it. No behavior change warranted: nothing downstream branches on the version value | scope note | Doc-only |

## Completed

| File | Change |
|---|---|
| [`src/build/image.sh`](../../src/build/image.sh) | `agent_image_name` return contract corrected: project lowercased, provider verbatim (matches pinned test) |
| [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) | Generic `{{VAR}}` doc mention rephrased so it no longer survives into generated files |
| [`scripts/onboard.sh`](../../scripts/onboard.sh) | `template_version` header + `.env` refresh call site document empty-means-unknown-version contract |
| [`scripts/workflows/apply.sh`](../../scripts/workflows/apply.sh), [`draft.sh`](../../scripts/workflows/draft.sh), [`confirm.sh`](../../scripts/workflows/confirm.sh), [`reject.sh`](../../scripts/workflows/reject.sh) | Headers now describe dual-use reality: exec'd by dispatch, sourceable for tests, main() guard-only |

## Deferred items

_(none)_
