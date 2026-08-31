# Agent Handover

**Date:** 2026-08-31
**Milestone:** M2.6 - Session Persistence
**Type:** docs
**Status:** Closed

## Objective

Reframe harness versioning as ONE problem with three independently-drifting
surfaces — container image content, git worktree checkout, host installed CLI —
none of which carries a serializable, increasing version. Produce the canonical
story (COMPLETE: no open questions), a design stub (mechanism decision staged
for next session), and reconcile the roadmap.

## Conflict / subsumption

- The three-drifting-surfaces framing (operator) supersedes the earlier
  "lock the stale-image O(n) docker inspects" framing. The `make resume LIST=1`
  slowness is a **symptom**, not the problem: it is the cost of not storing a
  version in the record. No memoization stopgap (operator: design only).
- Design B subsumes the deferred "image-digest tracking" (`20260831-02`): the
  standalone digest-in-list deferral is retired. Mechanism choice (docker
  digest `<repo>@sha256:` vs our `container-sig` tag vs semver) is staged for
  next session. Lean/wonk noted in the design stub: digest for docker-verifiable
  exactness; a source hash retained only if staleness survives (still unsettled).

## Scope (confirmed by operator)

- **Story** `20260831-story-active-image_and_harness_version_identity.md` —
  the main artifact; COMPLETE (no open questions, no requirement ambiguities);
  frames the three surfaces, marks prior solutions inadequate, subsumes the
  two-sig model + host-packaging + harness-sig; resolution points to the design.
- **Design stub** `20260831-design-active-image_and_harness_version_identity.md`
  — required sections, options pre-seeded, Decision + Consequences pending next
  session; open questions OK.
- **Roadmap reconciliation** — new open task (harness version identity; design
  next session) + SUPERSEDED tag on the image-staleness entry + in-place
  compaction of the M2.6 closed mega-entries (final-state summaries).
- Marking the subsumed docs superseded (not deleted — policy forbids deleting
  the reasoning record): story_session_identity_and_harness_versioning,
  story_harness_packaging_and_install_versioning, investigation_harness_sig.
- Bug E: resolved by not carrying forward (operator confirmed).

## Deferred / out of scope

- NO memoization / perf stopgap (operator: design only).
- NO impl / design-selection this session (mechanism settled next session + ADR).
- NO changelog extraction for M2.6 (in-place compaction only, per operator).

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Story complete — no open questions, no requirement ambiguities | **done (agent)** — story `Resolved` status, mechanism staged to design |
| AC2 | Design stub created + linked, options pre-seeded, Decision/Consequences pending | **done (agent)** |
| AC3 | Roadmap reconciled — new task + supersede tags + in-place compaction | **done (agent)** — 6 open items retained, open detail preserved |
| AC4 | Subsumed docs marked superseded (not deleted), redirects + supersede tags | **done (agent)** |
| AC5 | Bug E resolved (not carried forward) | **done (agent)** |

## Completed

- `devlog/discussions/20260831-story-active-image_and_harness_version_identity.md` — created (full story).
- `devlog/discussions/20260831-design-active-image_and_harness_version_identity.md` — created (stub).
- `devlog/roadmap.md` — new harness-version-identity open task; SUPERSEDED note on image-staleness entry; compacted closed M2.6 mega-entries (build-progress, prune-redesign, terminology-sweep, start/resume, start/serve, prune-label-reliability, set-e, container_sig guard, onboard-refresh, mount-delivery, .run-identity, registry-prune, compose-template, resolve-design-questions).
- Subsumed docs handled: `story_session_identity_and_harness_versioning.md` **deleted** (operator override), `story_harness_packaging_and_install_versioning.md` + `investigation_harness_sig_requirements.md` tagged `[SUPERSEDED in 20260831 ...]` + redirects.
- Handover converted to `docs` type; Bug E resolved.

## Decisions

| Decision | Status |
|---|---|
| Story is the main artifact; design is a stub this session (settle + ADR next session) | CONFIRMED (operator) |
| In-place roadmap compaction, no changelog extraction; keep M2.6.1-2.6.4 as one-liners | CONFIRMED (operator) |
| Subsumed docs marked superseded, NOT deleted (policy) | CONFIRMED (agent recommendation) |
| Mechanism (digest vs content-hash vs semver) left to the design doc for next session | CONFIRMED (operator) |
| Story disposition: `Resolved` (framing complete; mechanism staged out) | agent |

## Findings

- **Finding (policy concern, operator): the "closed story is never deleted" rule (story_policy + discussion_policy) is over-restrictive.** Operator flagged it as "whack" and wants it changed soon. The rule makes low-value reasoning records permanent even when their content is fully absorbed by an authoritative ADR, bloating the discussion tree. Proposed future change (not this iteration): allow archived/superseded docs whose decision record is captured in an ADR to be deleted, not merely archived. **Operator-directed this iteration (act rollback / explicit): the two-sig story was hard-deleted** (`story_session_identity_and_harness_versioning.md`) — an explicit operator override of the delete-prohibition policy; its content lives in the session-identity ADR. The two docs with still-live deferred content stay as `superseded`.

- Confirmed `make install` produces a dispatcher that `exec`s the live checkout
  (`Makefile` sed substitutions + `scripts/agent-sandbox.sh`): the host CLI has
  **no version surface** and silently tracks the checkout after any `git pull`.
- `container_sig()` hashes only a fixed harness source subset per layer and
  misses base image / runtime / dependency versions — the leak the story names.
- `image-sig` is the agent image's `container-sig` label copied into the record;
  the sandbox image has no record sig. Confirmed the `[IMAGE_STALE]` markers and
  `record_image_stale` docker inspects are downstream of the missing version.

## What's Next

Next session: settle the design mechanism (docker digest vs content-hash vs
semver, and whether staleness survives) in `20260831-design-active-*`, write the
ADR, then a follow-up impl. Standing: SERVE mode integration (roadmap);
dry-run probe-check harness (roadmap). 

## Post-close correction

- **Roadmap item 153 (dry-run probe-check unit-test harness) corrected to
  complete `20260828-03`** — was stale `- [ ]` though its handover was already
  Closed (bookkeeping miss). Fixed to `- [x]` this iteration.
- **Roadmap item (make resume volume reuse, Bug D) corrected to complete
  `20260828-04`** — was stale `- [ ]` though the handover is Closed (verdict:
  resume preserves the volume; 11 regression tests; no production bug). Fixed
  to `- [x]` this iteration.
- **Campaign-findings basket compacted** to a single `- [x]` summary (all 7
  sub-items were complete). Open items now 3: SERVE, harness version identity,
  mount-worktree history.