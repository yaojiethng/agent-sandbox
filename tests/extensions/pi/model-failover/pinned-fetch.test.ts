/**
 * The pinned request of pinned-fetch.ts: the connection lands on the chosen
 * address while the logical host is preserved as Host and, on TLS, as SNI.
 *
 * A local server is the chosen address and `example.invalid` is the logical
 * host, which does not resolve, so the case fails loudly if the pin is ignored.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import type { AddressInfo } from "node:net";
import { once } from "node:events";
import { canPinBody, pinnedFetch } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/pinned-fetch.ts";

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

describe("the pinned request", () => {
	it("reaches the pinned address while the Host stays the logical host", async () => {
		let seenHost: string | undefined;
		let seenBody = "";
		await withServer(
			(req, res) => {
				seenHost = req.headers.host;
				req.on("data", (chunk) => (seenBody += chunk));
				req.on("end", () => {
					res.writeHead(200, { "content-type": "text/plain" });
					res.end("pinned");
				});
			},
			async (port) => {
				const response = await pinnedFetch(`http://example.invalid:${port}/v1/chat`, { method: "POST", body: "hello" }, "127.0.0.1");
				assert.equal(response.status, 200);
				assert.equal(await response.text(), "pinned");
				assert.equal(seenHost, `example.invalid:${port}`, "the logical host is preserved in Host");
				assert.equal(seenBody, "hello", "the body is forwarded");
			},
		);
	});

	it("an error status comes back as a Response, not a throw", async () => {
		await withServer(
			(_req, res) => {
				res.writeHead(429, "Too Many Requests");
				res.end("limited");
			},
			async (port) => {
				const response = await pinnedFetch(`http://example.invalid:${port}/`, {}, "127.0.0.1");
				assert.equal(response.status, 429);
				assert.equal(await response.text(), "limited");
			},
		);
	});

	it("a stream body cannot be pinned and must fall back", () => {
		assert.equal(canPinBody("x"), true);
		assert.equal(canPinBody(new Uint8Array([1])), true);
		assert.equal(canPinBody(undefined), true);
		assert.equal(canPinBody(new ReadableStream()), false);
	});
});
