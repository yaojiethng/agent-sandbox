/**
 * The pinned request: issue one HTTP request against a chosen edge address
 * while the request keeps the provider's logical host.
 *
 * This is the network adaptor's sink. The provider API's own `fetch` is
 * replaced by a function that resolves the address itself and passes it to
 * Node's `lookup`, so DNS is not consulted and the connection lands on the
 * chosen edge. SNI and `Host` stay the logical host, so TLS and any
 * host-routed behaviour are unchanged.
 *
 * `accept-encoding` is stripped so the body arrives uncompressed: the WHATWG
 * `fetch` contract hands the bytes through untouched, and this module does not
 * implement decompression.
 */

import { request as httpRequest } from "node:http";
import { request as httpsRequest } from "node:https";
import { Readable } from "node:stream";

/** The request body shapes this module forwards. A stream body is not supported. */
function requestBody(body: RequestInit["body"]): Buffer | undefined {
	if (body === undefined || body === null) {
		return undefined;
	}
	if (typeof body === "string") {
		return Buffer.from(body);
	}
	if (body instanceof Uint8Array) {
		return Buffer.from(body);
	}
	if (body instanceof ArrayBuffer) {
		return Buffer.from(body);
	}
	if (ArrayBuffer.isView(body)) {
		return Buffer.from(body.buffer, body.byteOffset, body.byteLength);
	}
	throw new Error("pinnedFetch: unsupported request body type");
}

/** Whether this module can forward the body; a stream body must fall back to the original fetch. */
export function canPinBody(body: RequestInit["body"]): boolean {
	return body === undefined || body === null || typeof body === "string" || body instanceof Uint8Array || body instanceof ArrayBuffer || ArrayBuffer.isView(body);
}

/**
 * Issue one request pinned to `address`. The URL's host is kept as SNI and
 * `Host`; only the transport address changes.
 */
export function pinnedFetch(url: string, init: RequestInit, address: string): Promise<Response> {
	const target = new URL(url);
	const secure = target.protocol === "https:";
	const body = requestBody(init.body);
	const headers = new Headers(init.headers);
	// The response body is forwarded as it arrives, so ask for it uncompressed.
	headers.delete("accept-encoding");
	headers.set("host", target.host);

	return new Promise<Response>((resolve, reject) => {
		const request = secure ? httpsRequest : httpRequest;
		const options = {
			hostname: target.hostname,
			port: target.port === "" ? (secure ? 443 : 80) : Number(target.port),
			path: `${target.pathname}${target.search}`,
			method: init.method ?? "GET",
			headers: Object.fromEntries(headers.entries()),
			agent: false,
			lookup: (_hostname: string, _options: unknown, callback: (error: Error | null, addresses: { address: string; family: number }[]) => void) => {
				callback(null, [{ address, family: 4 }]);
			},
			...(secure ? { servername: target.hostname } : {}),
			...(init.signal ? { signal: init.signal } : {}),
		};
		const req = request(options, (res) => {
			const responseHeaders = new Headers();
			for (let i = 0; i < res.rawHeaders.length; i += 2) {
				responseHeaders.append(res.rawHeaders[i], res.rawHeaders[i + 1]);
			}
			const status = res.statusCode ?? 0;
			const hasBody = status !== 204 && status !== 304;
			resolve(
				new Response(hasBody ? (Readable.toWeb(res) as unknown as ReadableStream) : null, {
					status,
					statusText: res.statusMessage,
					headers: responseHeaders,
				}),
			);
		});
		req.on("error", reject);
		if (body !== undefined) {
			req.write(body);
		}
		req.end();
	});
}
