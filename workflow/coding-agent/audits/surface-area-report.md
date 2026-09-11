# Coding-Agent Workflow Surface Area

This report categorizes the coding-agent workflow files -- the skill files and prompt templates that drive agent behavior. It covers the former `src/reasoning/agent/drafts/` and `src/reasoning/agent/prompts/` surface at their post-relocation homes. The campaign records already in `workflow/coding-agent/` (`test-quality-campaign.md`, `test-quality-campaign-run.md`, `documentation-pass.md`) are session records, not workflow files, and are out of scope.

The envisioned future state: a targeted workflow file for each current use case, one canonical file per use case, non-current use cases dropped. This report is the input for the M3 reorganization task (`devlog/roadmap_future.md`, M3 section).

## Inventory

| File | Use case | Status | M3 target |
|---|---|---|---|
| [`gm.md`](../gm.md) | Kickoff: check-in -- survey the project state, present a work inventory, wait for direction | Current, canonical (rewritten 2026-09-11) | Keep |
| `prompts/new-iteration.md` | Kickoff: open an iteration with a known directive -- scope and acceptance gates | Current, canonical | Keep; candidate for workflow bundling per the M3 workflows-folder task |
| `prompts/agent-sandbox.md` | Meta: redirect harness questions to `/opt/sandbox/docs/` | Current | Keep |
| `prompts/wrapup.md` | Close: minor-loop Steps 7b-9 -- verify, reconcile, mark, seed | Current, canonical | Keep |
| `prompts/package-branch.md` | Export: package committed history as diffs for review (`/package-branch`) | Current, tool-backed | Keep |
| `prompts/defer.md` | In-iteration: park an adjacent issue into the handover's Deferred items | Current, canonical | Keep |
| `prompts/propagation-check.md` | In-iteration: verify a cross-file change reached every consumer | Current | Keep; AGENTS.md carries the checklist discipline, this file is the audit invocation |
| `drafts/bugfix.skill.md` | In-iteration: structured diagnosis of a systemic bug across a chain | Current | Keep |
| `drafts/refactor-mv-rename-file.skill.md` | In-iteration: atomic file move/rename procedure | Current | Keep; complements the AGENTS.md rename rule |
| `drafts/recovery.skill.md` | State repair: recover committed artifacts after a reset or policy violation | Current | Keep |
| `drafts/roadmap-management.skill.md` | State maintenance: mutate `roadmap.md`/`changelog.md` per policy | Current | Keep; natural pair with `roadmap-audit` -- management mutates, audit verifies |
| [`audits/audit.skill.md`](audit.skill.md) | Audit: closed-handover review -- deferred chains, close sequences, dangling references | Current, formalized | Merge with `handover-audit.skill.md` into one canonical handover audit |
| [`audits/handover-audit.skill.md`](handover-audit.skill.md) | Audit: handover content-quality rules (procedural, migrated out of `handover_policy.md`) | Current use case, draft form | Merge into the handover-audit pair above |
| [`audits/bash-audit.skill.md`](bash-audit.skill.md) | Audit: bash code vs `bash-coding-conventions.md`, read-only one-shot | Current, canonical | Keep; absorb the useful checks from `kelsey-code-reviewer.skill.md` |
| [`audits/kelsey-code-reviewer.skill.md`](kelsey-code-reviewer.skill.md) | Audit: bash/Dockerfile review against production-shell standards | Non-current -- Claude-format import | Port useful checks into `bash-audit.skill.md`, then drop |
| [`audits/roadmap-audit.skill.md`](roadmap-audit.skill.md) | Audit: roadmap compliance with `roadmap_policy.md`, compaction prep | Current, canonical | Keep |
| [`audits/architecture-doc-reviewer.skill.md`](architecture-doc-reviewer.skill.md) | Audit: doc staleness and scope-honesty review | Non-current -- Claude-format import | Merge its purpose into the roadmap task "Architecture-doc staleness sweep", then drop |
| [`audits/dhh-code-audit.skill.md`](dhh-code-audit.skill.md) | Audit: Ruby/JS code review against DHH standards | Non-current -- no Ruby or JavaScript in this repo; Claude-format import | Drop |
| `drafts/toc.sh` | Utility: print a markdown header outline with line numbers | Current, used | Relocate with the scripts, not a skill |

## Format divergence

Two generations coexist. Pi-native skills are markdown with `# Skill --` headers and prose procedure. Claude-format imports carry YAML frontmatter with `name`, `description`, `tools`, and `model`, plus `<example>` blocks. The three imports (`architecture-doc-reviewer`, `dhh-code-audit`, `kelsey-code-reviewer`) reference Claude tool APIs -- Glob, Grep, LS, TodoWrite, WebFetch, BashOutput, KillBash, `model: opus` -- that do not exist in pi, so they were never deployable as pi skills. The M3 fork-and-strip convention (`devlog/roadmap_future.md`, M3: the `improve-codebase-architecture` case) covers importing upstream skills: fork, strip harness-specific quirks, maintain locally.

## Naming inconsistencies

- `audit.skill.md` is titled "Handover Audit" inside, and `handover-audit.skill.md` covers the same use case in draft form. Two files, one use case. The M3 merge picks one canonical name.
- `dhh-code-audit.skill.md` carries frontmatter `name: dhh-code-reviewer`; filename and internal name disagree. Moot if the file is dropped.

## Deployment boundary

The deployed agent surface (`/opt/workflow/agent/`) is: `src/reasoning/agent/skills/`, `src/reasoning/agent/prompts/`, `workflow/coding-agent/gm.md` (COPYed into `/opt/workflow/agent/prompts/` by each provider dockerfile), and provider config. `_agent_sig_sources` in `src/libs/container_sig.sh` hashes exactly these paths.

`workflow/coding-agent/audits/` is repo-side only -- the former `drafts/` was never deployed and neither is this directory. The audits are operator-invoked procedures read from the repo, not commands the deployed agent loads.

The name `drafts/` implies draft status, but the directory holds current, in-use procedures (`bugfix`, `recovery`, `refactor-mv-rename-file`, `roadmap-management`). The M3 reorganization should rename or dissolve it so the name does not mislead.
