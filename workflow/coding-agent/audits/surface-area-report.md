# Coding-Agent Workflow Surface Area

This report categorizes the coding-agent workflow files -- the skill files and prompt templates that drive agent behavior. It covers the former `src/reasoning/agent/drafts/` and `src/reasoning/agent/prompts/` surface at their post-relocation homes, plus the campaign and documentation-pass files. It also carries the entrypoint map: the kickoff paths an operator can invoke, what each produces, and where the output goes.

The envisioned future state: a targeted workflow file for each current use case, one canonical file per use case, non-current use cases dropped. This report is the input for the M3 reorganization task (`devlog/roadmap_future.md`, M3 section).

## Inventory

| File | Use case | Status | M3 target |
|---|---|---|---|
| [`gm.md`](../prompts/gm.md) | Kickoff: check-in -- survey the project state, present a work inventory, wait for direction | Current, canonical (rewritten 2026-09-11) | Keep |
| `prompts/iter.md` | Kickoff: open an iteration with a known directive -- scope gate and release gate | Current, canonical | Keep; the loop workflow for the M3.2.1 migration |
| `prompts/agent-sandbox.md` | Meta: redirect harness questions to `/opt/sandbox/docs/` | Current | Keep |
| `prompts/` (wrapup removed) | Close: superseded by `iteration_policy.md` Steps 7-9 and the transient-commits rule in `git_policy.md` | Removed 2026-09-24 | -- |
| `prompts/package-branch.md` | Export: package committed history as diffs for review (`/package-branch`) | Current, tool-backed | Keep |
| `prompts/defer.md` | In-iteration: write an adjacent issue back to the roadmap as an open row | Current, canonical | Keep |
| `prompts/propagation-check.md` | In-iteration: verify a cross-file change reached every consumer | Current | Keep; AGENTS.md carries the checklist discipline, this file is the audit invocation |
| `drafts/bugfix.skill.md` | In-iteration: structured diagnosis of a systemic bug across a chain | Current | Keep |
| `drafts/refactor-mv-rename-file.skill.md` | In-iteration: atomic file move/rename procedure | Current | Keep; complements the AGENTS.md rename rule |
| `drafts/recovery.skill.md` | State repair: recover committed artifacts after a reset or policy violation | Current | Keep |
| `drafts/roadmap-management.skill.md` | State maintenance: mutate `roadmap.md`/`changelog.md` per policy | Current | Keep; natural pair with `roadmap-audit` -- management mutates, audit verifies |
| [`audits/audit.skill.md`](audit.skill.md) | Audit: closed-handover review -- deferred chains, close sequences, dangling references | Current, formalized | Merge with `handover-audit.skill.md` into one canonical handover audit |
| [`audits/test-quality-campaign.md`](test-quality-campaign.md) | Audit: test suite vs `testing_policy.md` and `testing-conventions.md` -- fix + report campaign, run by a fresh subagent | Current, canonical | Keep |
| [`audits/handover-audit.skill.md`](handover-audit.skill.md) | Audit: handover content-quality rules (procedural, migrated out of `handover_policy.md`) | Current use case, draft form | Merge into the handover-audit pair above |
| [`audits/bash-audit.skill.md`](bash-audit.skill.md) | Audit: bash code vs `bash-coding-conventions.md`, read-only one-shot | Current, canonical | Keep; absorb the useful checks from `kelsey-code-reviewer.skill.md` |
| [`audits/kelsey-code-reviewer.skill.md`](kelsey-code-reviewer.skill.md) | Audit: bash/Dockerfile review against production-shell standards | Non-current -- Claude-format import | Port useful checks into `bash-audit.skill.md`, then drop |
| [`audits/roadmap-audit.skill.md`](roadmap-audit.skill.md) | Audit: roadmap compliance with `roadmap_policy.md`, compaction prep | Current, canonical | Keep |
| [`audits/architecture-doc-reviewer.skill.md`](architecture-doc-reviewer.skill.md) | Audit: doc staleness and scope-honesty review | Non-current -- Claude-format import | Merge its purpose into the roadmap task "Architecture-doc staleness sweep", then drop |
| [`audits/dhh-code-audit.skill.md`](dhh-code-audit.skill.md) | Audit: Ruby/JS code review against DHH standards | Non-current -- no Ruby or JavaScript in this repo; Claude-format import | Drop |
| [`audits/documentation-pass.md`](documentation-pass.md) | Audit: document sweep vs `documentation_policy.md` via diagnostic checklists | Current use case, stub form (checklists only; procedure expansion deferred) | Keep; expand into a full procedure when first run |
| `drafts/toc.sh` | Utility: print a markdown header outline with line numbers | Current, used | Relocate with the scripts, not a skill |

## Format divergence

Two generations coexist. Pi-native skills are markdown with `# Skill --` headers and prose procedure. Claude-format imports carry YAML frontmatter with `name`, `description`, `tools`, and `model`, plus `<example>` blocks. The three imports (`architecture-doc-reviewer`, `dhh-code-audit`, `kelsey-code-reviewer`) reference Claude tool APIs -- Glob, Grep, LS, TodoWrite, WebFetch, BashOutput, KillBash, `model: opus` -- that do not exist in pi, so they were never deployable as pi skills. The M3 fork-and-strip convention (`devlog/roadmap_future.md`, M3: the `improve-codebase-architecture` case) covers importing upstream skills: fork, strip harness-specific quirks, maintain locally.

## Naming inconsistencies

- `audit.skill.md` is titled "Handover Audit" inside, and `handover-audit.skill.md` covers the same use case in draft form. Two files, one use case. The M3 merge picks one canonical name.
- `dhh-code-audit.skill.md` carries frontmatter `name: dhh-code-reviewer`; filename and internal name disagree. Moot if the file is dropped.

## Entry point map

The operator-invoked entry points, per use: when to use each, what it produces, and where the output goes.

| Entry point | Invoke when | What it produces | Where the output goes |
|---|---|---|---|
| [`prompts/gm.md`](../prompts/gm.md) (`/gm`) | A check-in: no task chosen yet. Survey the state, present a work inventory, recommend a direction, wait. | Survey findings and an inventory in chat. No files written. | Chat only; the next step is a new iteration with a handover. |
| [`prompts/iter.md`](../../../workflow/coding-agent/prompts/iter.md) | A directive is known: open an iteration properly. Gates on scope confirmation and acceptance before close. | One handover in `devlog/handovers/`, scoped work, one delivery commit. | Handover file + commit. |
| [`drafts/sequential-work.md`](../drafts/sequential-work.md) (`/sequential-work`) | A released plan names its units: run them one at a time through fresh subagents, verifying each return before the next dispatch. | One commit and one handover per unit, with the verification evidence in chat. | Repository records and commits; the subagent's report stays in chat. |
| [`drafts/review-loop-run.md`](../drafts/review-loop-run.md) (`/review-loop-run`) | A committed range needs a verdict: a fresh reviewer per round, ACCEPT or BLOCK, one fix round per block, capped at three. | A verdict per round, the fix commits, and a final report with the open blockers. | Chat and the iteration's handover; the fix commits ride the branch. |
| `audits/*.skill.md`, `audits/test-quality-campaign.md` | A specific review target: code, bash, handover, roadmap, docs, tests. | Findings or a fix proposal, per the audit's contract. Some audits fix (campaign); most are read-only. | Report in chat or the output mount; accepted findings become iteration work. |

## Deployment boundary

The deployed agent surface (`/opt/workflow/agent/`) is: `src/reasoning/agent/skills/`, `src/reasoning/agent/prompts/`, `workflow/coding-agent/prompts/` (folder COPYed into `/opt/workflow/agent/prompts/` by each provider dockerfile, merging with the prompts folder), and provider config. `_agent_sig_sources` in `src/libs/container_sig.sh` hashes exactly these paths.

`workflow/coding-agent/audits/` is repo-side only -- the former `drafts/` was never deployed and neither is this directory. The audits are operator-invoked procedures read from the repo, not commands the deployed agent loads.

Name collisions between `src/reasoning/agent/prompts/` and `workflow/coding-agent/prompts/` would silently overwrite at COPY time; there are none today. A prompt file belongs in exactly one of the two folders.

The name `drafts/` implies draft status, but the directory holds current, in-use procedures (`bugfix`, `recovery`, `refactor-mv-rename-file`, `roadmap-management`). The M3 reorganization should rename or dissolve it so the name does not mislead.
