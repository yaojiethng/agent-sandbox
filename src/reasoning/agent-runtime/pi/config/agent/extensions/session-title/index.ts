/**
 * session-title: the terminal tab carries the run id.
 *
 * pi writes the tab title itself -- `${APP_TITLE} - <sessionName> - <cwd>` -- at init,
 * at session bind, on an agent reset, and on `session_info_changed`. No settings key
 * disables that, and a writer outside pi cannot run after it, so the only place a
 * title can survive is inside the process.
 *
 * Every one of those writes, and an extension's `ctx.ui.setTitle` too, goes through a
 * single method: `tui.terminal.setTitle`. This module claims that method on the first
 * event, so pi's own writes carry the run id as well and the title has no race to
 * lose. Writing on the events alone is not enough: pi issues its write after the
 * event returns, so a synchronous write lands underneath pi's and is replaced.
 *
 * The widget factory is the documented way to reach the TUI instance, and the widget
 * is dropped in the same breath, so nothing is drawn.
 *
 * The title is `π - <run id>` and nothing else. The run id is the harness's session
 * identity, read once from `SESSION_ID` because it is fixed for the container's life.
 * With no id the extension stays inert, so a pi run outside the harness keeps pi's
 * title.
 *
 * `setTitle` exists in interactive mode only; print, json and rpc runs carry no
 * terminal UI, so the handler checks the capability rather than assuming it.
 *
 * README.md records the behaviour and its evidence; `title.ts` holds the format.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { sessionTitle } from "./title.ts";

/** The widget is a handle on the TUI instance; nothing is drawn. */
const WIDGET_KEY = "session-title";

export default function sessionTitleExtension(pi: ExtensionAPI): void {
	const title = sessionTitle(process.env.SESSION_ID);
	if (title === undefined) return;

	let claimed = false;

	const claim = (_event: unknown, ctx: ExtensionContext): void => {
		if (typeof ctx.ui?.setTitle !== "function") return;
		ctx.ui.setTitle(title);
		if (claimed) return;
		ctx.ui.setWidget(WIDGET_KEY, (tui) => {
			if (typeof tui.terminal?.setTitle !== "function") return { render: () => [] };
			const write = tui.terminal.setTitle.bind(tui.terminal);
			tui.terminal.setTitle = () => write(title);
			write(title);
			claimed = true;
			return { render: () => [] };
		});
		ctx.ui.setWidget(WIDGET_KEY, undefined);
	};

	pi.on("session_start", claim);
	pi.on("agent_start", claim);
	pi.on("session_info_changed", claim);
}
