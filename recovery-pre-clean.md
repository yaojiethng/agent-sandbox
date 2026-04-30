# Recovery — Pre-Clean

**Purpose:** address every audit-identified discrepancy by either (a) porting the fix from the squashed recovery tip as a discrete commit, or (b) re-fixing it from baseline in a fresh commit. The output is a sequence of audit-shaped commits that lands the audit's remediation list as separate, reviewable units before any feature reconstruction begins.

**Position in recovery flow:**

1. Investigations (`recovery-investigations*.md` — both baseline-state and recovery-tip-state) — done
2. **Pre-clean (this file)** — the first step of separating useful commits from the squashed recovery tip
3. 20260430 design step (`recovery-design-step.md`) — rescope A and B against the cleaned tree
4. Change A reconstruction (`recovery-change-a.md`)
5. Change B implementation (`recovery-change-b.md`)

---

## Framing

The audit was performed against **baseline** state (before the lost session). It identified discrepancies between the documented system state and what was actually in the tree at that point. Many of those discrepancies were resolved in the lost session and are reflected in the squashed recovery tip; some remain.

Pre-clean is the first step of separating useful commits from the squashed recovery tip. Pre-clean's job is **not** to replay every audit item from baseline — that would duplicate work already done. Pre-clean's job is **also not** to blindly accept the squashed recovery tip — that would lump correctness fixes together with feature work and lose the separation we're trying to recover.

For each audit item, pre-clean asks: *what is the cleanest way to land this fix as a discrete, reviewable commit on top of baseline?*

The end result should look like a series of commits that resolve the issues that were raised in the baseline state audit, with properly written commit messages and handovers, and a green test state. We will then use the post pre-clean state as the basis of the next steps of the recovery. Having an audit trail for the source of the changes is not a concern.

For each thing the audit flagged:

- If the squashed commit fixed it cleanly → port that fix as a separate commit (we get to keep the work, but as a discrete commit, not blended into feature work)
- If the squashed commit didn't fix it or introduced new issues → fix it fresh in pre-clean
- If the squashed commit fixed it cleanly but it is not part of the pre-clean scope → defer it to a later recovery step

The classification per item appears in the per-task sections below. The classifications are based on the comparison of the baseline-state and recovery-tip-state investigations.

**Important:** "port from squashed tip" does not mean cherry-picking from the squashed commit. The squashed commit is one big change; cherry-pick is not granular enough. It means: read what the squashed commit did for this item, understand it, and apply that change as a fresh commit on top of baseline. The fresh commit's content matches the squashed tip's content for that item, but is constructed deliberately, not extracted automatically.

---

## Audit findings — disposition table

This table summarises every audit finding and where it goes in the recovery flow. The detailed task descriptions follow.

| Audit finding | Baseline state | Recovery-tip state | Disposition |
|---|---|---|---|
| 1.1 — `snapshot.sh` writes `INIT_SHA`, not `SESSION_STATE` | Confirmed | Fixed in squashed tip (writes `SESSION_STATE`) | **Port** as P-1a |
| 1.2 — `diff.sh` reads `INIT_SHA` directly via `cat` | Confirmed | Fixed (uses `INIT_SHA` as function parameter, no file read) | **Port** as P-1b (combined with 1.3) |
| 1.3 — `package_diff.sh` reads `INIT_SHA` directly | Confirmed | Fixed (uses `session_state_read` for `session_ts`; no `INIT_SHA` read) | **Port** as P-1b (combined with 1.2) |
| 1.4 — `package_branch.sh` `session_state_read` is dead code | Confirmed | Fixed (live; `snapshot.sh` writes the file it reads) | **No action** — resolved by P-1a |
| 1.5 — `sandbox-entrypoint.sh` doesn't write `session_ts` | Confirmed | Fixed | **Port** as P-1a (combined with 1.1) |
| 1.6 — `start_agent.sh` doesn't write `SESSION_STATE` | Confirmed | Fixed | **Port** as P-1a (combined with 1.1) |
| 2.1–2.4 — Test fixtures use `INIT_SHA` instead of `SESSION_STATE` | Confirmed | Fixed (all four test files use `SESSION_STATE` fixtures) | **Port** as P-1c |
| 2.5 — No direct `session_state_read` tests | Confirmed | Confirmed (still missing) | **Re-fix** as P-3a |
| 2.6 — No `SESSION_STATE` fallback test when `SESSION_TS` unset | Confirmed | Not verified directly; probably still missing | **Re-fix** as P-3a (combined with 2.5) |
| 3.1 — `sandbox_lifecycle.md` documents `INIT_SHA` write | Confirmed | Confirmed (still stale at line 36) | **Re-fix** as P-2a |
| 3.2 — Stale duplicate `discussions/roadmap.md` | Confirmed | Confirmed | **Re-fix** as P-2b |
| 3.3 — `design_diff_and_branch_packaging_workflow.md` documents `INIT_SHA` write | Confirmed | Confirmed (still stale at line 318) | **Re-fix** as P-2c |
| 3.4 — `project_index.md` lists deleted `apply_workspace.sh` and `draft.sh` | Confirmed | Partial — `apply_workspace.sh` removed in tip, `draft.sh` still listed at line 125 | **Mixed** — see P-2d |
| 4.1 — `baseline.tar` tracked in git | Confirmed | Confirmed (still tracked) | **Re-fix** as P-2e |
| 5.1–5.3 — `SESSION_STATE` acceptance criteria unmet | Confirmed | Met in tip | **No action** — resolved by P-1 group |
| Q-I-1 — Three separate `git diff` invocations (no helper unification) | Confirmed | Confirmed (still three separate invocations) | **Defer to A.1** — design step decides interface |
| Q-I-4 — `agent-sandbox.sh` not sourceable for tests | N/A — routers didn't exist at baseline | Confirmed (top-level dispatch, no main guard) | **Deferred to A.0** — sourceability refactor; not audit-derived |
| Q-I-7 stale ref — `sandbox.Dockerfile:47` | Pre-existing | Still stale | **Re-fix** as P-2f |

---

## Procedural rules

These rules apply to every task in this file. Do not skip them.

1. **One concern per commit.** Splitting is cheaper than merging. If a task description bundles two things and they can be split cleanly, split them.
2. **Tree must be green at the end of every commit.** Run `scripts/run_tests.sh` before committing. If tests fail, the commit is not done. Exception: tasks marked "leaves tree red — paired with subsequent task" must explicitly reference which task restores green.
3. **Verify before implementing.** Each task below has a "verify before" step that confirms the recovery-tip investigation is still accurate (the tree may have moved). Run it. If reality has diverged from the investigation, stop and update this file before proceeding.
4. **Port commits use squashed-tip content as the source.** When a task is classified "port," the agent should read the squashed tip's version of the affected files, understand what changed for this item, and apply that change as a fresh commit. The agent does not cherry-pick.
5. **Re-fix commits use the agent's own implementation.** When a task is classified "re-fix," the agent implements from scratch against baseline. The squashed tip may or may not contain a relevant change; if it does, the agent may consult it as reference but does not copy from it.
6. **Do not roll bug fixes into feature work.** Pre-clean fixes only what the audit (and the investigations) flagged. New issues encountered during execution are tier 2 minimum — surface, do not fold in.
7. **Audit findings are claims, not truths.** The audit's findings have already been re-verified by the investigations. If a task's "verify before" step reveals a third state different from both, that is tier 4 — stop.

---

## Task groups

Tasks land in groups. Order within a group is fixed; order between groups is flexible.

**Recommended overall order:** P-1 → P-2 → P-3.

The P-1 group is the largest and lands the `SESSION_STATE` migration. Once P-1 is in, the test baseline shifts (tests that asserted old behaviour become wrong; tests that assert new behaviour become right). P-2 is documentation, independent. P-3 is test additions, depends on P-1 having landed.

---

## Group P-1 — `SESSION_STATE` migration (port from squashed tip)

**Why this group exists:** the audit's headline finding. The squashed tip has a complete migration; pre-clean's job is to land it as discrete commits before feature work goes on top.

**All tasks in this group are classified "port."** The agent reads the squashed tip's versions of these files to understand what to write.

### P-1a — Migrate `SESSION_STATE` write side

**Source:** squashed tip's `libs/snapshot.sh`, `libs/sandbox-entrypoint.sh`.

**Scope:**
- `libs/snapshot.sh`: replace the `INIT_SHA` write with `session_state_write` calls for `init_sha` and `session_ts`. Reference: squashed tip's `libs/snapshot.sh:298-301`.
- `libs/sandbox-entrypoint.sh`: ensure `session_ts` is written to `SESSION_STATE` after `snapshot_init_git` runs. Reference: squashed tip's `libs/sandbox-entrypoint.sh`.
- Any references to `start_agent.sh` writing `SESSION_STATE` (audit 1.6) should be verified — the recovery-tip investigation did not directly address whether `start_agent.sh` writes `SESSION_STATE` or whether the entrypoint does. Inspect the squashed tip's behaviour and replicate.

**Verify before:**
- `session_state_write` exists in `libs/session.sh` at baseline. (The audit indicates the read side exists but write side is missing; confirm both before starting.)
- The squashed tip's `snapshot.sh` lines 298-301 write to `SESSION_STATE`. Read those lines in the squashed tip to confirm the structure.

**Verify after:**
- Container init (in tests or by running the harness) creates `.git/SESSION_STATE` with both keys.
- `.git/INIT_SHA` is no longer created by `snapshot_init_git`.

**Tests:**
- `tests/test_snapshot_container.sh` will currently fail this commit because it asserts `INIT_SHA` exists at baseline. **Do not fix the test in this commit.** Test fixture migration is P-1c. This commit will leave the tree red on `test_snapshot_container.sh` (and possibly `test_diff.sh`, `test_package_diff.sh`, `test_package_branch.sh`).
- **Exception to procedural rule 2:** P-1a leaves the tree red. P-1c restores green. Land them in sequence without intermediate review-or-stop. If interruption is necessary, note the red state explicitly in the working file.

### P-1b — Migrate `SESSION_STATE` consumers

**Source:** squashed tip's `libs/diff.sh`, `libs/package_diff.sh`.

**Scope:**
- `libs/diff.sh`: remove direct `cat .git/INIT_SHA` reads. The squashed tip handles `INIT_SHA` as a function parameter passed in by callers, not as a file read. Replicate.
- `libs/package_diff.sh`: replace the `INIT_SHA` baseline-resolution path with `session_state_read` for whatever it actually needs. Note: the recovery-tip investigation found that `package_diff.sh` doesn't need `init_sha` at all — it only needs `session_ts`, which it reads via `session_state_read`. Confirm and replicate.
- Update error messages that reference `INIT_SHA` to reference `SESSION_STATE`.

**Verify before:**
- Baseline `libs/diff.sh` reads `.git/INIT_SHA` (recovery-tip investigation Q-I-2 supplemental finding for `diff.sh`).
- Baseline `libs/package_diff.sh:93-94` has the `cat .git/INIT_SHA` block. Confirm.
- The squashed tip's versions handle these reads via `session_state_read` or function parameters.

**Verify after:**
- `grep -n "INIT_SHA" libs/diff.sh libs/package_diff.sh` shows no file-read references (parameter names or comments are acceptable; explicit `cat` or `< .git/INIT_SHA` are not).

**Tests:** still red on the tests from P-1a; possibly more tests turn red here. P-1c restores green.

### P-1c — Migrate test fixtures

**Source:** squashed tip's `tests/test_snapshot_container.sh`, `tests/test_diff.sh`, `tests/test_package_diff.sh`, `tests/test_package_branch.sh`.

**Scope:** for each test file, replace `INIT_SHA` fixture writes with `SESSION_STATE` fixture writes. The squashed tip uses helpers like `write_session_state` (referenced in `test_package_branch.sh:26`) — confirm helper exists or define one.

**Verify before:**
- Each of the four test files at baseline writes `INIT_SHA` fixtures (audit 2.1–2.4 specifies line numbers).
- The squashed tip's versions write `SESSION_STATE` fixtures.

**Verify after:**
- `scripts/run_tests.sh` exits 0. Tree green for the first time since P-1a.
- `grep -n "INIT_SHA" tests/test_*.sh` returns only references to function parameters or comments, not file fixtures.

---

## Group P-2 — Documentation and stale files (re-fix)

**Why this group exists:** documentation drift was claimed fixed by handovers but wasn't. The recovery-tip investigation confirmed most doc fixes did not land. This group is independent of P-1 — order within group is flexible.

**Tasks in this group are classified "re-fix"** because doc changes are small enough that re-implementing against baseline is as fast as porting, and re-fixing avoids inheriting any subtle issues from the squashed tip's version.

### P-2a — `sandbox_lifecycle.md` describes `SESSION_STATE`

**Scope:** in `docs/architecture/sandbox_lifecycle.md`, replace the `INIT_SHA` write description (audit 3.1, recovery-tip line 36) with the current behaviour: `session_state_write` writes both `init_sha` and `session_ts` to `.git/SESSION_STATE`.

**Verify before:** baseline's line 36 (or thereabouts) shows the `INIT_SHA` write description. Confirm.

**Verify after:** grep the file for `INIT_SHA`. Should be zero hits unless used in a historical-context paragraph that explicitly says "previously".

### P-2b — Drop `docs/devlog/discussions/roadmap.md`

**Scope:** this file is a stale duplicate of `docs/devlog/roadmap.md`. Delete it. Audit finding 3.2.

**Verify before:** confirm the file is a duplicate (compare contents to `docs/devlog/roadmap.md`). If it has unique content not present in the canonical file, this task changes shape.

**Verify after:** grep the repo for links to `discussions/roadmap.md`. Update or remove any that exist.

### P-2c — `design_diff_and_branch_packaging_workflow.md` describes `SESSION_STATE`

**Scope:** in `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md`, update the `INIT_SHA` write reference (audit 3.3, recovery-tip line 318) to describe `SESSION_STATE`.

**Note:** this file is also touched by A.3 reconstruction. Pre-clean changes only the `INIT_SHA` reference; A.3 reconstruction does any other doc work for this file. Do not bundle.

### P-2d — `project_index.md` cleanup

**Scope:** remove deleted-file entries from `docs/development/project_index.md`. Audit finding 3.4.

**Mixed disposition:**
- `apply_workspace.sh` was removed in the squashed tip (recovery-tip investigation confirms).
- `draft.sh` is still listed (recovery-tip line 125).
- Any other deleted-file entries should be identified by cross-referencing the index against `git ls-files`.

**Verify before:** cross-reference every `.sh` entry in `project_index.md` against `git ls-files libs/ scripts/`. List of stale entries should match the audit's claim plus any new ones discovered.

**Verify after:** every `.sh` entry in `project_index.md` corresponds to an existing tracked file.

### P-2e — Remove `baseline.tar` from git

**Scope:** `git rm baseline.tar` and add `baseline.tar` to `.gitignore`. Audit finding 4.1.

**Verify before:** `git ls-files --error-unmatch baseline.tar` succeeds (file is tracked). Confirm.

**Verify after:** file removed from index; `.gitignore` covers it.

### P-2f — `sandbox.Dockerfile` stale comment

**Scope:** in `libs/sandbox.Dockerfile:47`, update the comment from `staged.diff` to reflect current output: `uncommitted.diff`, `all-changes.diff`, and `patches/`.

**Verify before:** confirm the comment exists at line 47.

---

## Group P-3 — Test coverage gaps (re-fix)

**Why this group exists:** the audit caught `session_state_read` as a coverage gap. We are writing tests for things that should have been tested but weren't.

**P-3 contains a single task (P-3a).** The originally planned P-3b (sourceability refactor) and the router unit tests have been moved out of pre-clean — see § "Out of pre-clean scope" below.

### P-3a — Direct tests for `session_state_read`

**Scope:** add tests to `tests/test_session.sh` covering:
- Read returns expected key values.
- Read of missing file returns the appropriate signal (per `session_state_read`'s contract — confirm by reading the function).
- Read of malformed file behaves per the function's contract.
- Read of an existing key returns its value.
- Read of a non-existent key in a valid file behaves per the contract.

**Verify before:**
- `tests/test_session.sh` has no existing `session_state_read` tests (recovery-tip investigation Q-I-3 confirms).
- `session_state_read`'s contract is clear from reading the function in `libs/session.sh`.

**Verify after:** new tests pass. Tree green.

**Note on ordering:** P-3a is independent of P-1 in principle, but logically belongs after P-1 lands so that `session_state_read` tests run against the actual write side.

---

## Out of pre-clean scope — Deferred to A.0

A.0 is a pre-A.1 reconstruction step containing infrastructure work that doesn't fit the pre-clean framing (not audit-derived, not feature work) but must land before A.1 begins. Two items are deferred there:

**`agent-sandbox.sh` sourceability refactor.** Wrap the top-level dispatch in `scripts/agent-sandbox.sh` in a `main` guard (e.g. `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]`). Without this, `agent-sandbox.sh` cannot be sourced by tests, and the routers cannot be tested directly. Confirmed needed by Q-I-4. Not in pre-clean because it was not identified by the audit; the recovery's pre-clean scope is strictly audit-derived.

**Router unit tests for `resolve_source_for_draft` and `resolve_diff_for_apply`.** These functions exist in the squashed tip (Q-I-5 confirms routing is fully extracted). The audit did not flag them. The deferred-items trace from prior recovery planning did flag a coverage gap, but the gap is in the squashed tip, not in baseline — so it does not belong in audit-shaped pre-clean. The tests depend on the sourceability refactor above and so must follow it.

A.0's scope therefore is:
1. Sourceability refactor for `scripts/agent-sandbox.sh`.
2. Direct unit tests for `resolve_source_for_draft` and `resolve_diff_for_apply`.

A.0 is documented separately in `recovery-change-a.md` (to be added during the design step). The reason it sits before A.1 rather than being folded into a later A.x: it is pure infrastructure with no design questions, and getting it in early gives subsequent A.x reconstructions the option to lean on routers that are now testable.

---

## Other items out of pre-clean scope

**Helper extraction for the three `git diff` invocations.** Q-I-1 confirms three separate invocations; this is real scope, but it's design work (interface choices) and belongs in the 20260430 design step + A.1.

**Anything not in the audit findings or the investigations.** New issues encountered during pre-clean execution are tier 2+ findings per the recovery protocol. Surface, do not fold in.

---

## Exit criteria for pre-clean

All of the following must be true before the 20260430 design step begins:

1. `scripts/run_tests.sh` exits 0 on the pre-clean branch tip.
2. Every audit finding in the disposition table at the top of this file shows as resolved (or correctly deferred to a later step) when the audit procedure is re-run or spot-checked.
3. The pre-clean branch contains a sequence of audit-shaped commits — one per task that landed — that an independent reviewer could read in order and understand.
4. The squashed recovery tip has **not yet** been rebased on top of pre-clean. Pre-clean's tree is its own thing; rebasing is a later operation done after the design step has rescoped Change A.

State 4 is important: the squashed tip is held aside until the design step uses the cleaned tree to determine what's actually left to reconstruct in Change A. Rebasing prematurely couples pre-clean's correctness work to the squashed tip's feature work, defeating the point of separating them.

---

## After pre-clean: what the design step inherits

The design step opens against:

- The pre-clean branch tip (a clean baseline + audit fixes).
- The squashed recovery tip (held aside, available for reference).
- The two investigation files.
- The original audit handover.

The design step's first task is to determine what Change A's actual remaining scope is, given:

- Pre-clean has landed audit fixes (so A.1's data-model migration is no longer needed; it was ported in P-1).
- The squashed tip contains feature work (router extraction, helper need, doc updates) that must be ported as discrete commits in Change A.
- Some items remain genuinely missing (helper unification, some doc updates, router tests) and need fresh implementation.

The design step's output is a re-scoped `recovery-change-a.md` that lists, per A.x section, what to port and what to re-implement.
