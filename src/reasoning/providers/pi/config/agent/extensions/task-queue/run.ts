/**
 * The Run facade: the persisted face of the queue. The primary's pi process
 * opens a Run per operation; the Run loads the persisted state, applies one
 * pure operation, writes the state back atomically, and appends the journal.
 *
 * Persistence is per operation, so the queue survives primary restarts and
 * a crashed operation is simply retried: request ids are recorded exactly
 * once, so a retry cannot double-enqueue.
 */

import { TaskQueueError } from "./errors.ts";
import type { OpResult } from "./ops.ts";
import { appendJournal, type JournalEvent } from "./record.ts";
import { freshState, loadState, saveState, type RunBaseline, type RunState } from "./state.ts";

export class Run {
	readonly stateDir: string;
	readonly mainRoot: string;
	private constructor(stateDir: string, mainRoot: string) {
		this.stateDir = stateDir;
		this.mainRoot = mainRoot;
	}

	/**
	 * Open the run in a state directory; a missing state starts a fresh run.
	 * The caller passes the repository's pre-existing worktrees and branches
	 * when it creates the run; the close sweep uses them to tell repository
	 * state apart from this run's leftovers.
	 */
	static open(stateDir: string, mainRoot: string, now = new Date().toISOString(), baseline?: RunBaseline): Run {
		const run = new Run(stateDir, mainRoot);
		const loaded = loadState(stateDir);
		if (!loaded) {
			const state = freshState(mainRoot, stateDir, now, baseline);
			saveState(state);
			appendJournal(stateDir, [{ type: "run:open", at: now, mainRoot }]);
			return run;
		}
		if (loaded.mainRoot !== mainRoot) {
			throw new TaskQueueError(
				"run-state-mismatch",
				`state ${stateDir} was opened for ${loaded.mainRoot}, not ${mainRoot}; one state directory serves one main tree`,
			);
		}
		return run;
	}

	current(): RunState {
		const state = loadState(this.stateDir);
		if (!state) {
			throw new TaskQueueError("state-corrupt", `run state vanished from ${this.stateDir}`);
		}
		return state;
	}

	/**
	 * Apply one operation: load, transition, persist, journal. Journal
	 * failures are surfaced on the result rather than failing the operation:
	 * the state file is durable even when the audit trail is not.
	 */
	handle<D>(fn: (state: RunState) => OpResult<D>): { data: D; events: JournalEvent[]; journalError?: string } {
		const state = this.current();
		const result = fn(state);
		saveState(result.state);
		let journalError: string | undefined;
		try {
			appendJournal(this.stateDir, result.events);
		} catch (err) {
			journalError = String(err);
		}
		return { data: result.data, events: result.events, journalError };
	}
}