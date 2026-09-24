# Agent Feedback

A persistent record of the coding agent's experience and recurring mistakes. Entries record friction points, poor stack design, poor operator prompting, and this-needs-reinforcing notes, plus agent mistakes and code smells. Written by the agent. Reviewed and addressed by the operator.

**Writer:** agent.
**Reviewer:** operator.

Entries are point-in-time records. The **A/O tag** names who raised the entry: `[A]` for an entry raised by the agent, `[O]` for an entry raised by the operator. Reconcile an entry against the current tree before acting on it. If the tree has outgrown an entry, mark it probation; if the entry is superseded  --  its lesson already carried by another entry or record  --  it jumps to probation as well. Either way, follow the normal procedure: wait to see whether it resurfaces; drop it if it does not.

Catalogue a recurrence on its existing entry. Before writing a new entry, grep the file for an entry on the same topic. If one exists, record the recurrence on it instead of creating a new one: set `state` to `open`, note the prior fix in `legacy:` (or, if already present, add to the resurfacing evidence), and fold the new failure mode into the entry. A recurrence re-opens and extends its entry. This keeps the count of recurrences rising on one entry so the operator can see the pattern and scope a durable fix. Do not open a sibling entry for the same topic.

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble  --  length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown

## [<A|O>] <date>  --  <short title>

state: open                        // open | probation | mitigated
                                   // probation = durable fix applied, or the tree has
                                   // outgrown the entry; kept for monitoring, dropped on no resurfacing
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```

`[A]` marks an entry raised by the agent. `[O]` marks an entry raised by the operator.

An entry is dropped when monitoring confirms the fix durable  --  a probation entry is kept for monitoring and dropped when it does not resurface. A durable fix is also recorded in the changelog and the roadmap. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Consolidated (M3 cleanup 2026-09-21)

Frame the merged entries below; each replaces the member entries that shared its roadmap solution. Members were consolidated per the cleanup-pass policy in `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`; their originating handovers carry a `[CORRECTION]` note.

### [A] 2026-09-21  --  Review-pass framing: directive wording (T1)

state: open
scoped: M3 T1 -- review-pass framing fixes
legacy: none
mitigation: three review-directive wording rules. (1) Round-cap / blocker-re-review fits a correctness review; a model-consensus quality pass converges in one round per model against a shared brief. (2) Name the base commit or the explicit `git diff <base>..<head>` range in the review directive, not a handover date the reader must convert. (3) Name an edit target with a seeded/runtime copy pair by full path, stating which copy is authoritative. Source session `20260918-10`.

### [A] 2026-09-21  --  Evidence before a conclusion: verification discipline (T1)

state: open
scoped: M3 T1 -- evidence-validation (verification) discipline
legacy: none
mitigation: validate evidence before trusting a conclusion, four sub-cases. (1) Treat reviewer remedies as hypotheses; verify each with a repro before applying (a proposed `cmd | mapfile` was worse than the bug). (2) After a negative-test mutation, check syntax (`bash -n`) and that it fails for the intended reason, not a side effect. (3) A filtered summary that gates a conclusion must be validated against unfiltered output (`diff -rq` bare). (4) An in-place suite-claim correction carries a certified rerun recorded beside it.

### [A] 2026-09-21  --  Record write-back gate (T1)

state: probation
scoped: M3 T1 -- record write-back gate
legacy: none
mitigation: a claimed record must be verified to have landed. When announcing a write-back (findings row, decision, task), grep the row key / content in the same turn. Keep findings rows as candidate records consolidated at review/publish, not one row per observation; run throwaway verification in `/tmp`, never in the repo tree; a feedback follow-up note is an observation, not a task assignment (the roadmap is the sole task list).

### [A] 2026-09-21  --  Close-milestone and iteration record discipline (T1)

state: open
scoped: M3 T1 -- close-milestone automation
legacy: none
mitigation: the milestone close is where record integrity fails. A green committed iteration without an open handover is a record defect, not a fast close; content below the unit-of-work threshold amends an open/same-session handover rather than opening a new one (hollow iterations); roadmap open-item status must be marked `[x]` in the same iteration its resolving handover closes; keep the close surfaces short and rely on the roadmap as the sole task list; close-out propagation greps sweep the full tests tree.

### [A] 2026-09-21  --  Process improvement: gate-release and scope-first discipline (T1)

state: open
scoped: M3 T1 -- process improvements
legacy: none
mitigation: three process rules. (1) A released task-list gate confirms scope and acceptance criteria, not policy text; present each changed policy section verbatim and await explicit release. (2) Session-relative finding numbers are valid only in their source conversation. (3) A redesign task first establishes purpose, then scopes exploration to it; do not launch a broad sweep before realigning onto the true objective.

### [A] 2026-09-21  --  Edit-tool failure family (T2)

state: open
scoped: M3 T2 -- edit-tool failure metrics + feedback resolution
legacy: none
mitigation: one failure family across the `edit` tool, resolved from the T2 measurement. Multi-edit atomicity (one failed entry rolls back the whole call); exact-match `oldText` (invisible whitespace / trailing chars break the match); overlapping/nested entries rejected; `oldText` must be unique. Sub-cases: a regex `sed -i` with a missing file operand silently writes nothing; the "did the write land?" reflex catches un-applied edits; table-row append must keep the anchor row (overwrite-instead-of-append is a distinct failure mode). Count and classify failures by cause via the T2 metric.

### [A] 2026-09-21  --  Doc-format discipline via lint (T3)

state: probation
scoped: M3.1 -- doc-format lint rules
legacy: none
mitigation: document-format rules are enforced by the lint gate, not left to memory. Non-ASCII punctuation is caught by the `doc-ascii` rule. Manually column-wrapped prose (hard-wrapped instruction blocks) currently has no detector -- add a lint rule. When composing/editing a document, check the recipient file's own formatting rules first (a file whose own policy forbids the pattern is the compliance failure).

### [A] 2026-09-21  --  Install and staleness family (T4)

state: open
scoped: M3 T4 -- atomic install + semantic versioning
legacy: none
mitigation: installed CLI staleness is hard to detect and masquerades as a code regression. A new subcommand surfaces as `Unknown subcommand` with no hint that `make install` is needed; diff the installed CLI's valid subcommands against the source before assuming the implementation is wrong. A symlinked CLI resolves to whichever checkout the link points at -- check `readlink -f "$(which <cmd>)"` and that checkout's feature presence before touching project source. The durable fix is the T4 self-contained binary + semantic versioning.

### [A] 2026-09-21  --  Library and test-harness migrations (T4)

state: open
scoped: M3 T4 -- library migrations
legacy: none
mitigation: tooling and harness notes for the library-migrations track. Use bash-native tools (sed, awk, perl) for text mutation; do not reach for python3 without checking it is present. Exec-style scripts need a `BASH_SOURCE[0] == "$0"` dual-use guard so unit seams can extract functions. A production flag added to a docker/compose call that tests exercise must update the test double's argument parser in the same commit, or the stub misparses and the suite hangs on the record timeout.

## Bash

Canonical bash coding rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md).

Bash friction entries migrated from `devlog/discussions/20260809-story-active-bash_complaints.md` (deleted).

### [A] 2026-08-09  --  Circular sourcing between `diff_export.sh` and `package_branch.sh`

state: open
scoped: M3 T7 -- skill-maintenance backlog triage (pending circular-sourcing ADR)
mitigation: extracted `_write_export_status` to a shared `export_status.sh` lib sourced by both. Shared functions live in leaf libraries, never in orchestrators.

`diff_export.sh` sources `package_branch.sh`. When `package_branch.sh` needed `_write_export_status`, it could not source `diff_export.sh` back without a cycle. The discovery was trial-and-error; no static analysis tool caught the cycle.

Scope: architecture decision recorded in ADR (not yet written). Cross-reference: no skill trap covers this; should be added as an architecture trap.

### [A] 2026-09-19  --  A prose comment starting with the word `shellcheck` becomes a Directive

state: probation
scoped: M3.1 -- ShellCheck gate (directive-parse warning)
legacy: none
mitigation: word the line so `shellcheck` is not the first token after `#` (for example "the shellcheck tool absent").

ShellCheck parses any comment line whose first token after `#` is `shellcheck` as a directive. A prose comment that begins with the word -- for example a test-file header line reading `#   shellcheck absent  --  rc 1` -- makes the tool emit `SC1073`/`SC1072` parse errors against the file, so the ShellCheck gate fails on the repository's own scripts. The trap fires twice in one file in this iteration because the natural way to start a line about the tool is the tool's name. The failure is loud and the fix is trivial, but it looks like a false positive until the directive rule is known.

Scope: ShellCheck directive parsing. Cross-reference: `docs/development/bash-coding-conventions.md` states the suppression policy (targeted `# shellcheck disable=` with a rationale) but does not warn that a bare leading `shellcheck` word is parsed at all.

---

Skill-trap coverage gaps (bash entries marked "no trap" or partially covered): consolidation into the bash-scripting-traps skill is deferred to a future skill-maintenance session; per-entry coverage is noted in each entry's Cross-reference line.

---

## Gotchas  --  operator-raised entries

Entries raised by the operator (tagged `[O]`), migrated from the former `devlog/GOTCHAS.md` (deleted in the unification).

### [O] 2026-08-09  --  Set handover Status Closed before the final commit (close = the commit)

state: probation
scoped: M3 -- iteration close one-commit rule (`docs/operations/git_policy.md` transient-commits; `docs/operations/iteration_policy.md` close-produces-one-commit)
legacy: the original fix landed 2026-08-19 and held across the intervening sessions; the defect resurfaced 2026-09-24 as `docs: close` commits whose only change was the handover Status flip and roadmap write-back (recorded in handover `20260924-02`)
mitigation: a commit whose only change is the handover Status flip or the roadmap write-back is a defect, not a delivery commit. The close edit belongs in the iteration's single delivery commit: set `Status: Closed` and apply the write-back, then commit or amend once. Within the iteration, commit the work when useful (`wip:` for in-progress snapshots); the close edit still folds into the delivery commit. The 2026-09-24 governance fix prescribes this in the transient-commits rule (git_policy) and close-produces-one-commit (iteration_policy). Probationary because the fixing iteration closed through a special case (a clean-tree-required rebase) and the unspecialised path has not yet shown the rule holds. Screen each subsequent close for a `docs: close`-shaped commit (only the Status flip or write-back); drop the entry when several closes in a row show none.

### [O] 2026-08-12  --  Library functions must `return`, not `exit`

state: probation
scoped: M3.1 -- sourced-lib / library lint rules
legacy: not swept, fixed on contact
mitigation: library functions sourced by entrypoint scripts must use `return 1`, not `exit 1`. All entrypoints run under `set -euo pipefail`, so a non-zero return triggers script exit identically. Bare `exit` in a sourced function is a latent bug if the function is ever called from a different context (e.g. test harness, sub-shell, interactive use). Entrypoint scripts (`scripts/*.sh`) may use `exit` legitimately. Canonical rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md) rule 3.1.

### [O] 2026-09-18  --  Mechanical-edit one-liners must carry a match-count guard and a timeout

state: open
scoped: M3 T2 -- tool timeout / run-budget on the bash tool, tests, and lint
legacy: none
mitigation: a perl one-liner intended to count matches in a test file was written with the `/g` modifier against a full-file slurp; it matched nothing, but the loop structure ran forever, emitting a line count that grew into the hundreds of millions before the run was aborted and the log killed. The deeper fix: a mechanical transform that prints only a summary at the end is invisible while it spins. Always (1) bound the tool with `timeout`, (2) have the transform emit a match/replacement count to stderr BEFORE any output, and (3) diff against the input to verify the change before committing. A long-running transform with no stderr progress is the signal to inspect the loop, not to wait. The standing order to run every script through `timeout` is withdrawn: a blanket timeout on a simple script maxes out the wait every run. Move to a test harness with per-test timeouts.

### [O] 2026-09-22  --  Design documents record the final design, not the questionnaire

state: open
scoped: M3 T1 -- Workflow + Policy Organization (design-document policy amendment; not scheduled, roadmap row under T1)
legacy: ties to [A] 2026-09-04 "Record-layer documents drafted as reasoning traces" and [A] 2026-08-18 "Multi-question turns during a grill-me design walk" -- the same records-state-not-session-history rule, applied to design-session capture
mitigation: a grill-me or design walk must not be captured as an open-questions-and-replies transcript in the design document. Write the answers back into the design body; include a short "designs considered and rejected" section with each rejected option and why; put the completed final design at the forefront. A questionnaire log reads as a record of effort, not a record of reasoning, and adds length without an understanding benefit. Amend the design-document / documentation-policy conventions to prohibit the pattern at the root.

## Agent experience  --  session 20260809-04

### [A] 2026-08-10  --  git operations touching the index/worktree revert uncommitted session work

state: open
scoped: M3 T7 -- sandbox persistence (protect uncommitted session work from git ops)
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

### [A] 2026-08-18  --  Multi-question turns and implicit acceptance during a grill-me design walk

state: open
scoped: M3 T7 -- functional-stack navigation for questioning (design proposal)
legacy: none
mitigation: during the M2.6.6 design walk the agent posed two questions in one
turn (A+B, then D8+N1), skipped N2a to the next question without an explicit
approval, and treated operator probes as implicit approval of a pending
question  --  the operator corrected the pattern twice. One question per turn;
when a side-question arises, queue it explicitly in the live pile and return to
it after the main question is settled. An operator"s probing question is not
an approval of the pending question; re-pose the pending question for explicit
approval, naming what the probes settled and what remains open.

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

state: probation
scoped: M3 T1 -- prompt-scope discipline
legacy: none
mitigation: none

The test-quality-campaign prompt said "tests only - never change production source", but success criterion #3 (the prerequisite gate) can only be met by changing scripts/run_tests.sh, which is not a tests/ file. At run time the subagent touched the runner to satisfy the criterion and reported "no production source was touched" - inaccurate. The ambiguity: "tests only" was read as the tests/ directory, while the testing_policy prerequisite rule mandates a runner behaviour that lives outside it. Fix: name the test runner as in-scope in the campaign prompt, or make criterion #3 flag-only.

Same session, same prompt: the deliverable contract was iterated three times in chat (commit, then branch-and-merge, then uncommitted proposal) because the first draft pinned "commit one delivery commit" while the operator's model was "subagent proposes, main agent commits at iteration close". Pin the deliverable ("leave uncommitted, never commit") before writing a subagent prompt.

## Agent experience  --  session 20260904-01 (seed transport redesign)

### [A] 2026-09-04  --  Record-layer documents drafted as reasoning traces needed a full rewrite

state: open
scoped: M3 T8 -- STE-clean sweep / record-layer drafting discipline
legacy: none
mitigation: First drafts of the seed-transport ADR and concept doc mirrored the session's reasoning: narrative history, transient identifiers (session ids, commit hashes, handover names), implementation command dumps, and rationale-as-argument instead of rationale-as-mapping. The operator steer (records state, not session history; problem / solution / rejected-with-failure-locus / follow-up; requirements as behavioral contracts in concept docs; interface-level descriptions, commands only for external interactions) required full rewrites of both. Mitigation for next time: before writing a record-layer document, propose its skeleton (section list + what each section holds) in chat and get the structure confirmed; write prose only against the confirmed skeleton. Findings F8-F14 in handover 20260904-01-design-start_resume_rsync_stall.md carry the policy-amendment candidates.

## Agent experience  --  session 20260918-10 (thermo-nuclear review pass)

### [A] 2026-09-20  --  A subagent review pass is expensive and unmeasured

state: open
scoped: M3 -- `perf` workstream (`devlog/roadmap_future.md`, "Perf -- Subagent and Tool Observability")
legacy: none
mitigation: postponed to the M3 `perf` workstream, which owns the instrument for both halves (liveness and per-run metrics). Verbosity guidance until then: seed each round with the prior round's blockers and state the scope narrowly, because a fresh reviewer re-derives context that a measured, resumable run would not need to.

The thermo-nuclear review pass over this iteration ran two models per round across ten rounds in two tranches. Each round is a fresh `pi -p` context, so no round inherits the previous round's reasoning, and the log stays empty until the run flushes: neither the main agent nor the operator can see whether a round is progressing, stalled on the provider, or merely slow. There is no per-run accounting of wall-clock, tokens, throughput, latency, tool-call time, or agent turns, so the cost of a review tranche cannot be compared against its yield. The concrete cost of that blindness: a round that reports nothing new still consumes a full model pass, and the operator cannot tell from the outside whether a silent log means "thinking hard" or "network died".

Scope: harness-wide measurement gap, not a bash or skill trap. Cross-reference: the consolidated `edit`-tool failure entry in the `## Consolidated (M3 cleanup 2026-09-21)` section routes to the same M3 `perf`/T2 task, which instruments failed tool calls by cause.

## Agent experience  --  session 20260922 (test-harness isolation, M3.1 U1-U7)

### [A] 2026-09-22  --  Command substitution loses array writes: journal allocated state to a file

state: probation
scoped: M3.1 -- test-harness execution model (U1)
legacy: none
mitigation: `get_fixture_dir()` is called inside command substitution, so its `_ALLOC_DIRS+=()` append wrote to a lost sub-subshell copy and the allocator's teardown never removed the directories. A helper that registers state while called via `$( )` must persist it to a file (append on allocate, read on cleanup), not to a shell array.

### [A] 2026-09-22  --  An EXIT trap's final command overrides the shell exit status

state: probation
scoped: M3.1 -- test-harness execution model (U1)
legacy: none
mitigation: the per-test subshell's cleanup trap ended in `return 0`, flipping `fail()`'s exit 1 to exit 0: a failing test reported PASS. A cleanup EXIT trap must capture `$?` before cleaning and re-exit with it (`trap '_trap_rc=$?; cleanup; exit "$_trap_rc"' EXIT`).

### [A] 2026-09-22  --  Test subshells run `set +e`; capture-and-assert needs it

state: probation
scoped: M3.1 -- test-harness execution model (U1)
legacy: none
mitigation: a sourced script's `set -euo pipefail` leaks into the test file's shell, and `out=$(cmd); rc=$?` with a failing cmd aborts under errexit. The per-test subshell runs `set +e` so capture-and-assert works; the verdict is fail()/pass(), never the shell's errexit. Related capture trap: `( ... ) || rc=$?` only assigns rc on the failure arm, so initialize `rc=0` or a passing subshell leaves it unbound under `set -u`.

### [A] 2026-09-22  --  A condition on an always-true helper is a vacuous assertion; a masked rc hides real defects

state: probation
scoped: M3.1 -- final per-assertion sweep (U7)
legacy: ties to [A] 2026-09-20 "A subagent review pass is expensive and unmeasured" -- the fresh-subagent sweep is the yield side of that entry
mitigation: `if trace_grep "..." > /dev/null` always took the pass branch because `trace_grep` ends in `|| true`; the traced operation was never gated. Any conditional on a helper that always returns 0 is a vacuous assertion -- use the `grep -q` variant. The sweep found six such assertions and one silent-green (an empty failed `docker compose config` satisfied its own grep). The reverse face: a masked invocation rc hid a real production defect (`scripts/prune.sh` committed without its exec bit, so `stop --prune` returned 126); the same masks that U4 documented as load-bearing also conceal genuine failures, so assert the rc of any success-expected command.
