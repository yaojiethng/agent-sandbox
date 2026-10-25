/**
 * The report: what the operator sees at session start. One line per fact,
 * and a quota-class cooldown is a notice because it needs operator action
 * rather than patience.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { buildEdgeReport, buildReport, edgeLine, formatDuration, routeLine } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/report.ts";
import { chain, COOLDOWNS, NOW, route } from "./helpers.ts";

describe("the report", () => {
	it("formats durations compactly", () => {
		assert.equal(formatDuration(0), "0s");
		assert.equal(formatDuration(45_000), "45s");
		assert.equal(formatDuration(120_000), "2m");
		assert.equal(formatDuration(125_000), "2m 5s");
		assert.equal(formatDuration(3_600_000), "1h");
		assert.equal(formatDuration(3_660_000), "1h 1m");
		assert.equal(formatDuration(3_661_000), "1h 1m 1s");
	});

	it("names an eligible route, with its streak when it has one", () => {
		assert.equal(routeLine("p", "m", { state: "eligible", streak: 0 }, NOW), "p/m eligible");
		assert.equal(routeLine("p", "m", { state: "eligible", streak: 2 }, NOW), "p/m eligible (2 consecutive transient failures)");
	});

	it("names a cooling route with the class and the remaining window", () => {
		const entry = { state: "cooling", until: NOW + 90_000, class: "transient" } as const;
		assert.equal(routeLine("p", "m", entry, NOW), "p/m cooling on transient for another 1m 30s");
		const lapsed = { state: "cooling", until: NOW - 10, class: "limited" } as const;
		assert.equal(routeLine("p", "m", lapsed, NOW), "p/m cooling on limited, deadline lapsed");
	});

	it("names the scope beside the class, so an exhausted account reads differently from a disabled model", () => {
		const account = { state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited", scope: "account" } as const;
		assert.equal(routeLine("p", "m", account, NOW), "p/m cooling on limited (account) for another 1h");
	});

	it("the report lists one chain header per chain and one line per route", () => {
		const two = chain("c", [route("p", "m1"), route("p", "m2")]);
		const view = (provider: string, model: string) => (model === "m2" ? ({ state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" } as const) : ({ state: "eligible", streak: 0 } as const));
		const lines = buildReport([two], view, NOW).map((row) => row.text);
		assert.equal(lines.length, 3);
		assert.match(lines[0], /chain c: 2 route\(s\), threshold 3/);
		assert.match(lines[1], /p\/m1 eligible/);
		assert.match(lines[2], /p\/m2 cooling on limited for another 1h/);
	});

	it("a quota-class cooldown is a notice and a transient one is not", () => {
		const two = chain("c", [route("p", "m1"), route("p", "m2")]);
		const view = (provider: string, model: string) =>
			model === "m1"
				? ({ state: "cooling", until: NOW + COOLDOWNS.transient, class: "transient" } as const)
				: ({ state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" } as const);
		const flagged = buildReport([two], view, NOW).filter((row) => row.notice);
		assert.equal(flagged.length, 1, "only the quota-class cooldown needs the operator");
		assert.match(flagged[0].text, /p\/m2/);
		const rows = buildReport([two], view, NOW);
		assert.equal(rows.filter((row) => row.notice).length, 1);
	});

	it("names an edge by its derived rate and streak", () => {
		assert.equal(edgeLine("1.1.1.1", { state: "eligible", window: [] }, NOW), "1.1.1.1 eligible (rate 50%)");
		assert.equal(edgeLine("1.1.1.1", { state: "eligible", window: [{ ok: false, at: NOW - 2 }, { ok: false, at: NOW - 1 }] }, NOW), "1.1.1.1 eligible (rate 25%, streak 2)");
		assert.match(edgeLine("1.1.1.1", { state: "cooling", window: [], until: NOW + 60_000 }, NOW), /cooling for another 1m/);
	});

	it("the edge report lists one line per address of a managed route host", () => {
		const two = chain("c", [route("p", "m1")]);
		const lines = buildEdgeReport([two], () => "gateway.test", () => ["1.1.1.1", "2.2.2.2"], () => ({ state: "eligible", window: [] }), NOW).map((row) => row.text);
		assert.equal(lines.length, 2);
		assert.match(lines[0], /edge 1\.1\.1\.1 eligible/);
	});
});
