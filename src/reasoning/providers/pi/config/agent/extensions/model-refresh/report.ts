/**
 * Where the catalog reconciliation is shown.
 *
 * The extension used to write its progress to `console.warn`. The TUI owns the
 * terminal, so a line written behind its back lands inside the rendered frame
 * and every line after it is drawn against the wrong frame. The fix is not a
 * different string; it is a different sink.
 *
 * `refreshModels` runs while the model runtime is being built, which is before
 * any extension UI exists, so the reconciliation is recorded as data and
 * rendered later, on `session_start`, which is the first event carrying a UI.
 * A refresh that happens after that point renders immediately, so a later
 * `/model` or a reload shows the same surfaces.
 *
 * In a mode with no TUI there is no frame to corrupt, so the console stays the
 * sink there. `ctx.mode` is the discriminator, not a guess.
 */

import type { CatalogReport } from "./types.ts";

/** The footer row the persistent summary occupies. */
export const STATUS_KEY = "model-refresh";

/** The working message shown while a refresh is in flight. */
export const WORKING_MESSAGE = "Refreshing model catalogs...";

/** The line shown when a refresh completes. */
export const COMPLETION_PREFIX = "Model catalogs refreshed.";

/** The subset of pi's `ExtensionUIContext` this module uses. */
export interface ReportUi {
	setStatus(key: string, text: string | undefined): void;
	setWorkingMessage(message?: string): void;
	notify(message: string, type?: "info" | "warning" | "error"): void;
}

/**
 * The one-line reconciliation, attributed per source.
 *
 * A source that was not reached is named as skipped rather than counted as
 * zero, so a line never reads as a source that answered with nothing.
 */
export function summarize(report: CatalogReport): string {
	const parts = [
		`${report.providerId}: ${report.served} served`,
		`baked ${report.baked}`,
		`store ${report.stored}`,
		`endpoint ${report.endpoint ?? "skipped"}`,
		`models.dev ${report.modelsDev ?? "skipped"}`,
	];
	const line = parts.join(", ");
	return report.failures.length === 0 ? line : `${line} (${report.failures.length} source(s) failed)`;
}

/** The notice shown on completion, carrying the failures when there are any. */
export function completion(report: CatalogReport): { message: string; type: "info" | "warning" } {
	const type = report.failures.length === 0 ? "info" : "warning";
	const head = `${COMPLETION_PREFIX} ${summarize(report)}`;
	return { message: report.failures.length === 0 ? head : `${head}. ${report.failures.join(". ")}`, type };
}

/**
 * Holds the latest reconciliation and renders it into pi's UI.
 *
 * Only the latest is kept. A startup that refreshes twice must not leave two
 * footer rows, and the newer report is the one that describes the catalog in
 * use.
 */
export function createReporter(statusKey: string = STATUS_KEY) {
	let latest: CatalogReport | undefined;
	let ui: ReportUi | undefined;

	// Internal on purpose, and unguarded on purpose: both call sites below check
	// the two preconditions themselves, so a guard here would be a branch no case
	// can reach and therefore no case can test.
	function render(): void {
		ui.setStatus(statusKey, summarize(latest));
		const done = completion(latest);
		ui.notify(done.message, done.type);
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
		/** Announce that a refresh is starting. No-op with no UI, by design. */
		begin(): void {
			ui?.setWorkingMessage(WORKING_MESSAGE);
		},
		/** Restore pi's default working message. */
		end(): void {
			ui?.setWorkingMessage();
		},
		/** The report held, for a caller that wants the counts itself. */
		current(): CatalogReport | undefined {
			return latest;
		},
	};
}
