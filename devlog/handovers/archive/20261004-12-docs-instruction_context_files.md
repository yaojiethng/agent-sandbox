---
date: 2026-10-04
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Documentation
status: Closed
---

# Handover - Docs: the context each instruction folder assumes

## Objective

Give every instruction runtime path a context file that states what the agent can reach from it, and keep the file true with a gate.

## Scope

| In | Out |
|---|---|
| One `CONTEXT.md` per instruction runtime path, in the shape [`instruction-context-template.md`](../../docs/development/instruction-context-template.md) fixes | A rewrite of any prompt, skill or policy the files reference |
| The reachable set at folder level: the load condition, every path with its condition, and what is not reachable | A per-file reference audit. The operator's subject is the folder, not the links the files carry |
| `scripts/check_instruction_context.sh` and its registration in `scripts/lint.sh` | A check over prose links, comment paths or bash paths. That rule is unowned and is written back as an M3.3.1 row |
| `pi-bump` moved out of the provider-neutral skill root into pi's own folder | The rest of the step 2 triage, which reads these files |
| The stale provider-config transport records written back as an M3.3.1 row -- the defect this prefactor exposed | The revision pass itself |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | Every instruction runtime path carries a context file in the template's shape | `bash scripts/check_instruction_context.sh` names 5 files and is clean | accepted |
| 2 | The reachable set is written in full in every file, and the `always` rows are identical | the gate's drift check | accepted |
| 3 | A provider-neutral folder names no provider | the gate's marker check; the four neutral folders name `$AGENT_HOME` | accepted |
| 4 | `pi-bump` sits in pi's own folder and is not in the neutral skill root | `git status`, `ls src/reasoning/agent/skills/` | accepted |
| 5 | `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean | the two commands; 1068 passed | accepted |

## Hot files

| File | Why in scope |
|---|---|
| `docs/development/instruction-context-template.md` | the shape, the condition values and the provider-neutral rule |
| `src/reasoning/agent/prompts/CONTEXT.md` | the merged prompt root, provider-neutral |
| `src/reasoning/agent/skills/CONTEXT.md` | the provider-neutral skill root |
| `src/reasoning/providers/pi/config/agent/prompts/CONTEXT.md` | pi's own prompt folder, the only one that names pi |
| `src/reasoning/providers/pi/config/agent/skills/CONTEXT.md` | pi's own skill folder, created by the `pi-bump` move |
| `workflow/coding-agent/skills/CONTEXT.md` | the one folder with no runtime path |
| `src/reasoning/providers/pi/config/agent/skills/pi-bump/SKILL.md` | moved from the neutral skill root |
| `scripts/check_instruction_context.sh` | the gate |
| `scripts/lint.sh` | the gate registration |
| `tests/test_instruction_context.sh` | the gate's 16 cases |
| `devlog/roadmap.md` | two M3.3.1 rows closed, and two raised: the link-and-path gate, and the retired-transport records sweep this prefactor exposed |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The subject is the runtime path, not the source folder | `src/reasoning/agent/prompts/` and `workflow/coding-agent/prompts/` merge into `/opt/workflow/agent/prompts/`, so a file in each would collide and one would overwrite the other | the template; the gate's collision check |
| The reachable set is written in full in every file, not pointed at | a reader of one file should not need another; the gate compares the `always` rows so the copy cannot drift silently | the template; the gate's drift check |
| A provider-neutral folder names no provider, and `$AGENT_HOME` is the resolution for a provider's own home | the same folders ship in all three provider images, so a provider name in one is false in the other two | the template's condition table; the gate's marker check |
| `pi-bump` moves to `src/reasoning/providers/pi/config/agent/skills/` | the operator's direction: a pi-specific skill belongs in pi's folder, and pi discovers it from its own user directory without a settings entry | the M3.3.1 row; pi's skills document |
| `/opt/provider-config/` is recorded as not reachable | the operator's question, answered from the tree: the design record that removed the path settled it, and the code followed; the records did not | the two context files; the M3.3.1 sweep row |

## Decisions pending

None.

## Findings

- `/opt/provider-config/` was retired deliberately, and the records still describe it. The settled decision is [`20260512-design-settled-provider_config_ownership_and_loading.md`](../../discussions/archive/20260512-design-settled-provider_config_ownership_and_loading.md), landed in commit `930f6b2`; three architecture documents, `agent_workflow.md`, the `run_agent.sh` header, the compose path table and the hermes overlay comment were not swept. Five of them name `libs/provider-entrypoint.sh`, a path that moved to `src/`. Written back as an M3.3.1 row, because the sweep covers the skill and prompt config surface this sub-milestone owns; T10 keeps env resolution, argument resolution, the env load path, the CLI contract and the make contract.
- `src/reasoning/providers/hermes/config/config.yaml` reaches no image: no `COPY` line names the hermes config directory, and no overlay mounts it. The hermes overlay comment claims a seeding that nothing performs. The sweep row covers the finding; hermes may be dormant.
- `/opt/provider-config/` is a stale claim in two of the context files, recorded under `Not reachable` with the evidence.
- The pi provider overlay bind-mounts `$SANDBOX_DIR/.pi/agent/{prompts,sessions,skills}` into `$AGENT_HOME`, and the entrypoint then writes the image's config template over them at every start. A host edit under `$AGENT_HOME/skills/` is overwritten on the next start; the direction is stated in the pi skill folder's context file.
- The general prompt folder states `Not reachable: a relative link from a file here into docs/ or devlog/`. That is the M3.3.1 row `A shipped prompt reaches a repository path by a form that resolves`, restated as a fact rather than fixed.
- The operator raised a general rule while releasing the gate: markdown links, link-shaped items in comments, bash file paths, and counts in instruction files should name only targets in an allowed set. Raised as an M3.3.1 row.
- The `milestone-start.md` directive table and the handover format gate disagree on the type vocabulary: the table offers `Spec`, `Story` and `Investigation` and omits `Audit`, while the gate accepts the eight values in `handover_policy.md`. This handover hit it first, with `docs` written where `Documentation` belongs.
- `src/reasoning/agent/prompts/` is absent from the frontmatter gate's `ROOTS` in `scripts/lint/prompt-frontmatter.mjs`, while its sibling `src/reasoning/agent/skills/` is present. The M3.3.1 rename row covers the name, not this gap.

## Completed

| File | Change |
|---|---|
| `docs/development/instruction-context-template.md` | added: the five runtime paths, the required shape, the condition values and the provider-neutral rule |
| `src/reasoning/agent/prompts/CONTEXT.md` | added: the merged prompt root, provider-neutral |
| `src/reasoning/agent/skills/CONTEXT.md` | added: the provider-neutral skill root |
| `src/reasoning/providers/pi/config/agent/prompts/CONTEXT.md` | added: pi's prompt folder, the only file naming pi |
| `src/reasoning/providers/pi/config/agent/skills/CONTEXT.md` | added: pi's skill folder |
| `workflow/coding-agent/skills/CONTEXT.md` | added: the folder with no runtime path |
| `src/reasoning/providers/pi/config/agent/skills/pi-bump/` | moved from `src/reasoning/agent/skills/pi-bump/` |
| `scripts/check_instruction_context.sh` | added: identity checks, the `always`-row drift check, the provider-marker check |
| `scripts/lint.sh` | the gate registered in `GATES` |
| `tests/test_instruction_context.sh` | added: 16 cases |
| `devlog/roadmap.md` | two M3.3.1 rows closed, the link-and-path row raised, and the retired-transport records sweep held under M3.3.1 |

Roadmap maintenance did not run: M3.3.1 is `In progress` with open rows, and no completed sub-milestone still reads as active.
