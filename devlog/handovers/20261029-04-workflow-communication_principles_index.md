---
status: Closed
milestone: M3.2.2
type: Workflow
date: 2026-10-29
---

# Handover - the communication principles are named before their rule

## Objective

Put each principle's name in front of its rule in the section an agent reads while it works, so the list can be scanned for a principle rather than read to find one.

## Scope

Continues the roadmap row **The prose principles trigger on the act of writing**, reopened for a second intervention. The first intervention changed ten `description` fields, which is the surface the model selects on; this one changes the index in the provider layer `AGENTS.md`, which is what an agent reads once it is working. Same subject, different surface.

Two decisions were offered at the scope gate on what an entry carries after the name, and the operator settled both: keep the rule text exactly as it stands, and do not fold the six prose-embedded principles into the list. This iteration reorders the twelve bullets, rewrites the section's opening paragraph, and brings the installed copy level with its source.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every bullet opens with the principle's name | read the list: the first token after each list marker is the skill link | Agent [x] every bullet |
| Each entry's rule text is the wording it carried before | the pre-change and post-change bullets compared name by name | Agent [x] identical, except `rewrite-syntax-never-semantics`, whose link sat behind `, per` and now ends its own sentence |
| The section's opening paragraph carries the operator's wording | read it against the operator's ruling: one sentence on the guidance, one on reading the leaf skill, one naming the agent as the one who names an entry | Agent [x] as ruled |
| No principle is dropped | the entry names compared against the pre-change set | Agent [x] the same names |
| Every link resolves | `bash scripts/check_reach.sh` | Agent [x] clean across the mount points and folders |
| The repo source and the installed copy agree | `diff` on the two paths | Agent [x] identical after the copy |
| The roadmap row names the intervention and closes with this handover | the row is `- [x]`, names the index change, and cites this record | Agent [x] ticked |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The entry keeps its rule text and gains only its name at the front | The operator's instruction, restated twice: flip the bullet, change nothing else. The text is the compressed judgement an agent reads without opening the skill, and the index states it deliberately | this record |
| The rule text is untouched even where it reads as a rule rather than a situation | The six entries the operator left in prose, and the twelve rules, keep their wording; a rewrite would be the earlier intervention's subject, not this one | this record |
| The section's opening paragraph is the operator's, not the agent's | The agent's draft was a single hint sentence and dropped the section's claim about its own status. The operator's version leads with the guidance, keeps the leaf-skill instruction, and closes on the agent naming an entry when it applies | this record, and the operator's edit in the tree |
| Only the twelve bullets are reordered | Six principles sit inside two paragraphs, and folding them in would delete the grouping those paragraphs carry | this record |

## Decisions pending

None.

## Findings

- **`communication-principle-one-addressing-axis` is listed twice**, as a bullet and again as "the judgement behind a numbered list". Flagged, not fixed: the operator's instruction was to flip the bullets.
- **Six principles are reachable only inside prose paragraphs.** Flagged, not fixed, for the same reason.
- **The installed copy had drifted from its source.** `$AGENT_HOME/agent/AGENTS.md` still held the pre-change section, so the surface an agent actually reads was one revision behind the repository's, and the divergence passed every gate. The copy is brought level here.
- **The conventions document promises a gate comparison that does not exist.** `docs/development/instruction-surface-conventions.md` says to copy the source to `$AGENT_HOME/agent/AGENTS.md` "and let `scripts/check_instruction_surfaces.sh` prove they match"; that script never reads the installed copy. Filed under gate upkeep rather than fixed here.
- **No gate reads this section's shape.** The instruction-surface gate holds the layer scope tables, the loop inventory and the subject table; the reach gate checks that a linked path resolves. What an entry says is verified by a read.
- **The growth gate the section cites has no numeric cap.** `scripts/report_instruction_growth.sh` reports and refuses nothing, and no gate holds a size for either `AGENTS.md`. Recorded, not fixed here.
- **The section no longer claims to state no rule of its own.** The operator's paragraph deleted that sentence, which resolves the contradiction between the preface and the rule-shaped entries.

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | Twelve bullets reordered to name first; the opening paragraph rewrapped around the leaf-skill instruction |
| `docs/development/instruction-surface-conventions.md` | The provider layer is described as holding an index of the principle skills |
| `devlog/roadmap.md` | Row reopened, extended with the intervention, and ticked |
| `$AGENT_HOME/agent/AGENTS.md` | Installed copy brought level with its source |
