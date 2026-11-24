# session-title

Names the terminal tab after the session's run id: the app mark (code point U+03C0), a hyphen, then the id.

## Why an extension and not the harness

pi writes the tab title itself, in `interactive-mode.js`: at `init`, at session bind, on an agent reset, and on `session_info_changed`. No settings key disables that, and the harness runs on the host, so a title written by `make start` is replaced before the first frame. Only a process inside pi can write after pi, which is what this extension is.

## The events

The extension writes on three events, each of which follows pi's own write:

- `session_start` -- the startup path.
- `agent_start` -- the first event that always follows the startup writes, and it repeats per run, so the title returns after any write pi makes in between.
- `session_info_changed` -- a rename.

**Measured order at startup (2026-11-24, pty capture).** The extension's `session_start` write lands first and pi's init write lands second, so the tab carries pi's own title until the first run begins; `agent_start` then puts the run id back, and pi makes no further write during idle turns. `ui_prompt_start` was tried as a later hook and did not fire before the first prompt, so it is not registered.

## The format

The title is the app mark, a hyphen and the run id, and nothing else. The id is the harness's session identity, read once from `SESSION_ID` because it is fixed for the container's life. The builder is `title.ts`, a pure function with no pi import.

Two guards keep it honest:

- **No run id, no title.** A pi run outside the harness keeps pi's own title rather than a made-up value.
- **No UI, no call.** `setTitle` exists in interactive mode only; print, json and rpc runs carry no terminal UI, so the handler checks the capability.

## Where the id comes from

`SESSION_ID` in the agent container's environment, declared in `src/build/docker-compose.yml`. The editor side needs one setting, stated in the quickstart: `"terminal.integrated.tabs.title": "${sequence}"`.

## Tests

`tests/test_session_title.sh` runs the node suite in `tests/extensions/pi/session-title/`: `title.test.ts` for the format and its empty cases, `wire.test.ts` for the registrations, the guard, and the inert run.
