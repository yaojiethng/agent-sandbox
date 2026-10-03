/**
 * The Run facade: the persisted face of the queue. The primary's pi process
 * opens a Run per operation; the Run loads the persisted state, applies one
 * pure operation, writes the state back atomically, and appends the journal.
 *
 * Every one of those steps runs inside the state directory's ownership
 * lock, so the complete load-derive-save cycle is serialized against
 * another process on the same state directory, not only against another
 * tool call of the same turn. The lock is held around the git work too
 * when the operation needs it, which is why `transact` takes the whole
 * derivation rather than only its result: the fork's cut, the re-queue's
 * rollback, and the bring-back's write all happen inside the same
 * critical section as the record they leave.
 *
 * Persistence is per operation, so the queue survives primary restarts and
 * a crashed operation is simply retried: request ids are recorded exactly
 * once, so a retry cannot double-enqueue.
 */

import { TaskQueueError } from "./errors.ts";
import { withOwnershipLock, requireSync, type LockScope, type SectionLive } from "./lock.ts";
import type { OpResult } from "./ops.ts";
import { appendJournal, type JournalEvent } from "./record.ts";
import { freshState, loadState, saveState, type RunBaseline, type RunState } from "./state.ts";

export interface RunIdentity {
	/** The pi session writing this state directory, for the lock metadata. */
	sessionId?: string;
	/**
	 * The repository's pre-existing worktrees and branches, read inside the
	 * lock and only when the run is new. The close sweep uses them to tell
	 * the repository's own state apart from this run's leftovers.
	 */
	snapshotBaseline?: () => RunBaseline;
}

export class Run {
	readonly stateDir: string;
	readonly mainRoot: string;
	private readonly sessionId: string;
	private constructor(stateDir: string, mainRoot: string, sessionId: string) {
		this.stateDir = stateDir;
		this.mainRoot = mainRoot;
		this.sessionId = sessionId;
	}

	/**
	 * Open the run in a state directory; a missing state starts a fresh run.
	 * The create runs under the lock, so two processes opening one
	 * directory cannot each write their own fresh state over the other.
	 */
	static open(stateDir: string, mainRoot: string, now = new Date().toISOString(), baseline?: RunBaseline, identity?: RunIdentity): Run {
		const run = new Run(stateDir, mainRoot, identity?.sessionId ?? "unknown");
		run.start(now, baseline, identity?.snapshotBaseline);
		return run;
	}

	private start(now: string, baseline: RunBaseline | undefined, snapshot: (() => RunBaseline) | undefined): void {
		withOwnershipLock(this.stateDir, { sessionId: this.sessionId }, () => {
			const loaded = loadState(this.stateDir);
			if (loaded) {
				if (loaded.mainRoot !== this.mainRoot) {
					throw new TaskQueueError(
						"run-state-mismatch",
						`state ${this.stateDir} was opened for ${loaded.mainRoot}, not ${this.mainRoot}; one state directory serves one main tree`,
					);
				}
				return;
			}
			const state = freshState(this.mainRoot, this.stateDir, now, snapshot ? snapshot() : baseline);
			saveState(state);
			appendJournal(this.stateDir, [{ type: "run:open", at: now, mainRoot: this.mainRoot }]);
		});
	}

	current(): RunState {
		const state = loadState(this.stateDir);
		if (!state) {
			throw new TaskQueueError("state-corrupt", `run state vanished from ${this.stateDir}`);
		}
		return state;
	}

	/**
	 * Apply one operation under the lock: load, derive, persist, journal.
	 * The derive step is handed the loaded state and the lock's liveness
	 * refresh, and may perform the git work the operation needs, so the
	 * work and the record it leaves are one serialized unit. A derive that
	 * runs long beats at each git step, so a live section's lock is never
	 * taken from it. Journal failures are surfaced on the result rather
	 * than failing the operation: the state file is durable even when the
	 * audit trail is not. A post-record step runs here too, still under the
	 * lock and only once the record is durable, so a transition that leaves
	 * evidence for its own recovery drops it in that order. An async derive
	 * is refused at once: it would release the lock at its first await and
	 * keep writing past it.
	 */
	transact<D>(
		fn: (state: RunState, live: SectionLive) => OpResult<D>,
		scope?: LockScope,
	): { data: D; events: JournalEvent[]; journalError?: string } {
		return withOwnershipLock(this.stateDir, { sessionId: this.sessionId, ...scope }, (live) => {
			const state = this.current();
			const result = requireSync(fn(state, live));
			saveState(result.state);
			let journalError: string | undefined;
			try {
				appendJournal(this.stateDir, result.events);
			} catch (err) {
				journalError = String(err);
			}
			result.commit?.();
			return { data: result.data, events: result.events, journalError };
		});
	}

	handle<D>(fn: (state: RunState, live: SectionLive) => OpResult<D>): { data: D; events: JournalEvent[]; journalError?: string } {
		return this.transact(fn);
	}
}
