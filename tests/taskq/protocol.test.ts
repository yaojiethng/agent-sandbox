/**
 * The worker protocol files: the request documents workers write, the
 * numeric request order the primary reads them in, and the worker's own
 * request-sequence counter with its atomic write and typed parse errors.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import {
	listWorkerRequests,
	nextRequestId,
	parseWorkerRequest,
	readWorkerState,
	workerStatePath,
	writeWorkerState,
} from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/protocol.ts";
import { NOW, withTmp, writeFile } from "./helpers.ts";

function expects(code: string): (e: unknown) => boolean {
	return (e) => e instanceof TaskQueueError && e.code === code;
}

describe("worker request documents", () => {
	it("parses and validates the raw bytes of one document", () => {
		const raw = JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "done", message: "m", at: NOW });
		const parsed = parseWorkerRequest(raw, "t1-1.json");
		assert.deepEqual(parsed, { taskId: "t1", requestId: "t1-1", status: "done", message: "m", at: NOW });
		for (const bad of [
			"{not json",
			"[]",
			JSON.stringify({ requestId: "t1-1", status: "done", message: "m" }),
			JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "maybe", message: "m" }),
			JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "done" }),
		]) {
			assert.throws(() => parseWorkerRequest(bad, "t1-1.json"), expects("request-invalid"));
		}
	});

	it("lists request documents in numeric request order, not lexicographic", () => {
		withTmp((dir) => {
			const doc = (requestId: string, message: string) => JSON.stringify({ taskId: "t1", requestId, status: "running", message, at: NOW });
			writeFile(dir, "taskq/requests/t1-2.json", doc("t1-2", "m2"));
			writeFile(dir, "taskq/requests/t1-10.json", doc("t1-10", "m10"));
			writeFile(dir, "taskq/requests/t1-1.json", doc("t1-1", "m1"));
			writeFile(dir, "taskq/requests/broken-9.json", "{not json");
			const listed = listWorkerRequests(dir);
			assert.deepEqual(listed.map((r) => r.requestId), ["t1-1", "t1-2", "broken-9", "t1-10"]);
			assert.deepEqual(
				listed.map((r) => (r.invalid ? "invalid" : r.request?.message)),
				["m1", "m2", "invalid", "m10"],
			);
		});
	});
});

describe("worker state counter", () => {
	it("allocates request ids sequentially and persists the counter", () => {
		withTmp((dir) => {
			assert.equal(nextRequestId(dir, "t1"), "t1-1");
			assert.equal(nextRequestId(dir, "t1"), "t1-2");
			assert.deepEqual(readWorkerState(dir), { seq: 2 });
		});
	});

	it("a torn counter write reads as a typed worker-proto error, not a crash", () => {
		withTmp((dir) => {
			writeWorkerState(dir, { seq: 3 });
			fs.writeFileSync(workerStatePath(dir), "{torn", "utf8");
			assert.throws(() => readWorkerState(dir), expects("worker-proto"));
			// A well-formed file with a non-numeric sequence is rejected too.
			writeFile(dir, "taskq/state.json", JSON.stringify({ seq: "high" }));
			assert.throws(() => readWorkerState(dir), expects("worker-proto"));
		});
	});

	it("no temp file survives a counter write", () => {
		withTmp((dir) => {
			writeWorkerState(dir, { seq: 1 });
			const files = fs.readdirSync(path.join(dir, "taskq")).sort();
			assert.deepEqual(files, ["state.json"]);
		});
	});
});