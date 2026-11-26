---
date: 2026-11-26
milestone: M3.5.6 - The discussion record corpus
type: Housekeeping
status: Closed
---

# Handover - Retiring the discussion archive

## Objective

Empty the discussion archive the way the handover archive was emptied, keeping only what an open row still needs, so one rule governs every record in the layer.

## Scope

A seventh row on `M3.5.6`: eighty archived records placed against four criteria, seventy-four deleted, six graduated into `devlog/discussions/`, thirty citing files rewritten, and the folder's three exemptions removed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every archived record is placed by evidence, not by date or by folder. | `.scratchpad/dispatch/brief-archive-evidence.md`; the seat's table in its log | Agent [x] |
| No record the tree still needs is deleted. | the six graduates are cited by an open row and no live carrier restates them | Agent [x] |
| No citation points at a deleted file. | `bash scripts/check_markdown.sh` clean; `bash scripts/check_linking.sh` clean | Agent [x] |
| The retired folder leaves no exemption behind. | `grep -rn 'discussions/archive' scripts/ src/ .agents/` returns the plan handover only | Agent [x] |
| The gates and the suite pass. | `bash scripts/lint.sh` clean across 31 gates; `bash scripts/run_tests.sh` 1750 passed | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A record graduates only against four criteria: not superseded, an open row names it as its source, its sampled references are present, its evidence is unique. | The folder was exempt from every gate, so nothing else decided. Tenancy alone was too coarse: an archived record can be unowned and still be the design source a shipped ADR cites. | this record; the brief |
| A failed record is deleted and its citing link becomes a code span. | The established move from the handover retirement: the name survives in the text, and no reader follows a link into nothing. | 30 citing files |
| The enquiry's state is assigned from what the record says it reached, not from the folder it came out of. | Five graduates carry an unmet recommendation and stay `open`; one study's recommendation is recorded and it is `ended`. | the six names |
| The ADR archive stays. | An ADR states a decision that remains true after it is superseded, so tenancy does not govern it. | operator direction |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The citation surface was thirty files, not the sixteen the first count gave: the count read Markdown only, and three archived ADRs, the shipped reference docs, a knowledge-vault index and nine test headers also cited the tree. | measurement | the retirement touched ADRs, reference documents and test headers, not just the roadmap | this record |
| The archive hid a broken citation: `devlog/roadmap.md` pointed at a read-through `.jsonl` that had already been deleted, and no gate covered the folder. | gate | an exempt tree accumulates dead links invisibly | this record; the folder is gone |
| Two records were superseded by a live carrier rather than by a newer record: the prompt-eval story by the `evals` skill, and the provider bug report by the shipped `model-refresh` extension and its README. | record | tenancy alone would have kept both alive | this record |
| `_ADVISOR_DOCS`'s first entry names `opencode/glm-5.3-flash-free`, which the provider no longer serves, so the seat refused at startup and the run pinned the role's second entry. | tool | a role table line can rot while every dispatch still reads it | reported to the operator |
