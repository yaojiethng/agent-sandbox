# Handover 20260901-05 — docs layer-separation and correspondence ADRs

**Milestone:** M2.6 - Session Persistence
**Type:** docs
**Status:** Closed
**Date:** 2026-09-01

## Objective

Write the two new-ADR candidates deferred from `20260901-04`, distilling
their rationale out of the concept docs that currently host it:

1. **Layer separation** — reasoning/capability layers are separate because
   they vary independently. Rationale today is split between
   `docs/concepts/two_layer_model.md` ("Why the Layers Are Separate") and the
   conclusion of `devlog/discussions/investigation_mcp_server.md` (the fused
   single-container model as rejected alternative).
2. **Correspondence mechanism** — git is never the correspondence mechanism
   between sandbox and host; the git-agnostic diff file is. Rationale today
   sits in `docs/concepts/sandbox_host_correspondence_model.md` ("Core
   Principle") and `devlog/discussions/design_apply_draft_workflow.md`.

Concept docs keep the model (the *what*) and link the ADRs as further
reading; the rejected-alternative reasoning moves into the ADR entries.

## Scope

- Two living ADR files in `docs/adr/` (names agent-recommends /
  operator-decides), per `adr_policy.md` format.
- Slim the rationale passages in the two concept docs into links.
- Register both ADRs in `project_index.md`; update roadmap (mark the
  deferred-item follow-up).
- Cross-link: correspondence ADR ↔ `sandbox_delivery_model.md` (worktree
  rejection is the same principle applied to git mediation).

Out of scope: the interface-contract thread (roadmap 159), version-identity
impl (roadmap 158), pre-existing broken links (candidate `chore`).

## Carried forward

- ADR naming: agent recommends, operator decides.
- `two_layer_model.md` is indexed "Do not edit; reference only" — the slim
  edit is a rationale-move consistent with `20260901-04` treatment; flag if
  operator prefers otherwise.

## Acceptance Criteria

- AC1: A layer-separation ADR exists (decision, rationale, fused model as
  rejected alternative with why-rejected).
  **done (agent)** — `agent_sandbox_two_container_separation.md` (fused
  single-container harness as dated historical entry with why-rejected).
- AC2: A correspondence-mechanism ADR exists (decision, rationale, git-based
  correspondence as rejected alternative).
  **done (agent)** — `container_host_correspondence_mechanism.md`.
- AC3: Concept docs carry model + link only; no rationale duplication.
  **done (agent)** — `two_layer_model.md` rationale paragraph replaced by
  further-reading link; correspondence doc Core Principle kept as model
  statement + link.
- AC4: Both ADRs registered in `project_index.md`; roadmap updated; handover
  current.
  **done (agent)** — index rows added. Roadmap needed no change: this
  iteration originated from handover `20260901-04` Deferred items, not a
  roadmap task.
- AC5: Link check green; no stale references.
  **done (agent)** — see verification output in session; stale-ref count
  unchanged at the 4 known non-link mentions (D5, prior iteration).

## Hot files

- `docs/adr/` (two new files)
- `docs/concepts/two_layer_model.md`, `docs/concepts/sandbox_host_correspondence_model.md`
- `docs/development/project_index.md`, `devlog/roadmap.md`

## Decisions

| # | Decision | Status |
|---|---|---|
| D1 | Iteration type `docs` | confirmed (operator) |
| D2 | ADR file names: `agent_sandbox_two_container_separation.md`, `container_host_correspondence_mechanism.md` | confirmed (operator) |
| D3 | `two_layer_model.md` may be slimmed (rationale → ADR link), consistent with `20260901-04` treatment | confirmed (operator) |
| D4 | Entry dates: git history is squashed to a baseline, so the original settlement dates are unrecoverable; entries are dated 2026-09-01 (the recording date) and name the originating milestone/investigation in the entry text | confirmed (agent) |

## Completed

- Wrote `docs/adr/agent_sandbox_two_container_separation.md` (current entry
  + fused-model historical entry with why-rejected; cross-links to delivery
  model and session identifier).
- Wrote `docs/adr/container_host_correspondence_mechanism.md` (single current
  entry; git-mediated correspondence and stateful apply tracking as rejected
  alternatives; cross-links to delivery model and diff packaging).
- Slimmed `two_layer_model.md` "Why the Layers Are Separate" to model
  statement + further-reading link; added further-reading link to
  `sandbox_host_correspondence_model.md` Core Principle.
- Registered both ADRs in `project_index.md` ADR section.
- Verified: link check green; entry-field structure check ok; stale-ref
  count unchanged.

## Findings

- Original settlement dates are unrecoverable (git history squashed to a
  baseline); entries are dated with the recording date (2026-09-01) and name
  the originating milestone/investigation in the entry text (D4).

## Findings

- Both rationales already exist in prose; no new design decisions needed —
  this is distillation, not settlement.

## Deferred items

(none yet)

## What's Next

- Closed after operator pre-close review; single `docs:` delivery commit.
