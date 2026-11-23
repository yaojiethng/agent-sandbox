---
date: 2026-11-23
milestone: M3.5.1 - The work-log record layer
type: Plan
status: Closed
---

# Handover - The record's cost and read window

## Objective

Decide, by a cold-session replay, whether the per-iteration handover earns its cost, and reduce it to the sections its 1-10 record read window actually consumes.

## Scope

The problem: the handover record is written once per iteration (1,126 records, 87,016 lines) and the operator never reads it. Its consumers are bounded -- `/gm` reads the latest ten for status and findings, `/iter` reads one for `Objective`, `Findings` and `Decisions`, `/wrapup` reads the active record, and no runtime code reads content at all. The 716 archived records are write-only. Two of its largest sections, `Completed` (13,209 lines) and `Scope` (7,753), are never read back; `Completed` restates git and is lossy against it.

The question this session owns is whether the residue the read window consumes can be recovered from git, the roadmap, the ADR and the producing session transcript. If it can, the sections that duplicate them are dead weight; if it cannot, the unreachable residue is the handover's justification and bounds what may be deleted.

This decision belongs to M3.5.1, the work-log layer that owns the record; M3.5.3's record-model work inherits the surviving section set rather than owning the test. The deletion work it feeds is filed in M3.5.1 as a parent row with three subtasks.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A definite decision names the record's residue and its recovery substrate. | Read `docs/adr/work_log_record_seam.md` `## 2026-11-23`. | Agent [x] |
| The roadmap row states the decided outcome and the cutover. | `grep -n "residue" devlog/roadmap.md`. | Agent [x] |
| The two-iteration split is recorded. | This record's Decisions. | Agent [x] |
| The gates pass. | `check_record_citations.sh`, `check_handover_format.sh`, `check_record_names.sh`. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The ADR is an amendment to `work_log_record_seam.md`, not a new file. | The seam already owns the record's shape and read surface; a second file would govern one principle from two places. | `docs/adr/work_log_record_seam.md` |
| The transcript lever is bundled in the `recovery` skill, not the project's `scripts/`. | The skill ships to any project; a project script does not travel with it, and the command belongs with the evidence doc it serves. | This record; `recovery/scripts/pi/` |
| The removal splits into two iterations: the lever first, the record residue second. | The lever is independently verifiable and the residue must not land before recovery can work without it. | This record; the roadmap row |
| A absorbs the replace: one change lands the residue and the transcript lever, and the later decision-and-finding-log milestone is dropped. | The residue is the decision-and-finding log in substance, and a second migration would rewrite the same file for no new outcome. | This record; `roadmap.md` M3.5.1 |
| Recovery is repointed at the session transcript, and the record shrinks to its residue. | The transcript store is mounted and durable, and the handover's working sections are a lossy cache over it; the residue -- `Objective`, `Acceptance`, `Decisions`, `Findings` -- is the part continuity cannot cheaply re-derive. | This record; `recovery` |
| No new sub-milestone is created for record deletion. | The row already lived in M3.5.1, and one outcome does not justify a fourth record sub-milestone under M3.5. | This record; `roadmap.md` M3.5.1 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The effective read window is 1-10 records: `/gm` latest ten, `/iter` latest one, `/wrapup` the active one, `handover-maintenance` the chain on demand. | record | The design target is that window, not the archive; an archive-wide census is wasted work. | `docs/adr/work_log_record_seam.md` |
| `/gm` reads "each record's `status`, findings and deferred items", and `work-log` forbids the record to carry a deferred-item section. | record | The main consumer's read contract is stale; it asks for a section that cannot exist. | `roadmap.md` M3.5.1, the `/gm` read-contract row |
| `Completed` (13,209 lines) and `Scope` (7,753) are never read back by any consumer; `Acceptance criteria` is read only at the close. | record | The two largest sections are write-only, and `Completed` restates git lossily (sample: 19 handover rows against 31 git files). | `docs/adr/work_log_record_seam.md` |
| The `M3.5.1` track carries no `README.md` and no reserved id block, so `worklog.sh reserve-id` falls back to the day's first free id. | record | A second track writing today can collide on `20261123-01`; the folder/milestone gate that would catch a mismatch is itself an open M3.5.1 row. | `roadmap.md` M3.5.1, the folder/milestone gate row |
| `milestone-close` says a closed milestone's detail lives in the changelog and the handovers; deleting a track makes the changelog the sole durable seat. | record | The track-deletion subtask must state what the changelog carries before a track can be deleted. | `roadmap.md` M3.5.1, the track-deletion subtask |
| The chosen design is the "replace" in substance: the shrunken record is the decision-and-finding log, so the later milestone is redundant unless it is re-scoped. | record | The two-step plan collapses to one change; the roadmap write-back drops the later row. | `docs/adr/work_log_record_seam.md` |
| `recovery` reads the handover as its claim -- the unit, the range or files, what landed; the read-window census counted read frequency, not failure consequence. | record | The `Active` working sections are a materialized point-in-time claim, not write-only bulk. | `docs/adr/work_log_record_seam.md` |
| The session store is mounted and durable -- `container-interface.json` maps `${SANDBOX_DIR}/.pi/agent/sessions` to `~/.pi/agent/sessions` -- holds 901 transcripts, and `measure_sessions.mjs` already parses its tool calls. | record | Recovery can read the primary; the missing piece is one command, not a new store. | `docs/adr/work_log_record_seam.md`; iteration 1 |
| Nothing in `iter` or `commit` requires the `Active` handover to be committed at a checkpoint. | code | A reset before the delivery commit already leaves the claim only in the transcript; the repoint fixes it without a new rule. | `docs/adr/work_log_record_seam.md` |

## Completed

| File | One-line change summary |
|---|---|
| `docs/adr/work_log_record_seam.md` | New `2026-11-23` entry: the record is a residue and recovery reads the transcript; R6 added; `Current` advanced. |
| `devlog/roadmap.md` | The trim subtask becomes the residue outcome with the two-iteration order and the cutover; the `/gm` read-contract row is filed. |
| `devlog/handovers/M3.5.1/20261123-01-plan-record_cost_replay.md` | This record. |
