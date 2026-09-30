/**
 * The other writer of the two-process lock test: a separate process that
 * takes the ownership lock and then either owns no work at all (mode
 * "idle", a live owner with nothing in flight), or delivers one break
 * point through the Run facade. It then either holds the lock until it is
 * killed (mode "hold", the live owner the other process must report) or
 * exits without releasing it (mode "crash", the lock a killed writer
 * leaves behind). The test drives it; this file only plays the other
 * writer.
 */

import * as fs from "node:fs";
import { withOwnershipLock } from "../../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/lock.ts";
import { Run } from "../../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { forkOp, joinOp } from "../../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import type { RunState } from "../../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";

const AT = "2026-01-01T00:00:00.000Z";

const [stateDir, ready, mode] = process.argv.slice(2);

/** Block forever without yielding: the lock stays held until the kill. */
function hold(): void {
	for (;;) {
		Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 200);
	}
}

if (mode === "idle") {
	withOwnershipLock(stateDir, { sessionId: "lock-holder" }, () => {
		fs.writeFileSync(ready, "held", "utf8");
		hold();
	});
} else {
	withOwnershipLock(stateDir, { sessionId: "lock-holder", taskId: "t1", worktree: "/wt/t1" }, () => {
		const run = Run.open(stateDir, "/repo/main", AT);
		run.transact((s: RunState) => {
			const forked = s.tasks.t1 === undefined ? forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT) : null;
			return joinOp(forked ? forked.state : s, { taskId: "t1", requestId: "t1-1", status: "done", head: "h1", changed: 1 }, AT);
		}, { taskId: "t1", worktree: "/wt/t1" });
		fs.writeFileSync(ready, "held", "utf8");
		if (mode === "crash") {
			// A killed writer never releases: the lock file survives with its
			// metadata, and the next acquirer has to break it.
			process.exit(0);
		}
		hold();
	});
}
