/**
 * The pi wiring: the factory registers the three events that follow pi's own
 * title writes, and it claims the terminal's title writer so pi's later writes
 * carry the run id as well.
 *
 * The pi surface is a small fake: the factory touches only `on`, and the
 * context touches only `ui.setTitle` and `ui.setWidget`, so the fake captures
 * those and the test drives them the way the runtime does.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import factory from "../../../../src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/index.ts";
import { APP_MARK } from "../../../../src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/title.ts";

type Handler = (event: unknown, ctx: unknown) => void;
type Sink = (title: string) => void;
type WidgetFactory = (tui: { terminal: { setTitle: Sink } }) => unknown;

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

/** A context whose UI records title writes and widget calls. */
function fakeCtx(options: { setTitle?: boolean } = {}) {
	const written: string[] = [];
	const widgets: Array<{ key: string; content: WidgetFactory | undefined }> = [];
	// The terminal pi writes through, captured when the factory asks for it.
	const terminal = { setTitle: (title: string) => written.push(title) };
	const ui: Record<string, unknown> = {
		setWidget(key: string, content: WidgetFactory | undefined) {
			widgets.push({ key, content });
			if (typeof content === "function") content({ terminal });
		},
	};
	if (options.setTitle !== false) ui.setTitle = (title: string) => written.push(title);
	return { ctx: { ui }, written, widgets, terminal };
}

/** Run every registered handler once. */
function fire(handlers: Map<string, Handler[]>, ctx: unknown) {
	for (const list of handlers.values()) for (const handler of list) handler({}, ctx);
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

	it("writes the title on every registered handler", () => {
		withRunId("f6e5d4", () => {
			const { handlers, pi } = fakePi();
			const { ctx, written } = fakeCtx();
			factory(pi as never);
			fire(handlers, ctx);
			assert.ok(written.length >= 3, "each handler writes once");
			assert.deepEqual([...new Set(written)], [`${APP_MARK} - f6e5d4`], "every write carries the run id");
		});
	});

	it("claims the terminal's title writer, so pi's own write carries the run id", () => {
		withRunId("f6e5d4", () => {
			const { handlers, pi } = fakePi();
			const { ctx, written, terminal } = fakeCtx();
			factory(pi as never);
			fire(handlers, ctx);
			terminal.setTitle(`${APP_MARK} - sandbox`);
			assert.equal(written.at(-1), `${APP_MARK} - f6e5d4`, "pi's own write lands as the run id");
			assert.ok(!written.includes(`${APP_MARK} - sandbox`), "pi's own title never reaches the terminal");
		});
	});

	it("claims the terminal once, and drops the widget that reached it", () => {
		withRunId("f6e5d4", () => {
			const { handlers, pi } = fakePi();
			const { ctx, widgets } = fakeCtx();
			factory(pi as never);
			fire(handlers, ctx);
			assert.deepEqual(
				widgets.map((w) => [w.key, w.content === undefined ? "cleared" : "factory"]),
				[
					["session-title", "factory"],
					["session-title", "cleared"],
				],
			);
		});
	});

	it("does not throw when the context carries no setTitle", () => {
		withRunId("f6e5d4", () => {
			const { handlers, pi } = fakePi();
			const { ctx, widgets } = fakeCtx({ setTitle: false });
			factory(pi as never);
			for (const list of handlers.values()) for (const handler of list) assert.doesNotThrow(() => handler({}, ctx));
			assert.equal(widgets.length, 0, "no terminal is claimed without a UI to write through");
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
