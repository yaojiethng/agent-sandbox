---
date: 2026-10-15
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Workflow
status: Closed
---

# Handover - the reviewer dispatch

## Objective

Give every review dispatch on any subject one mechanism: a fixed set of reviewers, one brief-passing form, and preconditions that refuse a run rather than trusting the caller.

## Scope

A review dispatch is a read-only delegated run. It takes a brief, holds judgement against it, and returns a report. It writes nothing, so its only evidence is its log and its session file. This project runs such dispatches constantly, and each one was written by hand from the provider `AGENTS.md` prose.

The unit is a provider-layer skill at `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/`.

| Part | What it holds |
|---|---|
| `SKILL.md` | the constrained reviewer as a contract, and the pi form as a hint |
| `dispatch.sh` | the preconditions, the pair dispatch, and the three result checks |
| `tests/test_pi_reviewer_dispatch.sh` | the refusals, and a stubbed `pi` for the dispatch path |

**The contract**, which is what makes the subagent constrained rather than general: read-only, no edits and no commits; one brief file passed verbatim, and the brief is the only variable; a model and a thinking level the caller pins; a report in the brief's shape; its own session file and log; the effective model read back from the session file; and two of them agree or disagree, where agreement is the signal.

**The hint**, after the `setup-pstack` pattern of a generic contract with a conditional fast path for the tool at hand. When pi is the calling agent, the invocation is `pi --provider <p> --model <id> --thinking <l> --session <path> -p "$(cat brief)"`; both reviewers run in the foreground of one call; and the full model id matters because `--model` is a substring match that silently takes the last match.

**The migration.** The provider `AGENTS.md` `## Running Review Subagents` keeps only what a script cannot hold, which is the role resolution order, the attribution rule, the model-selection quirk and the orphan rule. The mechanics move into the skill.

The plugin split from the fixed-brief unit, handover `20261014-14`, on operator direction (2026-10-15). That unit's end state calls this skill, so this one lands first.

Out of scope: a general-purpose document advisor; the four draft review prompts under `workflow/coding-agent/drafts/`, whose cleanup is M3.2.2; the worker fan-out shape, which the harness owns through the `taskq_*` tools; and the write-back of any review's findings.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill sits at the provider path, and the seeded source and the running copy agree | `ls`; `diff -r` | Agent [x] |
| `SKILL.md` states the constrained-reviewer contract in full and carries the pi form as a hint, after the `setup-pstack` pattern | read it | Operator [x] |
| `dispatch.sh` refuses a missing brief, an empty brief, an absent or unwritable scratch directory, and a dirty tree | `bash tests/test_pi_reviewer_dispatch.sh` | Agent [x] |
| The pair runs in one call at both full ids and `high`, and the run reports the effective model read from each session file | read the script; the test's stub | Agent [x] |
| The scratch directory is defined in the provider `AGENTS.md` and passed to the script as a required argument, so the script carries no default to drift from it | read both | Operator [x] |
| The general dispatch mechanics live in `## Fresh Subagent Invocation`, so no dispatch type loses them, and `### Keeping a subagent alive` reaches every dispatch | read the section | Operator [x] |
| `AGENTS.md`'s `## Running Review Subagents` keeps only what a script cannot hold, and points at the skill | read it | Operator [x] |
| Lint is clean and the suite is green | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The dispatch is a provider-layer skill, not a harness library | it invokes the `pi` CLI, so it is provider-specific, and `src/libs/` ships to `/opt/sandbox/lib/` as the provider-agnostic harness layer | this handover |
| The name is `pi-reviewer-dispatch` | it names the constrained kind, a reviewer, rather than the general mechanism, and the `pi-` prefix records the provider whose invocation it carries | this handover |
| The skill carries a script beside its `SKILL.md` | a provider skill directory ships whole, so a script beside the skill is present in the image; and the clean-tree precondition becomes a refusal in code rather than a sentence a caller may skip | this handover |
| Two reviewers on two fixed models, both at thinking level `high`, and no role-tag lookup | operator direction: a fixed pair is the consistent dispatch the unit exists for, and the `_ADVISOR` tag names one model rather than a pair. The ids are the effective models from the passing runs, `openrouter` with `z-ai/glm-5.3-flash` and `opencode-go` with `step-5-preview-free`. This departs from the provider layer rule that model choices live in the recommendations file, so the ids are recorded as an operator decision rather than a recommendation. | this handover; the skill |
| The test injects a stub `pi` through `PATH`, and the script gains no flag for it | the house rules forbid a speculative flag, and no production caller would pass one | this handover |
| The worker fan-out stays with the harness | one worktree per task, a protocol directory and a break-point handshake are the `taskq_*` tools' shape; a shell script would rebuild a surface that exists | this handover |
| The scratch directory is a chain, not a constant: the provider `AGENTS.md` defines the path, the skill states the dependency and names no value, and the script takes it as a required argument | one home for the value, and no default in the script to drift from the definition | this handover; the skill |
| The general dispatch mechanics move to `## Fresh Subagent Invocation`, and the review section narrows to what is review-specific | the mechanics were general but their only home was the review section, so deleting them there would have left an implementer dispatch with no worked example, and `### Keeping a subagent alive` read as a reviewer rule although the orphan rule governs every subagent | this handover; provider `AGENTS.md` |
| The records for this work are `20261015-01` and `20261015-02`, not `13` and `14` | the index resets daily, and the date rolled to 2026-10-15 during this session; delivery order is preserved, because the dispatch takes `01` and the brief takes `02` | this handover; Findings |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The day's index rule assigns `NN` as `max + 1` over the day's existing records, which makes the index a record of creation order rather than delivery order. Delivery order is the property that matters here, because a unit that lands first is the one a later unit depends on. Relaxing the rule is recorded as its own roadmap row. | rule gap | raised as a row |
| A `dispatch.sh` was drafted under this skill's directory before the split, with no `SKILL.md` beside it and no test. The `check_shell.sh` gate caught a declared-and-unused variable in it, which is the gate working. | defect | corrected in this iteration |
| The `## Running Review Subagents` section restated in prose a ritual the provider `AGENTS.md` already loads, so every dispatch carried the mechanics twice. | duplication | corrected in this iteration |
| The instruction-surface gate refused the new `/tmp/` row in the `## Scope` table until the manifest declared it as a session row. The gate is doing its job: a path the layer claims must be a path the container declares. | defect | corrected in this iteration |
| Adding the scratch directory first went in as a table row without a manifest entry, so the layer table and the container interface disagreed until the gate caught it. | defect | corrected in this iteration |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/pi-reviewer-dispatch/dispatch.sh` | drafted before the split; shellcheck-clean |
| `devlog/roadmap.md` | the row **The reviewer dispatch is one mechanism, not a ritual per caller**, raised, and the index-relaxation row |
| `devlog/handovers/20261014-14-workflow-doc_advisor_policy.md` | renamed to `20261015-02`, re-scoped to the brief, and its dispatch prose recorded as this unit's migration target |
| `.../skills/pi-reviewer-dispatch/SKILL.md` | created: the constrained-reviewer contract, the pi hint, the scratch-directory dependency, four steps with completion criteria, non-goals and failure modes |
| `.../skills/pi-reviewer-dispatch/dispatch.sh` | rewritten to take the scratch directory as a required argument, with the four refusals, the one-call pair dispatch and the three result checks |
| `tests/test_pi_reviewer_dispatch.sh` | created: 7 cases, 24 assertions, a stubbed `pi` injected through `PATH` |
| `src/build/container-interface.json` | a `/tmp/` session row, so the layer table's scratch-directory row is a declared container path |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the `/tmp/` Scope row; `## Fresh Subagent Invocation` gains the general dispatch mechanics and the resuming fact, with `### Keeping a subagent alive` beneath it; `## Running Review Subagents` narrows to what a script cannot hold |
