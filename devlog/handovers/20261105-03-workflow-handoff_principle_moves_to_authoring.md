---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the handoff judgement moves to the authoring sheet

## Objective

Move the handoff judgement out of the always-loaded principle corpus and into the sheet that writes the only documents it governs, so the corpus holds judgements that apply to any text and this one sits where a prompt or a skill is written.

## Scope

The M3.3.3 row **The handoff principle may belong to the prompt-writing corpus**, reopened this iteration after the prior iteration closed it the other way. Unit A of the two-unit handling the operator confirmed at the start of this session; unit B, the prose-entrypoint row, stays open.

The criterion the move rests on, ruled by the operator this session: the four moves describe a unit that is **invoked and whose end continues into another run**. Code fails it because its contract is a signature a compiler enforces and its receiver is a caller, not a continuation; a reference fails it for want of a last step; a tutorial fails it because a closing pointer starts a separate job rather than continuing this one; and an ADR fails it twice, having no run to continue and carrying its supersession in a field the `decision-records` convention already owns.

Ruled out of scope, with the reason: the sibling prose-entrypoint row, which is a separate unit; and the M3.3.6 rows, which the previous iteration filed and this one does not touch.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The handoff pattern exists and offers the four moves and the test | `rg -n 'Read the last step' .agents/skills/instruction-authoring/patterns/handoff.md` prints the test, and the file lists moves 1 to 4 | Agent [x] |
| The body sheet cites the pattern rather than carrying it | `rg -n 'patterns/handoff.md' .agents/skills/instruction-authoring/references/body.md` prints the runbook section and the shared-shape slot | Agent [x] |
| The body sheet is renamed and every pointer follows | `test -f .agents/skills/instruction-authoring/references/body.md`; `rg -n 'forms\.md' --glob '!devlog/**'` names only the ADR sentence that records the rename | Agent [x] |
| The judgement leaves the principle corpus | `test ! -d .../communication-principle-hand-off-by-naming-the-boundary`; `rg -l 'hand-off-by-naming-the-boundary' --glob '!devlog/**'` names only the ADR entry that records the retirement | Agent [x] |
| The shipped index no longer lists it | `rg -n 'hand-off-by-naming' src/reasoning/providers/pi/config/agent/AGENTS.md` prints nothing, and the list it leaves still reads as one sentence | Agent [x] |
| No shipped principle points at a project path for this judgement | `rg -n 'instruction-authoring' .../principle-match-precision-to-stakes/SKILL.md` prints nothing | Agent [x] |
| The in-force criterion is stated once, at the new home | `## When it applies` names an invoked unit whose end continues, and no corpus-level claim survives | Agent [x] |
| The reversal is recorded in the ADR and the roadmap | `rg -n 'invoked and whose end continues' docs/adr/principle_skill_shape.md` prints the dated entry; the roadmap row is `[x]` with a landing note naming the reversal | Agent [x] |
| Every decision this iteration recorded is realized in the files | the `## Decisions` table read against the tree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The in-force test is invocation, and the description and body say so | A judgement scoped to "any text" was the defect; five text classes were weighed and one passed | `patterns/handoff.md` and the ADR entry |
| The four moves become `patterns/handoff.md`, linked from `references/body.md` as a pattern and not as a rule | One shape among several, and a runbook that ends inside its own scope has none; the sheet cites it from the slot and from the runbook section | `patterns/handoff.md`, `references/body.md` |
| `references/forms.md` is renamed `references/body.md` | The file holds the body's shape and three forms; `forms` named a taxonomy it only partly carries and read as a rule set beside `patterns/` | `references/body.md`, and the four carriers repointed |
| `principle-match-precision-to-stakes` drops its handoff pointer instead of repointing it | A shipped principle may not name a project path, and the link was already tenuous in the other direction | `principle-match-precision-to-stakes` |
| The shipped index loses the entry with no replacement | The subject is no longer a whole-artifact judgement in that corpus, and the authoring sheet names it where an author reads | provider `AGENTS.md` |
| The roadmap row is reopened rather than a new row filed | It is the same question, and the superseded ruling must stay visible beside the one that replaced it | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `principle-match-precision-to-stakes` still points at the handoff principle, which the previous iteration recorded as removed in both directions | defect, record | a shipped principle names a judgement that is about to retire | this iteration, by the third decision |
| `references/forms.md` is named by four carriers, one of them outside the sheet: `instruction-authoring` step 3 and its carried-file table, `prompt-conventions.md`, and `prose-review` in the workflow module | propagation | a rename that stops at the sheet leaves three stale paths | this iteration, by grep before the move |
| `instruction-authoring` step 1 and the `dispatch` convention use "hands off" for a brief handed to a worker, a different sense from a unit's last step routing to the next | ambiguity, text | the moved text must name the next document rather than say "handoff" alone | this iteration, in the moved wording |
| The rename's negative check found two carriers the file table missed: the previous ADR entry's 'references/forms.md carries the worked splits', and a reference to the old path inside the new entry itself | defect, record | a live ADR entry pointed at a file that no longer exists | this iteration, both fixed; the entry keeps the old name once, as the rename it records |

## Completed

| File | Change |
|---|---|
| `.agents/skills/instruction-authoring/patterns/handoff.md` | new: the four moves, the invocation criterion, the four neighbours it does not reach, the why, the test; the test and the term `workflow` are the operator's, the applicability sentence and the why restored after the amendment cut them |
| `.agents/skills/instruction-authoring/references/body.md` | renamed from `forms.md`; the runbook section and the shared-shape slot cite the pattern, offered not required |
| `.agents/skills/instruction-authoring/SKILL.md` | step 3 links `body.md`; the carried-file table gains the pattern row; after the operator's amendment, step 3 is one paragraph that keeps the operator's ordering of the three files, and step 4 keeps the ordering rule and the title rule the amendment dropped |
| `.agents/skills/instruction-authoring/references/prompt-conventions.md` | `forms.md item 4` repointed to `body.md` |
| `workflow/coding-agent/skills/prose-review/SKILL.md` | `references/forms.md ## Advisor` repointed to `body.md` |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` | deleted, and the installed copy removed from the seeded home |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | the whole-artifact list loses its handoff entry |
| `src/reasoning/providers/pi/config/agent/skills/principle-match-precision-to-stakes/SKILL.md` | the handoff pointer is gone, so nothing shipped names a project path |
| `docs/adr/principle_skill_shape.md` | a dated entry records the reversal, and the earlier entry's stale `forms.md` reference is repointed |
| `devlog/roadmap.md` | the handoff row reopened on the new criterion and closed with its landing note |
| `devlog/handovers/20261105-03-workflow-handoff_principle_moves_to_authoring.md` | this record |

The roadmap maintenance check ran over `devlog/roadmap.md` before this record was written and found nothing to maintain: M3.3.3 is the active sub-milestone and still holds open rows, which is the state the prior handover reports.
