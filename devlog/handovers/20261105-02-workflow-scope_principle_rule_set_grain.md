---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - one home for the organizational judgement

## Objective

Make `principle-single-source-of-truth` the one home of the organizational judgement, with a unit that can be decided, and give the workflow-specific material it carried to the document that owns that workflow.

## Scope

The M3.3.3 row **`principle-own-the-scope-you-declare` states its judgement once, at one grain or two**, and the row beside it, **The handoff principle may belong to the prompt-writing corpus**. Unit A of the two-unit handling the operator confirmed at the start of this session. Unit B, the corpus-membership ruling on the prose-entrypoint row, was not worked.

The operator's ruling during the read: one subject in one mode is one source, so the unit of ownership is a **subject together with a mode** and two documents may serve one subject. That reframed the row from a word cut into the merge recorded below.

Ruled out of scope, one sentence each with the reason: the Diataxis frame as its own principle and the split of `references/organization.md`, because the operator deferred them to a later iteration and this unit states the arrangement that makes it workable until then; the `reach` disambiguation, for the same reason; a sweep of `**Fires on.**` across the corpus, because the rule is stated here and applied to the files this unit touches; and the corpus-membership row on the prose-entrypoint pattern, which stays open.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The judgement has one home | `test ! -d src/reasoning/providers/pi/config/agent/skills/principle-own-the-scope-you-declare`; `rg -l 'own-the-scope-you-declare'` outside `devlog/` names only the ADR entry that records the retirement | Agent [x] |
| The principle states extent, ownership, the handling set and the rule grain | read `**The pattern.**` and `**The test.**` in `principle-single-source-of-truth` | Agent [x] |
| The principle claims no moment | `rg -n 'Fires on' principle-single-source-of-truth/SKILL.md` prints nothing; the handoff principle's part reads `**Where you meet it.**` | Agent [x] |
| The workflow instance lives in `forms.md` and not in the principle | `rg -n 'conditions it runs under' .agents/skills/instruction-authoring/references/forms.md` prints the line; the same in the principle prints nothing | Agent [x] |
| The handoff principle applies to any handoff and names the downstream where the reader needs it | read its description and move 1 | Agent [x] |
| The authoring sheet no longer claims that a principle states its trigger as a part | `rg -n 'Fires on' .agents/skills/instruction-authoring/references/skill-conventions.md` prints nothing | Agent [x] |
| The corpus holds one statement per situation | `communication-principle-keep-a-subject-near` cedes the two-subjects case; `principle-match-precision-to-stakes` no longer links the retired name | Agent [x] |
| The shape gate and the suite are clean | `bash scripts/check_document_shape.sh` clean across 174 instruction files and 26 principle skills; `bash scripts/run_tests.sh` 1445 pass | Agent [x] |
| The link and surface gates are clean | `bash scripts/lint.sh` clean across 20 gates | Agent [x] |
| A cold reader reaches the same answer | three artifacts read against the old text and the new | pushed: filed under M3.3.6 as a sub-row of **Every reference to the organizational judgement says something true**, on operator direction to carry it rather than run it here |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The unit is a subject together with a mode, and the two principles merge into one | The two files stated one judgement and no reader could tell which governed; the cause was an undefined unit, so any document could claim any content and a second document of a different mode read as a duplicate | `docs/adr/principle_skill_shape.md`, 2026-11-05 |
| `principle-single-source-of-truth` keeps the name, the file and the leitwort | It carries the most carriers, it is the established term, and the operational name retires into it rather than the reverse | the same entry |
| A principle claims no moment | A principle stated as belonging to a moment is not called up at the others, which is a plausible cause of the violations rather than a description of them; selection reads the description, which names a situation | `references/skill-conventions.md`, the same entry |
| The agent may link and move; the operator holds removal and widening | The two files disagreed on authorisation, and widening a unit changes an owner that already exists | the same entry |
| The four mode names stay in the principle with a one-clause gloss, and the folder mapping and authoring guidance stay in `references/organization.md` | This is the arrangement that works until the Diataxis frame has a principle of its own, which the operator deferred | `references/organization.md`; the same entry |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The organizational statement belongs where it can reach both the judgement and this repository's folder mapping | defect, placement | the provider layer cannot link `organization.md`, and the two are coupled until the mode frame is a principle, so a shipped rule had to name no path | the project `AGENTS.md` `## Output Format`, on operator direction; filed under M3.3.6 for the frame split |
| `scripts/check_document_shape.sh`'s failure message executes the backticked paths it names, so a finding prints `Permission denied` instead of the defect | defect, reproduced | the gate reports the wrong failure, and the operator cannot see what broke | the open M3.1.2 row, **`check_document_shape.sh` reports the wrong failure**; reproduced twice this iteration |
| Editing the repository leaves `$AGENT_HOME/agent/skills/` stale until the next container start, and `/opt/workflow/agent/config/` holds the pre-change image copy that reseeds it | measured | a session reads a mixed corpus between the edit and the image rebuild | this iteration synced the six edited skills and `AGENTS.md` into `$AGENT_HOME` and removed the retired skill there; `/opt/workflow/agent/config/` is outside both the repository and `$AGENT_HOME`, so it was not written |
| The five-item account the retired file carried did not survive as a checklist | design | the content is material of several modes, and the placement rule sends each to its own | the account's workflow instance landed in `references/forms.md`; the rest is the mode split the deferred iteration owns |
| The Diataxis frame has no principle home, so the classification lives in a principle about ownership and the authoring guidance lives in a project reference | design, deferred | the split is workable but not yet the shape it should be | operator direction, 2026-11-05: filed under M3.3.6, **The mode frame is a principle of its own** |
| Eight live references to the organizational judgement still speak the unit the merge replaced | defect, record | a reader follows a pointer to a claim the principle no longer makes | filed under M3.3.6, **Every reference to the organizational judgement says something true**, with its two sub-rows |
| `reach` is stated as a property of documents and is a property of this distribution | defect, record | a project that runs its own workflow is told to declare a reach it does not have | filed under M3.3.6, **Reach is a property of distribution, and scope is its formal definition**, which consolidates the two rows moved there from M3.3.3 |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/skills/principle-single-source-of-truth/SKILL.md` | rewritten: the subject-and-mode unit, extent, the four handling methods, the rule grain, the awkward cases, the test; 705 words where two files carried 1,390 |
| `src/reasoning/providers/pi/config/agent/skills/principle-own-the-scope-you-declare/SKILL.md` | deleted |
| `.agents/skills/instruction-authoring/references/forms.md` | the workflow instance: conditions and steps here, the rationale with the record, the output contract with the thing described |
| `.agents/skills/instruction-authoring/references/skill-conventions.md` | a description names a situation; a principle claims no moment |
| `.agents/skills/instruction-authoring/SKILL.md` | step 1 repointed to the surviving principle |
| `.agents/skills/project-documentation/references/organization.md` | states which file owns the classification and which owns the guidance and folders |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` | widened past runbooks; the downstream named in move 1; primed at the surviving principle |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-keep-a-subject-near/SKILL.md` | cedes the two-subjects case to the surviving principle |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-rewrite-syntax-never-semantics/SKILL.md` | repointed |
| `src/reasoning/providers/pi/config/agent/skills/principle-match-precision-to-stakes/SKILL.md` | the tenuous link removed |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | `## Write Discipline` unchanged; the organizational statement left it for the project layer |
| `AGENTS.md` | `## Output Format` `**Documents**` names the mode-decided placement, linking `organization.md` and the principle together |
| `docs/adr/principle_skill_shape.md` | dated 2026-11-05 entry: the merge, the unit, the no-moment ruling, four rejected alternatives, the edge cases |
| `devlog/roadmap.md` | the two rows closed with their landing notes; and four rows filed under M3.3.6, the reach-and-scope consolidation with its three sub-rows, the mode frame, and the reference map with its two |
| `devlog/handovers/20261105-02-workflow-scope_principle_rule_set_grain.md` | this record |
