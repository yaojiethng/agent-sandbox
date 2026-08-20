# Agent Handover

**Date:** 2026-08-19
**Milestone:** M2.6.6 — terminology (session→iteration)
**Type:** Implementation (2A session→iteration prose/entity sweep)
**Status:** Closed

## Objective

Execute **iteration 2A — session→iteration prose/entity sweep**: rename the `new-session` skill → `new-iteration` (file + invocation surface), and sweep the ops-work-cycle meaning of "session" → "iteration" across the independent prose in policy docs, AGENTS.md files, prompts, drafts/skills, concepts, and dev docs. Container-lifecycle "session" (Bucket C1) and historical records (Bucket C3) are NOT touched.

## Context (verified)

- Baseline `2d6aa23` (2B field-schema migration). Working tree clean.
- 2B removed "session" from all handover field headings → the 2A prose sweep no longer collides with any schema heading.
- Mapping (register `docs/concepts/terminology.md`): **session** = container lifecycle (SESSION_ID); **iteration** = work cycle (handover + commit).
- The `new-session` prompt is loaded by directory glob (`/opt/workflow/agent/prompts`) → a `git mv` to `new-iteration.md` is picked up at runtime automatically; no explicit-name wiring to break.
- B1 surface (skill + invocation): `new-session.md` file; handover_policy.md:221 reference; eval_new_session.sh → eval_new_iteration.sh; eval_commit3.sh D8/D9/E-checks; eval_protocol.md references; terminology.md already references `new-iteration (formerly new-session)` (forward-correct).
- B2 surface (ops-work-cycle prose): counted "session" words in live docs — iteration_policy (54), handover_policy (34), git_policy (31), roadmap_policy (17), milestone_policy (8), story_policy (2), root AGENTS.md (18), pi provider AGENTS (9), claude-ai provider AGENTS (20); prompts (new-session 7, package-branch 15, wrapup 6, whats-next 5, defer 2, propagation-check 2); drafts (recovery 16, audit 7, handover-audit 5, roadmap-management 3, bugfix 2, refactor-mv 1); concepts (agent_workflow 22, context_resolution 8, autonomous_task 2, two_layer_model 2); dev docs (project_index 18, testing_policy 19, testing-conventions 17, quickstart 10, interface-conventions 8, contributors 2, bash-coding-conventions 1).
- **NOT in 2A** (Bucket C1/A — container lifecycle, kept as "session"): `sandbox_identity.md` (29), `execution_model.md` (34), `sandbox_lifecycle.md` (24), `sandbox_host_correspondence_model.md` (36) — these are the container-identity docs owned by phase 3 (run→session). Also `_new_session_identity()` in start_agent.sh and all `SESSION_TS`/`SESSION_STATE`/`RESUME_SESSION`/`session-diffs` container tokens.
- **B3 (workflow CLI tokens)** deferred to phase 4/5 (bundles refactor): `--session=<name>`, `--session-summary`, `SESSION_NAME`/`SESSION_ARG`/`SESSION_SUMMARY_ARG`/`SESSION_DIR`; draft-context `SESSION_TS` KEPT.
- **tests/eval/\*** are archival (Bucket C3) — the eval scripts assert `new-session.md` historical state; NOT run by `make test`. Whether to rename `eval_new_session.sh` (it is a *live* eval harness pointing at a live prompt) needs an operator call (see scope question).
- GOTCHAS `[G] 2026-08-09`: policy/AGENTS.md text changes require per-section approval. 2A touches policy docs, so these need section-by-section approval, not a mechanical sweep — the operator's approved 2B flow (classified change manifest + `git diff` review) is the model.

## Scope structure (operator decisions, 2026-08-19)

- **Single 2A unit** (Option 1) — one iteration, one commit.
- **Approval-oriented ordering within the unit:** do the parts that need NO explicit approval FIRST (mechanical renames in prompts, drafts, concepts, dev docs, skill, invocation surface); leave policy docs and AGENTS.md LAST, with per-section (table-form) approval.
- **Approval form:** for a mostly-rename sweep, present changes as a **table** — each row the old line and the new line with a few words of context on each side, not paragraph-by-paragraph. Speeds review materially.
- **Eval script:** `tests/eval/eval_new_session.sh` treated as **archival** (Bucket C3) — left untouched; a mid-session finding records that it is out-of-date and due for removal.

## Files in scope (proposed — full 2A, before split)

| File | Change |
|---|---|
| `src/reasoning/agent/prompts/new-session.md` | `git mv` → `new-iteration.md`; body session→iteration |
| `docs/operations/handover_policy.md:221` | reference table → `new-iteration.md` |
| `tests/eval/eval_new_session.sh` | → `eval_new_iteration.sh` (if operator opts to sweep live eval) |
| `docs/operations/iteration_policy.md` | ops-work-cycle "session"→"iteration" (54) |
| `docs/operations/handover_policy.md` | remaining "session"→"iteration" (34) |
| `docs/operations/git_policy.md` | "Session branch"→"Iteration branch", etc. (31) |
| `docs/operations/roadmap_policy.md`, `milestone_policy.md`, `story_policy.md` | "session"→"iteration" (17/8/2) |
| `AGENTS.md`, `src/reasoning/providers/pi/config/agent/AGENTS.md`, `claude-ai/AGENTS.md` | "session"→"iteration" (18/9/20) |
| prompts: `wrapup.md`, `whats-next.md`, `defer.md`, `package-branch.md`, `propagation-check.md` | work-unit "session"→"iteration" |
| drafts: `recovery.skill.md`, `audit.skill.md`, `handover-audit.skill.md`, `roadmap-management.skill.md`, `bugfix.skill.md`, `refactor-mv-rename-file.skill.md` | work-unit "session"→"iteration" |
| concepts: `agent_workflow.md`, `context_resolution.md`, `autonomous_task.md`, `two_layer_model.md` | work-unit "session"→"iteration" (only B2 occurrences) |
| dev docs: `project_index.md`, `testing_policy.md`, `testing-conventions.md`, `quickstart.md`, `interface-conventions.md`, `contributors.md`, `bash-coding-conventions.md` | work-unit "session"→"iteration" |
| `devlog/roadmap.md` | terminology task phased sub-point → mark 2A done (per-iteration) |
| `devlog/handovers/20260819-12-...` | this handover |

**Order of execution within the unit (approval-free first, policy/AGENTS last):**
1. Skill rename + body (`new-iteration.md`) + handover_policy:221 reference (that row sits in a policy file, presented in the approval-late group).
2. Prompts (wrapup, whats-next, defer, package-branch, propagation-check); drafts (recovery, audit, handover-audit, roadmap-management, bugfix, refactor-mv).
3. Concepts (agent_workflow, context_resolution, autonomous_task, two_layer_model) + dev docs (project_index, testing_policy, testing-conventions, quickstart, interface-conventions, contributors, bash-coding-conventions) — screened for B2-only occurrences.
4. **Approval-late group (per-section table):** policy docs (iteration_policy, handover_policy, git_policy, roadmap_policy, milestone_policy, story_policy) + AGENTS.md (root, pi, claude-ai).

## Out of scope (deferred)

- Bucket C1 container-lifecycle docs (sandbox_identity, execution_model, sandbox_lifecycle, sandbox_host_correspondence_model) — phase 3 (run→session).
- B3 workflow CLI tokens + draft-context `SESSION_TS` — phase 4/5 (bundles).
- Historical handovers/discussions/changelog + `tests/eval/*` (incl. `eval_new_session.sh` — archival) — Bucket C3.
- Phase 3 `RUN_ID`→`SESSION_ID`; phase 5 bundles.

## Findings

| # | Finding | Disposition |
|---|---|---|
| 1 | `tests/eval/eval_new_session.sh` (and eval_commit3.sh/protocol) reference the renamed `new-session` prompt; archival (Bucket C3), not run by `make test`. | left untouched per operator; out-of-date and due for removal (operator) |
| 2 | `new-iteration.md` references "handover_policy.md Types section" — resolves when handover_policy `## Session Types` → `## Types` lands in the approval-late group. | current unit (approval-late) |
| 3 | In `recovery.skill.md`, "session log (JSONL)" refers to the container runtime session log (C1) — kept as "session"; the work-unit "sessions" in the procedure were swept to "iterations". | current unit (documented) |
| 4 | **Two-headed close/seed anchor (SRP violation):** `iteration_policy.md#steps-89-close-and-seed` (its own "8–9. Close and seed" header) and `roadmap_policy.md#session-close-steps-8-9`/`#iteration-end-steps-8-9` (roadmap_policy's own "Iteration end (Steps 8–9)" header) both denote the same lifecycle moment but live in two docs with two anchors; handover_policy links to one, iteration_policy links to the other. | cleanup target, deferred (operator); logged for a future single-source fix |
| 5 | **`roadmap_policy.md` "When the Roadmap Is Touched" / "Milestone promotion check" sections are badly written** — unclear rules, loaded language ("intends"); the former "Pre-session Status Promotion Check" heading renamed to "Milestone promotion check" but the section body is not rewritten here. | deferred (operator reviewing/glazing over); full STE rewrite pending |
| 6 | **git_policy Branching Strategy + Merge Policy out of date** — "session branch" model does not fit real practice; likely removal, not rewrite. The "session branch" terms in those sections were left untouched (OOS for the session→iteration rename). | OOS for the sweep; mid-iteration finding — decide removal/rewrite separately |
| 7 | **Stale `claude-ai` provider folder deleted** — contained only an outdated AGENTS.md (no dockerfiles/impl), kept separate from the live providers (hermes/opencode/pi). `provider_onboarding_guide.md` cites `providers/claude-ai/base.dockerfile` etc. as **Reference:** lines — those paths were ALREADY dangling (the folder never had them), so the delete adds no new breakage; the guide's claude-ai references remain stale/illustrative. | deleted (operator: stale, not reading it); guide reference noted adjacently |

## Completed

**Approval-free portion (steps 1–3):**

| File | Change |
|---|---|
| `src/reasoning/agent/prompts/new-session.md` | `git mv` → `new-iteration.md`; body session→iteration |
| `src/reasoning/agent/prompts/wrapup.md` | session→iteration (description, propagation replay, gate, scope reconciliation, close, seed what's next) |
| `src/reasoning/agent/prompts/whats-next.md` | fresh-session→fresh-iteration, next-session→next-iteration (×2); kept `Mid-session findings\|Findings` 2B dual-grep |
| `src/reasoning/agent/prompts/defer.md` | session→iteration (description, Deferred rows) |
| `src/reasoning/agent/prompts/package-branch.md` | prose session→iteration; kept B3 `--session-summary`/`SESSION_`/`SESSION_STATE`/`run_id` tokens |
| `src/reasoning/agent/prompts/propagation-check.md` | closing-the-session→closing-the-iteration; kept `agent-sandbox.session-name` C1 |
| `src/reasoning/agent/drafts/recovery.skill.md` | work-unit session→iteration; kept JSONL "session log" C1, `--session-summary` B3, `**Session date:\|**Date:` 2B bridge |
| `src/reasoning/agent/drafts/audit.skill.md` | session→iteration (across iterations, not an iteration type, 20 iterations, prior iteration's handover, next-iteration destination, Findings triage at iteration close) |
| `src/reasoning/agent/drafts/handover-audit.skill.md` | session→iteration (×4); kept `session 20260522-03` C3 date ref |
| `src/reasoning/agent/drafts/roadmap-management.skill.md` | session→iteration (×3) |
| `src/reasoning/agent/drafts/bugfix.skill.md` | part-of-this-session→iteration; kept `session-diffs/` C1 |
| `src/reasoning/agent/drafts/refactor-mv-rename-file.skill.md` | mid-session→mid-iteration |
| `docs/concepts/agent_workflow.md` | work-unit session→iteration; kept container-run L13/L59/L71/L73 and settings-config L73 |
| `docs/concepts/autonomous_task.md` | session→iteration (×3) |
| `docs/development/project_index.md` | iteration-scoped/iteration-workflow/iteration-boundary/iteration-open-close; kept C1 session-select/session-state/RUN_ID rows |
| `docs/development/contributors.md` | session-workflow→iteration-workflow (×2) |

**Approval-late portion (step 4, policy + AGENTS):**

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | full session→iteration + STE simplification; "unit" dropped (L91 "For multi-iteration sessions", L139 prescriptive, L160 task-list); start/end lifecycle; "Close and seed" header kept |
| `docs/operations/roadmap_policy.md` | session→iteration; `### Iteration start (Step 1)` + `### Iteration end (Steps 8–9)` + `#iteration-end-steps-8-9` anchor; `## Pre-session Status Promotion Check`→`## Milestone promotion check` |
| `docs/operations/handover_policy.md` | session→iteration + STE-simplified intro/Purpose; `## Session Types`→`## Types`; `new-iteration.md` reference; status values Open/Active/Closed kept |
| `docs/operations/git_policy.md` | lifecycle/commit prose session→iteration; **Branching Strategy + Merge Policy "session branch" left OOS** (see finding 6) |
| `docs/operations/milestone_policy.md` | session→iteration (iteration execution, first sub-milestone to iterate, minor loop iteration, sub-milestone is iterated, whose iteration will resolve) |
| `docs/operations/story_policy.md` | session→iteration (relevant minor loop iteration) |
| `AGENTS.md` | work-cycle session→iteration; `## Session Start`→`## Iteration Start` |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | work-cycle session→iteration; container-runtime "session" kept |
| `src/reasoning/providers/claude-ai/AGENTS.md` | **deleted** (stale, operator) |

**Suite:** 476 passed / 0 failed / 0 skipped (final, after all portions).

## Decisions

| # | Decision | Rationale |
|---|---|---|
| A | **Single 2A unit** — skill rename + B2 prose sweep in one iteration/commit | operator (Option 1) |
| B | **Approval-free parts first; policy/AGENTS last** (per-section table approval) | egonomics of approval; mechanical renames need no gating |
| C | **Approval as a table** — old vs new line, few words of context each side | mostly-rename sweep; faster than paragraph-by-paragraph |
| D | **`eval_new_session.sh` left archival** (Bucket C3); mid-session finding records it out-of-date/due for removal | operator: treat as archival |
| E | **Drop "unit" entirely** — not a registered term; granularity covered by iteration task lists + per-handover numbering. L91 "For multi-iteration sessions", L139 "when a session contains multiple iterations", L160 task-list phrasing. | operator: unit was artifact of the stripped transient-numbering violation |
| F | **Iteration start/end** for the lifecycle (not open/close); keep "open/close" for handover status/handover-handling & git PR. roadmap_policy `### Iteration start (Step 1)` + `### Iteration end (Steps 8–9)` + `#iteration-end-steps-8-9` anchor; keep iteration_policy "8–9. Close and seed". | operator: iterations start/end; open/close is git/handover vocabulary |
| G | **STE simplification during the sweep** — subject-first, delete-test, verb-over-noun, prescriptive-imperative, one-concept-per-sentence, active voice | operator: many "session execution" / "iteration execution" phrases were redundant; apply the delete-test |

## Sentence-writing guidelines (distilled from this edit)

Applied while rewriting policy prose session→iteration; matches the STE delete-test in `documentation_policy.md`.

1. **Subject first.** Front-load the subject; don't stack nouns behind a possessive/complement. ("content rules for session handover documents" → "handover content rules")
2. **Delete what the reader can omit.** Cut redundant nouns ("iteration *execution*"), redundant determiners, and filler ("This document defines..." → "Defines...").
3. **Prefer a verb over a noun phrase.** ("is a log describing the work done in the iteration" → over "is an iteration log"; "iterating on sub-milestones" over "can be sessioned")
4. **State the rule prescriptively, not descriptively.** Forbid the failing behavior with an imperative; don't describe the failure as rationale. ("Do not write iteration N+1's spec until N's output is confirmed" over "Cross-unit dependencies... are the primary source of spec contradictions")
5. **One concept per sentence.** Split compound requirements; full stops over long dashes.
6. **Use the active/imperative voice for instructions.** ("Mark each criterion as accepted or pushed to next iteration" over "each criterion is marked...")

## Acceptance criteria

- [x] `new-session.md` → `new-iteration.md` + live invocation (runtime glob)
- [x] All B2 work-unit "session"→"iteration" applied per the propagation checklist; container-lifecycle "session" (C1) and historical records (C3) untouched (git_policy Branching/Merge "session branch" explicitly OOS — finding 6)
- [x] Policy docs + AGENTS.md changed section-by-section with operator table approval (then direct, per operator)
- [x] Suite green (476/0/0)
- [x] Roadmap terminology task phased sub-point reflects 2A done

## What's Next

- **Run→session sweep (phase 4 / iteration 3)**: `RUN_ID`→`SESSION_ID` across compose/build/start/run/stop/entrypoint/snapshot/diff_export/draft_state/package_branch/routing/draft/Makefile.template/docs/tests; persistence-critical — `SESSION_STATE` write key `run_id`→`session_id` and `agent-sandbox.run-id` label→`agent-sandbox.session-id` atomic; stop `--run-id`→`--session-id`; container-lifecycle docs (sandbox_identity, execution_model, sandbox_lifecycle, sandbox_host_correspondence_model) get their first sweep here.
- **Bundles refactor (phase 5 / iteration 4)** — `--session=<name>`→`--bundle=`, `--session-summary`→`--bundle-summary`, `SESSION_*`→`BUNDLE_*`, stale `output/diff` cleanup.
- **Deferred mid-iteration findings to resolve (from this handover):** git_policy Branching Strategy + Merge Policy (remove/rewrite — finding 6); `roadmap_policy.md` Milestone promotion check + When Roadmap Is Touched STE rewrite (finding 5); two-headed close/seed anchor single-source fix (finding 4); stale `eval_new_session.sh` removal (finding 1).
- **STE sentence-writing guidelines** distilled in this handover — candidate promotion to `documentation_policy.md` STE section.
- The `--session=<name>` CLI token and draft-context `SESSION_TS` remain until phase 5.

## Operational notes

- Open gotchas in force: library functions `return` not `exit`; policy-text per-section approval; handover close = the commit.
