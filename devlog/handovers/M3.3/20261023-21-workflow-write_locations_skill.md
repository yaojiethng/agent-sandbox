---
date: 2026-10-23
milestone: M3.3 - Instruction Surface
type: Workflow
status: Closed
---

# Handover - Write locations

## Objective

Give a fresh agent one place that answers where a file may be written, how long it lives and who can see it, and point the write discipline at it, so the choice of location stops being re-derived from a directory that disappeared.

## Scope

The provider layer's write-discipline paragraph in `AGENTS.md`, and the skill it points at. The paragraph carried two rules for one kind of file - throwaway verification - and no rule for the other kind, an instrument a later session reuses. The distinction was learned the hard way this session: an equivalence harness with 21 invocations lived in `.scratchpad/` and was gone when the container was replaced, exactly when the next unit needed it.

Out of scope: the harness-side change that would remove `.scratchpad/`'s dependence on a project's `.gitignore` rule. That is filed as **The session scratch depends on the project's ignore rule** under T7, because it is a start-path change with its own test, not a document. Also out of scope: a session-durable scratch root under `workspace/`. It was considered and dropped at the design step: only the tree is a volume, `workspace/` is the container layer, so such a root would need a second named volume per session, and it would still die at session end, which is the durability the lost harness actually needed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A skill states the roots, what each survives and who can see each | `src/reasoning/agent/skills/write-locations/SKILL.md`, `## The roots` | Agent [x] |
| The skill separates a throwaway check from an instrument a later session reuses | same file, `## The judgements`, first two entries | Agent [x] |
| The skill names the manifest as the source of the path list | same file, the paragraph after the table | Agent [x] |
| The write-discipline paragraph points at the skill instead of carrying both rules | `grep -n write-locations src/reasoning/providers/pi/config/agent/AGENTS.md` | Agent [x] |
| The installed copy states the same rule as the source | `diff <(sed -n 54p ~/.pi/agent/AGENTS.md) <(sed -n 54p src/reasoning/providers/pi/config/agent/AGENTS.md)` | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `.scratchpad/` stays | it is already session-durable, because the tree is a named volume; a scratch root under `workspace/` would need a second volume and would die at session end anyway | this record, and the skill's table |
| The location rule is a skill, not an `AGENTS.md` paragraph | the rule needs three axes - what a root holds, what it survives, who sees it - and a paragraph can carry one | the skill |
| The skill lives in `src/reasoning/agent/skills/` | the roots ship with agent-sandbox and not with a project, so a project convention-skill would hand a different image a table of mounts it does not have | this record |
| The vocabulary names what a location survives, never "durable" alone | a session-durable root and a host-visible one are both durable, and the difference is the whole answer | the skill, `## The roots` |
| The pointer is a link, not a code span | every instruction root in the image is reachable from every shipped surface, because the reach set is assembled from all cells' runtime paths; a hand read of the citing cell's own `reachable` rows suggests otherwise and is wrong | [`linking.mjs`](../../scripts/lint/linking.mjs) and `src/build/container-interface.mjs` `instruction_reach` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The session's only durable-by-session root is the tree, which is the named volume `...-sandbox-data`; `/home/agentuser/workspace` is the container's overlay, and only `input/`, `output/` and `session-diffs/` are host binds, so a `workspace/tmp` written today would be as durable as `/tmp` | environment | a proposal to make the agent's scratch root live under `workspace/` would have bought nothing without a new named volume, and would still not survive the session | the decision above; no row |
| `.scratchpad/` depends on the sandbox project's own `.gitignore` rule, and nothing writes `.git/info/exclude` today, so a delivered project whose ignore file lacks the rule shows the agent's scratch as untracked files | mechanism | an agent's scratch can surface in a project's `git status`, and a `git add -A` can carry it into a commit | the roadmap's new **The session scratch depends on the project's ignore rule** row under T7 |
| The installed skill root `/opt/workflow/agent/skills/` is baked into the image, so the new skill is loadable once `make build` runs and not before; this container's copy predates it | environment | the pointer in this session's installed `AGENTS.md` names a path that exists only in the tree | flagged; unchanged by this iteration, and the same blocked build item as the dispatch library |
| The reach set was read by hand and answered wrongly: the citing cell's own `reachable` rows name `/opt/workflow/agent/config/` and the pi install, so a link to the harness skill root looked illegal, while `instruction_reach` builds the image set from every cell's runtime path and admits it | process | a code span was written on an inference, and one gate run would have settled it; the wrong inference then entered this record as a finding, which is the worse cost | corrected here: the pointer is a link, and the decision row above states the rule that made it legal |

## Completed

| File | Change |
|---|---|
| [`src/reasoning/agent/skills/write-locations/SKILL.md`](../../src/reasoning/agent/skills/write-locations/SKILL.md) | new: the roots table with its two axes, four judgements, non-goals and four failure modes |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the write-discipline paragraph keeps `.scratchpad/` and names the skill for the rest |
| `$AGENT_HOME/agent/AGENTS.md` | the installed copy carries the same paragraph |
| [`devlog/roadmap.md`](../roadmap.md) | new T7 row for the scratch root's ignore rule |
