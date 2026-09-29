/**
 * The transition table: the one explicit from-state x action -> to-state
 * matrix of the whole state machine.
 *
 * Every legality question the queue asks is asked of this table: a task
 * accepts a break point because the table has a join row from its phase, a
 * task verifies because the table has a verify row from its phase, an entry
 * triggers because the table has a trigger row from its state. An edge that
 * is not in the table is not expressible, and the suite walks the table
 * rather than a list of conditionals, so a phase or an action cannot be
 * added without the machine check noticing.
 *
 * Three subjects share the shape. The task has four phases; the queue
 * entry has its three states; the run is open or closed. The rows are
 * typed, so a phase or an action that does not exist cannot be written
 * down.
 */

import { TaskQueueError } from "./errors.ts";
import type { EntryState } from "./queue.ts";
import type { TaskPhase } from "./tasks.ts";

/** What the primary does to a task. */
export type TaskAction =
	| "fork"
	| "join"
	| "verify-usable"
	| "verify-not-usable"
	| "propose"
	| "bring-back"
	| "requeue-in-place"
	| "requeue-fresh";

/** The two re-queue routes, named by what each one does to the worktree. */
export type RequeueRoute = "in-place" | "fresh";

/** What the queue does to one entry. */
export type EntryAction = "schedule" | "trigger";

/** What the primary does to the run. */
export type RunAction = "close";

/** The run is open until it is closed. */
export type RunPhase = "open" | "closed";

export interface TaskTransition {
	/** The phase the task is in; null is "no task yet". */
	from: TaskPhase | null;
	action: TaskAction;
	to: TaskPhase;
}

export interface EntryTransition {
	from: EntryState;
	action: EntryAction;
	to: EntryState;
}

export interface RunTransition {
	from: RunPhase;
	action: RunAction;
	to: RunPhase;
}

/**
 * The task lifecycle. `verify` is two rows because the audit's outcome
 * routes the task two ways: a usable audit terminates the task, a
 * not-usable one leaves it in the queue for another segment. The re-queue
 * rows are the two routes the primary chooses between: the same worktree
 * and the same worker, or a fresh cut from the baseline.
 */
export const TASK_TRANSITIONS: readonly TaskTransition[] = [
	{ from: null, action: "fork", to: "forked" },
	{ from: "forked", action: "join", to: "active" },
	{ from: "active", action: "join", to: "active" },
	{ from: "active", action: "verify-usable", to: "terminated" },
	{ from: "active", action: "verify-not-usable", to: "active" },
	{ from: "active", action: "requeue-in-place", to: "active" },
	{ from: "active", action: "requeue-fresh", to: "forked" },
	{ from: "terminated", action: "propose", to: "terminated" },
	{ from: "terminated", action: "bring-back", to: "retired" },
	{ from: "retired", action: "close", to: "retired" },
];

/**
 * The entry states. A triggered entry has no outgoing row, which is the
 * single-trigger rule (I5) stated once: nothing can move an entry off
 * triggered, and a requested entry cannot skip the schedule.
 */
export const ENTRY_TRANSITIONS: readonly EntryTransition[] = [
	{ from: "requested", action: "schedule", to: "scheduled" },
	{ from: "scheduled", action: "trigger", to: "triggered" },
];

/** The run. A closed run has no outgoing row. */
export const RUN_TRANSITIONS: readonly RunTransition[] = [{ from: "open", action: "close", to: "closed" }];

/** Every task phase, in lifecycle order. */
export const TASK_PHASES: readonly TaskPhase[] = ["forked", "active", "terminated", "retired"];

/** The phase one action leads to, or undefined when the action is not legal there. */
export function taskTo(from: TaskPhase | null | undefined, action: TaskAction): TaskPhase | undefined {
	return TASK_TRANSITIONS.find((t) => t.from === (from ?? null) && t.action === action)?.to;
}

/**
 * The phase one action leads to, for a call that already passed its gate.
 * A missing row means the gate and the table disagree, which is a defect in
 * this extension rather than a caller's mistake, so it is reported as a
 * corrupt state instead of silently leaving the phase where it was.
 */
export function nextPhase(from: TaskPhase, action: TaskAction): TaskPhase {
	const to = taskTo(from, action);
	if (to === undefined) {
		throw new TaskQueueError("state-corrupt", `the transition table carries no ${action} row from ${from}; the gate and the table disagree`);
	}
	return to;
}

/** The actions a phase admits, in table order. */
export function taskActions(from: TaskPhase): TaskAction[] {
	return TASK_TRANSITIONS.filter((t) => t.from === from).map((t) => t.action);
}

/** The phases an action is legal from, for the gate message. */
export function taskPhasesOf(action: TaskAction): TaskPhase[] {
	return [...new Set(TASK_TRANSITIONS.filter((t) => t.action === action && t.from !== null).map((t) => t.from as TaskPhase))];
}

/** True when the action is legal from the phase. */
export function canTask(from: TaskPhase | null | undefined, action: TaskAction): boolean {
	return taskTo(from, action) !== undefined;
}

/** The entry state one action leads to, or undefined when it is not legal. */
export function entryTo(from: EntryState, action: EntryAction): EntryState | undefined {
	return ENTRY_TRANSITIONS.find((t) => t.from === from && t.action === action)?.to;
}

/** The run state one action leads to, or undefined when it is not legal. */
export function runTo(from: RunPhase, action: RunAction): RunPhase | undefined {
	return RUN_TRANSITIONS.find((t) => t.from === from && t.action === action)?.to;
}

/**
 * A phase no action leaves: the only phase a task can end in. Derived from
 * the table rather than listed, so a new terminal phase is declared by its
 * rows.
 */
export function isTerminalPhase(phase: TaskPhase): boolean {
	return !TASK_TRANSITIONS.some((t) => t.from === phase && t.to !== phase);
}

/** A one-line rendering of a legal edge, for a gate that rejects one. */
export function legalFrom(action: TaskAction): string {
	const phases = taskPhasesOf(action);
	return phases.length === 0 ? "nowhere" : phases.join(" or ");
}
