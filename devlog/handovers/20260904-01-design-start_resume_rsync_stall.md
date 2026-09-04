# Handover 20260904-01 — design start/resume rsync stall: seed transport redesign

**Milestone:** M2.6 - Session Persistence
**Type:** design
**Status:** Closed
**Date:** 2026-09-04
**Session base:** container history replayed from session export `20260902-182452-1484fd` (base-sync `42fc502` + 9 patches; single-commit variant `fe90a4c` also produced). Container later re-seeded at `1df2d81` after delivery; this handover continues on the new baseline.

**Note:** this handover supersedes `devlog/handovers/20260903-01-debug-start_resume_rsync_stall.md` (delivered host-side; file not present in the re-seeded container). Its record is carried forward below, with its type corrected from `debug` to `design` — the iteration's dominant activity became redesign, not debugging.

## Objective

Original: diagnose the operator-reported start/resume stall (rsync/tar failure, sandbox never initializes, health-wait blocks) before any fix.

Current: the diagnosis closed with a location-level root cause, and the operator has adopted a redesigned seed transport (helper-container seed). This iteration records that design across the record layers (ADR, concept doc, architecture docs). Implementation follows in a later iteration.

## Completed (carried forward, diagnosis phase)

| Task | Evidence |
|---|---|
| Root cause + mechanism confirmed | Findings F1–F4 below |
| Failing commit identified; drop/keep recommendation | F3 — keep commit, strip pollution (applied host-side by operator, by hand) |
| Stall mechanism explained | F4 |
| Sentinel guard impl (20260904-01-impl-sentinel_untrackable_guard) | **reverted** at operator direction — not useful under the refined design (D4) |
| Seed transport redesign adopted in chat | Design section below |
| Option set + two rejected external methods recorded | `devlog/discussions/20260904-design-settled-helper_container_seed.md` (AC0) |
| ADR rewritten to requirements-first structure, STE100-style prose, sparse links | `docs/adr/sandbox_delivery_model.md` (AC1) — full rewrite: Requirements table (R1–R6, R7 promoted) above the current solution; mandated fields with per-requirement Rationale sub-headers; rejections state failure locus (intent / execution / impossibility); superseded entries condensed; transient references removed |
| Concept doc rewritten to interface level, standalone | `docs/concepts/copy_delivery.md` (AC2) — model, behavioral contract ("What the user relies on": all seven requirements restated as user-observable guarantees, content-complete for onboarding, no seam vocabulary), seed *interface* (mount diagram + input/output/guarantee contract; internal commands deferred to the ADR), session lifecycle, references. Zero handover/incident/sentinel references; defect history lives only in the ADR |

## Design (adopted, operator-approved)

Replace the 7-step host-side seed (`snapshot_seed_tar` → mktemp → `docker cp` stdin → read-back verification → `baseline.tar` unpack → mixed init → rsync overlay → tar-transform + symlink-target repair → staging cleanup) with a single helper-container seed:

1. Compose runs a one-shot seeder (the sandbox image, which already carries git + rsync — no network dependency, no `apk add`) with the project bind-mounted **read-only** at `/src` and the sandbox volume at `/dest`.
2. `cp -a /src/.git /dest/.git` — history and config cross natively; no `baseline.tar`, no unpack, no mixed-init dance.
3. `git -C /src ls-files -z --cached --others --exclude-standard | tar -C /src --null -T - -cf - | tar -C /dest -xf -` — git's own enumeration decides what crosses (gitignored content is never read); tar preserves symlinks and exec bits; deletions are absent by construction on the fresh volume.
4. `git -C /dest reset --quiet` — mixed reset: index = HEAD, working tree untouched. The git-status-parity invariant in one command.

Retained: `snapshot_guard_sentinel` concept as a fail-closed tripwire for legacy/polluted repos (re-implement if still warranted), case-mismatch check, volume-label identity wiring. Retired: seed tar member prefix/transform, symlink-target repair, stdin 0B read-back verification, `baseline.tar` + mixed-init reconstruction, the in-project-tree sentinel location itself.

## Findings

| # | Finding | Status |
|---|---|---|
| F1 | SHA miscorrespondence: host SHAs (`51a2f3f..8a81858`) do not correspond to container SHAs (`42fc502..fd93279`); identity matched by subject. The container replay deliberately excluded 631 `.agent-sandbox-seed/worktree/**` hunks — this difference was the bug's dividing line. | Confirmed |
| F2 | Root cause: host commits tracked `.agent-sandbox-seed/worktree/**` (capability-layer draft state). `baseline.tar` (=`git archive HEAD`) carried sentinel members; container unpack collided with the docker-cp-extracted seed (`File exists` / `utime: Operation not permitted`), failed, stalled. | Confirmed |
| F3 | Offending commit: host `4336b5f`. Recommendation was keep-commit/strip-paths; operator fixed host by hand. | Closed |
| F4 | Stall mechanism: readiness signalled only after `snapshot_init_git` returns; unpack failure exits the container before the signal; health-wait blocks on both `start` and `resume`. | Confirmed |
| F5 | Retrospective (operator questions answered): host-side origin; agent-caused act (`git add -A` swept untracked sentinel), harness-enabled (no ignore guard for a harness-created path); container side behaved correctly (fail-closed loud death). | Confirmed |
| F6 | Operator challenge accepted: the sentinel in the project worktree is a **location failure that by construction makes tracking failures possible** — the tracking defenses (gitignore, info/exclude guard) patched the location decision instead of removing it. The cross-filesystem objection to relocation was wrong: a second mountpoint of the same volume (or the adopted two-mount helper) makes any move a `rename(2)` within one filesystem. | Confirmed |
| F7 | The `.agent-sandbox-seed/` prefix, tar transform, symlink repair, init-time gitignore, pollution incident, and tracking guards are all consequences of staging inside the repo root; the seed tar itself (stdin streaming, read-back verify) was never the problem. | Confirmed |
| F8 | **STE100 availability.** STE100 is not in the agent system prompt. It exists in `documentation_policy.md` as one clause ("New and changed prose meets ASD-STE100") plus the delete-test heuristic — no approved-word list, no verb table, no sentence-length rule. Compliance is therefore heuristic, not verifiable. | Open |
| F9 | **Writing rules are findable but not triggered.** All prose rules live in one 270-line `documentation_policy.md` that AGENTS.md says to read "before the relevant task" — but nothing in the doc-writing workflow forces that read at write time; this session read the policy only after the operator asked. A one-page writing-conventions extract (STE100 quick rules, link policy, line wrapping, header format) — or a skill that bundles the checklist — would close the gap without duplicating the policy (single canonical owner stays `documentation_policy.md`). | Open |
| F10 | **ADR policy conformance — corrected.** Initial assessment overstated the conflict: the operator's structure fits the mandated fields (Decision / Rationale / Rejected alternatives / Edge cases / drivers) with sub-headers nested inside; the Requirements preamble and the requirement-promotion cycle are *additions* the policy does not describe, not contradictions. The rewritten ADR now conforms to the mandated field names. | Resolved |
| F11 | **Link policy drives link inflation.** `documentation_policy.md` says "link to relevant documents wherever possible", which rewards maximal linking; the operator's expectation is sparse, context-only links. The rule needs rewording (e.g. "link when the target changes what the reader does next") or the two rules will keep fighting. | Open |
| F12 | **Reasoning-trace framing is the default failure mode.** Unprompted, agents write records as session transcripts (narrative of what happened, with transient identifiers and justification chains). The fix is structural, not exhortation: templates with explicit Problem / Solution / Rejected (with failure locus: intent, execution, or impossibility) / Follow-up slots, and a steering line of the form "records state, not session history". The rewritten ADR follows this shape and can serve as the reference example. | Open |
| F13 | **Suggested permanent adr_policy.md amendments** (operator-gated; not applied): (1) allow an optional Requirements preamble between the `Current:` line and the first entry, for principles that accumulate invariants across entries — written as a table, promoted entries marked with their source incident; (2) define the promotion cycle in the Rejected alternatives definition — each rejection states its failure locus (intent / execution / impossibility) and any requirement or edge case it surfaces, which is promoted into the Requirements table and constrains the next solution; (3) permit sub-headers within entry fields (e.g. per-requirement Rationale subsections) — currently the Structure block reads as flat fields only. | Open |
| F14 | **Suggested permanent documentation_policy.md additions** (operator-gated; not applied), from the copy_delivery rewrite steering: (1) concept docs describe components at interface or diagram level — exact commands and exact variable values appear only for external interactions the harness does not control (e.g. docker CLI mappings); internal command sequences live in the ADR or architecture docs; (2) previous implementations and defect history live only in the ADR — concept docs are standalone and carry no handover references, session ids, or "Discovered in" pointers; (3) cross-doc duplication rule application: an invariants table defined in an ADR is linked, not restated, in concept docs. | Open |

## Decisions

| # | Decision | Rationale |
|---|---|---|
| D1 | Seed tar stays git-enumerated (during diagnosis phase) | Enumeration was correct; defect was tracked host-draft content |
| D2 | ADR + handover written directly at HEAD (not output mount) | Sandbox is the deliverable; avoids mid-boundary copy across `/dev/sdd` |
| D3 | ~~Sentinel guard impl: `info/exclude` + fail-closed preflight~~ | **Superseded by D4/D5** — committed as `f0ad56c`, reverted at operator direction: a tracking guard patches the location failure instead of removing it; unnecessary under the relocated design |
| D4 | Relocate harness seed staging out of the project worktree entirely | The sentinel is a disposable one-shot slice with no semantic place in the worktree; location failure made tracking susceptibility structural |
| D5 | Adopt helper-container seed transport (design section above) | Collapses 7 steps to 3 in-container commands; preserves every invariant (gitignored never crosses, parity, symlinks/exec bits, deletions); no network dependency; supersedes both the `docker cp` pipeline and the second-mountpoint variant |

## Acceptance Criteria (current scope — docs)

- AC0: Discussion doc recording the option set (including the two rejected external methods) — `devlog/discussions/20260904-design-settled-helper_container_seed.md`.
- AC1: ADR entry for the seed-transport decision; prior entry demoted per `docs/operations/adr_policy.md`.
- AC2: Concept doc (`copy_delivery.md`) pipeline rewritten; invariants preserved.
- AC3: Architecture docs (`execution_model.md`, `sandbox_lifecycle.md`) updated where they describe the `docker cp` seed pipeline.
- AC4: Consistency sweep — no doc presents retired machinery as current; suite green, lint Clean.

## Deferred

- Implementation: compose seeder service, `run_agent.sh` seed-path retirement, `snapshot.sh` cleanup, entrypoint simplification, trace-test rewrites. **On roadmap.**
- AC3 architecture-doc sweep (`execution_model.md`, `sandbox_lifecycle.md`) — rides with implementation. **On roadmap.**
- Documentation policy amendments (F11–F14 + STE100 quick rules, skeleton-first, records-state steering into `AGENTS.md` + `documentation_policy.md`). **On roadmap — next iteration per operator.**
- Relocation of draft/packaging worktree materialization out of the project tree (rides with mount-delivery work).
