/**
 * The tab title, as a pure function of the run id.
 *
 * A terminal title is the payload of one OSC escape sequence, so a control byte
 * inside it would end the sequence early and leave the rest of the title on the
 * screen as text. The id is sanitized before it is formatted.
 */

/** The app mark pi uses in its own title. */
export const APP_MARK = "π";

/**
 * Keep only the bytes that may appear in a title: no C0 controls, no DEL.
 * Returns "" for a missing value, so callers have one empty case.
 */
export function sanitizeRunId(value: string | undefined): string {
	if (!value) return "";
	return value.replace(/[\u0000-\u001f\u007f]/g, "").trim();
}

/** `π - <run id>`, or undefined when there is no run id to show. */
export function sessionTitle(runId: string | undefined): string | undefined {
	const id = sanitizeRunId(runId);
	return id === "" ? undefined : `${APP_MARK} - ${id}`;
}
