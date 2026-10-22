---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - a fixed writing advisor for the policy slices

## Objective

Give the policy-retirement slices one writing and structure advisor with a fixed brief, so every slice review starts from the same instruction instead of a hand-written one.

## Scope

Every review pass over a policy slice was dispatched with a hand-written brief. The advisors were consistent with each other; the briefs were not, and each got some checks right and omitted others. The practice has now run across many handovers in this milestone.

The artifact is a prompt template, `doc-advisor-policy.md`, exposed as `/doc-advisor-policy`. Its brief is specialized to this use case rather than general: cut nothing that carries a rule, find repeated and misattributed and inconsistent content, and report what could not be shortened.

It lives in the provider layer at `src/reasoning/providers/pi/config/agent/prompts/`, the directory pi auto-discovers and the entrypoint re-seeds into `$AGENT_HOME` at every container start. No `settings.json` key is involved, because `~/.pi/agent/prompts/` is a default discovery location and does not need one.

**Split, and the order.** The dispatch mechanism was drafted here and split out on operator direction (2026-10-15). The brief and the dispatch are two outcomes: handover `20261014-13` owns the `pi-reviewer-dispatch` skill, its script and its test, and this unit owns the brief. The dispatch lands first, because this unit's end state calls it, so this record opens as `Open` and closes after `20261014-13`.

This unit's remaining work is that call. The dispatch prose in the prompt's steps 3 and 4 is a placeholder that works; it becomes a call to the skill, leaving no model id and no invocation mechanics in the prompt.

Out of scope: the four draft review prompts under `workflow/coding-agent/drafts/`, whose cleanup is M3.2.2; a general-purpose document advisor; any change to a maintenance skill; and the review of a specific slice, which this artifact exists to serve.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `/doc-advisor-policy` appears as a command after a reload | operator's command list | Operator [x] |
| The template sits where pi discovers it, with no `settings.json` key needed | `ls src/reasoning/providers/pi/config/agent/prompts/`; the seeded copy beside it | Agent [x] |
| The seeded source and the running copy agree | `diff` the two files | Agent [x] |
| The brief carries every section it must, with none left to the dispatcher's judgement | read it | Operator [x] |
| The prompt's dispatch steps are a call to the `pi-reviewer-dispatch` skill, with no model id and no invocation mechanics left in it | `grep` the prompt for a model id and for `--provider` | Agent [x] |
| A slice reviewed through it returns findings the operator can check claim by claim | the first slice reviewed through it | Pushed - only a review can settle it |
| Lint is clean and the suite is green | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prompt holds the brief, rather than a skill or a draft | the operator invokes it and the agent dispatches from it; a draft under `workflow/coding-agent/drafts/` is not loaded into a session | this handover |
| The name is specialized to the policy campaign | the artifact exists for one campaign and the operator directs its removal; a general name would claim a permanent surface | this handover |
| The paths and the instructions are hardcoded, with no argument | a fixed brief is the point; an argument reopens the per-pass inconsistency the artifact exists to remove | this handover |
| pi's own `AGENTS.md` names `$AGENT_HOME` as the agent's configuration home, and drops the claim that a project-level `.pi/settings.json` override takes precedence | the two statements pointed in opposite directions once the new line landed, and the override names a path that is gitignored and absent for this project | this handover; provider `AGENTS.md` |
| The brief asks each finding to be labelled measured, inferred or guessed | an unlabeled claim is the one a dispatcher must re-run, and every finding this milestone that was later refuted was one; the label makes the verification step cheap | this handover; the brief |
| The prompt names the dispatch skill rather than describing it | the dispatch has one home, the skill, and a prompt that restated it would be a second copy to reconcile | this handover |
| The template lives in the provider layer's `prompts/` directory | `~/.pi/agent/prompts/` is a pi default discovery location, so the file needs no `settings.json` key; the image bakes the source and the entrypoint re-seeds it every start, so it survives a container end | this handover; [`provider_lifecycle.md`](/opt/sandbox/docs/reference/provider_lifecycle.md) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The handover for this iteration was reported as written at the scope gate and did not exist. The claim was made before the file was created, and the operator read it as fact. | process defect | current iteration |
| A `dispatch.sh` was drafted under `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/` before the split, with no `SKILL.md` beside it and no test. It belongs to the split-out unit, and leaving a script with no skill in the tree reads in a review as an accident. | scope | split out; its shape is recorded in the roadmap row |
| The roadmap records themselves still fall short of the writing bar. The operator has candidates for where the problems are and will test them next iteration; the concern is deliberately out of scope for this one. | steering | not this iteration |
| The brief asked for findings but not for the evidence behind them. Every finding this milestone that was later refuted was an unlabeled inference presented as fact, and both advisory reviews of this unit recommended a claim label independently. | gap | corrected in this iteration, on operator direction |
| The loading mechanism was first written into the seeded provider config and the running copy as a `settings.json` `prompts` key naming `.agents/prompts/`. A user setting's resource path resolves from the agent directory, so it resolved to `~/.pi/agent/.agents/prompts/` and loaded nothing. The key is reverted in both files. | defect | corrected in this iteration |
| The second attempt put the key in a project `.pi/settings.json` and changed `.gitignore` to let it commit. That route is worse: `.pi/` is gitignored, and the working tree is the untrusted snapshot rather than the provider config. Both are reverted. | defect | corrected in this iteration |
| An edit to `$AGENT_HOME/agent/settings.json` lasts only until the container ends, because the entrypoint re-copies the image's config over it at every start. Anything that must persist belongs in `src/reasoning/providers/pi/config/agent/`, not in the running copy. | constraint | recorded above |
| `.agents/skills/` is discovered by pi from the working directory and its ancestors, but `.agents/prompts/` has no equivalent discovery rule, so a project-scoped prompt cannot be loaded the way a project-scoped skill is. | constraint | recorded above |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/prompts/doc-advisor-policy.md` | created: the fixed brief for a policy-slice writing review, and the dispatch and handling steps around it |
| `/home/agentuser/.pi/agent/prompts/doc-advisor-policy.md` | the same file, running copy; the two agree |
| `src/reasoning/providers/pi/config/agent/settings.json` | the `prompts` key was added and reverted, because a user setting's path resolves from the agent directory |
| `/home/agentuser/.pi/agent/settings.json` | the same key, added and reverted |
| `.pi/settings.json`, `.gitignore` | a project-setting route was attempted and reverted |
| `.../prompts/doc-advisor-policy.md` | the dispatch prose in steps 3 and 4 replaced by a call to the `pi-reviewer-dispatch` skill, and a claim-label rule added to the brief; 79 lines to 54, and no model id or invocation remains |
| `/home/agentuser/.pi/agent/prompts/doc-advisor-policy.md` | the same file, installed; the two agree |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the `## Scope` table's `$AGENT_HOME/` row names `/home/agentuser/.pi` and where configuration goes; the model-resolution rung 2 reads `$AGENT_HOME/agent/settings.json` and drops the project-override clause |
| `/home/agentuser/.pi/agent/AGENTS.md` | the same file, installed; the two agree |
