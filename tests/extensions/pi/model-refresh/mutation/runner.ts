/**
 * The mutation gate's engine: replay one catalog row and report the verdict.
 *
 * The engine never mutates the repository. Each row builds a throwaway mirror
 * under the system temp directory that holds one copy of the extension and one
 * copy of the suite, and the row breaks and replays the copies. The repository
 * is the read side only, so a row that dies between the break and its verdict
 * cannot leave the working tree broken, and the sibling suites that read the
 * same sources through the folder glob cannot see a mutant.
 *
 * The mirror holds the two subtrees the suite's own imports reach: the
 * extension and the suite, at the relative paths those imports expect. The
 * suite reaches pi through absolute paths into the global pi installation, so
 * every import resolves inside the mirror or by absolute path, and the mirror
 * needs no `node_modules`.
 *
 * The mirror drops `mutation.test.ts`: the gate must not be able to re-enter
 * itself through a mutant, and a row that only proves the gate file is
 * reachable proves nothing about an invariant.
 *
 * Two cheap checks run before the suites, because a mutant that fails for the
 * wrong reason is worse than no mutant:
 *
 *   - the anchor must be unique in the subject, so a drifted row is a no-op
 *     and not a silent edit of the wrong line;
 *   - the mutant must load, so a syntax error cannot pass for a proven row.
 *
 * A child killed at its deadline has no exit status. That is its own verdict,
 * because a harness that reads the deadline as a failure would prove every
 * break on a busy host.
 *
 * A row that never ran has no verdict to hide behind. When the pi installation
 * the suite reads is absent the engine returns `not-run` rather than skipping:
 * a gate that prints fifteen rows and fifteen green verdicts on a host with no
 * pi is a gate that read green without running.
 *
 * A control row replays an unmutated mirror and must reach `survived`. Without
 * it a mirror the suite cannot run green in turns every break green, because a
 * replay that is red for any reason reads as proof.
 */

import { spawnSync } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { EXTENSION_DIR, type Mutation } from "./catalog.ts";

export const REPO_ROOT = path.resolve(import.meta.dirname, "../../../../..");
const SUITE_DIR = "tests/extensions/pi/model-refresh";
/** The gate's own suite: dropped from every mirror, so a row cannot re-enter the gate. */
const GATE_SUITE = "mutation.test.ts";

/**
 * The prefix an invariant case's test name carries, `INV <id> -- <statement>`.
 * A failing test name that does not carry it belongs to a suite rather than to
 * a case, so it names no invariant.
 */
const INVARIANT_PREFIX = "INV ";

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_AI_ROOT = `${PI_PACKAGE_GLOBAL}/node_modules/@earendil-works/pi-ai`;

/** Per-row deadline. The replayed suite runs in seconds, so this bounds a hung mutant rather than a slow one. */
const ROW_DEADLINE_MS = 120_000;
/** The load probe's own deadline, on the same reasoning. */
const PROBE_DEADLINE_MS = 60_000;

/** True when the pi package the extension loads against is installed. */
export function piAvailable(): boolean {
	return fs.existsSync(`${PI_PACKAGE_GLOBAL}/dist/index.js`) && fs.existsSync(`${PI_AI_ROOT}/dist/index.js`);
}

export type Verdict = "proven" | "survived" | "no-op" | "unloadable" | "timed-out" | "not-run";

/**
 * The verdict a row has to reach for the gate to pass. A break is proven by the
 * suite turning red against it; a control is proven by the suite staying green,
 * so `proven` on a control names a harness that cannot be trusted rather than a
 * line the suite pins.
 */
export function expectedVerdict(row: Mutation): Verdict {
	return row.control === true ? "survived" : "proven";
}

/**
 * The environment a replayed suite runs in. `node --test` marks its own child
 * processes with `NODE_TEST_CONTEXT`, and a child that inherits the marker
 * treats its `--test` argument as a recursive run: it skips every file and
 * exits 0. The replayed suite would then look green against every mutant, so
 * the marker is stripped.
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
	/** True for a control row, which replays an unmutated mirror. */
	control: boolean;
	verdict: Verdict;
	/** Why the row came out as it did, in one line. */
	detail: string;
	/** The names of every test that failed in the replayed suite, case or suite. */
	failing: string[];
	/**
	 * The invariant case names that failed on an assertion rather than on a
	 * thrown error.
	 *
	 * Two filters, each one closing a way a verdict could be read as proof
	 * without one. A failing name the suite gave an enclosing describe block,
	 * such as the invariant report itself, is not a case and names no
	 * invariant. A case that failed because the mutant threw says the mirror
	 * was replayed, not that the case held the line, so an assertion is
	 * required as well. What is left is what a break is attributed to.
	 */
	asserted: string[];
	/** Wall time of the row, in milliseconds. */
	ms: number;
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

/** The replayed suites: every model-refresh suite in the mirror but the gate. */
function replaySuites(mirror: string): string[] {
	const dir = path.join(mirror, SUITE_DIR);
	return fs
		.readdirSync(dir)
		.filter((name) => name.endsWith(".test.ts") && name !== GATE_SUITE)
		.sort()
		.map((name) => path.join(dir, name));
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
const piAi = process.env.PI_AI_ROOT;
const requireFromPi = createRequire(path.join(pi, "dist/index.js"));
const { createJiti } = await import(path.join(pi, "node_modules/jiti/lib/jiti.cjs"));
const jiti = createJiti(process.argv[2], {
  alias: {
    "@earendil-works/pi-coding-agent": path.join(pi, "dist/index.js"),
    "@earendil-works/pi-ai": path.join(piAi, "dist/index.js"),
    "@earendil-works/pi-ai/providers/all": path.join(piAi, "dist/providers/all.js"),
    "typebox": requireFromPi.resolve("typebox"),
    "@sinclair/typebox": requireFromPi.resolve("typebox"),
  },
});
await jiti.import(process.argv[2]);
`;

/**
 * The tests that failed in a replayed suite, split by how they failed.
 *
 * `node --test` prints a nested suite's cases indented under their parent, so
 * the anchor allows the leading whitespace: without it a red suite inside a
 * describe block yields no names at all, and the gate cannot say which
 * invariant the failure was about.
 *
 * A failure that is an assertion and a failure that is a thrown error are kept
 * apart. A mutant that makes the product throw turns the whole suite red, and a
 * gate that reads any red line as proof would call every such mutant proven
 * against every invariant it names.
 *
 * The names kept in `asserted` are the invariant cases, which is a second cut
 * on the same list. The suite reports its own describe blocks as failures, and
 * a report block that fails for the report's reasons names no invariant: a
 * row that turned the report red would otherwise be attributed to whichever
 * invariant its `invariant:` field happens to name.
 */
function suiteFailures(output: string): { failing: string[]; asserted: string[] } {
	const failing: string[] = [];
	const asserted: string[] = [];
	for (const block of output.split(/^\s*not ok \d+ - /m).slice(1)) {
		const newline = block.indexOf("\n");
		const name = (newline === -1 ? block : block.slice(0, newline)).trim();
		failing.push(name);
		if (name.startsWith(INVARIANT_PREFIX) && block.includes("code: 'ERR_ASSERTION'")) {
			asserted.push(name);
		}
	}
	return { failing, asserted };
}

/** Replay one row in its own mirror. The mirror is removed whatever the verdict is. */
export function runMutation(m: Mutation): MutationOutcome {
	const started = Date.now();
	const root = fs.mkdtempSync(path.join(os.tmpdir(), "model-refresh-mutant-"));
	const finish = (verdict: Verdict, detail: string, failures: { failing: string[]; asserted: string[] } = { failing: [], asserted: [] }): MutationOutcome => ({
		id: m.id,
		invariant: m.invariant,
		breaks: m.breaks,
		control: m.control === true,
		verdict,
		detail,
		failing: failures.failing,
		asserted: failures.asserted,
		ms: Date.now() - started,
	});
	try {
		if (!piAvailable()) {
			return finish("not-run", "the pi installation the suite reads is absent, so no mirror was replayed");
		}
		const mirror = buildMirror(root);
		const subject = path.join(mirror, m.subject);
		// The mirror is the only tree this engine writes in. A subject that
		// resolves out of it is a drifted row, not a mutation.
		if (path.relative(mirror, subject).startsWith("..")) return finish("no-op", "the subject resolves outside the mirror");

		if (m.control !== true) {
			const before = fs.readFileSync(subject, "utf8");
			const hits = occurrences(before, m.old);
			if (hits.length === 0) return finish("no-op", "the anchor text is not in the subject any more");
			if (hits.length > 1) return finish("no-op", `the anchor text appears ${hits.length} times; the row is ambiguous`);
			const after = before.slice(0, hits[0]) + m.next + before.slice(hits[0] + m.old.length);
			if (after === before) return finish("no-op", "the replacement is the text it replaces");
			fs.writeFileSync(subject, after, "utf8");
		}

		// A mutant that does not load turns every suite red for a reason that
		// says nothing about the invariant, so it is not proof. A control row
		// breaks nothing, so there is nothing to load.
		if (m.control !== true) {
			const probeFile = path.join(root, "probe.mjs");
			fs.writeFileSync(probeFile, PROBE, "utf8");
			const probe = spawnSync(process.execPath, [probeFile, subject], {
				encoding: "utf8",
				timeout: PROBE_DEADLINE_MS,
				env: { ...childEnv(), PI_PACKAGE_GLOBAL, PI_AI_ROOT },
			});
			if (probe.status === null) return finish("timed-out", "the load probe did not finish");
			if (probe.status !== 0) {
				const reason = `${probe.stderr}\n${probe.stdout}`
					.split("\n")
					.find((line) => line.trim() !== "");
				return finish("unloadable", reason ?? "the mutant did not load");
			}
		}

		const run = spawnSync(process.execPath, ["--test", ...replaySuites(mirror)], {
			cwd: mirror,
			encoding: "utf8",
			timeout: ROW_DEADLINE_MS,
			env: childEnv(),
		});
		// A killed child has no status. Reading the deadline as a failure would
		// prove every break on a busy host, so the deadline is its own verdict.
		if (run.status === null) return finish("timed-out", `the suite did not finish inside ${ROW_DEADLINE_MS / 1000}s`);
		const failures = suiteFailures(`${run.stdout}\n${run.stderr}`);
		if (run.status !== 0) {
			const detail = failures.failing.length > 0 ? `${failures.failing.length} failing: ${failures.failing.slice(0, 3).join("; ")}` : `the suite exited ${run.status} with no named failure`;
			return finish("proven", detail, failures);
		}
		return finish("survived", "the model-refresh suite stayed green against the mutant", failures);
	} finally {
		fs.rmSync(root, { recursive: true, force: true });
	}
}

/** What the report needs from the suite the rows replay. */
export interface GateIndex {
	/** Every invariant id the suite's catalog defines. */
	invariants: readonly string[];
	/** The catalog case a failing test name belongs to, for the report. */
	caseName: (testName: string) => string;
}

/**
 * The gate's own index: one line per row, in row-id order so two runs print the
 * same report, then the case that caught each proven row, then the rows that
 * did not reach the verdict they must.
 *
 * The head carries the invariants no row names. That list is a fact about the
 * suite, not a verdict on a row, so it is printed and not failed: a mutation
 * catalog is not obliged to attack every invariant, and a gate that failed on
 * the gap would have to grow a row for each gap to go green, which is a
 * different design from the one this gate has.
 */
export function renderMutations(rows: readonly MutationOutcome[], index: GateIndex): string {
	const ordered = [...rows].sort((left, right) => left.id.localeCompare(right.id));
	const lines = ordered.map((r) => `  ${r.verdict.toUpperCase().padEnd(10)} ${String(Math.round(r.ms / 1000)).padStart(3)}s ${(r.control ? "ctrl" : r.invariant).padEnd(4)} ${r.id} -- ${r.breaks}`);
	const off = ordered.filter((r) => r.verdict !== expectedVerdict(r));
	const controls = ordered.filter((r) => r.control).length;
	const held = new Set(ordered.filter((r) => r.control !== true).map((r) => r.invariant));
	const unheld = index.invariants.filter((id) => !held.has(id));
	const head = `mutation gate: ${ordered.length} rows (${controls} control), ${ordered.length - off.length} as expected, ${off.length} not as expected; ${held.size} of ${index.invariants.length} invariants named by a row: ${[...held].sort().join(", ") || "none"}; no row names: ${unheld.join(", ") || "none"}`;
	// A row proven by a coarser case of its own invariant reads the same as one
	// proven by the case written for it, so the report names the case. Where an
	// invariant has several cases, the one that fired is the one the row
	// actually exercises, and a row that reaches a different case than its
	// `breaks` sentence describes is visible here.
	const proven = ordered.filter((r) => r.verdict === "proven");
	const caught = [
		"  the case that caught each proven row:",
		...proven.map((r) => `    ${r.id} -- ${r.asserted.map(index.caseName).join(", ") || "no case named it on an assertion"}`),
	];
	const tail = off.map((r) => `  ${r.verdict}: ${r.id} -- ${r.detail}`);
	return [head, ...lines, ...caught, ...tail].join("\n");
}
