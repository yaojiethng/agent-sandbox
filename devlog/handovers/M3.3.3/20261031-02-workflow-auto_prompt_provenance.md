---
date: 2026-10-31
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - The adapted prompt carries its provenance record

## Objective

Make `auto.md`'s provenance readable from the tree: its upstream, what the fork changed, and the milestone that owns the full command.

## Scope

The roadmap row `The adapted prompt carries its provenance record` under M3.3.3. The record lands beside the prompt, and `source-bump` is edited because the new record falsifies its statement that a prompt has no maintenance record.

The manifest's prompt-cell loader text is amended because the nested record makes its "each Markdown file here" claim false.

Out of scope: the full `/auto` command and its final name, which M3.2.3 owns; the `poteto-mode` dependency, which the M3.6.5 row `auto.md` names a skill no image ships owns; and the two commits that created `.agents/prompts/auto.md` and `.agents/prompts/resync.md` with no handover, which `devlog/AGENT_FEEDBACK.md` already records and which no closed-record correction has been directed for.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A `MAINTENANCE.md` beside `auto.md` states the `poteto-agent` upstream, the fork's kept, rewritten, added and dropped changes, and that M3.2.3 owns the full command | `test -f .agents/prompts/auto/MAINTENANCE.md`; read `## Source`, `## Adapted` and `## Owner` | Agent [x] |
| The record names the upstream revision as unrecorded and invents none | `rg -n 'revision' .agents/prompts/auto/MAINTENANCE.md` | Agent [x] |
| `source-bump` reads a prompt's `MAINTENANCE.md` and no longer says a prompt has none | `rg -n 'a prompt has no maintenance record' .agents/skills/source-bump/SKILL.md` returns nothing; `rg -n 'skill, runbook or prompt' .agents/skills/source-bump/SKILL.md` finds each carrier | Agent [x] |
| The manifest's prompt-cell loader text says only a direct Markdown child is a command | `rg -n 'directly in this directory is an invocable command' src/build/container-interface.json` | Agent [x] |
| The roadmap row is `[x]` with handover `20261031-02` and a completion note | `rg -n 'adapted prompt carries its provenance' devlog/roadmap.md`; `git diff devlog/roadmap.md` | Agent [x] |
| Every decision recorded this iteration is realized in the files | read `## Decisions`; check each destination | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The record lives at `.agents/prompts/auto/MAINTENANCE.md` | `.agents/prompts/` is mounted as a prompt directory, where each direct `.md` child becomes an invocable command; a nested directory keeps the record off the command surface while it stays beside the prompt | this handover |
| The record follows the fork-and-strip shape, plus `## Owner` | `## Source`, `## Adapted` and `## Name` are the shape every skill record uses; `## Owner` carries the milestone the row asks for | this handover |
| The upstream revision is stated as not recorded | The fork landed by hand and no revision was captured, so inventing one would make the record false | this handover |
| `source-bump` reads a prompt's record | The new record makes its universal claim that a prompt has no maintenance record false, in four places | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `devlog/handovers/20261030-03-workflow-source_bump_skill.md` records that a prompt artifact has no `MAINTENANCE.md`, which this iteration falsifies | record staleness | the closed record states a rule that no longer holds | operator direction; a closed-record correction is not applied unasked, per `docs/adr/closed_record_corrections.md` |

## Completed

| File | Change |
|---|---|
| `.agents/prompts/auto/MAINTENANCE.md` | Records the `poteto-agent` source, the fork's adaptation, the name, and M3.2.3 as owner. |
| `.agents/skills/source-bump/SKILL.md` | Reads a prompt's maintenance record where it previously said a prompt has none. |
| `src/build/container-interface.json` | Limits the prompt-cell loader text to direct Markdown children. |
| `devlog/roadmap.md` | Marks the row `[x]` and records the outcome. |
| `devlog/handovers/20261031-02-workflow-auto_prompt_provenance.md` | Closed this handover. |
