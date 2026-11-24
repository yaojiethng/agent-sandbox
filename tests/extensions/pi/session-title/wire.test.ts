/**
 * The pi wiring: the factory registers the three events that follow pi's own
 * title writes, and every one of them sets the same title.
 *
 * The pi surface is a small fake: the factory touches only `on`, so the fake
 * captures the registrations and the test drives the handlers the way the
 * runtime does.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import factory from "../../../../src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/index.ts";
import { APP_MARK } from "../../../../src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/title.ts";

type Handler = (event: unknown, ctx: unknown) => void;

/** The minimal pi surface the factory uses. */
function fakePi() {
	const handlers = new Map<string, Handler[]>();
	return {
		handlers,
		pi: {
			on(event: string, handler: Handler) {
				const list = handlers.get(event) ?? [];
				list.push(handler);
				handlers.set(event, list);
			},
		},
	};
}

/** A context whose UI carries the given title sink, or none at all. */
function fakeCtx(setTitle?: (title: string) => void) {
	return { ui: setTitle ? { setTitle } : {} };
}

/** Run the factory with a run id in the environment, restoring it afterwards. */
function withRunId<T>(runId: string | undefined, body: () => T): T {
	const saved = process.env.SESSION_ID;
	if (runId === undefined) delete process.env.SESSION_ID;
	else process.env.SESSION_ID = runId;
	try {
		return body();
	} finally {
		if (saved === undefined) delete process.env.SESSION_ID;
		else process.env.SESSION_ID = saved;
	}
}

describe("session-title wiring", () => {
	it("registers on the events that follow pi's own title writes", () => {
		withRunId("f6e5d4", () => {
			const { handlers, pi } = fakePi();
			factory(pi as never);
			assert.deepEqual([...handlers.keys()].sort(), ["agent_start", "session_info_changed", "session_start"]);
		});
	});

	it("sets the title on every registered handler", () => {
		withRunId("f6e5d4", () => {
			const titles: string[] = [];
			const { handlers, pi } = fakePi();
			factory(pi as never);
			for (const list of handlers.values()) for (const handler of list) handler({}, fakeCtx((t) => titles.push(t)));
			assert.deepEqual(titles, Array(3).fill(`${APP_MARK} - f6e5d4`));
		});
	});

	it("does not throw when the context carries no setTitle", () => {
		withRunId("f6e5d4", () => {
			const { handlers, pi } = fakePi();
			factory(pi as never);
			for (const list of handlers.values()) for (const handler of list) assert.doesNotThrow(() => handler({}, fakeCtx()));
		});
	});

	it("registers nothing when the run has no id", () => {
		withRunId(undefined, () => {
			const { handlers, pi } = fakePi();
			factory(pi as never);
			assert.equal(handlers.size, 0);
		});
	});
});
