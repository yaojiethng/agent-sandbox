/**
 * The network adaptor: the managed-host filter, the pin, the delegation of
 * everything else, and the recorded edge the outcome observer charges.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import type { AddressInfo } from "node:net";
import { once } from "node:events";
import { NetworkAdaptor, modelOfRequest } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/adaptor.ts";
import { EdgeLedger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/edge-ledger.ts";
import type { SelectionConfig } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts";
import { tempLedgerPath } from "./helpers.ts";

const CONFIG: SelectionConfig = { policy: "rate", epsilon: 0 };

function stubFetch(): { calls: string[]; fetch: typeof globalThis.fetch } {
	const calls: string[] = [];
	const fetch = (async (input: RequestInfo | URL) => {
		calls.push(String(input));
		return new Response("delegated");
	}) as unknown as typeof globalThis.fetch;
	return { calls, fetch };
}

async function withServer(handler: http.RequestListener, run: (port: number) => Promise<void>): Promise<void> {
	const server = http.createServer(handler);
	server.listen(0, "127.0.0.1");
	await once(server, "listening");
	const { port } = server.address() as AddressInfo;
	try {
		await run(port);
	} finally {
		server.close();
	}
}

describe("the network adaptor", () => {
	it("delegates an unmanaged host untouched", async () => {
		const stub = stubFetch();
		const adaptor = new NetworkAdaptor({ originalFetch: stub.fetch, edges: new EdgeLedger(tempLedgerPath()), config: CONFIG, resolve: async () => ["127.0.0.1"] });
		const response = await adaptor.fetch("http://unmanaged.invalid/x");
		assert.equal(await response.text(), "delegated");
		assert.deepEqual(stub.calls, ["http://unmanaged.invalid/x"]);
	});

	it("pins a managed host and records the chosen edge", async () => {
		await withServer(
			(_req, res) => res.end("pinned"),
			async (port) => {
				const adaptor = new NetworkAdaptor({
					originalFetch: (async () => {
						throw new Error("a managed host must not delegate");
					}) as unknown as typeof globalThis.fetch,
					edges: new EdgeLedger(tempLedgerPath()),
					config: CONFIG,
					resolve: async () => ["127.0.0.1"],
				});
				adaptor.manage("example.invalid");
				const response = await adaptor.fetch(`http://example.invalid:${port}/v1/chat`, { method: "POST", body: JSON.stringify({ model: "m" }) });
				assert.equal(await response.text(), "pinned");
				assert.equal(adaptor.edgeUsed("example.invalid", "m"), "127.0.0.1");
			},
		);
	});

	it("delegates when resolution yields no address", async () => {
		const stub = stubFetch();
		const adaptor = new NetworkAdaptor({
			originalFetch: stub.fetch,
			edges: new EdgeLedger(tempLedgerPath()),
			config: CONFIG,
			resolve: async () => {
				throw new Error("dns failed");
			},
		});
		adaptor.manage("example.invalid");
		const response = await adaptor.fetch("http://example.invalid/x");
		assert.equal(await response.text(), "delegated");
		assert.equal(stub.calls.length, 1);
	});

	it("reads the model id from the JSON body", () => {
		assert.equal(modelOfRequest({ body: JSON.stringify({ model: "step-5" }) }), "step-5");
		assert.equal(modelOfRequest({ body: "not json" }), "");
		assert.equal(modelOfRequest(undefined), "");
	});
});
