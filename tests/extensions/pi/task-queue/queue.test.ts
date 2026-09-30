/**
 * The queue state machine (I2, I4, I5) and the exactly-once birth rules
 * (I1). Pure unit tests: no I/O, no git.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TaskQueueError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import {
	type QueueEntry,
	entryIdOf,
	entriesForTask,
	getEntry,
	transitionSchedule,
	transitionTrigger,
	validateBirth,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";

function entry(taskId: string, seq: number, state: QueueEntry["state"] = "requested"): QueueEntry {
	return {
		entryId: entryIdOf(taskId, seq),
		taskId,
		workerId: `w-${taskId}`,
		workdir: `/wt/${taskId}`,
		requestId: `${taskId}-${seq}`,
		requestSeq: seq,
		state,
	};
}

function birthOk(entries: QueueEntry[], e: QueueEntry): void {
	assert.doesNotThrow(() => validateBirth(entries, e));
}

function expects(code: string): (e: unknown) => boolean {
	return (e) => e instanceof TaskQueueError && e.code === code;
}

describe("queue birth rules (I1: every request enqueues exactly once)", () => {
	it("accepts a first entry", () => {
		birthOk([], entry("t1", 1));
	});

	it("accepts a next segment entry in sequence", () => {
		birthOk([entry("t1", 1)], entry("t1", 2));
	});

	it("rejects a duplicate entry id", () => {
		assert.throws(() => validateBirth([entry("t1", 1)], entry("t1", 1)), expects("request-duplicate"));
	});

	it("rejects a duplicate request id, even under another entry id", () => {
		const dup = entry("t1", 2);
		dup.requestId = "t1-1";
		assert.throws(() => validateBirth([entry("t1", 1)], dup), expects("request-duplicate"));
	});

	it("rejects a request sequence that breaks the per-task order", () => {
		assert.throws(() => validateBirth([entry("t1", 1)], entry("t1", 3)), expects("request-invalid"));
	});

	it("sequences one task independently of another", () => {
		assert.doesNotThrow(() => validateBirth([entry("t1", 1), entry("t2", 1)], entry("t1", 2)));
	});
});

describe("transition request -> scheduled (I4)", () => {
	it("schedules a requested entry", () => {
		const t = transitionSchedule([entry("t1", 1)], entryIdOf("t1", 1));
		assert.equal(t.entry.state, "scheduled");
		assert.equal(getEntry(t.entries, entryIdOf("t1", 1))?.state, "scheduled");
	});

	it("rejects an unknown entry", () => {
		assert.throws(() => transitionSchedule([], "nope"), expects("entry-unknown"));
	});

	it("rejects a re-schedule: a scheduled break point not yet triggered cannot be re-scheduled (I4)", () => {
		const once = transitionSchedule([entry("t1", 1)], entryIdOf("t1", 1));
		assert.throws(() => transitionSchedule(once.entries, entryIdOf("t1", 1)), expects("entry-not-requested"));
	});

	it("rejects scheduling a triggered entry: transitions never move backward (I4)", () => {
		const once = transitionSchedule([entry("t1", 1)], entryIdOf("t1", 1));
		const twice = transitionTrigger(once.entries, entryIdOf("t1", 1));
		assert.throws(() => transitionSchedule(twice.entries, entryIdOf("t1", 1)), expects("entry-not-requested"));
	});
});

describe("transition scheduled -> triggered (I4, I5, I2)", () => {
	function scheduled(taskId: string, seq: number): QueueEntry[] {
		return transitionSchedule([entry(taskId, seq)], entryIdOf(taskId, seq)).entries;
	}

	it("triggers a scheduled entry exactly once (I5)", () => {
		const once = transitionTrigger(scheduled("t1", 1), entryIdOf("t1", 1));
		assert.equal(once.entry.state, "triggered");
		assert.throws(() => transitionTrigger(once.entries, entryIdOf("t1", 1)), expects("entry-already-triggered"));
	});

	it("refuses to trigger a break point the primary never scheduled (I4)", () => {
		assert.throws(() => transitionTrigger([entry("t1", 1)], entryIdOf("t1", 1)), expects("entry-not-scheduled"));
	});

	it("refuses to trigger an unknown entry", () => {
		assert.throws(() => transitionTrigger([], "nope"), expects("entry-unknown"));
	});

	it("triggers entries in request order per task (I2)", () => {
		const entries = [...scheduled("t1", 1), ...scheduled("t1", 2)];
		assert.throws(() => transitionTrigger(entries, entryIdOf("t1", 2)), expects("entry-out-of-order"));
		const first = transitionTrigger(entries, entryIdOf("t1", 1));
		assert.doesNotThrow(() => transitionTrigger(first.entries, entryIdOf("t1", 2)));
	});

	it("treats a scheduled earlier entry as pending, a triggered one as done", () => {
		const entries = [...scheduled("t1", 1), ...scheduled("t1", 2)];
		const first = transitionTrigger(entries, entryIdOf("t1", 1));
		// second must wait until the first is triggered; then it frees.
		const second = transitionTrigger(first.entries, entryIdOf("t1", 2));
		assert.equal(second.entry.state, "triggered");
	});

	it("does not constrain cross-task order (I2)", () => {
		const entries = [...scheduled("t1", 1), ...scheduled("t2", 1)];
		assert.doesNotThrow(() => transitionTrigger(entries, entryIdOf("t2", 1)));
	});

	it("leaves every other entry untouched by a transition", () => {
		const entries = [...scheduled("t1", 1), ...scheduled("t2", 1)];
		const t = transitionTrigger(entries, entryIdOf("t1", 1));
		assert.equal(getEntry(t.entries, entryIdOf("t2", 1))?.state, "scheduled");
		assert.equal(entriesForTask(t.entries, "t2").length, 1);
	});

	it("keeps an entry's references identical from birth to trigger (I3 dequeue/enqueue sameness)", () => {
		const born = entry("t1", 1);
		const before = { taskId: born.taskId, workerId: born.workerId, workdir: born.workdir, requestId: born.requestId, requestSeq: born.requestSeq };
		const t1 = transitionSchedule([born], entryIdOf("t1", 1));
		const t2 = transitionTrigger(t1.entries, entryIdOf("t1", 1));
		assert.deepEqual(
			{ taskId: t2.entry.taskId, workerId: t2.entry.workerId, workdir: t2.entry.workdir, requestId: t2.entry.requestId, requestSeq: t2.entry.requestSeq },
			before,
		);
	});
});