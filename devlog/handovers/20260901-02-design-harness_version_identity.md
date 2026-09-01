# Agent Handover

**Date:** 2026-09-01
**Milestone:** M2.6 - Session Persistence
**Type:** design
**Status:** Closed

## Objective

Settle the mechanism decision for harness software version identity across the
three independently-drifting surfaces (container image content, git worktree
checkout, host installed CLI), recorded as an ADR. The story
[`20260831-story-active-image_and_harness_version_identity.md`](../discussions/20260831-story-active-image_and_harness_version_identity.md)
fixes the requirements (`Resolved`); the design stub
[`20260831-design-active-image_and_harness_version_identity.md`](../discussions/20260831-design-active-image_and_harness_version_identity.md)
is to be refined and settled, then an ADR recorded.

Operator note: the design is to be **settled and closing this iteration, but the
ADR is not closed until implementation is done** — the ADR records the decision
and stays open until the impl landing. (As of this writing the nature of that
ADR-status discipline is being confirmed via the design grill.)

## Conflict / subsumption

- Three-drifting-surfaces framing (settled `20260831-09`) supersedes the
  two-sig / staleness / digest-deferral threads. This iteration selects the
  mechanism.
- Host-surface open questions from the two superseded docs feed the design:
  `story_harness_packaging_and_install_versioning.md` (self-contained snapshot
  vs semver) and `investigation_harness_sig_requirements.md` (change classes
  1/2/3 + self-contained-binary vs semver comparison).

## Scope (confirmed by operator)

- Settle the mechanism per surface in the design stub: **Decision + Consequences**,
  evaluated against the story's 8 Constraints; resolve whether image staleness
  survives as a distinct signal; settle whether `container-sig` keeps any role.
- **Initiate the ADR** under `docs/adr/` (name per adr_policy); ADR left open
  until implementation lands.
- Update the design stub Status to settled; reconcile the roadmap
  harness-version-identity entry.
- No implementation code this iteration (deferred to a follow-up `impl`).

## Deferred / out of scope

- **NO implementation this iteration** — no record schema changes, no removal of
  `container-sig` / `image_is_stale` / `record_image_stale` / `[IMAGE_STALE]`.
  The ADR stays open until that impl lands.
- Changelog detail for the eventual impl.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| AC1 | Design settled per surface, Decision + Consequences filled in the stub, evaluated against all 8 Constraints | **done (agent)** — ADR constraint evaluation added |
| AC2 | Freshness signal retirement resolved (drop list-time staleness; freshness not a list-time property) + source-fingerprint deferral | **done (agent)** |
| AC3 | ADR written recording the mechanism decision, incl. contract-compatibility as a deferred capability | **done (agent)** — `docs/adr/harness_versioning.md` |
| AC4 | Design stub Status -> settled; roadmap entry reconciled | **done (agent)** — stub settled; roadmap pending close |

## Completed

- Read the two superseded docs in scope (`story_harness_packaging_and_install_versioning.md`, `investigation_harness_sig_requirements.md`).
- Grounded the design space in live code (`container_sig.sh`, `session_inventory.sh`, `compose.sh`, `Makefile install:`, `docker-compose.yml` labels).
- Settled the mechanism via the grill (Q1-Q9); recorded decisions, findings, ACs in the handover.
- Wrote ADR `docs/adr/harness_versioning.md` (Status: settled = decision recorded; task stays open until impl).
- Finalized the design stub `20260831-design-active-image_and_harness_version_identity.md` to Status: settled with Decision + Consequences.
- Applied the partial-supersede protocol edit to `20260722-session_identity_and_container_markers.md` (image-marking claim superseded).
- Reconciled roadmap: updated the version-identity entry (DESIGN SETTLED, impl NEXT) + added three promoted tasks (interface-contract compat, dry-run overhaul, ADR-policy revision).

## Decisions

| Decision | Status |
|---|---|
| Design settled + closed this iteration; ADR open until impl | confirmed (operator) |
| Standpoint: avoid semver, but not at the cost of missing a real constraint; semver acceptable if pushed | confirmed (operator) |
| **Image surface = docker digest** (`<repo>@sha256:`) | confirmed (operator) — accepted "for now" |
| **Worktree surface = plain `$REPO_ROOT` git HEAD SHA** (no tags, no `git describe`) | confirmed (operator) |
| **Host surface = symlink install, no separate version.** `make install` becomes a symlink (self-locating dispatcher, no copy, no `sed`-bake) — the installed CLI *is* the worktree file, so the dispatcher-vs-scripts leak disappears by construction and there is nothing to version independently. Rollback = `git -C $REPO_ROOT checkout <sha>` (same as worktree; the old separate-artifact rollback is gone — accepted) | confirmed (operator) |
| **Semver deferred to the full-packaging milestone** (`~/.agent-sandbox/<version>/` self-contained snapshot); the host-version decision reopens there, flagged as forward-looking note, not decided now | confirmed (operator) |
| Host-surface drift signal is **moot by construction** under symlink (no dispatcher-vs-scripts drift possible) | confirmed (operator) |
| **Image freshness signal dropped.** `[IMAGE_STALE]` / `record_image_stale` / `image_is_stale` list-time usage retired (kills the 2×N docker-inspect cost). A fresh digest is only knowable post-build, so "newer image available" is not a list-time property; the recorded digest is exact identity. No staleness column | confirmed (operator) |
| **Source fingerprint deferred to the packaged-install milestone** (challenges enumerated: manual file list; host/container differing file sets; doc-edit false positives via `host-head-sha`) | confirmed (operator) |
| **Interface-contract compatibility = DISTINCT design thread** (deferred capability). The real need behind "freshness" is two co-resident harness copies speaking the same shape. Promoted to roadmap at iteration end; ADR/handover record it as a deferred capability | confirmed (operator) |
| **Interface-contract naming = "interface-contract compatibility"**; input includes the harness-worktree version, over a narrow contract-version of the subsets the container consumes, not a full-repo HEAD | confirmed (operator) |
| **Record schema (Q7):** add `agent-sandbox.agent-image-digest` + `agent-sandbox.sandbox-image-digest` (proper parallel label convention) as the image-version fields; **NO `harness-head-sha` record field** (image identity fully carried by digest; harness-source version over-broad, absorbed into deferred interface-contract thread); retire `image-sig` from new records; **NO back-compat** (digest-less record at resume = refuse loudly) | confirmed (operator) |
| **ADR scope (Q9): SINGLE ADR** carrying the full settled mechanism set, with a precise `Supersedes` (narrow: image-marking claim of `20260722-session_identity_and_container_markers`) + a bounded `Deferred` section naming the three deferred threads (interface-contract compat, source fingerprint, semver at full packaging), each marked deferred-not-decided. Status **open/pending-impl** (per earlier instruction); later impl iteration closes it | confirmed (operator) |
| **ADR-policy revision is NON-BLOCKING + NON-URGENT:** write the version-identity ADR now under current policy (precise Supersedes section); the policy revision is a separate roadmap/back-log task, promoted at iteration end, not gating this ADR | confirmed (operator) |
| **Dry-run correct-container gate = structural verification (phase-3 records) + digest roundtrip** (running image's repo-digest == just-built-from-current-source digest), replacing `dry_run_image_verify`'s `container_sig` recompute | confirmed (operator) — structural + digest roundtrip right |
| **container-sig Q8 (reframed, operator-directed):** 1) **image digest subsumes container-sig** for its intended use — image version identity = digest. 2) **container-sig persists, narrowly, as the existing leaky implementation of the deferred interface-contract**: after symlink install, host-side computes `container-sig`, container records it; combined they give a **binary exact-match check** of contract-interface versions (leaky — exact-match only, no back-compat/range; accepted; warns on mismatch, = current behavior). 3) **container-sig is scoped for deletion once a redesigned contract-interface implementation lands**. NOT retired now | confirmed (operator) |
| **Dry-run always builds/runs current source — no staleness warning; a stale container after a current build is an ERROR.** `--fast`/headless (skip/cached build) is DEFERRED to the dry-run refactor's scope, not this design — introduced when the restrictions are clearer. For now dry-run is designed to always work with the freshest container | confirmed (operator) |
| **Digest-less image special case REMOVED — hard error** (not `unknown→FAIL`). The no-sig case was a container-sig-migration hangover; all images must bear a digest/sig. Add a TEMPORARY double-check while moving to digest, ripped out once migration done | confirmed (operator) |
| **Dry-run semantics overhaul is important to complete** (Finding; see Findings) | confirmed (operator) |

## Findings

- **ADR policy revision (NEW, operator finding):** the current ADR practice is inadequate — subsumed-design ADRs remain in `docs/adr/` alongside their superseding ones, which is confusing and unclean to maintain (the `20260722` session-identity+container-markers ADR now partially-subsumed twice — once by `20260831` derivation, once (proposed) by the version-identity image-marking claim — yet still sits as `settled`). Points to a revision of `docs/operations/adr_policy.md` on how subsumed ADRs are marked/handled (supersede tag on the old vs deprecate-and-remove, freshness of `Status: settled` after partial supersession). Promotes a **roadmap task for the ADR-policy revision** at iteration end. **Non-blocking/non-urgent** — the version-identity ADR is written now under current policy.

- **Dry-run semantics overhaul (NEW, operator-directed):** dry-run's freshness semantics were ported from `start` unchanged in the `20260828` refactor, but they must be a distinct animal: dry-run is the operator's e2e/diagnostic for **current** source, so it must **always build/run current source** — a stale container even after a fresh build is an **error**. `[IMAGE_STALE]` was a stopgap for un-refactored dry-run, not a design. `dry_run --fast` (cached/skip build) is a candidate that may legitimately use an old image and would warrant its own staleness warning — mechanism undecided. **Also test `resume` semantics**, since dry-run controls its container fully. See the digest-roundtrip decision in the Decisions table.

- **Interface-contract compatibility (NEW deferred thread, operator-directed):** the real need behind the retired freshness signal is that two co-resident harness copies (host checkout driving a session vs the wiring baked into the image) must speak the same *shape*. Historical failures in this band: bind-mount folder shape, `SANDBOX_DIR` format, onboard command shape, host/container command semantics — i.e. the change-class-1/2/3 (command shape / dispatch / lib) High-severity band from `investigation_harness_sig_requirements.md`. Two contract points the host-vs-container framing misses: (1) **intra-session container↔container drift** (agent vs sandbox images buildable independently via `--targets=agent|sandbox`; mount-delivery wiring landing in one while the other is older); (2) **session-record schema as a resume-breaking contract** (`.compose/<session-id>.yml` + in-worktree `SESSION_STATE` written by host at start, read by both host-resume/list and container-entrypoint; sharper under exact-resume-via-digest). Livable mechanism is an explicit **interface/contract version** declared+compared by each co-resident copy (bumped only when the cross-boundary contract changes; immune to doc edits; no overlapping-file-set dependency) — not a source fingerprint. Deferred capability; promoted to roadmap at iteration end.

- `container_sig()` signs a fixed subset (`_sandbox_sig_sources` / `_agent_sig_sources`); misses base image / runtime / dependency versions.
- Record (`x-session-labels` in `src/build/docker-compose.yml`) carries `host-head-sha`, `host-branch`, `session-ts`, `session-id`, `image-sig` (agent's container-sig copied in by `compose.sh`); sandbox has no record sig.
- `record_image_stale` (`session_inventory.sh`) is the 2×N docker-inspect cost behind `resume LIST=1`.
- `make install` sed-substitutes the repo path into a thin dispatcher (`Makefile install:`); no version surface, execs live checkout.
- **No ADR exists for `container-sig`** — its design lives only in discussion `design_session_identity_hash_based.md`; reframing it does not subsume an ADR.

## What's Next

- **Follow-up `impl` iteration** (not this one) implements the mechanism and closes
  the ADR/task: add `*-image-digest` record labels, symlink install, dry-run
  digest roundtrip, retire list-time staleness, temporary container-sig transition
  double-check then removal.
- **Roadmap promotion (at close):** separate `- [ ]` entries for (1)
  interface-contract compatibility, (2) dry-run semantics overhaul, (3) ADR-policy
  revision — plus the version-identity task (open until impl).

## Post-close correction

*(none yet)*