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

#### T1 - Workflow + Policy Organization

- [ ] **Autonomous execution framing** -- define the Task Brief format (`TASK.md`, placed in `SANDBOX_DIR/.agent-input/input/` per the M1.5 input channel) and the agent execution lifecycle for a single headless run
- [ ] **Close-milestone automation** -- replace the manual administrative close checklist with `make close-milestone`, which atomically bumps milestone state in one clean commit (close is ceremonial; all substantive work sits in pre-close per the milestone lifecycle reframe)
- [ ] **AC-machinery policy for chores / doc / plan sessions** -- define how the acceptance-criteria machinery applies when a session type has no standard AC
- [ ] **Process improvements** (deferred from M2.7) -- fast-track criteria, decision recording rigor, stale-skill-reference cleanup
- [ ] **Loop-documentation structure decision** -- decide whether major/minor loop docs need a structural split (e.g. `major_loop_policy` / `minor_loop_policy`), its form, and the canonical milestone_policy / iteration_policy boundary. Deferred from session `20260809-04`. The milestone_policy expansion to own the whole major loop rides on this.
- [ ] **Formal state diagram of the major/minor loop workflow** -- a state diagram covering scoping -> story/investigation -> roadmap entry -> minor-loop handoff -> pre-close -> formal close, with minor-loop iterations in the handoff. Supports the loop-doc restructure. Deferred from `20260809-04`.
- [ ] **Separate the new-iteration workflow into `workflows/`** -- move iteration-specific instructions out of `AGENTS.md` and the shared policies into standalone workflow-bundled policy files (the `workflow/knowledge-vault/` bundling is the precedent). Keeps the shared governance surface minimal; enables future workflows (plan, policy-change, autonomous-iteration).
- [ ] **Coding-agent workflow consolidation** -- per [`workflow/coding-agent/audits/surface-area-report.md`](../workflow/coding-agent/audits/surface-area-report.md): one canonical prompt per use case; merge the handover-audit pair; fold useful `kelsey-code-reviewer.skill.md` checks into `bash-audit.skill.md`; drop non-current Claude-format imports (`dhh-code-audit.skill.md`, `architecture-doc-reviewer.skill.md`); relocate `toc.sh` out of skills; rename/dissolve `drafts/`. For the documentation-audit use case, one pi-native prompt per [`audits/documentation-audit-comparison.md`](../workflow/coding-agent/audits/documentation-audit-comparison.md), absorbing `architecture-doc-reviewer.skill.md` and `documentation-pass.md`. This extends to authoring the `new-iteration` prompt surface and, per operator direction, major-loop-start / major-loop-wrapup prompts.
- [ ] **Git policy rewrite: bind commit-message body length and reference scope** (shelved from M2.6, raised `2026-09-18`) -- rewrite `docs/operations/git_policy.md` Body/footer to state a tight body budget (why-not-what), forbid redundancy with the handover attribution, and require every reference to earn its place.
- [ ] **Review-pass framing fixes** -- three refinements to review-pass framing, each tracking a live [AGENT_FEEDBACK](AGENT_FEEDBACK.md) `2026-09-18` entry: (1) round-cap / blocker-re-review fits correctness reviews, a model-consensus quality pass one round per model (entry `Review-loop round-cap guidance`); (2) name the base commit / exact `git diff` range in a review directive (entry `Name the base commit`); (3) name an edit target with a seeded/runtime copy pair by full path with the authoritative copy stated (entry `pi's AGENTS.md is ambiguous`).
- [ ] **Evidence-validation (verification) discipline** -- one shared rule family: validate evidence before trusting a conclusion. Four sub-cases, each a live [AGENT_FEEDBACK](AGENT_FEEDBACK.md) entry: reviewer remedies as hypotheses to verify with a repro (`Subagent review remedies`); `bash -n` + intended-failure reason after a negative-test mutation (`Negative-test mutations`); a filtered summary that gates a conclusion validated against unfiltered output (`Filtered diff trees identical`); an in-place suite-claim correction carrying a certified rerun (`suite-green correction`). The shared durable fix is a validation-discipline section in the testing/conventions doc.
- [ ] **Record write-back gate** -- a workflow gate verifying that a claimed record actually landed (row-key / content grep in the same turn), analogous to but distinct from the roadmap write-back gate. Resolves the recording/findings discipline family: findings churn + under-recording, throwaway stray files in the repo tree, a feedback follow-up note that is not a task assignment, and assert-without-write slips.
- [ ] **Prompt-scope discipline** -- a campaign or review prompt must not contradict its own success criteria (a prompt whose scope statement conflicts with what it is instructed to deliver). Resolves the campaign-prompt-scope family.

- [ ] **WIP-commit policy** -- document in `docs/operations/git_policy.md` and the provider-layer `AGENTS.md` when mid-iteration WIP commits are acceptable (standard practice, not an exception) and that the delivery commit at iteration end still carries the type prefix. Raised from this planning iteration's WIP commit.

#### T2 - Perf

The parent finding (cost, throughput, and failure modes are invisible for subagent runs and tool calls) is tracked in [AGENT_FEEDBACK](AGENT_FEEDBACK.md) `2026-09-20 -- A subagent review pass is expensive and unmeasured`. Measurement output follows the record conventions in `documentation_policy.md`.

- [ ] **Subagent run telemetry** -- emit a persisted per-run record for a `pi -p` invocation: model and thinking level, timestamps, wall-clock, tokens in/out, throughput, per-request latency, tool-call count and duration, agent turns. Surface at run end.
- [ ] **Subagent liveness** -- a signal readable while the run is in flight distinguishing "progressing" from "stalled on provider/network", sharing one instrument with the telemetry record
- [ ] **Time attribution** -- split wall-clock into model time, tool-execution time, and harness overhead, so a slow review is attributable (provider vs tooling vs orchestration)
- [ ] **Tool-call telemetry** -- count every tool call by name and outcome with duration and per-tool failure rate
- [ ] **`edit`-tool failure metrics + feedback resolution** -- count and classify every failed `edit` call by cause (text not found, ambiguous match, overlapping/nested regions, unread/renamed file, missing `path`), record follow-up cost, and surface per-type frequency for triage. Then resolve the [edit-tool collation entry](AGENT_FEEDBACK.md) and its write-land-reflex / overwrite-vs-append family from data (agent-prompting vs tool-contract vs harness problem), distilling the findings into AGENTS.md edit-tool steering.

#### T3 - Backpressure

The copy-delivery Markdown `pre-commit` hook is the first instance ([`git_hooks.md`](../docs/adr/git_hooks.md)); mount delivery carries no hook under the current delivery constraint. The test-family split landed in handover `20260920-03`.

- [ ] **Mount-delivery hooks (constraint change)** -- git hooks for mount delivery require changing the delivery model's host-exposure constraint (an agent-writable hook in the mount `.git` executes on the host). The constraint change and its security cost are the deliverable; implementation follows only if the constraint changes.
- [ ] **ShellCheck as a git hook** -- extend the commit hook to run the ShellCheck gate over staged shell files, giving shell rules the same commit-time backpressure as the Markdown rules
- [ ] **Doc-format lint rules** -- add lint coverage for the documentation-format discipline: a rule detecting manually column-wrapped prose (hard-wrapped instruction blocks; the `MD013` line-length rule is disabled per the no-wrap policy, so the wrap has no detector). Resolves the hard-wrapped-instruction-blocks and editing-a-doc-whose-own-policy-forbids families; the plain-ASCII `doc-ascii` rule already covers non-ASCII.
- [ ] **Sourced-lib / library lint rules** -- a lint check that sourced-library functions (`src/libs/`, `src/build/`) use `return`, not `exit`, and that sourced-lib reads do not redirect from unguaranteed paths (the conventions-doc rules from the M3 feedback close). Resolves the [!H] library `return`-not-`exit` family.
- [ ] **Tool timeout / run budget** -- do we need a max-time timeout on the `bash` tool? Arbitrary one-off bash scripts, `make test`, and lint are the common hang sites. Minimally, test and lint should carry a maximum-time timeout; `sleep` should never be used; `timeout` may be used only with a correct invocation (some invocation forms always wait the maximum). Resolves the mechanical-edit-one-liner-hang family.

#### T4 - Library Migrations

- [ ] **Evaluate whether make still earns its place; if not, assess substitutes** (surfaced from handover `20260919-15`) -- make serves as a directory-based script wrapper, jerry-rigging arg parsing (`PROVIDER=pi` vs `--provider=pi`) and carrying a second invocation idiom whose help/error surfaces must match the CLI. The original reason (command too long) is weakened by `.env` identity resolution. The evaluation is the deliverable; a removal decision is a separate follow-up.
- [ ] **Atomic install + semantic versioning for the agent-sandbox utility** -- write to a temp file, verify, then `mv` into place; give the installed artifact a semantic version. Independent of the make-wrapper decision; applies to any install path. This is the harness-sig item (`devlog/roadmap_future.md` "Harness Packaging and Versioning"): self-contained binary + semantic versioning for runtime-drift detection.
- [ ] **Nushell rewrite evaluation** (moved from M2 not-in-scope) -- evaluate whether rewriting host-side tooling in a cross-platform structured-data language (nushell) removes the GNU/BSD host difference at justifiable cost, against the `scripts/install.sh` requirement gate and portable call sites. See `docs/development/host_requirements.md`.
- [ ] **Official bash unit-test harness evaluation** -- evaluate moving the repository's self-built test harness to an official bash unit-test harness

#### T5 - Archival

- [ ] **Roadmap mechanism: linear-style task tracking** -- full linear/management-app redesign. The handover next-session trim and always-push-to-roadmap behavior are scoped for immediate implementation outside M3; only the linear format remains.
- [ ] **Roadmap-mechanism rewrite study** -- study the roadmap/management mechanism against OpenAI's Symphony spec and evaluate which features to borrow; the linear-style design above is the fold point for agreed borrowings.
- [ ] **Next-task placement** -- move the next-session seed out of the handover into a next-task subheader in the sub-milestone (handover next-session trim is immediate; the subheader placement rides on the linear format)
- [ ] **Rotate out stale handovers and discussions** -- completed-milestone handovers and graduated stories are archived to a git tag or branch and removed from `HEAD`; the roadmap, architecture docs, and changelog remain the permanent record.
- [ ] **Session (chat) log + generated-artifact archival** -- define storage rules for chat logs and any generated artifacts (perf logs, metrics) the pipeline starts producing; see `20260428-story-active-sequencing_and_knowledge_persistence.md`.

#### T6 - Performance Optimizations / UI Tweaks

- [ ] **Pre-snapshot validation gate** -- configurable per-project check run by `start_agent.sh` before building `.agent-input/`; fail fast before the container starts
- [ ] **Structured task logs** -- store structured logs per agent and task run (overlaps the T5 generated-artifact storage task)

#### T7 - Harness Specialization / Sandbox Persistence

- [ ] **Skill-maintenance backlog triage** (raised [AGENT_FEEDBACK](AGENT_FEEDBACK.md) `2026-09-20`) -- give the backlog a roadmap home: fold the three bash `set -e` language-limitation entries into `bash-coding-conventions.md` or a bash skill, distill the edit-tool collation entry into AGENTS.md edit-tool steering, write the pending circular-sourcing ADR, then close or probation each backlog entry whose fix landed.
- [ ] **Proper skill installation; fork-and-strip convention** -- install each upstream skill, fork it, and strip provider-specific quirks (Claude `subagent_type=Explore` is not pi's `pi -p`). Concrete instance: [`improve-codebase-architecture/SKILL.md`](../src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md) references a Claude-only Agent-tool API. Fix that instance and define the convention. Surfaced from session `20260812-09`.
- [ ] **Commit-metadata capture** -- capture agent_id, task_id, timestamp with each commit; prerequisite for trusting autonomous output and for the M4 metadata-seeding milestone
- [ ] **Environment-change persistence (install layers across runs)** -- apt installs, `pi update --self`, and `pi install` land in the per-run writable layer and tear down at run end; the copy/bind-mount model persists only mounted sources. Parked as not-in-scope for the current model (`roadmap_future.md` Deferred); revisit whether a persisted install-cache volume (durable-by-designation) is now worthwhile.
- [ ] **Functional-stack navigation for questioning** -- a harness/behavioral design to keep a working "call stack" of the task context: the agent tracks the stack, emits keyword hints, and exposes navigation functions (abandon -> unwind, continue at same depth, resolve current, skip/drop current) when an operator question spawns. Resolves the multi-question-turns / implicit-acceptance grill-me family. Design proposal.

#### T8 - Documentation

- [ ] **STE-clean sweep of the existing doc and policy body** -- deferred from `20260809-03`; new and changed documents are already drafted to ASD-STE100, so the sweep is now a backlog over the remaining body, not a body-wide rewrite. Apply the standard to the docs, policies, and agent files that predate it. Includes the record-layer drafting discipline (propose a skeleton and get it confirmed before writing prose; records state, not session history), resolving the record-layer-docs-as-reasoning-traces family.

---

## Notes

- Future milestone detail: [`roadmap_future.md`](roadmap_future.md).
- Security guarantees and current threat model are defined in [`docs/architecture/security.md`](../docs/architecture/security.md).
