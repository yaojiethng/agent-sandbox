---
date: 2026-11-24
milestone: M3.5.1 - The work-log record layer
type: Implementation
status: Closed
---

# Handover - read recovery's evidence from the transcript

## Objective

Give `recovery` a command that reads a named session transcript, so the evidence for lost work comes from the primary instead of the record's summary.

## Scope

Continues **Retire the records of closed rows and closed milestones** > **Carry the record's residue, not its transcript copy** > **Iteration 1: read recovery's evidence from the transcript**; follows handover `20261123-01-plan-record_cost_replay`, which decided the split and the command's seat.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `session_evidence.mjs` prints the header, the files touched, the write-shaped `bash` commands and the last assistant text for a named session. | `bash tests/test_session_evidence.sh` | Accepted |
| The command resolves a session by id, by path, and by `--cwd <path> --latest`. | `bash tests/test_session_evidence.sh` | Accepted |
| The command exits 1 with a named message on a missing store and on an id that matches nothing. | `bash tests/test_session_evidence.sh` | Accepted |
| `recovery/SKILL.md` triage step 1 reads the transcript when no record is named, and keeps a named record as the claim. | `sed -n '/## Triage/,/## The classes/p' workflow/coding-agent/skills/recovery/SKILL.md` | Accepted |
| `references/evidence.md` `## pi` names the command and the output it prints. | `grep -n 'session_evidence' workflow/coding-agent/skills/recovery/references/evidence.md` | Accepted |
| Every decision this iteration recorded is realized in the files. | read the Decisions table against `git diff` | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The command is `session_evidence.mjs`, bundled at `workflow/coding-agent/skills/recovery/scripts/pi/` and invoked from `references/evidence.md` `## pi`. | The skill ships to any project; a project script does not travel with it, and the command belongs beside the evidence doc it serves. | This record |
| The command takes a session id or a path, and `--cwd <path> --latest` with no id; it resolves the store by matching the session header's `cwd`, not by re-encoding the path. | The store's directory encoding is not documented and has drifted (`--home-agentuser-sandbox--`), so the header is the authority. | This record |
| The output is a header (id, cwd, start, provider/model), the files touched by `write`/`edit` with counts and last timestamp, the write-shaped `bash` commands, and the last assistant text. | These are what a recovery claim needs: when, where, what changed, and what the agent said it did. | This record |
| The parser is a self-contained copy of the `measure_sessions.mjs` message walk, not an import. | `measure_sessions.mjs` is a project script; the skill must run from its own directory on install. | This record |
| `recovery/SKILL.md` triage step 1 reads the transcript when the caller names no record; a named record stays the claim. | The record is an optional claim, and the transcript is the primary when no record exists. | This record |
| A missing store or no match exits 1 with a named message, never a stack trace. | The command runs inside a recovery, so its failure must read as evidence rather than a crash. | This record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The session store's directory encoding is undocumented and does not follow one rule: `/home/agentuser/sandbox` maps to `--home-agentuser-sandbox--`, so a caller cannot compute the directory reliably. | code | `--cwd` must resolve by the session header rather than the directory name, or a cwd lookup silently misses. | This iteration, decision above |
| The roadmap keeps M3.6.5 fully checked while its summary reads `In progress`; the close owns the status flip, and flipping it early unassigns any handover filed under it. | record | The maintenance report is carried, not fixed here; `/milestone-close` owns it. | `roadmap.md` M3.6.5, its close |
| `--cwd <path> --latest` picks the newest session recorded in that tree, which can be a preflight or a parallel run rather than the caller's session. | code | The caller passes the session id when it matters; the printed header always names the id, so a wrong pick is visible. | `references/evidence.md` `## pi` |

## Completed

| File | One-line change summary |
|---|---|
| `workflow/coding-agent/skills/recovery/scripts/pi/session_evidence.mjs` | New command: resolves by id, path or `--cwd --latest`, and prints the header, touched files, write-shaped bash and last assistant text. |
| `workflow/coding-agent/skills/recovery/SKILL.md` | Triage step 1 reads the transcript when no record is named. |
| `workflow/coding-agent/skills/recovery/references/evidence.md` | `## pi` names the command and its output. |
| `tests/test_session_evidence.sh` | 5 tests, 5 passed. |
| `devlog/roadmap.md` | Iteration 1 marked landed; maintenance carried M3.6.5 with no fixable edit. |
