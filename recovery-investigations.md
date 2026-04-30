# Recovery — Investigation Document

**Purpose:** answer code-verification questions that the recovery scope depends on. Run this before pre-clean implementation begins and re-run questions where indicated after pre-clean to feed the 20260430 design step.

**Status:** unfilled. Each section has space for findings.

---

## How to use this document

For each question:

1. **Read** the question, the rationale, and what to look for.
2. **Run** the verification — typically grep, file inspection, or test execution. Do not modify anything.
3. **Record** the finding verbatim in the "Finding" subsection. Quote line numbers and exact strings where relevant.
4. **Note** the disposition: which file or step the finding feeds into.

If a question's answer changes during pre-clean (e.g. P-1 lands and now consumers all use `session_state_read`), re-run the question and add a second finding entry dated to the re-run.

---

## Questions

### Q-I-1 — Diff helper unification status

**Asks:** are there three separate `git diff` invocations producing diff files (in `libs/diff.sh` x2 and `libs/package_diff.sh` x1), or has one parameterised helper been extracted?

**Why it matters:** if not unified, item 10 from the deferred-items trace is real scope. The disposition splits across pre-clean (helper extraction) and 20260430 design step (interface standardisation choices).

**What to look for:**

- In `libs/diff.sh`: locate `write_uncommitted_diff` and `write_all_changes_diff`. Read the function bodies. Are they each calling `git diff` directly, or are they each calling a third helper?
- In `libs/package_diff.sh`: locate the line that produces `uncommitted.diff`. Is it `git diff HEAD ...` inline, or a call to a function in `diff.sh`?
- Count the distinct `git diff` invocations across the three files. Three invocations = not unified. One invocation in a helper called by three sites = unified.

**Verification commands (read-only):**

```sh
grep -n "git diff" libs/diff.sh libs/package_diff.sh
grep -n "^[a-z_]*()" libs/diff.sh libs/package_diff.sh
```

**Finding:**

_Unfilled. Record the grep output and a one-sentence summary of what shape the code is in._

**Disposition based on outcome:**

- **Three separate invocations:** add helper extraction to pre-clean (new task P-4a — see `recovery-pre-clean.md` after update). Interface standardisation choices defer to 20260430 design step.
- **One helper, three call sites:** no scope change. Note in `recovery-change-a.md` § A.1 cross-cutting that handovers under-described what landed.
- **Two helpers, one inline:** partial unification. Add helper consolidation to pre-clean. Interface choices still defer to design step.

**Re-run after pre-clean?** No — once answered, the answer is stable until pre-clean's helper-extraction task (if any) lands.

---

### Q-I-2 — `package_diff.sh` reads `INIT_SHA` directly?

**Asks:** does `libs/package_diff.sh` currently `cat .git/INIT_SHA` or call `session_state_read`?

**Why it matters:** confirms the scope of pre-clean P-1b. Audit finding 1.3 claims direct `cat`, but verify before relying on it.

**What to look for:**

- In `libs/package_diff.sh`: any reference to `INIT_SHA`, `cat`, or `session_state_read`.
- In particular, the function or block that resolves the baseline ref for the `git diff` call.

**Verification commands:**

```sh
grep -n "INIT_SHA\|session_state_read\|\.git/INIT" libs/package_diff.sh
```

**Finding:**

_Unfilled._

**Disposition:**

- **Reads `.git/INIT_SHA`:** P-1b applies as written (covers `diff.sh` and `package_diff.sh`).
- **Already uses `session_state_read`:** P-1b shrinks to `diff.sh` only.
- **Neither (uses some other mechanism):** record what it uses and re-scope P-1b.

**Re-run after pre-clean?** No — P-1b's outcome will change this; that's expected.

---

### Q-I-3 — `tests/test_session.sh` `session_state_read` coverage

**Asks:** does `tests/test_session.sh` have any direct tests for `session_state_read`?

**Why it matters:** confirms scope of pre-clean P-3a. Audit finding 2.5 says no coverage, but verify.

**What to look for:**

- Test names mentioning `session_state_read`, `SESSION_STATE`, or related.
- Indirect coverage where another tested function calls `session_state_read` internally (still coverage, but not direct).

**Verification commands:**

```sh
grep -n "session_state_read\|SESSION_STATE" tests/test_session.sh
grep -n "^test_" tests/test_session.sh
```

**Finding:**

_Unfilled._

**Disposition:**

- **No coverage:** P-3a applies as written.
- **Indirect only:** P-3a applies; mark new tests as direct coverage.
- **Direct coverage exists:** P-3a may shrink to filling gaps. Re-scope.

**Re-run after pre-clean?** No.

---

### Q-I-4 — Router callsites and sourceability

**Asks:** where are `resolve_source_for_draft` and `resolve_diff_for_apply` defined, where are they called from, and can they be tested by sourcing the file that defines them?

**Why it matters:** if the routers can't be sourced cleanly (e.g. `agent-sandbox.sh` has top-level execution that runs when sourced), then writing direct tests requires either extracting the routers into a sourceable file or using a more complex test harness. That decision affects pre-clean P-3b/P-3c scope.

**What to look for:**

- Definition site of both functions.
- Call sites of both functions.
- Whether the file that defines them has top-level execution that would interfere with sourcing.

**Verification commands:**

```sh
grep -rn "resolve_source_for_draft\|resolve_diff_for_apply" scripts/ libs/ tests/
head -30 scripts/agent-sandbox.sh   # check for top-level execution
```

**Finding:**

_Unfilled. Note: definition file, call sites, sourceability assessment._

**Disposition:**

- **Sourceable cleanly:** P-3b/P-3c apply as written. Tests source the file and call the functions directly.
- **Not sourceable (top-level execution interferes):** flag as a structural concern. Two paths:
  - Pre-clean adds a refactor task to make `agent-sandbox.sh` sourceable for tests (e.g. wrap top-level execution in a `main` guard). This is principled but expands pre-clean.
  - Tests use a different harness (e.g. invoke `agent-sandbox.sh` as a subprocess and assert on output). Less clean but smaller scope.
  - Defer router unit tests to after A.2 reconstruction, where the routers may move or get refactored anyway. The deferred-items trace specifically caught the original deferral; deferring again is a regression.

  **Recommendation if not sourceable:** add a refactor task to pre-clean. The tests are gated on this, and so is any future testing of CLI logic — solving it once is better than working around it twice.

**Re-run after pre-clean?** Yes if pre-clean adds a sourceability fix; the second run confirms the fix worked.

---

### Q-I-5 — Inline routing logic in `draft_run` / `apply_run` (current state)

**Asks:** how much routing logic remains inside `draft_run` and `apply_run` in the recovered tree? Per the handover trail, A.2 was supposed to extract this into `agent-sandbox.sh`. Did it land that way in the squashed commit?

**Why it matters:** affects A.2 reconstruction scope. If routing was extracted, A.2 reconstruction is mostly a re-application of work already in the squashed commit. If not extracted, A.2 includes the extraction.

**What to look for:**

- In `libs/diff_workflow.sh`: does `apply_run` resolve paths internally, or does it accept a path argument and apply it directly?
- In `libs/draft_workflow.sh`: does `draft_run` accept `SOURCE_DIR` and `SESSION_NAME` as arguments per handover 06's claim, or does it resolve them internally?
- In `scripts/agent-sandbox.sh`: do `resolve_source_for_draft` and `resolve_diff_for_apply` exist, and are they called before invoking the workflow functions?

**Verification commands:**

```sh
grep -n "^apply_run\|^draft_run" libs/diff_workflow.sh libs/draft_workflow.sh
grep -n "resolve_source_for_draft\|resolve_diff_for_apply" scripts/agent-sandbox.sh
sed -n '1,5p' libs/diff_workflow.sh   # check function signature comments
```

**Finding:**

_Unfilled. Note: signatures of both functions, presence of routers in agent-sandbox.sh, summary of where resolution actually happens._

**Disposition:**

- **Routing extracted (matches handover 06):** A.2 reconstruction is light. Note in `recovery-change-a.md` § A.2.
- **Routing still inline:** A.2 reconstruction includes extraction. Significant scope.
- **Partial extraction:** record specifics. May fold into A.2 or split.

**Re-run after pre-clean?** No.

---

### Q-I-6 — `package_diff` cross-write status

**Asks:** does `package_diff.sh` write only to `output/diffs/`, or does it also write a copy to `session-diffs/`?

**Why it matters:** confirms the channel boundary that A.2 established. Item 3 from the deferred-items trace was the cross-write question; the trace concluded it was correctly punted, but verify the current state matches that conclusion.

**What to look for:**

- Output paths in `libs/package_diff.sh`. Should be `$OUTPUT_DIR/diffs/...` only.

**Verification commands:**

```sh
grep -n "session-diffs\|output/diffs\|CHANGES_DIR\|OUTPUT_DIR" libs/package_diff.sh
```

**Finding:**

_Unfilled._

**Disposition:**

- **Single write to `output/diffs/`:** boundary intact. No action.
- **Cross-writes to `session-diffs/`:** unintended behaviour. Surface as a finding for the 20260430 design step.

**Re-run after pre-clean?** No.

---

### Q-I-7 — Stale doc references count

**Asks:** how many references to `changes.diff`, `staged.diff`, `BASELINE_SHA`, `diff_commit_pending` remain in `docs/` and `libs/`?

**Why it matters:** confirms the scope of A.3 reconstruction. The audit found four specific drift cases (3.1–3.4); A.3's acceptance criterion 4 is "no stale references remain." A pre-A.3 grep gives the actual count and target list.

**What to look for:**

- Each of the four stale terms across `docs/` and `libs/`.
- Distinguish stale references (should be updated) from intentional historical references (should remain).

**Verification commands:**

```sh
grep -rn "changes\.diff\|staged\.diff\|BASELINE_SHA\|diff_commit_pending" docs/ libs/ \
  | grep -v "docs/devlog/handovers/"   # exclude handovers; they're historical
```

**Finding:**

_Unfilled. Record the file:line list. Note any that look intentionally historical._

**Disposition:**

- Feeds A.3 reconstruction's target list. Each line in the finding becomes a known target for A.3.
- Some pre-clean tasks (P-2a, P-2c) handle a subset; the rest land in A.3.

**Re-run after pre-clean?** Yes — re-run after P-2 group lands. The remaining references are A.3's scope.

---

### Q-I-8 — `baseline.tar` actual state

**Asks:** is `baseline.tar` tracked, gitignored, regeneratable, and what's its content?

**Why it matters:** confirms scope of P-2e. The audit says it's tracked. We also need to know if removing it breaks anything (it shouldn't, per the handover claim, but verify).

**What to look for:**

- `git ls-files --error-unmatch baseline.tar` — is it tracked?
- `cat .gitignore | grep baseline` — is it ignored?
- Anywhere it's referenced in scripts/libs/docs.

**Verification commands:**

```sh
git ls-files --error-unmatch baseline.tar 2>&1
grep -rn "baseline\.tar" scripts/ libs/ docs/ Makefile* 2>/dev/null
```

**Finding:**

_Unfilled._

**Disposition:**

- **Tracked, no references in code:** P-2e applies as `git rm`. Add `baseline.tar` to `.gitignore` if not already.
- **Tracked, referenced in code:** the references need updating before removal. Expand P-2e scope.

**Re-run after pre-clean?** No.

---

### Q-I-9 — Test count and current pass/fail state

**Asks:** what's the current pass/fail count of `scripts/run_tests.sh`?

**Why it matters:** establishes the baseline. Audit reports "249 tests across 13 files pass" but that was from a specific point in time. Re-run.

**What to look for:**

- Total test count.
- Pass / fail / skip counts.
- If anything fails, which tests and why.

**Verification commands:**

```sh
scripts/run_tests.sh 2>&1 | tail -50
```

**Finding:**

_Unfilled. Record summary line and any failures._

**Disposition:**

- **All pass:** baseline confirmed. Pre-clean tasks each have a known-green starting point.
- **Failures:** must be understood before pre-clean begins. A failing baseline means we don't know what state the recovery is actually in. Stop and investigate.

**Re-run after pre-clean?** Yes — after each P-1 sub-commit, after P-2 group, after P-3 group. Confirm green at each step.

---

## Summary table for design step

After all questions are answered, fill this table to feed the 20260430 design step.

| Question | Finding (one line) | Affects | Action |
|---|---|---|---|
| Q-I-1 | | pre-clean P-4a; A.1 scope; design step | |
| Q-I-2 | | pre-clean P-1b scope | |
| Q-I-3 | | pre-clean P-3a scope | |
| Q-I-4 | | pre-clean P-3b/c approach | |
| Q-I-5 | | A.2 reconstruction scope | |
| Q-I-6 | | design step (channel boundary) | |
| Q-I-7 | | A.3 reconstruction scope | |
| Q-I-8 | | pre-clean P-2e scope | |
| Q-I-9 | | pre-clean baseline | |

---

## Re-run protocol

After pre-clean lands, re-run questions marked "Re-run after pre-clean? Yes":

- Q-I-4 (if pre-clean added a sourceability fix)
- Q-I-7 (after P-2 group)
- Q-I-9 (continuously, after each pre-clean commit)

Findings from the re-run feed the 20260430 design step's scoping of A's remaining work. Any divergence from the original finding is itself a finding worth recording (e.g. "pre-clean P-2 reduced stale references from 14 to 6; A.3 targets the remaining 6").
