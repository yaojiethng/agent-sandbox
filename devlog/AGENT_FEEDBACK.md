# Agent Feedback

A persistent record of the coding agent"s experience: friction points, poor stack design, poor operator prompting, and "this needs reinforcing" notes. Recorded by the agent. Reviewed and addressed by the operator.

**Writer:** agent.
**Reviewer:** operator.

Entries are point-in-time records. Reconcile an entry against the current tree before acting on it. If the tree has outgrown an entry, mark it probation; if the entry is superseded  --  its lesson already carried by another entry or record  --  it jumps to probation as well. Either way, follow the normal procedure: wait to see whether it resurfaces; drop it if it does not.

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble  --  length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown
## [<A|G>] <date>  --  <short title>

state: open                        // open | probation | mitigated
                                   // probation = durable fix applied, or the tree has
                                   // outgrown the entry; kept for monitoring, dropped on no resurfacing
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```

An entry is dropped when monitoring confirms the fix durable  --  a probation entry is kept for monitoring and dropped when it does not resurface. A durable fix is also recorded in the changelog and the roadmap. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Bash

Canonical bash coding rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md).

Bash friction entries migrated from `devlog/discussions/20260809-story-active-bash_complaints.md` (deleted).

### [A] 2026-09-20  --  `run_test`'s `$1 || true` suppresses `set -e` inside the test, so an `set -e` guard cannot be observed

state: closed
scoped: M2.6 close
legacy: none
mitigation: 2026-09-20 -- the rule landed in `testing_policy.md` (run_test docs) in handover `20260920-03`, and the inert autosave-loop test was reworked to the fresh-`bash`-probe pattern: `tests/test_routing.sh::test_autosave_loop_survives_failing_ticks` now runs the shipped loop under a real `set -euo pipefail` shell in a separate process and asserts a marker file. Verified: removing the `|| true` guard from `autosave_loop` turns that test red (mutation test, then restored).

`tests/libs/test_common.sh`'s `run_test` invokes each test as `$1 || true`. Bash disables `set -e` for a command in a `||` list, and that suppression covers the whole function body: nested function calls and even a subshell the body starts with its own `set -euo pipefail` do not abort on a failing command. A test written to prove "this loop survives a failing step under `set -e`" therefore passes whether or not the production code guards the failure, because the guard is never exercised. This produced an inert regression test for the autosave loop's status absorption: removing the `|| true` from the shipped `autosave_loop` left the suite green. Measured directly: the mutated loop makes one attempt and dies in a plain `set -e` shell, and 86 attempts under `run_test`.

Scope: bash `set -e` semantics interacting with the test harness. Cross-reference: `docs/development/testing-conventions.md` documents the harness structure but not this suppression; the rule above belongs there when it is next touched.

## Edit tool

Collation entry for pitfalls of the `edit` tool (exact-match text replacement). Goal: once sufficient entries accumulate, distill them into AGENTS.md steering guidelines for edit-tool usage (drafted by the agent, proposed to the operator per the governance one-section rule). Append new pitfalls as sub-bullets; keep each one line.

### [G] 2026-09-12  --  Edit-tool pitfalls (collation, seeded)

state: open
scoped: M3 -- `perf` workstream (`devlog/roadmap_future.md`, "Perf -- Subagent and Tool Observability")
legacy: none
mitigation: collation pending -- this entry exists to accumulate instances; the distillation into steering guidelines is the durable fix. Postponed 2026-09-19: the proper resolution now rides on the M3 `perf` workstream, which instruments the `edit` tool (failed-call counts classified by cause, plus the retry cost) so the distillation is grounded in measurements rather than impressions. Do not close this entry before that task lands.

Seed instances (all observed 2026-09-12):

- Multi-edit atomicity: one failed `edits[]` entry rolls back the ENTIRE call -- sibling edits that matched fine are silently lost. Detected only by a later grep (the mandatory-structure paragraph for the Test Structure Template was lost this way and re-applied at the next edit).
- `oldText` matching is exact: invisible whitespace or trailing characters break the match with a raw "could not find" error; fall back to `sed -n Np` inspection or `bash` insertion when the anchor is a single line.
- Overlapping or nested `edits[]` entries are rejected; nearby changes must be merged into a single edit.
- `oldText` must be unique in the file; a too-short anchor that appears more than once fails.

### [A] 2026-08-09  --  Empty string bypasses `${VAR:-default}`

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

### [A] 2026-08-09  --  `git rev-parse --verify 0000...` succeeds

state: open
scoped: none
legacy: none
mitigation: defensive coding only. Validate against a known commit set when dummy SHAs from test fixtures are a risk.

Git treats the all-zero SHA as a valid reference to the empty tree object. `rev-parse --verify` returns 0. No warning, no error.

Scope: upstream git behavior  --  not fixable in this project. Cross-reference: not applicable for trapping (upstream behavior).

### [A] 2026-08-09  --  `local FOO=$(cmd)` swallows exit codes under `set -e`

state: open
scoped: none
legacy: none
mitigation: split the assignment:

```bash
local FOO; FOO=$(failing_cmd)
```

`local` is a builtin that always returns 0. Under `set -e`, the exit code of command substitution in the value is silently absorbed.

Scope: shellcheck warns on this (`SC2155`). Cross-reference: Trap 15 covers the top-level `local` scope only. The function-scope exit-code-swallowing pattern is distinct and unaddressed.

### [A] 2026-08-09  --  Expected-failure commands under `set -e` need `|| true` (grep -c, ls, diff --quiet)

state: open
scoped: none
legacy: none
mitigation: `command || true`; for grep counting use:

```bash
local COUNT
COUNT=$(grep -c "pattern" file 2>/dev/null) || true
```

Any command expected to sometimes fail (`ls missing*`, `grep -c` on absent patterns, `diff --quiet` on dirty trees) must be suffixed with `|| true`. The pattern is pervasive but easy to forget on new checks. `grep -c` is the sharpest instance: it returns exit 1 on zero matches, which is often the expected result, so under `set -e` it aborts the script exactly when the check is working. Could adopt a `_count_matches()` wrapper pairing both patterns.

Scope: language design limitation. The subshell-scoped `|| true` pattern (from session `20260805-01`) is the best available mitigation. Cross-reference: Trap 16 covers pipeline-level swallowing only; individual-command patterns are not addressed.

### [A] 2026-09-19  --  A sourced-lib `while read < file` aborts a `set -e` caller on a missing file

state: open
scoped: `src/libs/*.sh` (sourced libraries), callers under `set -euo pipefail` (entrypoints)
legacy: none
mitigation: a read of a nonexistent file inside a sourced lib function -- `while IFS='=' read ...; done < "$file"` -- makes the *function call site* fail under `set -e`. The caller that wrote `x="$(record_contract_version "$file")"` in a `set -euo pipefail` entrypoint dies silently mid-shell when `$file` is absent; a surrounding `|| ...` does not rescue it because the abort happens inside the command substitution, not at the call. Guard the file before the read (`[[ -f "$file" ]] || return 0` in the caller) or make the lib function itself tolerate absence. General rule: a sourced-lib read of a path the caller cannot guarantee is a `set -e` hazard, distinct from the exit-vs-return gotcha (GOTCHAS H 2026-08-12) -- this is a redirection abort, not a status-choice issue. Cross-reference: the `set -e` trap entries above. The instance that produced this entry is gone: `record_contract_version` was deleted in handover `20260919-19`, and its replacement reads through `session_state_read`, which carries the file guard. The general rule stands.

### [A] 2026-08-09  --  No test fixture lifecycle  --  manual `rm -rf` everywhere

state: probation
scoped: none
legacy: none
mitigation: use `$FIXTURE_DIR` subdirectories instead of `mktemp -d`. For supplemental dirs, add `trap "rm -rf "$_tmpdir"" RETURN`.

Bash test files have no `setup`/`teardown` framework. Every test manually creates temp dirs with `mktemp -d` and cleans up with `rm -rf`. Tests that fail midway leak temp directories.

Scope: could standardize a `test_teardown` helper. Not urgent  --  leaked temp dirs in CI are ephemeral. Cross-reference: no skill trap covers this.

reconciled: 2026-09-01  --  the framework this entry asks for now exists: `test_setup` in `tests/libs/test_common.sh` provides `$FIXTURE_DIR` (`mktemp -d`) with an automatic `rm -rf` cleanup trap, and suites use it. Marked probation per the reconcile-before-acting rule (tree has outgrown the entry); drop if it does not resurface.

### [A] 2026-08-09  --  Undefined-variable errors under `set -u` are opaque

state: open
scoped: none
legacy: none
mitigation: always declare `local` before use. Shellcheck catches this (`SC2154`).

`set -u` causes any reference to an undefined variable to abort with only the variable name  --  no line number, no context.

Scope: bash limitation. `set -u` has no built-in context reporting. Cross-reference: not applicable for trapping (bash limitation).

### [A] 2026-08-09  --  Circular sourcing between `diff_export.sh` and `package_branch.sh`

state: open
scoped: none
legacy: none
mitigation: extracted `_write_export_status` to a shared `export_status.sh` lib sourced by both. Shared functions live in leaf libraries, never in orchestrators.

`diff_export.sh` sources `package_branch.sh`. When `package_branch.sh` needed `_write_export_status`, it could not source `diff_export.sh` back without a cycle. The discovery was trial-and-error; no static analysis tool caught the cycle.

Scope: architecture decision recorded in ADR (not yet written). Cross-reference: no skill trap covers this; should be added as an architecture trap.

### [A] 2026-09-19  --  A prose comment starting with the word `shellcheck` becomes a Directive

state: open
scoped: none
legacy: none
mitigation: word the line so `shellcheck` is not the first token after `#` (for example "the shellcheck tool absent").

ShellCheck parses any comment line whose first token after `#` is `shellcheck` as a directive. A prose comment that begins with the word -- for example a test-file header line reading `#   shellcheck absent  --  rc 1` -- makes the tool emit `SC1073`/`SC1072` parse errors against the file, so the ShellCheck gate fails on the repository's own scripts. The trap fires twice in one file in this iteration because the natural way to start a line about the tool is the tool's name. The failure is loud and the fix is trivial, but it looks like a false positive until the directive rule is known.

Scope: ShellCheck directive parsing. Cross-reference: `docs/development/bash-coding-conventions.md` states the suppression policy (targeted `# shellcheck disable=` with a rationale) but does not warn that a bare leading `shellcheck` word is parsed at all.

---

Skill-trap coverage gaps (bash entries marked "no trap" or partially covered): consolidation into the bash-scripting-traps skill is deferred to a future skill-maintenance session; per-entry coverage is noted in each entry's Cross-reference line.

---

## Agent experience  --  session 20260809-04

### [A] 2026-08-09  --  Directive/policy granularity mismatch for governance changes causes run-ahead

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-02`): `new-session.md` no longer reads as blanket authorization  --  the "implementation does not begin until both gates are confirmed" line was deleted (redundant with the procedural stops), the gate sections state what they confirm in declarative headers, and the gates" permission language now matches the canonical model (gates are released; content  --  scope, acceptance criteria  --  is confirmed). Per operator decision, the per-section policy gate is NOT restated in the directive: AGENTS.md owns it and is always loaded. Monitor for resurfacing of run-ahead on policy changes. When confirmed durable, delete and record in changelog/roadmap.

### [A] 2026-08-09  --  Findings recording discipline (churn and under-recording)

state: open
scoped: none
legacy: none
mitigation: two failure modes from the same session. Over-recording: recording every
observation as a permanent distinct finding row invites duplicates and table corruption
(finding text leaked into the AC table; overwritten CORRECTION blocks)  --  frame
Findings rows as candidate records consolidated at the review/publish step; edit
task notes in place rather than appending duplicate steering records. Under-recording:
session 08 produced friction (dash-sweep tooling, un-applied rule, gate-velocity) but
recorded none of it; the gap surfaced via operator review, not self-capture. The
AGENTS.md pointer states what to record but not the reflex to stop and write findings
when a session turns edit-heavy.

### [A] 2026-08-09  --  Hard-wrapped instruction blocks and inconsistent prose wrapping

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-01`): `documentation_policy.md` gained `### Line wrapping` (single-flowing prose; hard breaks on sentence/paragraph boundaries; ~80 cols for code comments) + audit-check entry. Wrap remediation applied across the frequently-read set (AGENTS.md x2, skills, policy files, cli-conventions, adr_policy, handover_policy). Monitor for resurfacing; the M3 doc-bloat/audit sweeps the non-frequently-read remainder. When confirmed durable, delete and record in changelog/roadmap.
resurfaced: session `20260901-03`  --  first confirmed resurfacing, so probation is lifted back to open. Two policy documents were manually column-wrapped at ~80 characters, misreading "single-flowing paragraphs" as a license to wrap at sentence boundaries; the rule is positive (one paragraph per line, no column breaks). Lesson added: when composing or editing, match the recipient file's own line form. Operator-side record: GOTCHAS `2026-09-01` (editing a doc whose own policy text forbids the pattern).
reworked: 2026-09-01  --  the `### Line wrapping` wording was rewritten to state the rule positively (never manually word wrap prose; no line break mid-paragraph, not at sentence boundaries, not at a column limit), removing the sentence-boundary license that caused the resurfacing; the pi-layer AGENTS.md Write Discipline section carries the same rule in brief; the governed doc set was swept and unwrapped (content-identical, line structure only). Second fix applied  --  escalated to probation; drop if it does not resurface. Sweep tooling promoted at rework time: `scripts/manual/unwrap_prose.sh` (--check detector mode; unwrap with built-in structure-preserving verification, restores on failure) is the current sweep solution -- run it over the governed set if this resurfaces while on probation.

### [A] 2026-08-09  --  Non-ASCII punctuation under a plain-ASCII doc policy

state: open
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-01`): `documentation_policy.md` `### Character set` generalized to cover non-ASCII + control/formatting symbols + audit-check entry. Functional `` scrubbed from frequently-read live docs; only deliberate literals remain (documentation_policy rule, AGENT_FEEDBACK finding record). Closed handovers retain `` (read-only, out of scope). Monitor for resurfacing (new ``/non-ASCII in live docs). When confirmed durable, delete and record in changelog/roadmap.
resurfaced: session `20260821-02`  --  introduced `Q7`/`N2`/`Numbering` in the start/resume design handover"s cross-references. Cause: imitating`` from a closed-handover reference without checking the target doc or the policy. Not durable yet  --  keep monitoring; scrub on sight in live docs.
resurfaced: session `20260901-12`  --  four section-sign references (``) written into an active handover while citing the roadmap-update timing rule. Cause: imported referencing habit from outside the repo, not from any repo document (the policy itself names`` as banned). Scrubbed on sight. Probation lifted back to open; not durable yet.

### [A] 2026-08-09  --  Tracked-backlog proliferation at close

state: open
scoped: none
legacy: none
mitigation: close touches many canonical surfaces (two persistent files, roadmap tasks, decisions, deferred items). Watch-outs: keep AGENT_FEEDBACK/GOTCHAS short (no-index, length -> durable fix), and rely on the roadmap as the sole task list to avoid scattering.

### [A] 2026-08-09 - A regex edit with a missing file operand silently does nothing

state: open
scoped: none
legacy: none
mitigation: when a sed -i pipeline omits the file operand while still parsing validly, it exits 0 and writes nothing; set -e does not catch it. Verify the file changed after a mechanical edit sweep. Cross-reference: bash-scripting-traps skill.

### [A] 2026-08-09  --  A "did the write land?" reflex is missing for rule edits

state: open
scoped: none
legacy: none
mitigation: session 08 proposed, refined, then swept an em-dash rule, but the rule text itself was never applied; the un-applied edit surfaced only at AC-verification grep. When an edit is intended to change a rule, grep the canonical line after writing to confirm the intended text landed.
additional-resurfacing: session `20260821-02`  --  multi-edit rewrites of a single handover Decisions block repeatedly clobbered unrelated decision entries (D2, D5, D8 individually dropped across successive `edit` calls) because successive edits to the same block were matched against the pre-edit original and overlapped. Lesson: when editing a numbered block repeatedly, prefer one rewrite of the whole block (or verify decision integrity with a grep of all headers after each batch), not piecewise edits that can drop siblings.
additional-resurfacing: session `20260818`  --  asserted "N2a recorded" in chat but the row was never written (table-append slip); the omission was discovered only at the table-integrity check before the close pass. When announcing a write-back, verify the row exists (row-key grep) in the same turn; an un-landed assertion is invisible to the next agent until the close pass.

Cross-reference: the operator-side family record is GOTCHAS `2026-08-18` (table-row append edits must keep the anchor row)  --  same family, distinct failure mode (overwrite-instead-of-append).

## Agent experience  --  session 20260810-07

### [A] 2026-08-10  --  `SCRIPT_DIR` ambiguous about which scripts copy is meant (host/snapshot/sandbox)

state: open
scoped: M2.6 (general CLI refactor track)
legacy: none
mitigation: the initial Finding B under-diagnosed the ambiguity as a derivation-mechanism issue (self vs injected BASH_SOURCE index). The operator sharpened it: the name does not say WHICH scripts directory is meant  --  the harness can resolve scripts/ from the host repo, the snapshot, or inside the sandbox, and every one is a valid BASH_SOURCE[0] result depending on context. Session 2"s descriptive STE100 rename must disambiguate which scripts tree, not just rename the mechanism. Feeds the M2.6 rename session.

### [A] 2026-08-10  --  Throwaway verification harness created a stray file in the repo tree

state: open
scoped: none
legacy: none
mitigation: during Finding-B verification, a `cp ... 2>/dev/null || true` wrote `tests/tests_common_verify.sh` (not a real test) into the repo. Caught via `git status` and removed. Run throwaway verification scripts in /tmp, never in the repo tree; the git-tracked tree surfaces strays in `git status`.

### [A] 2026-08-10  --  edit tool rejected a call for a missing required `path` argument

state: open
scoped: none
legacy: none
mitigation: the first `edit` call on `common.sh` omitted the required `path` field and was rejected by tool validation. Self-corrected on the retry. Always pass `path` explicitly on edit calls

---

[CORRECTION -- 2026-08-10]: CLI interaction standards document renamed from `cli-standards.md` to `cli-conventions.md` (ste-framing: conventions, not standards). All in-body `cli-standards` references in this record updated to the new filename to keep the historical link resolvable. The rename and new framing are recorded in handover `20260810-09`.

## Agent experience  --  session 20260810-12

### [A] 2026-08-10  --  git operations touching the index/worktree revert uncommitted session work

state: open
scoped: none
legacy: none
mitigation: negative-test mutation was reverted with `git restore scripts/stop.sh`, which
reverts to HEAD  --  destroying the session"s uncommitted array refactor in that file (the
mutation check itself passed: the test failed as expected; only the revert was wrong).
The generalized form surfaced the same session: a `git stash` + `git checkout
tests/test_trace_start.sh` (a) normalized the stub"s working-tree exec mode to the index
mode  --  16 tests failed with "Permission denied"  --  and (b) reverted the test file"s
uncommitted session edits. Root cause of the mode churn was a host/container
`core.fileMode` mismatch (host `false` vs container `true`), not a repo defect; resolved
on the host by bringing `core.fileMode` to parity and normalising host tree exec bits.
Lesson: ANY git operation that touches the index/working tree (stash, checkout, restore,
switch) can revert uncommitted edits and normalize untracked-in-git modes. For
negative-test mutation reverts and debug-patch removal, use temp copies (`cp file
/tmp/x.bak` before mutating, `cp /tmp/x.bak file` after), never git, while the session
has uncommitted changes in that file. To re-assert a lost executable bit regardless of
`core.fileMode`: `chmod +x file` + `git update-index --chmod=+x`.

---
[Post-edit annotation -- 2026-09-01]: corrected misdiagnosis. The container mode
churn was due to a host-side `core.fileMode` mismatch (host `false` vs
container `true`), not a repo defect. Exec-bit issue resolved on the host by
bringing `core.fileMode` to parity (`true`) and normalising host tree exec
bits.

### [A] 2026-08-10  --  Subagent review remedies need empirical verification, not blind acceptance

state: open
scoped: none
legacy: none
mitigation: the thermo-nuclear subagent correctly flagged that
`mapfile -t X < <(cmd)` swallows the command"s exit status under
`set -euo pipefail`, but its proposed remedy (`cmd | mapfile`) was worse than
the bug: `mapfile` in a pipeline runs in a subshell (lastpipe is off by
default in non-interactive shells), so the array is silently empty in the
parent. Only a minimal repro (`printf "a\nb\n" | mapfile -t X; echo
"${#X[@]}"` -> 0, vs process substitution -> 2) exposed it. Treat reviewer
findings as hypotheses and their remedies as proposals: verify both with a
repro before applying.

### [A] 2026-08-10  --  Negative-test mutations: verify syntax and intended-failure reason before trusting the result

state: open
scoped: none
legacy: none
mitigation: the first awk-based mutation for the P1 negative check produced a
syntactically invalid stop.sh; the test "passed" vacuously (rc=2 from a
syntax error, not from the bug being tested). Only a `bash -n` after mutating
caught it. After any negative-test mutation, check (a) the mutated file is
still valid (`bash -n`), and (b) the test fails for the intended reason, not
a side effect. A vacuous pass is more dangerous than a detected failure  --
it looks green while testing nothing. Same family as the "did the write
land?" reflex but distinct: that catches un-applied edits, this catches
mis-applied ones.

### [A] 2026-08-10  --  `python3` is absent from the container

state: open
scoped: none
legacy: none
mitigation: `command -v python3` returns nothing in this sandbox; a text
mutation that reached for python3 failed with "command not found" and fell
back to sed/awk. Use bash-native tools (sed, awk, perl if present) for
text-mutation tasks in this container; do not reach for python3 without
checking first.

### [A] 2026-08-18  --  Multi-question turns and implicit acceptance during a grill-me design walk

state: open
scoped: grill-me walks (design sessions)
legacy: none
mitigation: during the M2.6.6 design walk the agent posed two questions in one
turn (A+B, then D8+N1), skipped N2a to the next question without an explicit
approval, and treated operator probes as implicit approval of a pending
question  --  the operator corrected the pattern twice. One question per turn;
when a side-question arises, queue it explicitly in the live pile and return to
it after the main question is settled. An operator"s probing question is not
an approval of the pending question; re-pose the pending question for explicit
approval, naming what the probes settled and what remains open.

### [A] 2026-08-18  --  Asserted "recorded" for a decision before the row landed

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

## Agent experience  --  session 20260818-03

### [A] 2026-08-18  --  Repo-presence assertions are trivial restatements; guard the injection point in production instead

state: closed
closed: 2026-09-12 -- the test-quality campaign (handover 20260912-05,
folded in commit 561dba7) found one surviving instance of this pattern
(the file-existence loop over provider files in test_run_agent.sh) and
rewrote the suite behaviourally; the entry's own mitigation (production
injection-point guards + trace tests over the file set) is the standing
rule

What happened: the agent added bare file-existence assertions to
`test_run_agent.sh` (compose template + overlay existence at hardcoded repo
paths). Operator corrected: presence of a committed repo file is trivially
true  --  the meaningful guard is each injection point checking the file it
needs and raising a descriptive error, which production already does
(all 5 required compose files are existence-guarded in `run_agent.sh`;
`compose_generate` re-checks each input). Behavioral coverage comes from
trace tests asserting the file set flows (which fail if a file is absent)
and static content checks. Presence assertions removed; production guards
verified. When adding tests for file wiring, check the production guard
first and test the behavior (selection/injection/error), not file existence.

## Agent experience  --  session 20260821-03

### [A] 2026-08-21  --  Installed CLI staleness is hard to detect: new subcommand surfaces as `Unknown subcommand`

state: open
scoped: none
legacy: none
mitigation: adding a new subcommand (or flag) to `scripts/agent-sandbox.sh` does
not reach the installed CLI until `make install` re-installs it (the dispatcher is
copied verbatim, sed-substituting `@@AGENT_SANDBOX_REPO@@`). The operator symptom
is a bare `Unknown subcommand: resume` with no hint that `make install` is needed  --
looks like the feature is un-hooked. Detection gap: the stale installed CLI still
lists `package-branch` but omits newer entries (e.g. `resume`), and the source
dispatcher matches. In this session the sandbox Makefile had refreshed (template
`resume:` present, L221) while the installed CLI was stale  --  the two staleness axes
(Makefile vs CLI) diverge. Lesson: when a subcommand/flag seems missing, diff the
installed CLI"s `Valid subcommands` against `scripts/agent-sandbox.sh` before
assuming the implementation is wrong; a stale install is the first suspect.

## Agent experience  --  session 20260821-14 (test-quality campaign)

### [A] 2026-08-21  --  Exec-style scripts without dual-use guards block unit seams

state: probation
scoped: none
legacy: none
mitigation: bounded sed-extraction of the function body into a subshell
(historical probes: `_env_field_probe`, `_template_version_probe`,
`_wsl_path_probe` -- all three deleted with the conventions compliance
sweep `20260823-08`; the last seam, `template_version_probe_real`
in `tests/test_onboard.sh`, was deleted `20260911-04` (handover
`20260911-04`); no extraction seams remain).

`scripts/prune.sh`, `scripts/onboard.sh` and the flag-parsing section of
`scripts/start_agent.sh` execute unconditionally when sourced  --  no
`BASH_SOURCE[0] == "$0"` guard, although `bash-coding-conventions.md` rule 1.11
and rule 3.3 mandate exactly that for dual-use scripts. Consequence: every
function inside them is unit-testable only by textually extracting its body,
which breaks silently if the function is renamed or reformatted (the probes
fail loudly by design, but the seam itself is fragile). Guards on those three
entry points would let tests source and call directly, deleting the
extraction layer entirely.

reconciled: 2026-09-01  --  all three named scripts now carry the guard
(`scripts/start_agent.sh` wraps `main "$@"` -- flag parsing lives inside
`main()` -- likewise `prune.sh` and `onboard.sh`), satisfying rules 1.11/3.3.
Marked probation per the reconcile-before-acting rule (tree has outgrown the
entry); drop if it does not resurface. Follow-up completed: the remaining sed-extraction seam
(`template_version_probe_real`, `tests/test_onboard.sh`) was deleted with handover `20260911-04`,
closing the roadmap item "Delete the remaining sed-extraction probe".

### [A] 2026-08-21  --  Knowledge/diagnostic tests outside `make test` rot silently

state: mitigated
scoped: none
legacy: none
mitigation: `make test-smoke` / `scripts/check_test_smoke.sh` (20260823-07)
syntax-checks every excluded script non-gatingly; the 20260823-06 audit
also removed the three scripts that had already rotted.

`tests/knowledge/`, `tests/integration/` and `tests/eval/` are excluded from
the runner glob by documented policy (testing_policy.md), which is correct for
non-deterministic seams  --  but nothing ever executes or even lint-checks them,
so they rot unnoticed. Precedent: `tests/test_dirs.sh`"s header records that
its coverage previously lived in "a broken manual knowledge test that sourced
a nonexistent libs/dirs.sh path"  --  rotted until noticed by accident. Cheapest
fix: a non-gating `make test-knowledge-smoke` running each script under
`bash -n` (syntax only) plus shellcheck, catching structural rot without
asserting on their nondeterministic behavior.

### [A] 2026-09-02  --  Non-conforming test prefix introduced (`discovery_` vs `knowledge_`)

state: mitigated
scoped: M2.6
legacy: none
mitigation: 2026-09-04 -- both `discovery_tar_*` probes were deleted with the legacy seed pipeline they probed (handover `20260904-06`), resolving the prefix defect by removal. The entry's deeper failure mode -- a `run_test` registration lost to rename-without-grep, silent because unregistered tests never run -- is now caught mechanically by `scripts/check_test_liveness.sh` (`make test-liveness`), which verified both directions on its first run.

The tar feasibility probes landed in `tests/knowledge/` as `discovery_tar_*.sh`, a prefix the testing policy does not list. Their content (external-tool behaviour) is the knowledge category, so the defect is the name, not the placement. Cleanup: rename to `knowledge_tar_*.sh`. Cross-reference: the same change introduced the rename-without-grep pattern -- a `run_test` registration was renamed by `sed` and briefly went missing before the suite caught it.

### [A] 2026-09-02  --  Campaign prompt scope contradicted its own success criteria

state: open
scoped: none
legacy: none
mitigation: none

The test-quality-campaign prompt said "tests only - never change production source", but success criterion #3 (the prerequisite gate) can only be met by changing scripts/run_tests.sh, which is not a tests/ file. At run time the subagent touched the runner to satisfy the criterion and reported "no production source was touched" - inaccurate. The ambiguity: "tests only" was read as the tests/ directory, while the testing_policy prerequisite rule mandates a runner behaviour that lives outside it. Fix: name the test runner as in-scope in the campaign prompt, or make criterion #3 flag-only.

Same session, same prompt: the deliverable contract was iterated three times in chat (commit, then branch-and-merge, then uncommitted proposal) because the first draft pinned "commit one delivery commit" while the operator's model was "subagent proposes, main agent commits at iteration close". Pin the deliverable ("leave uncommitted, never commit") before writing a subagent prompt.

## Agent experience  --  session 20260904-01 (seed transport redesign)

### [A] 2026-09-04  --  Filtered diff summary produced a wrong "trees identical" conclusion

state: open
scoped: none
legacy: none
mitigation: none

Comparing the sandbox tree against the seed-worktree snapshot, `diff -rq ... | grep -c "^Files differ"` returned 0 and was reported to the operator as "0 differing files". The grep pattern was wrong (diff prints `Files X and Y differ`, not `Files differ`), and diff had also exited early on `.git`. The operator's "the baseline is the same files" claim was accepted on this faulty evidence; ~45 files actually differed. Rule: a filtered summary that gates a conclusion must be validated against unfiltered output (run `diff -rq` bare, count real lines, check the exit path) before the conclusion is stated. Same class: `grep -c` returning 0 on a pattern typo is indistinguishable from a true negative.

### [A] 2026-09-04  --  `git rev-parse --git-path` returns repo-root-relative paths

state: open
scoped: none
legacy: none
mitigation: none

`git -C "$REPO" rev-parse --git-path info/exclude` returns `.git/info/exclude` -- relative to the repo root, not the caller's cwd. Using the output directly in a `mkdir -p`/append sequence wrote into the caller's cwd (here: the harness repo itself, during a test run). Any `--git-path`/`--show-cdprefix` output must be absolutized (`[[ $p == /* ]] || p="$REPO/$p"`) before filesystem use. Caught by the new tests before it shipped; the reverted sentinel-guard commit carried the buggy version, so the lesson must outlive the commit.

### [A] 2026-09-04  --  Record-layer documents drafted as reasoning traces needed a full rewrite

state: open
scoped: none
legacy: none
mitigation: none

First drafts of the seed-transport ADR and concept doc mirrored the session's reasoning: narrative history, transient identifiers (session ids, commit hashes, handover names), implementation command dumps, and rationale-as-argument instead of rationale-as-mapping. The operator steer (records state, not session history; problem / solution / rejected-with-failure-locus / follow-up; requirements as behavioral contracts in concept docs; interface-level descriptions, commands only for external interactions) required full rewrites of both. Mitigation for next time: before writing a record-layer document, propose its skeleton (section list + what each section holds) in chat and get the structure confirmed; write prose only against the confirmed skeleton. Findings F8-F14 in handover 20260904-01-design-start_resume_rsync_stall.md carry the policy-amendment candidates.

## Agent experience  --  session 20260918-10 (thermo-nuclear review pass)

### [A] 2026-09-18  --  Review-loop round-cap guidance fits correctness reviews, not model-consensus passes

state: open
scoped: none
legacy: none
mitigation: none

The autonomous review-pass template frames the loop as rounds-with-round-cap ("~6 rounds") that converged by fixing mechanism bugs across 5 rounds in the correctness pass. The thermo-nuclear pass with two independent models behaved differently: both BLOCKed on the same blocker class in one round, each with a fully-specified remedy, so the loop converged immediately with no WIP rounds. Treat the round-cap and the "blocker -> fix -> re-review round" dance as the correctness-review shape; for a model-consensus code-quality pass, one round per model against a shared brief, then consolidate, is the norm. Improve the framing in review-pass-run.md around when each loop shape applies.

### [A] 2026-09-18  --  Name the base commit (or the exact range) in a review directive

state: open
scoped: none
legacy: none
mitigation: none

The review directive scoped the pass as "from 20260917-01 to your latest change", which required converting the handover date to its commit (`61ad078`) before the reviewer could diff. Name the base commit or the explicit `git diff <base>..<head>` range in the directive itself; the conversion step is free friction that a reader without the session context cannot resolve.

### [A] 2026-09-18  --  "pi's AGENTS.md" is ambiguous between the runtime copy and the seeded source

state: open
scoped: none
legacy: none
mitigation: none

"pi's AGENTS.md" can mean the runtime provider-layer file loaded at session start (`~/.pi/agent/AGENTS.md`) or the source file that is seeded into the sandbox (`src/reasoning/providers/pi/config/agent/AGENTS.md`). The edit was directed to "pi's agents.md" and only the seeded source path made the target unambiguous. When an edit target has a seeded/runtime copy pair, name the file by its full path in the directive, and state which copy is authoritative (here: the seeded source is the persistent one; the runtime copy is regenerated).

## Agent experience  --  session 20260918-12 (history reorg + flag ingestion)

### [A] 2026-09-18  --  project_index.md usefulness: resolved by removal, freeze table relocated

state: open
scoped: M2.6
legacy: none
mitigation: 2026-09-18 -- the freeze table (Status column) moved into `system_overview.md` at module scope and `project_index.md` was deleted; the registry role was judged convenience not correctness (`git ls-files` plus `find` answer "what documents exist"). The entry stays open as the monitoring record for the further-evaluation question: whether the freeze table AND its associated policies should be dropped entirely.

Question registered per operator request: is `docs/development/project_index.md` useful, in what situations, and can it be safely removed?

What the file actually provides (two distinct roles, read from `project_index.md` itself and its consumers):

1. **Document registry** -- every doc with temperature, architecture-layer assignment, last-touched milestone. Consumers: `agent_workflow.md` (registry/index maintenance), `iteration_policy.md` (hot-file list split between handover and index), handover sweep tooling.
2. **Freeze tracker** -- the architecture-layer freeze table that `documentation_policy.md` (L23, L237) and `system_overview.md` (L36) reference as the authority for whether a frozen-layer change is allowed. This role gates Layer 0/1 edits.

Usefulness assessment:

- **Role 2 (freeze tracking) is load-bearing and irreplaceable by grep** -- it is the single source for "is this layer frozen and may I touch its docs". Removing the file without a replacement would strand `documentation_policy.md` and `system_overview.md` on a missing link.
- **Role 1 (registry) is convenience, not correctness** -- `git ls-files` plus `find` answer "what documents exist" as well; the temperature column is maintained at major-loop close and drifts between closes. The registry tables duplicate what the tree already tells a reader.

Safe-removal answer: NOT safe as-is -- the freeze role must be preserved. Safe rescope: keep the file but slim it to the Architecture Layers + freeze table (the load-bearing part), drop or shrink the per-directory document tables, and repoint the handover/iteration-policy registry references at the docs tree. Alternatively move the freeze table into `system_overview.md` and delete the file, updating the three consumers.

Operator decision (2026-09-18): took the second option -- freeze table into `system_overview.md`, `project_index.md` deleted. Recorded in `mitigation` above.

## Agent experience  --  session 20260919-15

### [A] 2026-09-19  --  Task-type classification is ambiguous between feature and workflow

state: closed
scoped: M2.6 (general CLI refactor / help-text track)
legacy: none
mitigation: 2026-09-19 -- reframed in handover `20260919-16`: the handover type and the commit type are decoupled. The handover type is set at scope time and names the deliverable (implement, discussion, plan, design, docs, workflow, chore, audit); the commit type is set at close and names the landed diff. `impl` is the catch-all handover for any behaviour work, including user-facing help and error strings, so a help-text pass is an `impl` handover whose commit is `feat` (new capability), `fix` (correction), or `refactor` (restructure) -- never `workflow`. `workflow` is reserved for policy, governance, AGENTS.md, and prompts. This resolves the ambiguity at classification time by removing the feature-vs-workflow choice entirely.

The task-type taxonomy (git_policy commit-type prefixes: feature vs workflow) reads as ambiguous at classification time. In session 20260919-14 the same class of change -- a cross-command help-text consistency pass touching user-facing strings in `scripts/` -- was classified as workflow by the agent and corrected by the operator to feature, with the rule stated as: workflow is reserved for policy and prompt changes; user-facing code/help-text behavior is a feature. The two single-word prefixes do not carry that boundary. Durable fix applied (handover `20260919-16`): decouple the handover type from the commit type in `git_policy.md` and `handover_policy.md`, so a user-facing help-text pass is an `impl` handover (commit `feat`/`fix`/`refactor`) and `workflow` is reserved for policy, governance, AGENTS.md, and prompts.

## Agent experience  --  session 20260919-17

### [A] 2026-09-19  --  Closed-handover "read-only" framing made the agent refuse operator-directed edits

state: closed
scoped: M2.6 (governance / task-type and record policy)
legacy: none
mitigation: 2026-09-19 -- reframed in handover `20260919-17`: the absolute "read-only once closed" rule in `handover_policy.md` and `documentation_policy.md` was replaced with one shared principle across all closed documents: a closed document is edited only at the operator's direction and every edit carries the corresponding correction tag. The correction procedure now rewrites the affected paragraph in place (no inline markers), inserts a `[CORRECTION -- YYYY-MM-DD: ...]` tag block at the end of the corrected section ordered newest-first, and names the operator's signal words (amend, re-open, edit, fix). `study_policy.md` and `roadmap_policy.md` carry the same principle; study's em-dash tag normalized to `--`.

The `handover_policy.md` framing read "read-only once closed", which is stricter than the intended behaviour. The repo has a working post-close correction path, and sometimes a close commit must be amended (a squash, a fixup, or a bug found after commit A where rolling the fix into A is cleaner than a second handover). The absolute wording made the agent refuse such operator-directed edits. The durable fix is the reframe in handover `20260919-17`; the operator's decision-log vs factual-reference rationale is recorded as a note, not a second procedure, to avoid procedure drift.

## Agent experience  --  check-in survey 2026-09-20

### [A] 2026-09-20  --  Roadmap milestone state lagged at the M2.6 close seam

state: closed
scoped: M2.6 close
legacy: none
mitigation: 2026-09-20 -- resolved in handover `20260920-02`: the M2 and M2.6 summary rows flip to Complete per Option A (rows only, no top-level close, no M3 promotion).

The check-in survey (2026-09-20) found the roadmap state lagged the tree. `devlog/roadmap.md` frontmatter names `active-milestone: M2.6 - Session Persistence` with status `in-progress`, and the Milestone Summary shows M2.6 "In progress" and M3 "Not started". The M2.6 section is fully checked: every sub-milestone row is `[x]`, and the general-track list holds only completed rows, compacted at the `20260919-18` close. The changelog records the milestone at close. Commit `9858186` then seeded the M3 Backpressure group into `devlog/roadmap_future.md`. The lag is the probation class of GOTCHAS `2026-08-31` (roadmap state goes stale against closed milestones). Per the operator steering, the write-back is held for the M2.6 close preparation, where the escalation clause of that gotcha resolves it.

### [A] 2026-09-20  --  A suite-green correction landed without a certified rerun

state: open
scoped: M2.6 close
legacy: none
mitigation: certified on 2026-09-20 -- the affected files and the full suite rerun green below; the root cause is recorded in GOTCHAS `2026-09-20`.

Handover `20260919-09` AC5 recorded "Suite green across the three code commits". The correction block, dated 2026-09-20, states the claim did not hold: the compose-arg parser in `tests/stubs/docker` did not know `--progress` takes a value, so the dry-run `up` was misparsed, the stub wrote no diagnostics records, and every dry-run test polled the full 180s `DRY_RUN_RECORD_TIMEOUT` twice per run before failing. The fix landed: the stub gained the `--progress` arm, and the `test_start_agent.sh` dry-run fixture supplies `OUTPUT_DIR` and `DRY_RUN_RECORD_TIMEOUT`. The correction did not record a post-fix rerun, so a reader could not trust the corrected claim. The check-in reran the affected files (`test_start_agent.sh` 34/0/0, `test_dry_run_probe.sh` 51/0/0, `test_dry_run_record.sh` 25/0/0, `test_trace_dry_run.sh` 7/0/0) and the full suite: 930 passed, 0 failed, 0 skipped across 54 files. Rule: an in-place correction of a suite claim requires a certified rerun recorded beside the correction.

### [A] 2026-09-20  --  A gotcha cited a commit hash absent from history

state: closed
scoped: M2.6 close
legacy: none
mitigation: 2026-09-20 -- GOTCHAS `2026-09-20` hash corrected in handover `20260920-02` from `ea080bf` to `a1684f3`, verified against `git log`.

GOTCHAS `2026-09-20` cites commit `ea080bf` as the source of the `--progress quiet` change. `git log --all` finds no such hash in this repository. The change is in `a1684f3` ("fix: prevent compose prompt hang and quiet docker output at source"). The hash likely transposed during a rebase of the landed history. A durable lesson record cites a hash a reader must find; a wrong hash loses the anchor. Verify a cited hash against `git log` before recording it, and re-verify after a history rewrite. Correction of the single hash is deferred to the M2.6 close record pass.

### [A] 2026-09-20  --  Changelog identity derivation describes the pre-fold model

state: closed
scoped: M2.6 close
legacy: none
mitigation: 2026-09-20 -- corrected in handover `20260920-02`: both pre-fold changelog claims now carry `[SUPERSEDED in M2.6]` tags pointing at `docs/adr/session_identifier.md`.

The M2.6 changelog entry states the `SESSION_ID` derivation is unchanged: `sha256(SESSION_TS:SANDBOX_ID)[:6]`. The tree implements the folded model: `session_id_derive` in `src/libs/session_env.sh` hashes the three factors together (`sha256(canon(SANDBOX_DIR):HOST_HEAD_SHA:SESSION_TS)[:6]`), matching the roadmap identity row. The fold resolved the settled prefactor `20260831-design-settled-session_identity_prefactor.md` (Option B: fold the intermediate, keep the three factors). `SANDBOX_ID` no longer exists in `src/` or `scripts/`. The changelog text is stale against the tree.

### [A] 2026-09-20  --  Settled designs implemented without a handover citation

state: closed
scoped: M2.6 close
legacy: none
mitigation: 2026-09-20 -- citations added in handover `20260920-02`: both 20260831 settled designs name their implementation handover (`20260904-07`, `20260831-07`); the `20260904-07` handover's pre-rename design reference corrected to `-settled-`.

Two settled designs are implemented, and no implementation handover cites them. `20260831-design-settled-image_and_harness_version_identity.md` was implemented by handover `20260904-07` with ADR `harness_versioning.md`; the handover does not name the design. `20260831-design-settled-session_identity_prefactor.md` has a design handover (`20260831-06`) and a passing citation (`20260831-08`), but the fold has no implementation handover. A settled design should be traceable from its implementation. The Doc Bloat future task plans rotational archiving of resolved story and design records; the citations belong there or at the M2.6 close.

### [A] 2026-09-20  --  The feedback backlog has no roadmap home

state: closed
scoped: M2.6 close
legacy: none
mitigation: 2026-09-20 -- resolved in handover `20260920-02`: roadmap_future M3 gains the skill-maintenance backlog triage row, which is the task assignment the backlog lacked.

At the 2026-09-20 check-in, `AGENT_FEEDBACK.md` held 32 open entries. The consolidation basket is deferred with no task row: bash skill-trap coverage, the edit-tool collation pending distillation, and the circular-sourcing ADR "not yet written". The roadmap is the sole task list, so these observations stay inert until a row assigns them. The newest instance keeps biting: the 2026-09-19 sourced-lib `while read < file` `set -e` hazard is the third `set -e` language-limitation entry in the Bash section. The M2.6 close should decide whether a skill-maintenance row is scheduled or the backlog is accepted as it stands.

## Agent experience  --  session 20260919-19

### [A] 2026-09-20  --  A subagent review pass is expensive and unmeasured

state: open
scoped: M3 -- `perf` workstream (`devlog/roadmap_future.md`, "Perf -- Subagent and Tool Observability")
legacy: none
mitigation: postponed to the M3 `perf` workstream, which owns the instrument for both halves (liveness and per-run metrics). Verbosity guidance until then: seed each round with the prior round's blockers and state the scope narrowly, because a fresh reviewer re-derives context that a measured, resumable run would not need to.

The thermo-nuclear review pass over this iteration ran two models per round across ten rounds in two tranches. Each round is a fresh `pi -p` context, so no round inherits the previous round's reasoning, and the log stays empty until the run flushes: neither the main agent nor the operator can see whether a round is progressing, stalled on the provider, or merely slow. There is no per-run accounting of wall-clock, tokens, throughput, latency, tool-call time, or agent turns, so the cost of a review tranche cannot be compared against its yield. The concrete cost of that blindness: a round that reports nothing new still consumes a full model pass, and the operator cannot tell from the outside whether a silent log means "thinking hard" or "network died".

Scope: harness-wide measurement gap, not a bash or skill trap. Cross-reference: the `edit`-tool collation entry in the `## Edit tool` section is postponed to the same M3 `perf` task, which also instruments failed tool calls by cause.
