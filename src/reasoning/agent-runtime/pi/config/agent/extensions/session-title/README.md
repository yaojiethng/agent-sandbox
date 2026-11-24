# session-title

Names the terminal tab after the session's run id: the app mark (code point U+03C0), a hyphen, then the id.

## Why an extension and not the harness

pi writes the tab title itself, in `interactive-mode.js`: at `init`, at session bind, on an agent reset, and on `session_info_changed`. No settings key disables that, and the harness runs on the host, so a title written by `make start` is replaced before the first frame. Only a process inside pi can write after pi, which is what this extension is.

## How it wins: it owns the title writer

pi's four writes and an extension's `ctx.ui.setTitle` all reach the terminal through one method, `tui.terminal.setTitle`, which emits `ESC ] 0 ; <title> BEL`. The extension claims that method on the first event, so every later write -- pi's included -- carries the run id:

```ts
const write = tui.terminal.setTitle.bind(tui.terminal);
tui.terminal.setTitle = () => write(title);
```

Reaching the TUI instance takes one call: the widget factory, `ctx.ui.setWidget(key, (tui) => ...)`, hands it over. The widget is cleared in the same breath, so nothing is drawn and the key is a handle, not a surface.

Writing on the events alone does not work, and the first version of this extension did exactly that. Measured 2026-11-24 in a pty: a synchronous `setTitle` in a handler lands *before* pi's own write for the same event, so pi replaces it and the tab reads pi's cwd title. The write is deferred behind an `await`, so a microtask is still too early; a a zero-delay `setTimeout` does land after it, and that is the fallback shape if the claim above ever stops working. Claiming the writer removes the ordering question rather than winning it, and it is also the only option that suppresses the second write, so the tab does not flicker.

**Measured after the change (2026-11-24, pty capture, interactive pi with `SESSION_ID=abc123`).** Five title writes in a session, every one carrying the run id, none carrying pi's own title. With `SESSION_ID` unset the extension registers nothing and pi's title stands.

## The events

The extension writes on three events, so the title is right even before the first claim lands:

- `session_start` -- the startup path.
- `agent_start` -- repeats per run.
- `session_info_changed` -- a rename.

## The format

The title is the app mark, a hyphen and the run id, and nothing else. The id is the harness's session identity, read once from `SESSION_ID` because it is fixed for the container's life. The builder is `title.ts`, a pure function with no pi import.

Three guards keep it honest:

- **No run id, no title.** A pi run outside the harness keeps pi's own title rather than a made-up value.
- **No UI, no call.** `setTitle` exists in interactive mode only; print, json and rpc runs carry no terminal UI, so the handler checks the capability.
- **No terminal, no claim.** A TUI without a title writer leaves the plain write in place rather than throwing.

## Where the id comes from

`SESSION_ID` in the agent container's environment, declared in `src/build/docker-compose.yml`. The editor side needs one setting, stated in the quickstart: `"terminal.integrated.tabs.title": "${sequence}"`.

## Tests

`tests/test_session_title.sh` runs the node suite in `tests/extensions/pi/session-title/`: `title.test.ts` for the format and its empty cases; `wire.test.ts` for the registrations, the guard, the inert run, and the claim -- that a write pi makes after the claim reaches the terminal as the run id, and that the widget that reached the terminal is dropped.
