---
description: "Handoff - a bug report against the dispatch harness, for a session that fixes what the ablation grid exposed. Six defects: a printed command that inherits stdin, an opencode/ id accepted on the pi backend, a caller that re-greps what the seam already classifies, no ceiling on concurrent runs against one SQLite store, a retry that repeats timeouts, and an assignment that returns an empty turn with a zero exit code."
argument-hint: "[defect id, e.g. D1 - optional]"
---

> $ARGUMENTS

# Handoff - the dispatch harness as it failed under the ablation grid

## What the next session is for

Fix, or file with an owner, the six defects below. They were exposed by a hundred-and-seventeen-cell ablation grid driven over `opencode run`, and none of them is about the model, the prompt or the corpus: each is a way the dispatch path reports success, health or slowness when the truth is the opposite. The evidence appendix is [`devlog/handovers/20261026-05-workflow-opencode_run_harness_defects.md`](../../devlog/handovers/20261026-05-workflow-opencode_run_harness_defects.md), which carries the trap table and the session-store query; this document is the actionable form of it and does not restate the table.

Priority order is the order below. D1 and D2 each produced a wrong conclusion that was written into a record and later retracted, and D6 manufactures a result from nothing.

## Where things stand

The grid stopped at thirty-five of a hundred and seventeen cells when the free tier ran out, and those cells were discarded for a second, independent reason: the run's working directory held the census rulings, so thirty of the thirty-five read a prior record or an earlier fault list. That failure is recorded in the ablation record sealed at `tests/eval/instruction-cleanup/payload.tar.gz` under `reports/` and its constraint now sits on the eval case set row of [`devlog/roadmap.md`](../../devlog/roadmap.md). The tier resets at UTC midnight, which the seam already knows: [`src/libs/dispatch/classify.ts`](../../src/libs/dispatch/classify.ts) carries `refresh: 'utc-midnight'` on the `plan-limit` pattern.

## Suggested skills

| Skill | Why this session needs it |
|---|---|
| `dispatch` | the session edits the seam it uses; the skill states the entrypoint, the run directory and the seat assignment |
| `testing` | every fix here is a behaviour asserted by a test, and the suite's homes and patterns are stated there |
| `decision-records` | a change to which backend serves which id, or to what a printed command carries, is an ADR-shaped decision |
| `git-discipline` | the commit type, the branch name and the fold rules for a multi-defect fix |

## The defects

### D1 - the printed dispatch command inherits the caller's stdin

**Repro.** Read a plan from a file into a loop and launch a cell per line:

```bash
while IFS=$'\t' read -r rep carrier config; do
  opencode run -m opencode/deepseek-v4.1-flash-free --variant medium \
    --dir /home/agentuser/sandbox "$(cat brief.md)" > cell.log 2>&1 &
  while [ "$(jobs -rp | wc -l)" -ge 6 ]; do wait -n; done
done < plan.tsv
```

**Observed.** The child consumed `plan.tsv`. The loop's next read found end of file, the loop ended, one cell ran out of thirteen, the process exited zero, and nothing was printed. Recorded in the status sheet as a smaller grid.

**Expected.** A launch consumes no caller input. [`src/libs/dispatch/launch.ts`](../../src/libs/dispatch/launch.ts) builds the shell command string that launch sites substitute for their own inline invocation, and that string carries no stdin redirection.

**Precedent.** [`docs/development/test_harness_mechanism.md`](../../docs/development/test_harness_mechanism.md) already records the same class as a guard in `scripts/run_agent.sh`: "the two `< /dev/null` redirections on compose invocations, which keep an attached session from reading the caller's stdin." The fix is the same guard at the seam.

**Fix candidate.** Append `</dev/null` to the printed command in `launch.ts`, and assert the printed string in a test. **Severity: high.** The failure is silent and reads as a completed run.

### D2 - an `opencode/` id is accepted on the pi backend, and its refusal reads as exhaustion

**Repro.**

```bash
pi --provider opencode --model opencode/deepseek-v4.1-flash-free -p "Reply with exactly: PONG"
```

**Observed.** `rc=1` in about one second, with `429: {"type":"FreeUsageLimitError","message":"Free usage limit reached..."}`. The same id through its own runtime answers:

```bash
opencode run -m opencode/deepseek-v4.1-flash-free "Reply with exactly: PONG"   # PONG, 6s
```

**Expected.** The id's prefix decides the runtime, and the seam refuses a mismatched pair by name. [`src/libs/dispatch/launch.ts`](../../src/libs/dispatch/launch.ts) selects the runtime; `.agents/drafts/seat-contract-run.md` states the three axes (provider namespace, serving runtime, entitlement) and the operating rule that an `opencode/` pair runs through `opencode run`.

**Already recorded.** `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` assumption A8: the gateway re-tightened its client check, so a free-tier model cannot be probed from `pi`.

**Impact.** The refusal is indistinguishable from a spent quota, and it was read that way: a record was written stating the free model was unavailable, then corrected the same day. **Severity: high.**

### D3 - the caller re-greps what the seam already classifies, and misses an accepted string

**Repro.** A runner that stops on `grep -q '"type":"FreeUsageLimitError"' cell.log`.

**Observed.** The CLI reports the same refusal as `AI_APICallError: Free usage limit reached` in the run log, which the pattern does not match; four cells were launched into an exhausted tier and each sat at its wall cap.

**Expected.** Callers ask the seam rather than pattern-match a log. [`src/libs/dispatch/classify.ts`](../../src/libs/dispatch/classify.ts) declares the `plan-limit` pattern as `FreeUsageLimitError|GoUsageLimitError|usage limit`, which matches both strings, and [`src/libs/dispatch/cli.ts`](../../src/libs/dispatch/cli.ts) exposes `walk` with `--class`, `--scope` and `--empty-log`.

**Fix candidate.** Document the classification call in the dispatch skill's failure section, and treat the log-grep idiom as a defect in any runner that carries it. **Severity: medium.** The seam is correct; the usage was not, which is why the fix is documentation plus a test that asserts the accepted strings.

### D4 - no ceiling on concurrent runs against one SQLite store

**Observed.** Six concurrent `opencode run` processes produced `database is locked` on a cell that then exited non-zero with a fifty-seven-byte log.

**Expected.** Either a documented concurrency ceiling for this backend, or retry-once-on-lock at the seam, since the condition clears on its own. **Severity: medium.** One cell in six failed for a reason invisible in its own brief.

### D5 - a retry written as "repeat on a non-zero exit" repeats timeouts

**Observed.** A cell that hit its wall cap was retried three times at the same cap, holding a five-way block for half an hour, and the summary reported timeouts that were never diagnosed.

**Expected.** Retry keys on the one transient condition, and every other outcome is recorded as it stands. The vocabulary for that already exists in [`docs/reference/terminology.md`](../../docs/reference/terminology.md): `transient`, `quota`, `capability`, `timeout`, `unknown`. **Severity: medium.**

### D6 - `--variant high` on the free model returns an empty turn with a zero exit code

**Repro.** `opencode run -m opencode/deepseek-v4.1-flash-free --variant high --dir <dir> "$(cat brief.md)"`, where the brief asks for a fault list over a 158-line file.

**Observed.** The assistant spends the reasoning budget and writes no text: `{"input":3144,"output":0,"reasoning":32000}` followed by `step-finish`, no text part, `rc=0`, and 432 bytes of log. `--variant medium` returns a full list in 266 seconds on the same brief.

**Evidence.** The query that shows this is in the appendix handover; a run's token counts are in the OpenCode store at `~/.local/share/opencode/opencode.db`, tables `session`, `message` and `part`, each row carrying a JSON `data` column.

**Expected.** A zero-output turn is a failure, not a result. The seam already has the notion: `dispatch walk --empty-log`. **Fix candidate.** Classify a zero `output` token turn as failed, and stop naming `high` for this id in `.agents/model-recommendations.md` until the level is re-measured. **Severity: high.** It manufactures a successful cell carrying nothing.

## What is already recorded, and must not be restated

| Record | What it holds |
|---|---|
| [`devlog/handovers/20261026-05-workflow-opencode_run_harness_defects.md`](../../devlog/handovers/20261026-05-workflow-opencode_run_harness_defects.md) | the trap table, the corrections, and the session-store query |
| [`docs/adr/pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) | the seat contract's decided part: one door, one assignment per seat, the runtime following the assignment |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | the seam's behaviour as shipped: the outcome table, the advance rule and the stop rule |
| [`.agents/drafts/cost-aware-dispatch-run.md`](cost-aware-dispatch-run.md) | the free tier's reachability from the CLI |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | the refusal vocabulary, class by class |
| `devlog/handovers/archive/20261017-05-impl-the_dispatch_failure_channel.md` | why the CLI's error channel is on stderr, with `--print-logs --log-level ERROR` |
| `devlog/handovers/archive/20261019-08-docs-free_tier_quota_in_the_dispatch_skill.md` | the measured free-tier request quota |

## Constraints

Work inside the working tree; no push. Any dispatch used while working on this session takes its assignment from [`.agents/model-recommendations.md`](../../.agents/model-recommendations.md) through the resolver, never from a hand read. Do not modify the operator's recommendation file to work around a defect: D6 changes what that file should say, and that edit is the operator's ruling.

## Sensitive information

None is carried here. Do not read or copy `~/.config/opencode` or `~/.local/share/opencode` beyond the `opencode.db` query above: the config directory holds account credentials, and the store holds session content rather than secrets. The free-tier quota is an account fact, not a credential.

## Definition of done

Each defect is either fixed with a test that fails before the change, or filed with a named owner and a written reason for deferral. D1's fix is asserted on the printed command string, not only on a manually redirected invocation. `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are green. The appendix handover gains one line per defect naming its outcome, so the record and the code do not diverge.
