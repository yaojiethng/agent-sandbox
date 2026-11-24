---
date: 2026-11-24
milestone: T7 - Harness Specialization / Sandbox Persistence
type: Implementation
status: Closed
---

# Handover - The tab title claims pi's writer instead of racing it

## Objective

Make the run id reach the terminal tab, where the shipped extension wrote it and pi replaced it before the frame drew.

## Scope

This iteration changes the write mechanism in [`session-title/index.ts`](../../../src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/index.ts) and nothing about the title's format or where the id comes from.

The shipped version wrote the mark-and-id title from `session_start`, `agent_start` and `session_info_changed`. pi writes its own title on the same events, after the handler returns and past a microtask boundary, so pi's write landed second every time and the tab read pi's cwd title. The extension now claims `tui.terminal.setTitle`, the single method pi's writes and every extension's `setTitle` pass through, which removes the race instead of winning it. The TUI instance comes from the widget factory, and the widget is cleared immediately so nothing is drawn.

Out of scope, with reasons: the editor setting (the operator applies it, and the workspace config is a separate decision), the roadmap's reach row filed under M3.3.8, and the orphaned `workflow/vscode/imageConfig/sandbox-agent-sandbox.json` carried from handover `20261124-01`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| pi's own title write reaches the terminal as the run id. | `wire.test.ts` `claims the terminal's title writer`; and the pty capture below | Agent [x] |
| No write in a session carries pi's title. | pty capture: five writes, every one carrying the id, none carrying the cwd name | Agent [x] |
| The widget that reached the TUI is dropped. | `wire.test.ts` `claims the terminal once, and drops the widget` | Agent [x] |
| The extension stays inert with no run id, and writes without a TUI. | `wire.test.ts` the last two units | Agent [x] |
| The extension's node suite and its wrapper pass. | `bash tests/test_session_title.sh` | Agent [x] |
| Every decision this iteration records is realized in the files. | read `index.ts` and the README against the Decisions table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Claim `tui.terminal.setTitle` rather than defer the write. | The claim removes the ordering question and the second write; a timer only wins the race and keeps both writes, so the tab can flicker. The claim also covers every later pi write without a per-event handler. | This record; `index.ts`; the extension's README |
| Reach the TUI through `ctx.ui.setWidget` and clear the widget at once. | The widget factory is documented and is the only documented route that hands an extension the TUI instance; clearing it keeps the key a handle rather than a surface. | This record; `index.ts` |
| Guard on `tui.terminal?.setTitle` and fall back to the plain write. | `terminal` is public on the TUI type but is not in `docs/tui.md`; a missing writer should degrade to the previous behaviour, not throw. | This record; `index.ts` |
| Keep a zero-delay `setTimeout` recorded as the fallback rather than shipped. | Measured: it lands after pi's write, so it is the shape to return to if the claim stops working; a microtask does not, and this is the trap that the first version fell into. | This record; the extension's README |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| pi writes its own title after the event handler returns, past a microtask boundary. Measured: a synchronous write in the handler is replaced; `queueMicrotask` still loses; a zero-delay `setTimeout` wins. | measurement | every event-based title write in an extension is silently defeated, and a test of the handler cannot see it | the claim; recorded in the README |
| pi's writes and an extension's `ctx.ui.setTitle` share one method, `tui.terminal.setTitle` (`interactive-mode.js` `createExtensionUIContext`). | code | one claim owns the tab, so shadowing is possible rather than fragile | `index.ts` |
| The earlier T7 verification captured the escape sequence but read the order backwards, so a red behaviour passed a green check. | process | a pty assertion has to name the last write, not the presence of a write | this record; the README states the last-write form |
| The extension's own unit test asserted the registrations and the write, and could not see the order, which is why the defect shipped. | code | the new unit asserts the claim and that pi's later write arrives as the run id | `wire.test.ts` |
| `SESSION_ID` is set in every process of a session container, not only in pi, so a pty check must pass the id explicitly to test both branches. | measurement | an inherited id silently turns the inert branch into the active one | this record |
| `workflow/vscode/imageConfig/sandbox-agent-sandbox.json` is referenced by no script and no document. | record | an orphan config an editor-surface change would silently not affect | out of scope, carried from handover `20261124-01` |

## Completed

| File | One-line change summary |
|---|---|
| `src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/index.ts` | claims `tui.terminal.setTitle` through the widget factory, once, with the plain write kept as the fallback |
| `src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/README.md` | records the claim, the measured order, the fallback, and the third guard |
| `tests/extensions/pi/session-title/wire.test.ts` | asserts the claim, pi's later write arriving as the run id, the dropped widget, and the two guards |
| `devlog/roadmap.md` | the T7 row's mechanism corrected in place; a row for this fix added under it |
| `devlog/handovers/T7/20261124-03-fix-terminal_title_shadow.md` | this record |
