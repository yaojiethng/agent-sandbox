# Agent Handover

**Session date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Session type:** Workflow
**Status:** Closed

## Objective

Target the misnomer *"subagents cannot persist files / cannot make git commits / are read-only reviewers"* and the class of stale artifacts it belongs to — claims from back when the agent could not commit. Find and correct **all** such inaccuracies in live (non-historical) docs/config.

## Observed instance (operator-quoted)

`src/reasoning/providers/pi/config/agent/AGENTS.md:61`:

> "The subagent's output is returned inline. It cannot persist files to the sandbox or make git commits — it is a read-only reviewer. The results should be triaged by the primary agent."

This is **factually wrong** (established in session `20260812-07`): subagents under this harness are bash subshells in the same context/workspace as the primary agent and **CAN** persist edits and run git. The text is a stale leftover from when agents had no commit capability.

## Audit completed this session (no change yet)

Searched the family (`subagent`, `read-only reviewer`, `cannot persist`, `cannot make git commit`, `cannot write`, `does not have git access`, `read-only` agent-capability claims) across `src/`, `docs/`, `AGENTS.md`, skills, prompts. Results:

| Location | Claim | Verdict |
|---|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md:61` | subagent cannot persist/commit — read-only reviewer | **STALE — fix** |
| `docs/architecture/execution_model.md:128` | "compromised agent cannot write executable files [to output/]" | accurate — it's about the `output/` channel being text-only (security), not agent capability |
| `src/reasoning/providers/claude-ai/AGENTS.md` | "no direct filesystem access … all outputs as artifacts" | accurate for the Claude Chat interface (different provider) |
| `docs/architecture/*` (execution_model, security, system_overview, provider_lifecycle) | `input/` read-only, `output/` agent read-write, `.snapshot/` read-only, closed handovers read-only, agent "does not act unilaterally" | all accurate — current capability model |
| `src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md:42` | "use the Agent tool with `subagent_type=Explore` to walk the codebase" | **flag** — references a Claude-specific `Agent` tool API in a repo whose primary provider is pi (`pi -p` subagents); may be stale/shared-provider — operator judgment |
| historical `devlog/handovers/`/`discussions/` | "agent cannot persist state between sessions" | read-only records; not edit targets |

`docs/architecture/execution_model.md:128` verified: the agent *does* have read-write on `sandbox/` and `output/` and can run git; the "cannot write executables" line is specifically about the `output/` **channel** restriction (attack-surface design), NOT a false agent-capability claim. Keep.

## Files in scope (Task)

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | correct the stale "cannot persist/commit — read-only reviewer" sentence |
| `scripts/onboard.sh` | remove the dead `AGENTS.md` stub block (cat > ...) + related "Edit AGENTS.md" message + header refs |
| `src/capability/entrypoint.sh` | remove the `_preflight_warn` that checks `$SANDBOX_DIR/AGENTS.md` (becomes meaningless once the stub is gone) |
| `docs/development/quickstart.md`, `scripts/templates/Makefile.template` (lines 283/286 refs) | remove/confirm references to the onboard AGENTS.md stub |

## Verified: root `AGENTS.md` is clean and actively used (no change)

The repo-root `AGENTS.md` is git-tracked and is the **project-layer context** pi loads via CWD-walk at `/home/agentuser/sandbox/AGENTS.md` in the agent container (`volumes_from: sandbox`). It has **no stale subagent/cannot-commit claims** (audit confirmed). It is NOT a target — the operator asked to check it; it is fine.

## Verified: onboard `AGENTS.md` stub is dead (never used)

`scripts/onboard.sh` writes an empty stub to **host `$SANDBOX_DIR/AGENTS.md`**. It is:
- **not mounted** into the agent container (agent mounts only `input/`/`output/`/`session-diffs/`; the repo root comes via `volumes_from: sandbox`), and
- **shadowed** by the committed repo-root `AGENTS.md` that pi actually loads. The onboard "Edit AGENTS.md to give the agent project context" instruction is therefore misleading — the stub is never read.

Removal propagates to: `onboard.sh` (stub block + message + header/comment refs), `src/capability/entrypoint.sh` `_preflight_warn` (would warn spuriously once the stub is gone), and doc/Makefile refs.

## Decisions

| # | Decision | Rationale |
|---|---|---|
| 1 | **Remove B (the dead host `AGENTS.md` stub) entirely** — `onboard.sh` block + entrypoint preflight warn + quickstart "fill in AGENTS.md" section | it is never mounted into the agent container and is shadowed by the committed repo-root `AGENTS.md`; keeping it is misleading (its name implies it is live). Operator notes: it was a premature implementation of M3's individual task-briefs feature, introduced before that mechanism existed — a mistaken keep |
| 2 | **Fix** the stale subagent claim in `pi/config/agent/AGENTS.md:61` | misnomer — subagents can persist edits / run git in the same workspace |
| 3 | Root `AGENTS.md` unchanged | it is live (project-layer context pi loads) and has no stale claims |
| 4 | `improve-codebase-architecture/SKILL.md` `subagent_type=Explore` finding | **deferred** (operator: follow up later, not now) |

## Mid-session findings

| # | Finding | Disposition |
|---|---|---|
| 1 | `src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md:42` references "the Agent tool with `subagent_type=Explore`" — a Claude-specific `Agent` tool API, not pi's `pi -p` subagent. **Deferred at operator request** — follow up later, not now. | deferred |

## Acceptance criteria

- [x] Stale subagent claim in `pi/config/agent/AGENTS.md` corrected
- [x] Onboard dead `AGENTS.md` stub block removed from `onboard.sh`; related message/refs removed
- [x] Capability `_preflight_warn` for `$SANDBOX_DIR/AGENTS.md` removed (kept AGENT_HOME warn)
- [x] Doc/Makefile references to the stub removed/confirmed; no dangling refs (repo-wide grep verified)
- [x] Suite green (469 passed, 0 failed, 0 skipped)
- [x] Skill.md Agent-tool finding recorded (deferred), not acted on
- [x] Roadmap updated; handover closed + committed

## Completed this session

- [x] Verified root `AGENTS.md` is clean and actively used (project-layer context pi loads) — no change
- [x] Confirmed the onboard `AGENTS.md` stub is dead (never mounted; shadowed by repo-root file; premature M3 task-briefs feature)
- [x] Removed the dead stub family: `onboard.sh` (block + header + refresh note + summary instruction), `capability/entrypoint.sh` (sandbox-stub `_preflight_warn`; kept AGENT_HOME warn), `quickstart.md` (tree line + fill-in section + checklist), `project_onboarding_guide.md` (Step 3 + table row + tree line + checklist), `Makefile.template` refresh notes, `test_onboard.sh` (3 stub assertions)
- [x] Corrected the stale subagent claim in `pi/config/agent/AGENTS.md`
- [x] Verified `provider_onboarding_guide.md` Stop-7 AGENTS reference is the legit provider-layer file, not the stub (kept)

## Operational notes

- Docs/config change only — no code or tests; `make test` expected unaffected.
- Follow `documentation_policy.md` for doc edits (none touch governance policy text sections requiring per-section proposal, but the AGENTS.md content change should be presented for review).
- Each handover Closed + separately committed.
