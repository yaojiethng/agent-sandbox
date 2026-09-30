/**
 * The invariant report's catalog and renderer: a naming layer over the
 * conformance suite, with no test logic of its own.
 *
 * The suite proves the invariants one deep test at a time. That is the right
 * depth, and it leaves one gap: a failure names a test, not an invariant, so
 * the operator reads a red line and has to remember which invariant that
 * test was written for. This module is the index. Every invariant the
 * primitive claims has one named case here, each case names the record that
 * states it, and the renderer prints the index with a verdict per
 * invariant, so a red line reads `I7` and the operator knows which review
 * finding class to look at.
 *
 * The lifecycle cases are derived, never listed. The four-phase lifecycle
 * and the transition table are the extension's own source of truth
 * (`transitions.ts`), and a hard-coded phase list here would be a second
 * list to drift: adding a phase to the table would leave this report
 * asserting a lifecycle the extension no longer has. The catalog therefore
 * builds its lifecycle cases from `TASK_PHASES` and its table case from
 * `TASK_TRANSITIONS`, and the report's own self-check compares the derived
 * set against the table.
 */

import { ENTRY_TRANSITIONS, TASK_PHASES, TASK_TRANSITIONS, type TaskAction, type TaskPhase } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/transitions.ts";

/** One named case of one invariant. */
export interface InvariantCase {
	/** The invariant label a review finding is filed under. */
	id: string;
	/** The case name inside the invariant; a derived case names its own subject. */
	name: string;
	/** One sentence: what holds. The report prints this verbatim. */
	statement: string;
	/** Where the case reads its expectation from. */
	source: string;
}

/** The tool surface, as the report names it. The gate must not change it. */
export const TOOL_SURFACE = [
	"taskq_fork",
	"taskq_join",
	"taskq_verify",
	"taskq_proposal",
	"taskq_merge",
	"taskq_requeue",
	"taskq_close",
	"taskq_status",
	"taskq_worker_request",
] as const;

/** The record that states the invariants this report indexes. */
const ADR = "docs/adr/task_queue_primitive.md";

/** Every distinct task action the table names, in table order. */
export function tableActions(): TaskAction[] {
	const seen: TaskAction[] = [];
	for (const row of TASK_TRANSITIONS) if (!seen.includes(row.action)) seen.push(row.action);
	return seen;
}

/**
 * The registered tool that drives each action the table names. The map is
 * keyed by the action union, so an action the table gains is a type error
 * here until the report says which tool drives it.
 */
const TOOL_OF_ACTION: Record<TaskAction, string> = {
	fork: "taskq_fork",
	join: "taskq_join",
	"verify-usable": "taskq_verify",
	"verify-not-usable": "taskq_verify",
	propose: "taskq_proposal",
	"bring-back": "taskq_merge",
	"requeue-in-place": "taskq_requeue",
	"requeue-fresh": "taskq_requeue",
	close: "taskq_close",
};

/** The action the table's first row into a phase names. */
export function actionInto(phase: TaskPhase): TaskAction {
	const row = TASK_TRANSITIONS.find((t) => t.to === phase);
	return row?.action ?? "fork";
}

/** The phases an action is legal from, null excluded. */
function fromPhasesOf(action: TaskAction): string {
	return [...new Set(TASK_TRANSITIONS.filter((t) => t.action === action).map((t) => String(t.from)))].join(", ");
}

/**
 * The call the walk reads a phase's snapshot after. Derived from the table's
 * own first row into the phase, so a phase the table gains gets a step
 * without this file naming the phase or the step.
 */
export function stepInto(phase: TaskPhase): string {
	return TOOL_OF_ACTION[actionInto(phase)];
}

/**
 * The catalog. The lifecycle entries are derived from the table; the rest
 * are the labels the primitive's own records use, one case each.
 */
export function buildCatalog(): InvariantCase[] {
	const cases: InvariantCase[] = [
		{
			id: "I1",
			name: "exactly-once identities",
			statement: "every recorded request produced exactly one entry, and every entry triggered exactly once",
			source: `${ADR} R1; the close audit over taskq_status counts`,
		},
		{
			id: "I5",
			name: "single trigger",
			statement: "a triggered entry has no outgoing edge, and a second trigger of it is refused",
			source: `${ADR} R1; the entry transition table`,
		},
		{
			id: "I7",
			name: "file-set bring-back",
			statement: "the bring-back writes exactly the file set the primary names, and leaves this run's own intent record behind when it stops",
			source: `${ADR} R5; taskq_status bringBack, and the run's bringback record`,
		},
		{
			id: "I11",
			name: "atomic join transition",
			statement: "one join is one write: the queue rests only in triggered, and the state file lands by one rename",
			source: `${ADR} R8; taskq_status entries, and the state file's inode across a write`,
		},
		{
			id: "I12",
			name: "inert timeout",
			statement: "an operation that stops spends nothing: a timed-out join consumes nothing, and a refused bring-back writes nothing",
			source: `${ADR} R8; taskq_status before and after the failed call`,
		},
		{
			id: "J1",
			name: "atomic subsume",
			statement: "the join subsumes record, schedule, and trigger as one transition, so the queue never rests in an intermediate state",
			source: `${ADR} R10; taskq_status entries after one join`,
		},
		{
			id: "J2",
			name: "exactly-once delivery",
			statement: "two joins on one worker request deliver it once, and the queue holds one entry for it",
			source: `${ADR} R1; taskq_status counts after two concurrent joins`,
		},
		{
			id: "J3",
			name: "blocking and inert wait",
			statement: "the join refuses a timeout it cannot honour at once, and a timed-out join consumes nothing",
			source: `${ADR} R10; the join result and taskq_status`,
		},
		{
			id: "J4",
			name: "one held join-unit",
			statement: "one held join-unit (a single join or one pool batch) waits on the operator, and taskq_status names the step that clears it",
			source: `${ADR} R10; taskq_status hold`,
		},
		{
			id: "J5",
			name: "order-safe selection",
			statement: "break points trigger in request order per task, and the named task wins across a fan-out",
			source: `${ADR} R2; taskq_status entries in delivery order`,
		},
		{
			id: "W1",
			name: "the fork owns the location",
			statement: "the fork takes no path: the worktree is derived from the run and the task, and a worktree inside the main tree is refused",
			source: `${ADR} R11; the fork schema and the derived worktree`,
		},
		{
			id: "W2",
			name: "one canonical location",
			statement: "a leftover at the canonical path is refused and the path is named",
			source: `${ADR} R11; the fork refusal`,
		},
		{
			id: "W3",
			name: "outside the main tree",
			statement: "the cut worktree sits outside the main tree, and the cut writes nothing into it",
			source: `${ADR} R11; the main tree's porcelain after the cut`,
		},
		{
			id: "S1",
			name: "the written loop closes",
			statement: "the tool surface drives the whole loop, from the fork to the close, and every tool in the surface is exercised",
			source: `${ADR} R12; the driven run and the registered tool names`,
		},
		{
			id: "S3",
			name: "no intermediate break-point surface",
			statement: "no registered tool exposes an intermediate break-point state to drive",
			source: `${ADR} R9 and the 2026-09-30 decision; the registered tool names`,
		},
		{
			id: "T1",
			name: "no value judgement",
			statement: "the phases and the audit outcomes are a structural finding about the return, and the bring-back's decision is a file set, not a grade",
			source: `${ADR} R14; the phase vocabulary, the outcome vocabulary, and the bring-back record`,
		},
		{
			id: "R12",
			name: "the transition-table walk",
			statement: `the report's lifecycle cases are the table's own phases, and every action the table names is one this report indexes`,
			source: `${ADR} R12; transitions.ts`,
		},
		{
			id: "R13",
			name: "one primary per state directory",
			statement: "a second writer on a state directory a live process owns is refused, and the refusal names that owner",
			source: `${ADR} R13; the ownership lock refusal`,
		},
		// The four-phase lifecycle, derived. A phase added to the table adds
		// a case here, and a phase removed removes one.
		...TASK_PHASES.map((phase) => ({
			id: "R14",
			name: `phase ${phase}`,
			statement: `the wired tools report a task as ${phase}, and the walk reads it after ${stepInto(phase)}, the step the table reaches that phase from ${fromPhasesOf(actionInto(phase))}`,
			source: `${ADR} R14; taskq_status phase, and the table's own row`,
		})),
	];
	return cases;
}

/** The entry states the table carries, for the single-trigger case. */
export function triggeredStates(): string[] {
	return [...new Set(ENTRY_TRANSITIONS.filter((t) => t.from === "triggered").map((t) => t.action))];
}

export type Outcome = "pass" | "fail" | "skip";

export interface CaseResult {
	id: string;
	name: string;
	statement: string;
	source: string;
	outcome: Outcome;
	/** The assertion message of a failed case. */
	detail?: string;
}

/** The index: one line per case, then the failing invariants. */
export function renderReport(results: readonly CaseResult[]): string {
	const width = Math.max(0, ...results.map((r) => r.id.length));
	const lines = results.map((r) => `  ${r.id.padEnd(width)}  ${r.outcome.toUpperCase().padEnd(4)}  ${r.statement}${r.detail ? ` -- ${r.detail}` : ""}`);
	const failed = [...new Set(results.filter((r) => r.outcome === "fail").map((r) => r.id))];
	const skipped = [...new Set(results.filter((r) => r.outcome === "skip").map((r) => r.id))];
	const passed = results.filter((r) => r.outcome === "pass").length;
	const head = `invariant report: ${results.length} cases across ${new Set(results.map((r) => r.id)).size} invariants, ${passed} pass, ${failed.length} fail, ${skipped.length} skip`;
	const tail = [
		failed.length > 0 ? `failing invariants (the review-finding classes to read): ${failed.join(", ")}` : "",
		skipped.length > 0 ? `skipped invariants: ${skipped.join(", ")}` : "",
	].filter((l) => l !== "");
	return [head, ...lines, ...tail].join("\n");
}
