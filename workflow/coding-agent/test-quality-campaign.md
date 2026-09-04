# Test Quality Campaign - Reflection-Gated, Policy-Grounded, Fix + Report (Bash)

## Authority

The repo testing policy is the authority. This prompt links to it and does not restate it. Before any action, read both:

- `docs/development/testing_policy.md` - placement, the `make test` invariant, the prerequisite rule, the `knowledge_` and `diagnose_` prefixes, the untested-behaviour-branch rule.
- `docs/development/testing-conventions.md` - the anti-patterns, especially **Anti-Pattern 6: Change-Mirror Test**, and the two checklists.

Where this prompt and a policy rule disagree, the policy wins.

## Mode

Autonomous, long-running, and token-aggressive. Ignore the usual per-iteration permission gates for the duration. Prefer depth: read the file instead of guessing from a grep.

Scope: tests only. Rewrite, delete, and add tests. Never change production source to make a test pass. If a test change exposes a real production defect, do not fix it here. Record it in `FLAKY_AND_BAD_TESTS.md` and flag it.

The operator invoking this campaign is the opt-in moment. Writing and changing tests is authorised for the duration. Outside the campaign, tests are opt-in and product-first.

## Deliverable

Produce a final report and leave the test changes uncommitted in the working tree as a proposal. Do not commit. The report lives in the output mount session directory. Do not continue past the report.

## Persistent State

Write all campaign state to the output mount (the `$OUTPUT_DIR` environment variable), nowhere else:

```bash
SESSION_DIR="$OUTPUT_DIR/test-campaign-$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$SESSION_DIR"
```

State files (your memory across turns; never rely on chat history alone): `TODO.md`, `INVARIANTS.md`, `COVERAGE.md`, `FLAKY_AND_BAD_TESTS.md`, `PROGRESS.md`, `CAMPAIGN_STATUS.md`, `FINAL_REVIEW.md` (last only).

Record the full `$SESSION_DIR` path in `CAMPAIGN_STATUS.md` immediately. Update at least one state file after every meaningful action.

## Phase 0 - Bootstrap

Create `$SESSION_DIR` and the state files. Confirm the test command (`make test`) and that the suite starts green, so later failures are yours.

## Phase 1 - Judgment (Reflection) + Inventory

Run the full suite and record pass/fail. Before changing anything, apply the reflection gate. For each test file answer three questions:

1. **Code mirroring vs value creation** - apply Anti-Pattern 6's test. Does the assertion fail only if the change is reverted? Does it assert the meaning or the exact string the change touched? A test that pins a behaviour a future reader would be tempted to change must name the record (ADR, design record, or handover decision) that explains it.
2. **Noise** - find tautological, file-exists, and string-presence assertions; tests of removed features; and dead tests (defined but never `run_test`-registered).
3. **Iteration friction** - find lock-step edits from output-contract changes that lacked a propagation checklist, and pins with no rationale.

Rate each file **High Value / Medium Value / High Noise**, assign a per-file target (**keep / rewrite / delete**), and record one overall rating for the suite (same three values). Record the verdicts in `FLAKY_AND_BAD_TESTS.md` and seed `TODO.md` (P0 = High Noise + dead tests + missing invariant branches).

## Phase 2 - Contract Extraction

For every pure (or near-pure) bash function and important loop, document preconditions, postconditions, invariants, edge cases, and every branch in `INVARIANTS.md`. Turn each missing contract into a `TODO.md` task. Note where the bash structure makes an invariant hard to express (global state, subshell side effects, exit-code swallowing).

## Phase 3 - Execution Grind

While `TODO.md` has open P0 or important P1 items: pick the highest priority, mark it in-progress, do the work (tests only), run until green, refresh `COVERAGE.md` for touched areas, mark done only when verified, append to `PROGRESS.md`, refresh `CAMPAIGN_STATUS.md` with "Next action: ...", then pick the next task. Every 4-6 tasks, re-run the broad suite and re-prioritise `TODO.md`.

## Phase 4 - Final Report, Commit, Submit

Only when the success criteria are met (or a hard external blocker appears), write `FINAL_REVIEW.md` with these sections:

1. Executive Summary - blunt overview of starting state to ending state.
2. Agent Feedback & Gotchas - what worked, what slowed you down, surprises, tooling friction. Be specific.
3. Test Harness Evaluation - how the harness is used, missed opportunities, whether the stack is adequate, and a stay-or-migrate recommendation with evidence.
4. Architectural & Functional Seams - bad seams, global state, hidden side effects, missing abstraction boundaries, and the testing pain each caused.
5. Bash Conventions & Testing Policy Gaps - rules to add or tighten so future agents produce better tests by default.
6. Remaining Gaps & Recommended Next Steps - justified leftovers and the highest-leverage follow-up work.
7. Campaign Metrics - bad tests removed or rewritten, invariants added, branches covered vs identified.

Then leave the test changes uncommitted in the working tree, and stop. Do not commit. End your output with a summary block the main agent can collect:

```
SESSION_DIR: <path>
changes: <files changed>
suite: <passed>/<failed>/<skipped>
```

Do not continue past the report.

## Success Criteria

Stop only when all hold:

1. Zero change-mirror tests (Anti-Pattern 6).
2. Zero dead tests - every `test_*()` registered and every `run_test` target resolving.
3. Prerequisites enforced - a broken stub or shim reports one named prerequisite error, not N unrelated test failures.
4. Output-contract changes carry a propagation checklist per AGENTS.md.
5. Pinned assertions name their rationale (ADR, design record, or handover decision).
6. No handover or finding claims a code path that no test exercises.
7. The suite is deterministic and green: `failed 0, skipped 0`.
8. Every High Noise verdict from Phase 1 is resolved (kept with rationale, rewritten, or deleted).

Coverage note: the harness has no line-coverage tool. "Coverage" here means invariant and branch coverage documented in `INVARIANTS.md` and exercised by tests, not a numeric percentage. Track pure functions with documented invariants vs total pure functions, and branches covered vs identified.

## Anti-Stopping Rules

Do not stop before the success criteria hold and the report is written. If context grows, summarise older work into the state files and continue. If a phase finishes early, deepen. If you hit a non-blocking question, write it into `CAMPAIGN_STATUS.md` and keep working. The campaign ends only after the report is written and the summary block is returned.

## Style

Be harsh and precise. Name the anti-pattern per `testing-conventions.md` ("this is a change-mirror test", "this is dead - defined but not registered"). Prefer deleting a bad test over leaving it. Prefer one strong invariant test over three weak ones. Cite concrete examples in every markdown note.

## Kickoff

Start with Phase 0. Then enter the loop and do not stop until the final report is written and the summary block is returned.
