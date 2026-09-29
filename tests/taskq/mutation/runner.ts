/**
 * The mutation gate's engine: replay one catalog row and report the verdict.
 *
 * The engine never mutates the repository. Each row runs in a throwaway
 * mirror under the system temp directory that holds one copy of the
 * extension and one copy of the suite, so a replayed row cannot leave the
 * working tree in a broken state, and two rows cannot see each other's
 * mutant. The repository is the read side only.
 *
 * The mirror drops `mutation.test.ts`: the gate must not be able to re-enter
 * itself through a mutant, and a row that only proves "the gate file is
 * reachable" proves nothing about the invariant.
 *
 * Two cheap checks run before the suites, because a mutant that fails for
 * the wrong reason is worse than no mutant:
 *
 *   - the anchor must be unique in the subject, so a drifted row is a no-op
 *     and not a silent edit of the wrong line;
 *   - the mutant must load, so a syntax error cannot pass for a proven row.
 *
 * A child killed at its deadline has no exit status. That is its own
 * verdict, because a harness that reads the deadline as a failure would
 * prove every break on a busy host.
 */

import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { Mutation } from "./catalog.ts";

export const REPO_ROOT = path.resolve(import.meta.dirname, "../../..");
const EXTENSION_DIR = "src/reasoning/providers/pi/config/agent/extensions/task-queue";
const SUITE_DIR = "tests/taskq";
/** The gate's own suite: excluded from every mirror. */
const GATE_SUITE = "mutation.test.ts";

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";

/** True when the pi package the extension aliases against is installed. */
export function piAvailable(): boolean {
	return fs.existsSync(path.join(PI_PACKAGE_GLOBAL, "dist", "index.js"));
}

export type Verdict = "proven" | "survived" | "no-op" | "unloadable" | "timed-out";

/**
 * The environment a replayed suite runs in. `node --test` marks its own
 * child processes with `NODE_TEST_CONTEXT`, and a child that inherits the
 * marker treats its `--test` argument as a recursive run: it skips every
 * file and exits 0. The replayed suite would then look green against every
 * mutant, so the marker is stripped.
 */
function childEnv(): NodeJS.ProcessEnv {
	const env = { ...process.env };
	delete env.NODE_TEST_CONTEXT;
	return env;
}

export interface MutationOutcome {
	id: string;
	invariant: string;
	breaks: string;
	verdict: Verdict;
	/** The failing test names, for a proven row. */
	detail: string;
	/** Wall time of the row, in milliseconds. */
	ms: number;
}

export interface RunnerOptions {
	/** Per-suite deadline in seconds. */
	perSuiteSeconds?: number;
}

/** Copy one directory tree, minus `skip` basenames. */
function copyTree(from: string, to: string, skip: ReadonlySet<string> = new Set()): void {
	fs.mkdirSync(to, { recursive: true });
	for (const item of fs.readdirSync(from, { withFileTypes: true })) {
		if (item.isDirectory()) {
			copyTree(path.join(from, item.name), path.join(to, item.name), skip);
		} else if (!skip.has(item.name)) {
			fs.copyFileSync(path.join(from, item.name), path.join(to, item.name));
		}
	}
}

/** Build a throwaway mirror: the extension and the suite, nothing else. */
function buildMirror(root: string): string {
	const mirror = path.join(root, "repo");
	copyTree(path.join(REPO_ROOT, EXTENSION_DIR), path.join(mirror, EXTENSION_DIR));
	copyTree(path.join(REPO_ROOT, SUITE_DIR), path.join(mirror, SUITE_DIR), new Set([GATE_SUITE]));
	return mirror;
}

/** The byte offsets of NEEDLE in TEXT, or an empty list. */
function occurrences(text: string, needle: string): number[] {
	const at: number[] = [];
	for (let i = text.indexOf(needle); i >= 0; i = text.indexOf(needle, i + 1)) at.push(i);
	return at;
}

/** The loader that proves a mutant parses, through the same jiti the runtime uses. */
const PROBE = `
import * as path from "node:path";
import { createRequire } from "node:module";
const pi = process.env.PI_PACKAGE_GLOBAL;
const requireFromPi = createRequire(path.join(pi, "dist/index.js"));
const { createJiti } = await import(path.join(pi, "node_modules/jiti/lib/jiti.cjs"));
const jiti = createJiti(process.argv[2], {
  alias: {
    "@earendil-works/pi-coding-agent": path.join(pi, "dist/index.js"),
    typebox: requireFromPi.resolve("typebox"),
    "@sinclair/typebox": requireFromPi.resolve("typebox"),
  },
});
await jiti.import(process.argv[2]);
`;

/** Replay one row. The mirror is removed whatever the verdict is. */
export function runMutation(m: Mutation, opts: RunnerOptions = {}): MutationOutcome {
	const started = Date.now();
	const root = fs.mkdtempSync(path.join(os.tmpdir(), "taskq-mutant-"));
	const finish = (verdict: Verdict, detail: string): MutationOutcome => ({ id: m.id, invariant: m.invariant, breaks: m.breaks, verdict, detail, ms: Date.now() - started });
	try {
		const mirror = buildMirror(root);
		const subject = path.join(mirror, m.subject);
		const before = fs.readFileSync(subject, "utf8");
		const hits = occurrences(before, m.old);
		if (hits.length === 0) return finish("no-op", "the anchor text is not in the subject any more");
		if (hits.length > 1) return finish("no-op", `the anchor text appears ${hits.length} times; the row is ambiguous`);
		const after = before.slice(0, hits[0]) + m.next + before.slice(hits[0] + m.old.length);
		if (after === before) return finish("no-op", "the replacement is the text it replaces");
		fs.writeFileSync(subject, after, "utf8");

		// A mutant that does not load turns every suite red for a reason
		// that says nothing about the invariant, so it is not proof.
		const probeFile = path.join(root, "probe.mjs");
		fs.writeFileSync(probeFile, PROBE, "utf8");
		const probe = spawnSync(process.execPath, [probeFile, subject], {
			encoding: "utf8",
			timeout: 60_000,
			env: { ...childEnv(), PI_PACKAGE_GLOBAL },
		});
		if (probe.status === null) return finish("timed-out", "the load probe did not finish");
		if (probe.status !== 0) return finish("unloadable", (probe.stderr || probe.stdout || "").split("\n").find((l) => l.trim() !== "") ?? "the mutant did not load");

		for (const suite of m.tests) {
			const file = path.join(mirror, SUITE_DIR, suite);
			const run = spawnSync(process.execPath, ["--test", file], { encoding: "utf8", timeout: (opts.perSuiteSeconds ?? 180) * 1000, env: childEnv() });
			// A killed child has no status. Reading the deadline as a failure
			// would prove every break on a busy host, so the deadline is its
			// own verdict.
			if (run.status === null) return finish("timed-out", `${suite} did not finish inside the deadline`);
			if (run.status !== 0) {
				const names = [...`${run.stdout}\n${run.stderr}`.matchAll(/^not ok \d+ - (.+)$/gm)].map((x) => x[1].trim());
				return finish("proven", names.length > 0 ? names.slice(0, 3).join("; ") : `${suite} exited ${run.status}`);
			}
		}
		return finish("survived", `the suite stayed green against the mutant (${m.tests.join(", ")})`);
	} finally {
		fs.rmSync(root, { recursive: true, force: true });
	}
}

/** The gate's own index: one line per row, then the rows that were not proven. */
export function renderMutations(rows: readonly MutationOutcome[]): string {
	const lines = rows.map((r) => `  ${r.verdict.toUpperCase().padEnd(10)} ${String(Math.round(r.ms / 1000)).padStart(3)}s ${r.invariant.padEnd(4)} ${r.id} -- ${r.breaks}`);
	const unproven = rows.filter((r) => r.verdict !== "proven");
	const head = `mutation gate: ${rows.length} rows, ${rows.length - unproven.length} proven, ${unproven.length} not proven`;
	const tail = unproven.map((r) => `  ${r.verdict}: ${r.id} -- ${r.detail}`);
	return [head, ...lines, ...tail].join("\n");
}
