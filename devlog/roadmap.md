---
active-milestone: M3 - Autonomous Task Execution, Manual Review Workflow
active-milestone-status: in-progress
---

# agent-sandbox Development Roadmap

This roadmap defines milestones, incremental goals, and tasks for the agent-sandbox project. It is designed to allow stepwise development and learning, with progress tracking for agents or humans.

Maintenance rules - task granularity, cleanup on completion, section removal - are defined in [`docs/operations/roadmap_policy.md`](../docs/operations/roadmap_policy.md).

---

## Milestone Summary

| Milestone | Status |
|---|---|
| M1 - Barebones Agent Container | [Complete - see changelog](changelog.md#m1--barebones-agent-container) |
| &nbsp;&nbsp;M1.1 - Interactive Virtual Workspace / Serve Mode | [Complete - see changelog](changelog.md#m11--interactive-virtual-workspace--serve-mode) |
| &nbsp;&nbsp;M1.2 - Sandbox File Isolation & Diff Workflow | [Complete - see changelog](changelog.md#m12--sandbox-file-isolation--diff-workflow) |
| &nbsp;&nbsp;M1.3 - Invocation Cleanup & Onboarding Workflow | [Complete - see changelog](changelog.md#m13--invocation-cleanup--onboarding-workflow) |
| &nbsp;&nbsp;M1.4 - Image Staleness Detection | [Complete - see changelog](changelog.md#m14--image-staleness-detection) |
| &nbsp;&nbsp;M1.5 - Workflow Convergence & Directory Restructuring | [Complete - see changelog](changelog.md#m15--workflow-convergence--directory-restructuring) |
| **M2 - Reasoning/Capability Layer Separation** | [Complete - see changelog](changelog.md#m2--reasoningcapability-layer-separation) |
| &nbsp;&nbsp;[M2.1 - General Capability Layer Prototype](changelog.md#m21--general-capability-layer-prototype) | Complete |
| &nbsp;&nbsp;[M2.2 - Reasoning Layer Modularisation](changelog.md#m22--reasoning-layer-modularisation) | Complete |
| &nbsp;&nbsp;[M2.3 - Apply Workflow: Capability Layer Diff Pipeline](changelog.md#m23--apply-workflow-capability-layer-diff-pipeline) | Complete |
| &nbsp;&nbsp;[M2.4 - Session and Config Persistence](changelog.md#m24--session-and-config-persistence) | Complete |
| &nbsp;&nbsp;[M2.6 - Session Persistence](changelog.md#m26--session-persistence-foundation-and-copy-model) | Complete |
| &nbsp;&nbsp;[M2.7 - Session Identity and Harness Versioning](changelog.md#m27--session-identity-and-harness-versioning) | Complete |
| **M3 - Autonomous Task Execution, Manual Review Workflow** | [In progress](#m3--autonomous-task-execution-manual-review-workflow) |
| **Multi-Agent** | |
| &nbsp;&nbsp;M4 - Metadata Seeding | Not started |
| &nbsp;&nbsp;M5 - Agent-Assigned Branch Management | Not started |
| &nbsp;&nbsp;M6.1 - Task Dispatch | Not started |
| &nbsp;&nbsp;M6.2 - Constraint Enforcement | Not started |
| &nbsp;&nbsp;M6.3 - Review & CI/CD Integration | Not started |
| **Standalone** | |
| &nbsp;&nbsp;M7 - Safe vs Unsafe Mode (Policy Layer) | Not started |
| &nbsp;&nbsp;M8 - Skills / Templates | Not started |

---

## User Stories

Open stories under active investigation. Closed stories are removed from this list.

- [`20260522-story-active-prompt_eval_infrastructure.md`](./discussions/20260522-story-active-prompt_eval_infrastructure.md) - How do we test that skills and prompt templates correctly reflect the policy documents they encode? Manual read-through comparison doesn"t scale across N skills x M policy sections.

---

## Upcoming Milestones

### M3 - Autonomous Task Execution, Manual Review Workflow

**Objective:** Move from interactive prompting to structured single-task execution with enough logging to verify the agent is doing useful work. Requires the two-layer foundation from M2.

**Depends on:** M2 two-layer architecture (headless mode requires the capability layer tool interface; task briefs are the operator input channel from M1.5).

**Finding -- Sub-milestone containment (recorded, not designed):** Milestones and sub-milestones are intended to be self-contained, but partial implementations from later milestones are frequently needed while the current milestone is incomplete. This suggests that how features are cut into sub-milestones, and how strictly they are sequenced, may be the wrong seam. The sub-milestone-as-container model is recognized as a candidate for re-examination, not as settled. Design and any restructuring is deferred to M3. The current deferred-items / sub-milestone task-list system is maintained until then.

- [ ] Define Task Brief format (`TASK.md` -- per-run brief placed in `SANDBOX_DIR/.agent-input/input/` before the run; aligns with the M1.5 input channel)
- [ ] Define agent execution lifecycle for a single headless task run
- [ ] Atomic install for `make install` -- write to temp file, verify, then `mv` into place
- [ ] Pre-snapshot validation gate -- configurable per-project check run by `start_agent.sh` before building `.agent-input/`; fail fast before the container starts
- [ ] Store structured logs per agent and task run
- [ ] Capture metadata with each commit (agent_id, task_id, timestamp) -- prerequisite for trusting autonomous output
- [ ] Converting the roadmap to linear-style task tracking -- full linear redesign. The handover next-session trim and always-push-to-roadmap behavior are scoped for immediate implementation (outside M3); only the linear/management-app format remains.
- [ ] Moving next-session seed out of handover and into a next-task subheader in the sub-milestone -- the handover next-session trim is scoped for immediate implementation; next-task subheader placement within the linear format remains.
- [ ] Close-milestone automation -- replace the manual administrative close checklist with a single script (`make close-milestone`) that atomically bumps milestone state. Clean commit, no partial-close risk. Close is ceremonial (no decisions); all substantive work occurs in pre-close (see the milestone lifecycle reframe).
- [ ] AC-machinery policy discussion for chores, doc, plan type sessions
- [ ] Process improvements (fast-track criteria, decision recording, stale skill reference) -- deferred from M2.7
- [ ] **Skill-maintenance backlog triage (raised AGENT_FEEDBACK 2026-09-20)** -- the feedback backlog in `devlog/AGENT_FEEDBACK.md` has no roadmap home; observations stay inert until a row assigns them. Consolidate the accumulation: fold the three bash `set -e` language-limitation entries into `bash-coding-conventions.md` or a bash skill; distill the edit-tool collation entry into AGENTS.md edit-tool steering once entries accumulate; write the pending circular-sourcing ADR; then close or probation each backlog entry whose fix landed.
- [ ] **Proper skill installation from upstream; fork and maintain a version with harness or provider-specific quirks stripped out** -- skills imported from upstream (e.g. Claude) carry harness/provider-specific tool references that do not apply in the agent-sandbox/pi context. Adopt a convention: install the upstream skill, fork it, and strip provider-specific quirks, maintaining the harness-local version. Concrete case already found: [`improve-codebase-architecture/SKILL.md`](../src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md) references "the Agent tool with `subagent_type=Explore`" -- a Claude-specific Agent tool API, not pi's `pi -p` subagent. Fix that instance and define the fork-and-strip convention (surfaced from session `20260812-09`; recording here in M3).
- [ ] **Loop-documentation structure decision (deferred to M3)** -- decide whether the major/minor loop documentation needs a structural split (e.g. `major_loop_policy` / `minor_loop_policy`), what form it takes, and where the canonical boundary between milestone_policy and iteration_policy lands. Deferred from session `20260809-04`; a split is one possible form, not a settled intent. The milestone_policy scope expansion to own the entire major loop (scoping -> story/investigation -> roadmap entry -> minor-loop handoff -> pre-close -> formal close) rides on this decision.
- [ ] **Formal state diagram of the major/minor loop workflow (deferred to M3)** -- produce a state diagram of the entire loop workflow (major loop: scoping -> story/investigation -> roadmap entry -> minor-loop handoff -> pre-close -> formal close; minor loop iterations inside the handoff). Supports the loop-documentation restructure and the combine/re-section effort.
- [ ] **Separate the new-iteration workflow into the workflows/ folder** -- move iteration-specific instructions and procedures out of `AGENTS.md`, the documentation, and the shared policy files, and consolidate workflow-specific logic into standalone policy files bundled with each workflow (the `workflow/knowledge-vault/` bundling is the existing precedent). The shared governance surface keeps only what is true for every workflow; each workflow owns its own procedure. This is the enabling structure for future workflows -- plan, policy-change, autonomous-iteration, and similar -- which otherwise would grow `AGENTS.md` and the shared policies further.
- [ ] **Coding-agent workflow consolidation** -- reorganize the skill and prompt surface per [`workflow/coding-agent/audits/surface-area-report.md`](../workflow/coding-agent/audits/surface-area-report.md): one canonical file per use case; merge the handover-audit pair into one file; absorb the useful checks from `kelsey-code-reviewer.skill.md` into `bash-audit.skill.md`; drop the non-current Claude-format imports (`dhh-code-audit.skill.md`, `architecture-doc-reviewer.skill.md` -- the latter's purpose merges into the roadmap task "Architecture-doc staleness sweep"); relocate `toc.sh` out of the skills area; rename or dissolve `drafts/`, whose name implies draft status but holds current procedures. Files were relocated to their M3-ready homes in handover `20260911-02`; the audit family was extended and the deployed prompts mirrored in handover `20260911-03` (audits also carry `test-quality-campaign.md` and `documentation-pass.md`; `workflow/coding-agent/prompts/` holds `gm.md` and `test-quality-campaign-run.md` and is deployed by folder COPY). For the documentation-audit use case, compile one pi-native prompt per [`workflow/coding-agent/audits/documentation-audit-comparison.md`](../workflow/coding-agent/audits/documentation-audit-comparison.md), absorbing `architecture-doc-reviewer.skill.md` and `documentation-pass.md`, then drop both.
- [ ] **Git policy rewrite: bind commit-message body length and reference scope (shelved from M2.6, raised 2026-09-18)** - `docs/operations/git_policy.md` commit-message guidance needs a body-length and reference-discipline rule. Symptom: the first line is good, but subsequent lines run overly long, carry excessive detail, and cite unnecessary references (e.g. a handover link in the commit body when the change is already attributed as the latest handover). Rewrite the Body/footer section: state a tight body budget (why-not-what), forbid redundancy with the handover attribution, and require every reference to earn its place.
- [ ] **Review-pass framing fixes (shelved from AGENT_FEEDBACK 2026-09-18, session `20260918-10`)** - three refinements to the review-pass framing. (1) The round-cap / blocker-re-review loop fits correctness reviews; a model-consensus quality pass converges in one round per model against a shared brief, then the main agent consolidates - `workflow/coding-agent/prompts/review-pass-run.md` should state when each shape applies. (2) A review directive names the base commit or the explicit `git diff <base>..<head>` range instead of a handover date the reader must convert. (3) An edit target with a seeded/runtime copy pair ("pi's AGENTS.md") is named by full path, with the authoritative copy stated.
- [ ] **Evaluate whether make is still needed as the sandbox command wrapper; if not, assess substitutes (surfaced from handover 20260919-15)** - make is used not for compilation but as a directory-based script wrapper. It can do this but is not specialised for it, so we lose features and jerry-rig arg parsing (Make variables `PROVIDER=pi` vs CLI flags `--provider=pi`), and now carry a second command-invocation idiom whose help/error surfaces must be kept consistent with the direct CLI (a list of those hint surfaces is the files-in-scope table in handover `20260919-15`). The original reason for make -- the full `agent-sandbox` command was too long to provision every arg -- is weakened: the `.env` identity resolution has shortened the command. Evaluate whether make still earns its place; if not, assess possible substitutes (a thin wrapper script, shell aliases, or a direct-CLI-only surface). The evaluation is the deliverable; a decision to remove make, if reached, is a separate follow-up.
- [ ] **Nushell rewrite evaluation (moved from M2 not-in-scope)** - evaluate whether rewriting the host-side tooling in a cross-platform structured-data language (nushell) would remove the GNU/BSD host difference at a justifiable cost. The bounded alternative is the `scripts/install.sh` requirement gate and portable call sites; the evaluation decides whether the host-support burden justifies the rewrite. See `docs/development/host_requirements.md`.
- [ ] **Backpressure** -- checks that fire at the local git boundary, so the agent learns about a defect when it commits instead of at the review gate. The copy-delivery Markdown `pre-commit` hook is the first instance ([`git_hooks.md`](../docs/adr/git_hooks.md)); mount delivery carries no hook under the current delivery constraint.
  - [ ] **Mount-delivery hooks (constraint change).** Git hooks, or hook-like behaviour, for mount delivery requires a change to the delivery model's host-exposure constraint: the mount `.git` is a host directory, so an agent-writable hook there executes on the host. The constraint change and its security cost are the deliverable; implementation follows only if the constraint changes.
  - [ ] **ShellCheck as a git hook.** Extend the commit hook to run the ShellCheck gate over the staged shell files, so the shell rules get the same commit-time backpressure as the Markdown rules.
  - [x] **Split `tests/test_draft_workflow.sh` into per-family files** - `test_draft_workflow.sh` was the repository's only file over 1000 lines (1102). Split into `test_draft_workflow.sh` (draft/ingest/resolve, 632), `test_confirm_workflow.sh` (303), and `test_reject_workflow.sh` (101), with the cross-family helpers (`draft_branch`, `_test_draft_run`, `_current_branch`, `_branch_exists`) moved to `tests/libs/draft_fixtures.sh` per the shared-fixtures rule. Family registrations intact: 29 + 9 + 4 = 42, suite green. Handover `20260920-03`.

#### Doc Bloat - Rotate Out Stale Handovers and Discussions

**Deferred from `roadmap.md` (not milestone-scoped).**

`devlog/handovers/` and `devlog/discussions/` accumulate every session's output. Most are only relevant during their milestone -- once a milestone is closed, the handover detail lives in the changelog. There is no need to keep the full history on `HEAD`. Design a rotate-out process: completed milestone handovers are archived to a git tag or a separate branch, removed from `HEAD`. Roadmap entries, architecture docs, and the changelog are the permanent record. The same applies to resolved stories in `devlog/discussions/` -- once graduated to a roadmap entry, the story discussion document can be archived. See `20260428-story-active-sequencing_and_knowledge_persistence.md` which is related.

- [ ] **Subagent progress visibility (scoped for M3)** -- provide internal visibility into a running subagent session (is it progressing, blocked, or stalled on network/provider) so the main agent can triage an interrupted `pi -p` review instead of losing the run. Surfaced from session `20260918`: a review round was lost to network loss with no way to see whether it had progressed before the flush; the midway session had to be recovered by reading the raw session transcript. No solution in mind yet -- candidate directions include a subagent heartbeat/status channel, progress markers in the transcript, or a resume-on-interrupt with continuation; design is deferred to M3. Contrast the `team.ts`-style orchestration seams under M4 in the Multi-Agent Coordination section. Folded into the `perf` workstream below, which owns the instrument that answers it.

#### Perf - Subagent and Tool Observability (scoped for M3)

**Deferred from `roadmap.md` (not milestone-scoped).** Broad header `perf`: this group owns measurement of the harness's own agent-facing surfaces -- subagent runs and tool calls. The unifying finding: the harness runs expensive subagent reviews and tool calls with no measurement of either, so cost, throughput, and failure modes are invisible. A ten-round review pass in session `20260919-19` took several hours of wall-clock with no live progress signal and no post-hoc breakdown; the only evidence available was a log file and a session transcript, read by hand.

**Finding -- subagent runs are unmeasured.** A `pi -p` review run exposes no liveness signal (the log stays empty until the run flushes at exit) and no cost accounting afterwards. Neither the main agent nor the operator can answer: is the run alive or stalled; how many tokens per second is it producing; what is the request latency; how much of the elapsed time is model time versus tool execution versus harness overhead. The existing "Subagent progress visibility" task above states the liveness half; this group adds the metrics half and owns the instrument for both.

**Finding -- the `edit` tool has no telemetry.** `devlog/AGENT_FEEDBACK.md` holds an edit-tool entry recording recurring exact-match failures, and the batch-edit work in session `20260919-19` produced further instances (a large multi-edit call whose overlapping hunks were rejected, and several edits that failed on whitespace). No instrumentation records which edits fail, how often, or why: there is no count of failed tool calls, no classification of the failure (no-match, ambiguous match, overlapping regions, stale file), and no measure of the retry cost that follows. The feedback entry's proper resolution is postponed to this task; do not close that entry before this work lands.

**Scope:**

- [ ] **Subagent run telemetry** -- emit a per-run record for a `pi -p` invocation covering: model and thinking level, start and end timestamps, total wall-clock, tokens in and out, throughput (tokens per second), per-request latency, tool-call count and duration, and the number of agent turns. Surface it at run end and persist it so a review tranche's cost is reconstructable without reading a transcript.
- [ ] **Subagent liveness** -- a signal readable while the run is in flight, so the main agent can tell "progressing" from "stalled on network or provider" without waiting for the flush. The candidate directions in the task above remain open; the metrics record and the liveness signal should share one instrument.
- [ ] **Time attribution** -- split a run's wall-clock into model time, tool-execution time, and harness overhead, so the dominant cost is measurable rather than assumed. This is what answers whether a slow review is a provider problem, a tooling problem, or an orchestration problem.
- [ ] **Tool-call telemetry** -- count every tool call by name and outcome, and record the duration. Include the failure rate per tool, not only a total.
- [ ] **`edit`-tool failure metrics** -- instrument the `edit` tool specifically: count failed calls, classify the failure (text not found, ambiguous match, overlapping or nested regions, unread/renamed file), and record the follow-up cost. This is the measurement the `devlog/AGENT_FEEDBACK.md` edit-tool entry lacks, and the reason its resolution is postponed here.
- [ ] **Resolve or reclassify the edit-tool feedback entry** -- once the metrics exist, decide from data whether the failures are an agent-prompting problem, a tool-contract problem, or a harness problem, and close the entry or convert it into a specific fix.

**Cross-references:** the liveness half is the "Subagent progress visibility" task above; the tool-call and `edit` halves touch the tool surface the `pi` provider exposes; the measurement output should follow the existing record conventions in `docs/operations/documentation_policy.md` (records state, not session history). Contrast the `team.ts`-style orchestration seams under M4.

---

## Notes

- Future milestone detail: [`roadmap_future.md`](roadmap_future.md).
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../docs/architecture/security.md).
