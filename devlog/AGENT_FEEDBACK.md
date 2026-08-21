# Agent Feedback

A persistent record of the coding agent's experience: friction points, poor stack design, poor operator prompting, and "this needs reinforcing" notes. Recorded by the agent. Reviewed and addressed by the operator.

**Writer:** agent.
**Reviewer:** operator.

This file is tied into the session's Mid-session findings for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble — length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown
## [<A|G>] <date> — <short title>

state: open                        // open | mitigated | probation
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```

An entry is deleted when resolved. A resolved durable fix is recorded in the changelog and the roadmap, not in this file. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Bash

Canonical bash coding rules: [`docs/development/bash-coding-conventions.md`](../../docs/development/bash-coding-conventions.md).

Bash friction entries migrated from `devlog/discussions/20260809-story-active-bash_complaints.md` (deleted).

### [A] 2026-08-09 — Empty string bypasses `${VAR:-default}`

state: open
scoped: none
legacy: none
mitigation: explicit emptiness check before the default:

```bash
local BASE_COMMIT="$BRANCH_FROM_ARG"
[[ -n "$BASE_COMMIT" ]] || BASE_COMMIT="HEAD"
```

`${VAR:-default}` expands to `default` only when `VAR` is unset, not when it is an empty string. An empty `VAR=""` is a set value, so the fallback is skipped.

Scope: could be linted. A shellcheck rule exists for this (`SC2086` adjacent), but the empty-vs-unset distinction is a language design issue, not a linting one. Cross-reference: no skill trap covers this.

### [A] 2026-08-09 — `git rev-parse --verify 0000...` succeeds

state: open
scoped: none
legacy: none
mitigation: defensive coding only. Validate against a known commit set when dummy SHAs from test fixtures are a risk.

Git treats the all-zero SHA as a valid reference to the empty tree object. `rev-parse --verify` returns 0. No warning, no error.

Scope: upstream git behavior — not fixable in this project. Cross-reference: not applicable for trapping (upstream behavior).

### [A] 2026-08-09 — `local FOO=$(cmd)` swallows exit codes under `set -e`

state: open
scoped: none
legacy: none
mitigation: split the assignment:

```bash
local FOO; FOO=$(failing_cmd)
```

`local` is a builtin that always returns 0. Under `set -e`, the exit code of command substitution in the value is silently absorbed.

Scope: shellcheck warns on this (`SC2155`). Cross-reference: Trap 15 covers the top-level `local` scope only. The function-scope exit-code-swallowing pattern is distinct and unaddressed.

### [A] 2026-08-09 — `|| true` required for failure-tolerant checks under `set -e`

state: open
scoped: none
legacy: none
mitigation: `command || true`; for grep counting use:

```bash
local COUNT
COUNT=$(grep -c 'pattern' file 2>/dev/null) || true
```

Any command expected to sometimes fail (`ls missing*`, `grep -c` on absent patterns, `diff --quiet` on dirty trees) must be suffixed with `|| true`. The pattern is pervasive but easy to forget on new checks.

Scope: language design limitation. The subshell-scoped `|| true` pattern (from session `20260805-01`) is the best available mitigation. Cross-reference: Trap 16 covers pipeline-level swallowing only; individual-command patterns are not addressed.

### [A] 2026-08-09 — No test fixture lifecycle — manual `rm -rf` everywhere

state: open
scoped: none
legacy: none
mitigation: use `$FIXTURE_DIR` subdirectories instead of `mktemp -d`. For supplemental dirs, add `trap 'rm -rf "$_tmpdir"' RETURN`.

Bash test files have no `setup`/`teardown` framework. Every test manually creates temp dirs with `mktemp -d` and cleans up with `rm -rf`. Tests that fail midway leak temp directories.

Scope: could standardize a `test_teardown` helper. Not urgent — leaked temp dirs in CI are ephemeral. Cross-reference: no skill trap covers this.

### [A] 2026-08-09 — Undefined-variable errors under `set -u` are opaque

state: open
scoped: none
legacy: none
mitigation: always declare `local` before use. Shellcheck catches this (`SC2154`).

`set -u` causes any reference to an undefined variable to abort with only the variable name — no line number, no context.

Scope: bash limitation. `set -u` has no built-in context reporting. Cross-reference: not applicable for trapping (bash limitation).

### [A] 2026-08-09 — `grep -c` returns exit 1 on zero matches

state: open
scoped: none
legacy: none
mitigation: `grep -c 'pattern' file || true` always; or capture the exit code manually:

```bash
grep -c 'pattern' file 2>/dev/null; local _rc=$?
```

Under `set -e`, `grep -c` abort the script when zero matches is the expected result.

Scope: language design. Could adopt a `_count_matches()` wrapper. Cross-reference: no skill trap covers this; Trap 9 is unrelated. Could pair with complaint #4 as a general expected-failure-commands trap.

### [A] 2026-08-09 — Circular sourcing between `diff_export.sh` and `package_branch.sh`

state: open
scoped: none
legacy: none
mitigation: extracted `_write_export_status` to a shared `export_status.sh` lib sourced by both. Shared functions live in leaf libraries, never in orchestrators.

`diff_export.sh` sources `package_branch.sh`. When `package_branch.sh` needed `_write_export_status`, it could not source `diff_export.sh` back without a cycle. The discovery was trial-and-error; no static analysis tool caught the cycle.

Scope: architecture decision recorded in ADR (not yet written). Cross-reference: no skill trap covers this; should be added as an architecture trap.

---

## Skill cross-reference — bash complaints to traps

| # | Entry | Trap coverage | Assessment |
|---|---|---|---|
| 1 | Empty string bypasses `${VAR:-default}` | None | No mitigation exists. Should be added as a new trap. |
| 2 | `git rev-parse --verify 0000...` succeeds | None | Upstream git behavior — not fixable. Defensive coding only. No trap to add. |
| 3 | `local FOO=$(cmd)` swallows exit codes | Trap 15 (top-level `local`) | Function-scope pattern distinct and unaddressed. New trap, or merge into Trap 15. |
| 4 | `|| true` required on individual commands | Trap 16 (pipeline `|| true`) | Individual-command patterns unaddressed. Broaden Trap 16, or add a companion trap. |
| 5 | No test fixture lifecycle | None | Could add a `test_teardown` trap pattern. |
| 6 | `set -u` errors are opaque | None | Bash limitation. No trap to add. |
| 7 | `grep -c` returns exit 1 on zero matches | None (Trap 9 unrelated) | Could pair with #4 as a general expected-failure-commands trap. |
| 8 | Circular sourcing between libs | None | Add an architecture trap: shared functions live in leaf libraries. |

**Summary:** 8 bash entries, 5 with no skill coverage, 1 partially covered (#4 by Trap 16), 2 not applicable for trapping. Six new traps or trap expansions are warranted. Deferred to a future skill-maintenance session.

---

## Agent experience — session 20260809-04

### [A] 2026-08-09 — Directive/policy granularity mismatch for governance changes causes run-ahead

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-02`): `new-session.md` no longer reads as blanket authorization — the "implementation does not begin until both gates are confirmed" line was deleted (redundant with the procedural stops), the gate sections state what they confirm in declarative headers, and the gates' permission language now matches the canonical model (gates are released; content — scope, acceptance criteria — is confirmed). Per operator decision, the per-section policy gate is NOT restated in the directive: AGENTS.md owns it and is always loaded. Monitor for resurfacing of run-ahead on policy changes. When confirmed durable, delete and record in changelog/roadmap.

### [A] 2026-08-09 — Mid-session findings duplicate-entry and rewrite churn

state: open
scoped: none
legacy: none
mitigation: recording every observation as a permanent distinct finding row invites duplicates and table corruption (finding text leaked into the AC table; overwritten CORRECTION blocks). Frame Mid-session findings as candidate records consolidated at the review/publish step. Edit task notes in place rather than appending duplicate steering records.

### [A] 2026-08-09 — Hard-wrapped instruction blocks and inconsistent prose wrapping

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-01`): `documentation_policy.md` gained `### Line wrapping` (single-flowing prose; hard breaks on sentence/paragraph boundaries; ~80 cols for code comments) + audit-check entry. Wrap remediation applied across the frequently-read set (AGENTS.md x2, skills, policy files, cli-conventions, adr_policy, handover_policy). Monitor for resurfacing; the M3 doc-bloat/audit sweeps the non-frequently-read remainder. When confirmed durable, delete and record in changelog/roadmap.

### [A] 2026-08-09 — Non-ASCII punctuation under a plain-ASCII doc policy

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-01`): `documentation_policy.md` `### Character set` generalized to cover non-ASCII + control/formatting symbols + audit-check entry. Functional `§` scrubbed from frequently-read live docs; only deliberate literals remain (documentation_policy rule, AGENT_FEEDBACK finding record). Closed handovers retain `§` (read-only, out of scope). Monitor for resurfacing (new `§`/non-ASCII in live docs). When confirmed durable, delete and record in changelog/roadmap.
resurfaced: session `20260821-02` — introduced `§Q7`/`§N2`/`§Numbering` in the start/resume design handover's cross-references. Cause: imitating `§` from a closed-handover reference without checking the target doc or the policy. Not durable yet — keep monitoring; scrub on sight in live docs.

### [A] 2026-08-09 — Tracked-backlog proliferation at close

state: open
scoped: none
legacy: none
mitigation: close touches many canonical surfaces (two persistent files, roadmap tasks, decisions, deferred items). Watch-outs: keep AGENT_FEEDBACK/GOTCHAS short (no-index, length → durable fix), and rely on the roadmap as the sole task list to avoid scattering.

### [A] 2026-08-09 - A regex edit with a missing file operand silently does nothing

state: open
scoped: none
legacy: none
mitigation: when a sed -i pipeline omits the file operand while still parsing validly, it exits 0 and writes nothing; set -e does not catch it. Verify the file changed after a mechanical edit sweep. Cross-reference: bash-scripting-traps skill.

### [A] 2026-08-09 — A "did the write land?" reflex is missing for rule edits

state: open
scoped: none
legacy: none
mitigation: session 08 proposed, refined, then swept an em-dash rule, but the rule text itself was never applied; the un-applied edit surfaced only at AC-verification grep. When an edit is intended to change a rule, grep the canonical line after writing to confirm the intended text landed.
additional-resurfacing: session `20260821-02` — multi-edit rewrites of a single handover Decisions block repeatedly clobbered unrelated decision entries (D2, D5, D8 individually dropped across successive `edit` calls) because successive edits to the same block were matched against the pre-edit original and overlapped. Lesson: when editing a numbered block repeatedly, prefer one rewrite of the whole block (or verify decision integrity with a grep of all headers after each batch), not piecewise edits that can drop siblings.

### [A] 2026-08-09 - Mid-session findings under-recorded during an edit-heavy session

state: open
scoped: none
legacy: none
mitigation: session 08 produced friction (dash-sweep tooling, un-applied rule, gate-velocity) but recorded none of it; the gap surfaced via operator review, not self-capture. The AGENTS.md pointer states what to record but not the reflex to stop and write findings when a session turns edit-heavy.

## Agent experience — session 20260810-07

### [A] 2026-08-10 — `SCRIPT_DIR` ambiguous about which scripts copy is meant (host/snapshot/sandbox)

state: open
scoped: M2.6 (general CLI refactor track)
legacy: none
mitigation: the initial Finding B under-diagnosed the ambiguity as a derivation-mechanism issue (self vs injected BASH_SOURCE index). The operator sharpened it: the name does not say WHICH scripts directory is meant — the harness can resolve scripts/ from the host repo, the snapshot, or inside the sandbox, and every one is a valid BASH_SOURCE[0] result depending on context. Session 2's descriptive STE100 rename must disambiguate which scripts tree, not just rename the mechanism. Feeds the M2.6 rename session.

### [A] 2026-08-10 — Throwaway verification harness created a stray file in the repo tree

state: open
scoped: none
legacy: none
mitigation: during Finding-B verification, a `cp ... 2>/dev/null || true` wrote `tests/tests_common_verify.sh` (not a real test) into the repo. Caught via `git status` and removed. Run throwaway verification scripts in /tmp, never in the repo tree; the git-tracked tree surfaces strays in `git status`.

### [A] 2026-08-10 — edit tool rejected a call for a missing required `path` argument

state: open
scoped: none
legacy: none
mitigation: the first `edit` call on `common.sh` omitted the required `path` field and was rejected by tool validation. Self-corrected on the retry. Always pass `path` explicitly on edit calls.
---
[CORRECTION -- 2026-08-10]: CLI interaction standards document renamed from `cli-standards.md` to `cli-conventions.md` (ste-framing: conventions, not standards). All in-body `cli-standards` references in this record updated to the new filename to keep the historical link resolvable. The rename and new framing are recorded in handover `20260810-09`.

## Agent experience — session 20260810-12

### [A] 2026-08-10 — `git restore` during negative-test verification wiped uncommitted session work

state: open
scoped: none
legacy: none
mitigation: negative-test mutation was reverted with `git restore scripts/stop.sh`, which
reverts to HEAD — destroying the session's uncommitted array refactor in that file (the
mutation check itself passed: the test failed as expected; only the revert was wrong).
Revert scratch mutations from a temp copy (`cp file /tmp/file.bak` before mutating,
`cp /tmp/file.bak file` after), never from git, while the session has uncommitted changes
in that file. The `git restore`/`git checkout` revert is only safe on committed-clean files.

### [A] 2026-08-10 — Subagent review remedies need empirical verification, not blind acceptance

state: open
scoped: none
legacy: none
mitigation: the thermo-nuclear subagent correctly flagged that
`mapfile -t X < <(cmd)` swallows the command's exit status under
`set -euo pipefail`, but its proposed remedy (`cmd | mapfile`) was worse than
the bug: `mapfile` in a pipeline runs in a subshell (lastpipe is off by
default in non-interactive shells), so the array is silently empty in the
parent. Only a minimal repro (`printf 'a\nb\n' | mapfile -t X; echo
"${#X[@]}"` → 0, vs process substitution → 2) exposed it. Treat reviewer
findings as hypotheses and their remedies as proposals: verify both with a
repro before applying.

### [A] 2026-08-10 — Negative-test mutations: verify syntax and intended-failure reason before trusting the result

state: open
scoped: none
legacy: none
mitigation: the first awk-based mutation for the P1 negative check produced a
syntactically invalid stop.sh; the test "passed" vacuously (rc=2 from a
syntax error, not from the bug being tested). Only a `bash -n` after mutating
caught it. After any negative-test mutation, check (a) the mutated file is
still valid (`bash -n`), and (b) the test fails for the intended reason, not
a side effect. A vacuous pass is more dangerous than a detected failure —
it looks green while testing nothing. Same family as the "did the write
land?" reflex but distinct: that catches un-applied edits, this catches
mis-applied ones.

### [A] 2026-08-10 — `python3` is absent from the container

state: open
scoped: none
legacy: none
mitigation: `command -v python3` returns nothing in this sandbox; a text
mutation that reached for python3 failed with "command not found" and fell
back to sed/awk. Use bash-native tools (sed, awk, perl if present) for
text-mutation tasks in this container; do not reach for python3 without
checking first.

### [A] 2026-08-10 — `git checkout` normalized stub mode AND reverted uncommitted test edits (stash/checkout cycle)

state: open
scoped: none
legacy: session 20260810-12 entry (git restore wipes uncommitted work)
mitigation: the repo has `core.filemode=false`, so `test/stubs/docker`'s
executable bit is invisible to git (index 100644, working tree 755 via the
snapshot pipeline). A `git stash` (for a HEAD-vs-current shellcheck
comparison) + `git checkout tests/test_trace_start.sh` (to remove a debug
patch) did two things: (a) normalized the stub's working-tree mode to the
index mode — 16 tests failed with "Permission denied" — and (b) reverted the
test file's uncommitted session edits. The session-12 lesson (never `git
restore` while uncommitted work exists) is broader than one command: ANY git
operation that touches the index/working tree (stash, checkout, restore,
switch) can revert uncommitted edits and normalize untracked-in-git modes.
For negative-test mutation reverts and debug-patch removal, use temp copies
(`cp file /tmp/x.bak`) only. To fix a lost executable bit under
`core.filemode=false`: `chmod +x file` + `git update-index --chmod=+x`.

### [A] 2026-08-18 — Multi-question turns and implicit acceptance during a grill-me design walk

state: open
scoped: grill-me walks (design sessions)
legacy: none
mitigation: during the M2.6.6 design walk the agent posed two questions in one
turn (A+B, then D8+N1), skipped N2a to the next question without an explicit
approval, and treated operator probes as implicit approval of a pending
question — the operator corrected the pattern twice. One question per turn;
when a side-question arises, queue it explicitly in the live pile and return to
it after the main question is settled. An operator's probing question is not
an approval of the pending question; re-pose the pending question for explicit
approval, naming what the probes settled and what remains open.

### [A] 2026-08-18 — Asserted "recorded" for a decision before the row landed

state: open
scoped: handover write-back
legacy: none
mitigation: the agent announced "N2a recorded" in chat but the row was never
written (table-append slip, see GOTCHAS 2026-08-18 family); the omission was
discovered only at the table-integrity check before the close pass. When
announcing a write-back, verify the row exists (row-key grep) in the same
turn; an un-landed assertion is invisible to the next agent until the close
pass. Distinct from the GOTCHAS append-anchor entry: that catches
overwrite-instead-of-append, this catches assert-without-write.

## Agent experience — session 20260818-03

### [A] 2026-08-18 — Repo-presence assertions are trivial restatements; guard the injection point in production instead

state: open
scoped: none
legacy: none
mitigation: the agent added bare file-existence assertions to
`test_run_agent.sh` (compose template + overlay existence at hardcoded repo
paths). Operator corrected: presence of a committed repo file is trivially
true — the meaningful guard is each injection point checking the file it
needs and raising a descriptive error, which production already does
(all 5 required compose files are existence-guarded in `run_agent.sh`;
`compose_generate` re-checks each input). Behavioral coverage comes from
trace tests asserting the file set flows (which fail if a file is absent)
and static content checks. Presence assertions removed; production guards
verified. When adding tests for file wiring, check the production guard
first and test the behavior (selection/injection/error), not file existence.

## Agent experience — session 20260821-03

### [A] 2026-08-21 — Installed CLI staleness is hard to detect: new subcommand surfaces as `Unknown subcommand`

state: open
scoped: none
legacy: none
mitigation: adding a new subcommand (or flag) to `scripts/agent-sandbox.sh` does
not reach the installed CLI until `make install` re-installs it (the dispatcher is
copied verbatim, sed-substituting `@@AGENT_SANDBOX_REPO@@`). The operator symptom
is a bare `Unknown subcommand: resume` with no hint that `make install` is needed —
looks like the feature is un-hooked. Detection gap: the stale installed CLI still
lists `package-branch` but omits newer entries (e.g. `resume`), and the source
dispatcher matches. In this session the sandbox Makefile had refreshed (template
`resume:` present, L221) while the installed CLI was stale — the two staleness axes
(Makefile vs CLI) diverge. Lesson: when a subcommand/flag seems missing, diff the
installed CLI's `Valid subcommands` against `scripts/agent-sandbox.sh` before
assuming the implementation is wrong; a stale install is the first suspect.
