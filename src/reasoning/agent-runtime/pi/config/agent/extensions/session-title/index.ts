/**
 * session-title: the terminal tab carries the run id.
 *
 * pi writes the tab title itself -- `${APP_TITLE} - <sessionName> - <cwd>` -- at init,
 * at session bind, on an agent reset, and on `session_info_changed`. No settings
 * key disables that, and a writer outside pi cannot run after it, so the only
 * place a title can survive is inside the process: this module writes on the
 * events that follow pi's own writes.
 *
 * The title is `π - <run id>` and nothing else. The run id is the harness's
 * session identity, read once from `SESSION_ID` because it is fixed for the
 * container's life. With no id the extension stays inert, so a pi run outside
 * the harness keeps pi's title.
 *
 * `setTitle` exists in interactive mode only; print, json and rpc runs carry no
 * terminal UI, so the handler checks the capability rather than assuming it.
 *
 * README.md records the behaviour and its evidence; `title.ts` holds the format.
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { sessionTitle } from "./title.ts";

export default function sessionTitleExtension(pi: ExtensionAPI): void {
	const title = sessionTitle(process.env.SESSION_ID);
	if (title === undefined) return;

	const apply = (_event: unknown, ctx: ExtensionContext): void => {
		if (typeof ctx.ui?.setTitle !== "function") return;
		ctx.ui.setTitle(title);
	};

	pi.on("session_start", apply);
	pi.on("agent_start", apply);
	pi.on("session_info_changed", apply);
}
