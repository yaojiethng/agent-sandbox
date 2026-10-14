/**
 * The edge ledger file: persistence, the version rule, and the read-merge-write
 * of one key. The machine itself is the subject of edges.test.ts.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { EdgeLedger, edgeKey, edgesPathFromEnv, parseEdgeLedger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/edge-ledger.ts";
import type { Outcome } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts";

const NOW = 1_700_000_000_000;
const THRESHOLD = 3;
const WINDOW = 180_000;
const success: Outcome = { ok: true };
const transient: Outcome = { ok: false, class: "transient" };

function tempLedgerPath(): string {
	const target = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "mff-edges-")), "edges.json");
	fs.rmSync(target, { force: true });
	return target;
}

describe("the edge ledger", () => {
	it("an outcome is persisted and read back by a fresh instance", () => {
		const file = tempLedgerPath();
		try {
			const writer = new EdgeLedger(file);
			writer.apply("gateway.test", "model-a", "1.1.1.1", transient, NOW, THRESHOLD, WINDOW);
			const reader = new EdgeLedger(file);
			reader.load();
			assert.equal(reader.get("gateway.test", "model-a", "1.1.1.1").state, "eligible");
			assert.equal(reader.get("gateway.test", "model-a", "1.1.1.1").window.length, 1);
			assert.equal(reader.get("gateway.test", "model-a", "2.2.2.2").window.length, 0, "an unseen edge is initial");
		} finally {
			fs.rmSync(path.dirname(file), { recursive: true, force: true });
		}
	});

	it("the edge health is keyed by host, model and address", () => {
		const file = tempLedgerPath();
		try {
			const writer = new EdgeLedger(file);
			writer.apply("gateway.test", "model-a", "1.1.1.1", transient, NOW, THRESHOLD, WINDOW);
			writer.apply("gateway.test", "model-a", "2.2.2.2", success, NOW, THRESHOLD, WINDOW);
			writer.apply("gateway.test", "model-b", "1.1.1.1", transient, NOW, THRESHOLD, WINDOW);
			const parsed = parseEdgeLedger(fs.readFileSync(file, "utf8"));
			assert.deepEqual([...parsed.keys()].sort(), [
				edgeKey("gateway.test", "model-a", "1.1.1.1"),
				edgeKey("gateway.test", "model-a", "2.2.2.2"),
				edgeKey("gateway.test", "model-b", "1.1.1.1"),
			].sort());
		} finally {
			fs.rmSync(path.dirname(file), { recursive: true, force: true });
		}
	});

	it("a file another version wrote reads as empty", () => {
		assert.equal(parseEdgeLedger(JSON.stringify({ version: 2, edges: {} })).size, 0);
		assert.equal(parseEdgeLedger("not json").size, 0);
	});

	it("a damaged entry is dropped while the rest of the file loads", () => {
		const parsed = parseEdgeLedger(
			JSON.stringify({ version: 1, edges: { good: { state: "eligible", window: [] }, bad: { state: "eligible" } } }),
		);
		assert.equal(parsed.size, 1);
		assert.ok(parsed.has("good"));
	});

	it("the environment override points the ledger away from the tree", () => {
		assert.equal(edgesPathFromEnv({ MODEL_FAILOVER_EDGES: "/tmp/x/edges.json" }), "/tmp/x/edges.json");
		assert.match(edgesPathFromEnv({}), /edges\.json$/);
	});
});
