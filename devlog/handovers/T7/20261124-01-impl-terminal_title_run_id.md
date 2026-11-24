---
date: 2026-11-24
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Implementation
status: Closed
---

# Handover - The pi extension names the tab by its run id

## Objective

Give the terminal tab that runs a session the session's run id, so an operator tells two tabs apart without reading scrollback.

## Scope

The operator's quality-of-life ticket: `make start` leaves the VSCode tab named `make`, because nothing sets a terminal title and the editor falls back to its `${process}` default. A pi extension inside the agent container sets the title from the run id and re-asserts it after each of pi's own title writes, so the id stays visible for the whole session.

This work is `session-title` under `src/reasoning/agent-runtime/pi/config/agent/extensions/`, beside `model-failover` and `model-refresh`. The operator directed the extension form on 2026-11-24, replacing the harness-side sequence emission the first scope proposed.

Out of scope, with reasons: editor-side work. VSCode appends only static text to its title template, so the run id can only travel through the process's own title sequence, and the one-time `terminal.integrated.tabs.title: "${sequence}"` opt-in is a documented prerequisite rather than a change here. Also out of scope, found while reviewing the ticket and not fixed: `workflow/vscode/imageConfig/sandbox-agent-sandbox.json` is referenced by no script and no document.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| During a live session the tab reads the app mark, a hyphen and the run id. | Operator: with `"${sequence}"` set, run `make start`; after the first prompt the tab reads the app mark and the same six-hex id the `Session ID:` line printed, and still does several turns later. A pty capture with only this extension loaded shows the title written. | Operator [x] |
| The builder emits exactly the app mark, a hyphen and the run id: no other segment, control bytes dropped, and no title at all without a run id. | `node --test tests/extensions/pi/session-title/title.test.ts` | Agent [x] |
| The handler registers on `session_start`, `agent_start` and `session_info_changed`, and each sets the title. | `node --test tests/extensions/pi/session-title/wire.test.ts` | Agent [x] |
| A UI context without `setTitle` does not throw. | `node --test tests/extensions/pi/session-title/wire.test.ts` | Agent [x] |
| The agent container receives `SESSION_ID`. | `grep -n 'SESSION_ID' src/build/docker-compose.yml` shows the key in the `agent:` service block. | Agent [x] |
| The editor prerequisite sits where an operator starts a session. | `grep -n 'terminal.integrated.tabs.title' docs/development/quickstart.md` | Agent [x] |
| Every decision this iteration records is realized in the files. | read the extension, the compose key and the quickstart note against the Decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Ship the title as a pi extension rather than a harness-side sequence emission. | pi re-asserts its own title at init, session bind, agent reset and `session_info_changed`, and no settings key disables it, so an emission from the host is replaced before the session starts. Only a process inside pi can write after pi. | This record; operator direction 2026-11-24 |
| Re-assert on `session_start`, `agent_start` and `session_info_changed`. | `agent_start` is the first event guaranteed to fire after pi's startup writes, and `session_info_changed` covers a rename; together they keep the id present from the first run onward. A pty capture measured our `session_start` write landing before pi's init write, so the id is not the startup title. | This record; the extension README |
| The title is the app mark, a hyphen and the run id, and nothing else. | The operator settled the format on 2026-11-24, dropping the session-name and working-directory segments the extension could have rebuilt; the cwd is readable from the tab's own context, and the id is what the operator needs from the title. | This record; operator direction 2026-11-24 |
| Take the run id from `SESSION_ID`, and add that key to the agent service's environment. | The extension's only input is the run identity; the agent service carries it nowhere today, and `SESSION_ID` is the harness key the sandbox service already receives. The agent environment stays unprefixed under the operator ruling recorded in the T6 row. | This record; `src/build/docker-compose.yml` |
| Stay inert when `SESSION_ID` is absent. | A pi run outside the harness has no run id, and a made-up value would mislabel the tab; leaving pi's title untouched is the honest default. | This record |
| Build the title in a pure function, with a handler module that only wires events. | A pure builder is testable without a pi process, and the wiring stays small enough to assert by registering against a fake. | This record |
| Read the run id once at load, not on each event. | The id is fixed for a container's whole life, so reading it per event would add a branch that no case can reach. | This record |
| Leave the pre-existing `test_convention_pointer.sh` failure to the milestone that owns the shell. | The defect is in `workflow/coding-agent/skills/code-review/SKILL.md`, which this iteration did not change; fixing it here would be an unapproved scope crossing, and the row keeps it visible instead of silent. | `devlog/roadmap.md`, the M3.2.3 row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The agent service's compose environment carries no `SESSION_ID`; only the sandbox service does. | code | the extension has no run id to read until the key is added | this iteration: the compose line |
| pi re-asserts its own terminal title four times and no settings key disables it. | code | a host-side emission cannot survive; only an in-process writer can | this iteration: the extension writes on the events that follow pi's writes |
| Measured in a pty, pi's init title write lands after the extension's `session_start` write, so the tab shows pi's own title until the first run begins. | code | the run id appears from the first prompt onward, not from container start | this iteration: stated in the README and in acceptance criterion 1 |
| `scripts/lint/pi-extension-compat.mjs` hardcodes `/usr/local/lib/node_modules` and refuses to run where pi is installed under `/opt/npm/pi`, as in this container. | code | the bump skill's probe cannot check an extension here | out of scope this iteration: a pre-existing environment mismatch, not filed |
| Extension UI calls exist in interactive mode; print, json and rpc modes carry no terminal UI. | code | an unguarded `setTitle` would throw inside a non-interactive run | this iteration: the guard and its unit test |
| `workflow/vscode/imageConfig/sandbox-agent-sandbox.json` is referenced by no script and no document. | record | an orphan config an editor-surface change would silently not affect | out of scope this iteration; carried as a scope sentence |
| `test_convention_pointer.sh::test_repository_carries_the_pointer` fails at HEAD: `workflow/coding-agent/skills/code-review/SKILL.md` carries a `## Project conventions` section without the canonical pointer sentence, lost in `2534a80a`. | code | the suite is red on a tree this iteration did not change, so the suite is red on a tree this iteration did not change, and the release gate reports the red rather than a clean run | written back as an open row under M3.2.3, which owns the shell; this iteration changed neither the file nor the gate |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/index.ts` | new: reads `SESSION_ID` once and re-asserts the title on `session_start`, `agent_start` and `session_info_changed`, guarded for a UI-less context |
| `src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/title.ts` | new: the pure builder -- the app mark, a hyphen and the run id, control bytes dropped, `undefined` without an id |
| `src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/README.md` | new: pi's four title writes, the three events, the measured startup order, the two guards |
| `src/build/docker-compose.yml` | the agent service environment gains `SESSION_ID` |
| `tests/extensions/pi/session-title/title.test.ts` | new: the format, the empty cases, control-byte scrubbing |
| `tests/extensions/pi/session-title/wire.test.ts` | new: the three registrations, the UI guard, the inert run |
| `tests/test_session_title.sh` | new: the harness wrapper around `node --test`, with the registration guard |
| `docs/development/quickstart.md` | new `## Terminal tab identity` section stating the one-time editor opt-in |
| `devlog/roadmap.md` | the T7 row this iteration works |
| `devlog/handovers/T7/20261124-01-impl-terminal_title_run_id.md` | this record |
