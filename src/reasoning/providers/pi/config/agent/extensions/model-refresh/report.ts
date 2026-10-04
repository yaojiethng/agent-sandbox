/**
 * Where the catalog transition is announced.
 *
 * The extension used to log its progress to `console.warn`. The TUI owns the
 * terminal, so a line written behind its back lands inside the rendered frame
 * and every line after it is drawn against the wrong frame. The fix is not a
 * different string; it is a different sink.
 *
 * The announcement is a function of the catalog transition, not of the update:
 * `refreshModels` records what the served catalog gained, lost and revised, and
 * this module renders that delta. A run that changed nothing and failed nothing
 * announces nothing, which is the correct rendering of a transition that did
 * not move.
 *
 * `refreshModels` runs while the model runtime is being built, before any
 * extension UI exists, so a startup report is held and rendered on
 * `session_start`, the first event carrying a UI. A refresh after that point
 * renders on completion. In a mode with no TUI there is no frame to corrupt, so
 * the console stays the sink there.
 */

import type { CatalogReport } from "./types.ts";

/** The subset of pi's `ExtensionUIContext` this module uses. */
export interface ReportUi {
	notify(message: string, type?: "info" | "warning" | "error"): void;
}

/** The one-line delta a catalog change announces. */
export function deltaLine(report: CatalogReport): string {
	return `updated catalog: +${report.added} / -${report.removed}, ${report.revised} revised`;
}

/**
 * What one report renders: the delta line when the catalog changed, then one
 * warning per source that failed. An unchanged, failure-free report renders
 * nothing at all.
 */
export function notices(report: CatalogReport): { message: string; type: "info" | "warning" }[] {
	const out: { message: string; type: "info" | "warning" }[] = [];
	if (report.changed) {
		out.push({ message: deltaLine(report), type: "info" });
	}
	for (const failure of report.failures) {
		out.push({ message: failure, type: "warning" });
	}
	return out;
}

/**
 * Holds the latest reconciliation and renders it into pi's UI.
 *
 * Only the latest is kept. A startup that refreshes twice must not announce
 * twice, and the newer report is the one that describes the catalog in use.
 */
export function createReporter() {
	let latest: CatalogReport | undefined;
	let ui: ReportUi | undefined;

	// Internal on purpose, and unguarded on purpose: both call sites below check
	// the one precondition themselves, so a guard here would be a branch no case
	// can reach and therefore no case can test.
	function render(): void {
		for (const notice of notices(latest)) {
			ui.notify(notice.message, notice.type);
		}
	}

	return {
		/** Capture the UI. Called from `session_start`, the first event that has one. */
		attach(next: ReportUi): void {
			ui = next;
			if (latest !== undefined) render();
		},
		/** Record a reconciliation. Renders at once when a UI is already attached. */
		record(report: CatalogReport): void {
			latest = report;
			if (ui !== undefined) render();
		},
		/** The report held, for the console sink and for a caller that wants it. */
		current(): CatalogReport | undefined {
			return latest;
		},
	};
}
