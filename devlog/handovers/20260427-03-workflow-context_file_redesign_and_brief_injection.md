# Agent Handover

**Session date:** 2026-04-27
**Milestone:** M2 — Reasoning/Capability Layer Separation (cross-cutting workflow)
**Session type:** Workflow
**Status:** Closed

## Objective

Redesign the agent context file system: separate critical from non-critical information with correct injection targeting, establish a clean boundary between harness-level and project-level AGENTS.md, and redesign or remove the `~/workspace/input/brief` stub injection.

## Scope

- Define two-layer model (provider / project) and reference template as a recorded decision in `agent_workflow.md`
- Audit and rewrite `agent_context_brief.md` against the claude.ai chat AGENTS.md and pi AGENTS.md (uploaded at implementation time); output is project-tier `AGENTS.md` at repo root
- Author `providers/AGENTS.template.md` as canonical provider-tier template
- Author at least one conforming `providers/<n>/config/AGENTS.md` against the template
- Update `provider_onboarding_guide.md` with provider AGENTS.md authoring step
- Produce implementation spec for `~/workspace/input/brief.md` stub injection removal (code change deferred to impl session)
- Remove or formally retain `agent_context_brief.md` with recorded rationale

Deferred: universal tier injection mechanism (no second project to test against); per-provider discovery quirks (Pi global fallback, etc.).

## Carried forward

None.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | Implementation spec produced for `~/workspace/input/brief.md` stub injection removal, sufficient for an impl session to execute without design decisions. |
| AC2 | `providers/AGENTS.template.md` exists with canonical provider-tier structure. |
| AC3 | At least one existing provider has a conforming `providers/<n>/config/AGENTS.md` authored against the template. |
| AC4 | `provider_onboarding_guide.md` includes a step for authoring `providers/<n>/config/AGENTS.md` referencing the template. |
| AC5 | Project-tier `AGENTS.md` at repo root exists, derived from triage of `agent_context_brief.md` against uploaded interface AGENTS.md files. |
| AC6 | `agent_context_brief.md` removed or explicitly retained with narrowed scope and recorded rationale. |
| AC7 | Two-layer model and reference template recorded in one authoritative location; other files link rather than restate. |
| AC8 | Architecture documents in scope describe the system as built. |

## Hot files

| File | Why in scope |
|---|---|
| `docs/concepts/agent_context_brief.md` | Primary triage subject — content audited and absorbed or narrowed |
| `AGENTS.md` (repo root, project-tier) | Output of triage — new or rewritten |
| `providers/AGENTS.template.md` | New file — canonical provider-tier template |
| `docs/operations/provider_onboarding_guide.md` | New authoring step for provider AGENTS.md |
| `docs/concepts/agent_workflow.md` | Three-tier model recorded here |
| `docs/architecture/execution_model.md` | Brief injection removal spec references this |
| `docs/architecture/sandbox_lifecycle.md` | Brief injection lifecycle described here; may need update |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Two-layer agent context model: provider layer + project layer | Clean separation of environment orientation (provider-owned) from workflow and collaboration (project-owned); no runtime injection required for a third tier | `agent_workflow.md` — Agent Context Model |
| Reference template at `providers/AGENTS.template.md` | Distils common provider-layer structure without enforcing a universal tier that cannot yet be defined; new providers author against it | `agent_workflow.md`, `provider_onboarding_guide.md` Step 7 |
| `~/workspace/input/brief.md` stub injection removed | Stub carried no content; agents reading it received misleading orientation signal at token cost; working-directory discovery and operator-uploaded files are sufficient | `agent_workflow.md` — Agent Context Model; impl spec below |
| `agent_context_brief.md` retired | Content fully absorbed into project-layer `AGENTS.md`; file had drifted from working workflow and was not consistently read | `agent_workflow.md` |

## Completed this session

| File | Change summary |
|---|---|
| `docs/concepts/agent_workflow.md` | New section: Agent Context Model — two-layer model, provider layer, project layer, reference template, stub removal note; Policy Map row added for provider AGENTS.md contract; References table updated |
| `AGENTS.md` (repo root, project layer) | New file — project-layer agent context derived from triage of `agent_context_brief.md`, `agents_pi.md`, `agents_claude_ai.md`; contains System, Role, Constraints, Collaboration Protocol, Propagation Discipline, Read Discipline, Output Format, Missing Documents, Session Start reading list |
| `providers/AGENTS.template.md` | New file — reference template for authoring provider-layer AGENTS.md files; sections: Interface, Sandbox Context, Input/Output Channels, Tools, Output Mechanism, Session Start, Constraints; authoring comments throughout |
| `providers/claude-ai/AGENTS.md` | New file — provider-layer context for Claude Chat; self-complete (file access gate, session open convention, what a session is, output mechanism carried in full; project-layer file noted as requiring operator upload) |
| `providers/claude-code/AGENTS.md` | New file — provider-layer context for Claude Code; filesystem/shell access model matching Pi; memory persistence note (within session only) |
| `providers/pi/config/agent/AGENTS.md` | Rewrite — project-layer content removed; provider-specific content retained: Pi tool set, tool preferences, discovery protocol, output mechanism, session start orientation; brief.md read instruction removed |
| `docs/operations/provider_onboarding_guide.md` | New Step 7 (Write `config/AGENTS.md`); steps renumbered 7–11; `~/workspace/input/brief.md` reference removed from Step 3; reference examples updated from `opencode`/`hermes` to `claude-ai`/`claude-code`; References table updated |
| `docs/architecture/system_overview.md` | Per-project config description updated: `agents.md (agent context brief)` replaced with two-layer description linking to `agent_workflow.md` |

## Deferred items

None.

## Next session

**Type:** Implementation

**Scope:** Apply documentation changes from this workflow session and execute stub removal.

---

### Task 1 — Delete `docs/concepts/agent_context_brief.md`

`agent_context_brief.md` has been retired. Its content is fully absorbed into `AGENTS.md` at repo root. Delete the file and all stale references.

Grep the repository for all remaining references to `agent_context_brief` and `agent_context_brief.md`:

```bash
grep -rn "agent_context_brief" .
```

Known instances to resolve:

| File | Location | Current text | Correct action |
|---|---|---|---|
| `contributors.md` | Line 5, opening paragraph | `read agent_context_brief.md for the working protocol specific to your interface` | Replace with: `read the provider-layer AGENTS.md in your working directory and the project-layer AGENTS.md at the repository root for the working protocol specific to your interface` |
| `docs/devlog/` | Possibly in older handovers | References to `agent_context_brief.md` | Leave closed handovers untouched — they are historical records. Flag any open handover references for resolution. |

Any additional instances found by grep must be resolved — either updated to reference `AGENTS.md` (project layer) or the provider-layer file as appropriate, or removed if the reference is no longer meaningful.

---

### Task 2 — Update `readme.md` provider list

`readme.md` line 11 states "Currently supported agent provider: OpenCode". This is stale.

Replace with:

```
Currently supported agent providers:
- claude-code
- opencode
- hermes
- pi
```

Verify the surrounding context still reads correctly after the change.

---

### Task 3 — Remove stub injection from harness scripts

**Decision:** `~/workspace/input/brief.md` stub injection is removed. The stub at `brief.md` (a template shell with three comment-only sections) is not injected into agent sessions. The `workspace/input/` path remains available for operator-supplied files.

**What to find:** Locate the code path in `scripts/start_agent.sh` (or whichever script performs "brief resolution" — visible in the execution model diagram as a step in `start_agent.sh`) that copies or writes the stub to `SANDBOX_DIR/.workspace/input/brief.md` or equivalent. Also locate the stub source file (likely `brief.md` at repo root or `providers/` level — confirmed content is three comment-only section headers).

**What to change:**
1. Remove the brief copy/write step from the harness script. Do not remove other `workspace/input/` handling — the channel is still valid for operator files.
2. Delete the stub source file if it exists as a committed file.
3. If `start_agent.sh` documentation or inline comments describe the brief injection step, update them to reflect the removal.

**What not to change:** The `workspace/input/` bind mount itself must remain — it is the operator file input channel. Only the harness-initiated stub write is removed.

**Verify:** After the change, a dry-run session should start without any harness-written file at `workspace/input/`. The directory should exist (created by the Dockerfile or harness) but be empty unless the operator places files there.

---

Context handover: None.
