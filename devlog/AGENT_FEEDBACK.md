# Agent Feedback

A persistent record of the coding agent's experience and recurring mistakes. Entries record friction points, poor stack design, poor operator prompting, and this-needs-reinforcing notes, plus agent mistakes and code smells. Written by the agent. Reviewed and addressed by the operator.

**Writer:** agent. **Reviewer:** operator.

Entries are point-in-time records. The **A/O tag** names who raised the entry: `[A]` for an entry raised by the agent, `[O]` for an entry raised by the operator. Reconcile an entry against the current tree before acting on it. If the tree has outgrown an entry, mark it probation; if the entry is superseded  --  its lesson already carried by another entry or record  --  it jumps to probation as well. Either way, follow the normal procedure: wait to see whether it resurfaces; drop it if it does not.

Catalogue a recurrence on its existing entry. Before writing a new entry, grep the file for an entry on the same topic. If one exists, record the recurrence on it instead of creating a new one: set `state` to `open`, note the prior fix in `legacy:` (or, if already present, add to the resurfacing evidence), and fold the new failure mode into the entry. A recurrence re-opens and extends its entry. This keeps the count of recurrences rising on one entry so the operator can see the pattern and scope a durable fix. Do not open a sibling entry for the same topic.

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble  --  length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

## [A] 2026-10-03  --  A heavy test file's own deadline fails it under parallel load

```text
state: open
scoped: none
legacy: none
mitigation: when a full-suite run reports only tests/test_runner_contract.sh as failed, re-run before treating it as a defect; the file takes about 7s alone against a declared 10s deadline.
```

`tests/test_runner_contract.sh` carries `# TEST_DEADLINE: 10` and takes about 7 seconds alone. Two full-suite runs on a loaded container timed it out; a third run passed at 97 seconds. The runner counts a deadline expiry as a failed file, so a load spike reads as a red run.

---

## [A] 2026-10-02  --  A capacity claim was stated as a fact with no signal behind it

```text
state: open
scoped: none
legacy: none
mitigation: before claiming to be out of room, budget or context, check for a signal. If there is no signal, the claim cannot be made -- name it as an inference, or do not make it.
```

After nine work units in one session the agent reported that it had run out of room and would stop short of the remaining six files. It had not run out of room. It had inferred exhaustion from the conversation's length and from a compaction note earlier in the session, and stated the inference as a fact.

The operator asked why. A search for a signal found none: the environment exposes `PI_PROVIDER`, `PI_MODEL`, `PI_SESSION_ID` and `PI_REASONING_LEVEL`, and no budget, token or context variable. There was nothing to check, so the claim could not have been checked -- which is the point. A claim about a state the agent cannot observe is not a report, and the communication standards' ban on hedging pushes toward flat declaratives rather than away from them.

The cost was one turn. The operator asked why, and the work resumed immediately and finished all six files.

**Prevention, in two parts.** The available part is a rule: stopping work early is a decision, and like any other it needs a reason the reader can check. The structural part is a signal -- expose remaining context or budget so an agent reads it instead of inferring it. Filed as a roadmap row.

---

## Entry format

Each entry follows this structural template.

````markdown

## [<A|O>] <date>  --  <short title>

```text
state: open                        // open | probation | mitigated
                                   // probation = durable fix applied, or the tree has
                                   // outgrown the entry; kept for monitoring, dropped on no resurfacing
scoped: <milestone or none>        // durable-fix destination when assigned
legacy: <prior fix, if any>        // set only on resurfacing
mitigation: <interim workaround, or none>
```
````

The field block is fenced, so the `doc-wrap` rule reads it as code rather than as one wrapped paragraph.

`[A]` marks an entry raised by the agent. `[O]` marks an entry raised by the operator.

An entry is dropped when monitoring confirms the fix durable  --  a probation entry is kept for monitoring and dropped when it does not resurface. A durable fix is also recorded in the changelog and the roadmap. This file holds only the active backlog.

Attribution is operator-owned. The agent proposes a class and the operator confirms it. The agent does not self-classify its own boo-boos as not-its-fault.

---

## Consolidated (M3 cleanup 2026-09-21)

Frame the merged entries below; each replaces the member entries that shared its roadmap solution. Members were consolidated per the cleanup-pass policy in `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`; their originating handovers carry a `[CORRECTION]` note.

### [A] 2026-09-21  --  Review-pass framing: directive wording (T1)

```text
state: open
scoped: M3 T1 -- review-pass framing fixes
legacy: none
mitigation: three review-directive wording rules. (1) Round-cap / blocker-re-review fits a correctness review; a model-consensus quality pass converges in one round per model against a shared brief. (2) Name the base commit or the explicit `git diff <base>..<head>` range in the review directive, not a handover date the reader must convert. (3) Name an edit target with a seeded/runtime copy pair by full path, stating which copy is authoritative. Source session `20260918-10`.
```

### [A] 2026-09-21  --  Evidence before a conclusion: verification discipline (T1)

```text
state: open
scoped: M3 T1 -- evidence-validation (verification) discipline
legacy: none
mitigation: validate evidence before trusting a conclusion, four sub-cases. (1) Treat reviewer remedies as hypotheses; verify each with a repro before applying (a proposed `cmd | mapfile` was worse than the bug). (2) After a negative-test mutation, check syntax (`bash -n`) and that it fails for the intended reason, not a side effect. (3) A filtered summary that gates a conclusion must be validated against unfiltered output (`diff -rq` bare). (4) An in-place suite-claim correction carries a certified rerun recorded beside it.
```

### [A] 2026-09-21  --  Close-milestone and iteration record discipline (T1)

```text
state: open
scoped: M3 T1 -- close-milestone automation
legacy: 2026-09-27 -- one policy decision landed as ten commits, one per released section, though the one-commit rule was explicit in `iteration_policy.md` and the provider `AGENTS.md`. The governance cadence in the project `AGENTS.md` was read as setting the commit count; it governs the proposal. The unit the gap lacked -- one roadmap task, one vertical slice -- is defined in `iteration_policy.md` Step 2 (handover `20260927-08`).
legacy: 2026-10-01 -- the propagation sweep recurred against a different surface. Adding a `Decisions pending` section to the handover format swept the prompt tree and the policy tree, and missed `workflow/coding-agent/audits/audit.skill.md`, whose structural-completeness rule enumerates the required sections; the rule would have fired on every conforming handover. The earlier mitigation named the tests tree, which is the same gap one directory over: an enumeration of the thing being changed lives outside the tree being changed, and a grep bounded by the changed paths cannot find it.
mitigation: the milestone close is where record integrity fails. A green committed iteration without an open handover is a record defect, not a fast close; content below the unit-of-work threshold amends an open/same-session handover rather than opening a new one (hollow iterations); roadmap open-item status must be marked `[x]` in the same iteration its resolving handover closes; keep the close surfaces short and rely on the roadmap as the sole task list; close-out propagation greps sweep the full tests tree. A section-by-section review of one task is still one unit: the cadence governs the proposal, and a unit's diff carries a writable subject.
```

### [A] 2026-09-21  --  Process improvement: gate-release and scope-first discipline (T1)

```text
state: open
scoped: M3 T1 -- process improvements
legacy: none
mitigation: three process rules. (1) A released task-list gate confirms scope and acceptance criteria, not policy text; present each changed policy section verbatim and await explicit release. (2) Session-relative finding numbers are valid only in their source conversation. (3) A redesign task first establishes purpose, then scopes exploration to it; do not launch a broad sweep before realigning onto the true objective.
```

### [A] 2026-09-21  --  Edit-tool failure family (T2)

```text
state: open
scoped: M3 T2 -- edit-tool failure metrics + feedback resolution
legacy: none
mitigation: one failure family across the `edit` tool, resolved from the T2 measurement. Multi-edit atomicity (one failed entry rolls back the whole call); exact-match `oldText` (invisible whitespace / trailing chars break the match); overlapping/nested entries rejected; `oldText` must be unique. Sub-cases: a regex `sed -i` with a missing file operand silently writes nothing; the "did the write land?" reflex catches un-applied edits; table-row append must keep the anchor row (overwrite-instead-of-append is a distinct failure mode). Count and classify failures by cause via the T2 metric.
legacy: 2026-09-27 -- the anchor-row mode recurred while inserting a roadmap row: the `newText` replaced the
anchor line instead of prefixing it, and the row's text was lost until it was restored from `HEAD` and verified
byte-identical. Read `newText` as the full replacement region before writing, and re-run `git diff --numstat` to
confirm an append shows one insertion and zero deletions. Second instance the same day: the marker-ordering row still carried the neighbouring trial row's body after the restore passed byte-identical, and the close read-back caught it. Run the numstat reflex after every row edit, not only after the recovery.
```

### [A] 2026-09-21  --  Doc-format discipline via lint (T3)

```text
state: open
scoped: M3.1 -- doc-format lint rules; `scripts/lint/doc-wrap.mjs`
legacy: the doc-wrap rule was claimed landed and live in `.markdownlint-cli2.mjs` (the 2026-09-21 add-a-lint-rule clause), which had the entry mitigated.
mitigation: document-format rules are enforced by the lint gate, not left to memory. Non-ASCII punctuation is caught by the `doc-ascii` rule. Manually column-wrapped prose (hard-wrapped instruction blocks) currently has no detector -- add a lint rule. When composing/editing a document, check the recipient file's own formatting rules first (a file whose own policy forbids the pattern is the compliance failure). The add-a-lint-rule clause landed: the `doc-wrap` rule is live in `.markdownlint-cli2.mjs`. **Recurrence (2026-10-01):** the doc-wrap rule, though enabled (`"doc-wrap": true`) and listed as live, does not fire on a paragraph explicitly hard-wrapped across two physical lines (a two-line test paragraph in-repo reports a clean gate). The one-paragraph-per-physical-line policy in `documentation_policy.md` `### Line wrapping` is therefore not enforced by the gate; an agent must comply by hand. Re-open: the add-lint-rule mitigation did not land an effective rule. **Recurrence (2026-10-02):** the config cause is identified. `customRules` in `.markdownlint-cli2.mjs` lists only `./scripts/lint/doc-ascii.mjs`, so `doc-wrap.mjs` is never registered, while the rule block sets `"doc-wrap": true` against a rule that was not loaded. The rule itself is sound: `bash tests/test_doc_wrap_rule.sh` passes under a temp config that registers it, and the repository config fires no `doc-wrap` finding on a deliberately hard-wrapped paragraph. Fixing the config registers the rule; nothing in the rule needs to change.
```

### [A] 2026-09-28  --  Handover-table stray-pipe and write-tool trailing-newline class (U3)

```text
state: open
scoped: recurring record defect, recurrences 4-5 in handover `20260928-08`; seed recurrences in U1, U2
legacy: the prior U2 handover (`20260928-07`) flagged this class for monitoring in U3; the guard (lint-check every handover table before pre-close) held and caught each recurrence, but the class recurred three times in a single WIP cycle
mitigation: the `write` tool drops the trailing newline on a full-file write (failing MD047), and handover table rows acquire stray pipe-cells or a Findings-style fourth column on an edit (failing MD056). Both are caught by lint before pre-close. The write-tool trailing-newline is a tool behaviour, not authoring: append a newline after every full-file `write`. The stray-pipe class is authoring under edit-time pressure: verify every handover table's column count before pre-close. The class persists -- consider a mechanical guard beyond the lint gate.
```

### [A] 2026-09-28  --  Advisor re-run has low marginal value after a clean consensus (U4)

```text
state: open
scoped: M3.2.1 -- advisor-usage criteria
legacy: none
mitigation: a second advisor run that only re-confirms a single mechanical correction adds little over the first run's defect list. In U4 the first run (deepseek-v4-flash) found one real defect (commit-type guidance); the second run merely re-verified the fix and returned a clean bill. The high-value re-run is when a fix touched multiple coupled files or changed the design -- then a fresh reviewer on the changed state earns its cost. Re-run sparingly: prefer one thorough advisor pass, fix, and only re-run when the change was structural or cross-file. Do not re-run to confirm a one-line correction against an authoritative table.
```

### [A] 2026-09-21  --  Install and staleness family (T4)

```text
state: open
scoped: M3 T4 -- atomic install + semantic versioning
legacy: none
mitigation: installed CLI staleness is hard to detect and masquerades as a code regression. A new subcommand surfaces as `Unknown subcommand` with no hint that `make install` is needed; diff the installed CLI's valid subcommands against the source before assuming the implementation is wrong. A symlinked CLI resolves to whichever checkout the link points at -- check `readlink -f "$(which <cmd>)"` and that checkout's feature presence before touching project source. The durable fix is the T4 self-contained binary + semantic versioning.
```

### [A] 2026-09-21  --  Library and test-harness migrations (T4)

```text
state: open
scoped: M3 T4 -- library migrations
legacy: none
mitigation: tooling and harness notes for the library-migrations track. Use bash-native tools (sed, awk, perl) for text mutation; do not reach for python3 without checking it is present. Exec-style scripts need a `BASH_SOURCE[0] == "$0"` dual-use guard so unit seams can extract functions. A production flag added to a docker/compose call that tests exercise must update the test double's argument parser in the same commit, or the stub misparses and the suite hangs on the record timeout.
```

## Bash

Canonical bash coding rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md).

Bash friction entries migrated from `devlog/discussions/20260809-story-active-bash_complaints.md` (deleted).

### [A] 2026-08-09  --  Circular sourcing between `diff_export.sh` and `package_branch.sh`

```text
state: mitigated
scoped: M3 T7 -- skill-maintenance backlog triage (pending circular-sourcing ADR)
mitigation: extracted `_write_export_status` to a shared `export_status.sh` lib sourced by both. Shared functions live in leaf libraries, never in orchestrators. Both libs source it on disk.
```

`diff_export.sh` sources `package_branch.sh`. When `package_branch.sh` needed `_write_export_status`, it could not source `diff_export.sh` back without a cycle. The discovery was trial-and-error; no static analysis tool caught the cycle.

Scope: architecture decision recorded in ADR (not yet written). Cross-reference: no skill trap covers this; should be added as an architecture trap.

### [A] 2026-09-19  --  A prose comment starting with the word `shellcheck` becomes a Directive

```text
state: mitigated
scoped: M3.1 -- ShellCheck gate (directive-parse warning)
legacy: none
mitigation: word the line so `shellcheck` is not the first token after `#` (for example "the shellcheck tool absent"). The shell gate now flags a prose directive rather than dropping it silently.
```

ShellCheck parses any comment line whose first token after `#` is `shellcheck` as a directive. A prose comment that begins with the word -- for example a test-file header line reading `#   shellcheck absent  --  rc 1` -- makes the tool emit `SC1073`/`SC1072` parse errors against the file, so the ShellCheck gate fails on the repository's own scripts. The trap fires twice in one file in this iteration because the natural way to start a line about the tool is the tool's name. The failure is loud and the fix is trivial, but it looks like a false positive until the directive rule is known.

Scope: ShellCheck directive parsing. Cross-reference: `docs/development/bash-coding-conventions.md` states the suppression policy (targeted `# shellcheck disable=` with a rationale) but does not warn that a bare leading `shellcheck` word is parsed at all.

### [A] 2026-09-25  --  `false` is a non-empty string inside `[[ ]]`, so a `&& false` mutation is not a mutation

```text
state: open
scoped: none
legacy: none
mitigation: to disable a guard while testing, replace its condition line with `if false; then`, and confirm the mutant file differs from its backup before running the suite, and that the line that changed is the site the verdict depends on. `[[ "$x" && false ]]` evaluates true, because the right-hand operand is a string test on a non-empty literal; `[[ -z "$x" && -n /dev/null ]]` is true for the same reason. Both forms report a false survivor. When a mutation uses perl to substitute a literal that contains a shell variable, `\Q...\E` does not stop interpolation: pass the literal through the environment (`OLD=... perl -0777 -pi -e 's/\Q$ENV{OLD}\E/.../'`) and keep the backup comparison in probes as well as in bite scripts.
```

A mutation is evidence only if it changes behaviour. Two forms that look like disablements do not: `&& false` and `-n /dev/null` inside `[[ ]]`, where the right-hand operand is a string test on a non-empty literal and therefore true. Both were used in the read-through's bite sweeps - a delivery guard, two resume guards, and a provider-recovery check - and each reported a survivor that was in fact an unchanged guard. The check that catches the whole family is cheap: verify the mutant differs from the backup before running the suite, and prefer a form with no operand at all.

A second form of the same failure surfaced in the apply.sh pass, in a probe script rather than a bite script: `s/\QFILES_CHANGED=$(grep -c "^diff --git" "$DIFF_FILE" || true)\E/` matched nothing, because perl interpolates `$DIFF_FILE` inside `\Q...\E`; the shell variable was unset in the perl process, so the pattern became a no-match and the probe reported the mutant's output as if the mutant had applied. Twenty of the first sweep's twenty-two bites no-op'd the same way for the same reason (the other two aborted with perl syntax errors on the interpolated quotes). The probe script had no backup comparison because the bite script already had one, which is why the check belongs in both.

A third form belongs to the same entry, from the interactive.sh pass. `\Q...\E` also stops `\n` from being a newline: `OLD='---\n### '` passed through the environment matches the literal characters backslash and n, not a line break, so a two-line replacement against a markdown file no-op'd with no error. The environment idiom removes the interpolation hazard but not the escape hazard. When the literal spans lines, put a real newline in the variable (`OLD=$'---\n### '`) or use the `edit` tool, whose `oldText` carries the newline directly.

A fourth false positive comes from outside the mutant. The Makefile-template pass's `start` `INTERACTIVE_FLAG` bite (M11) exited non-zero on its first run and a bite script that reads only the exit status recorded PROVEN; two re-runs gave 722/722 with the liveness gate reporting zero findings. The abort came from the liveness gate, which the read-through's row 135 records as observed once and unreproduced. A PROVEN verdict therefore needs the failing file's name and a re-run before it is trusted, not the exit status alone.

A fifth false positive, from the first rectification slice. The mutant differed from its backup and the mutation was real, but it landed at the wrong site. `scripts/workflows/confirm.sh` carries `git -C "$PROJECT_DIR" rebase --abort 2>/dev/null || true` twice, at six-space indentation in the drop-step failure path and four-space indentation in the conflict path. A line-based matcher given the six-space form hit the drop-step guard, while the verdict belonged to the conflict path; the suite stayed green and the bite reported a survivor that the intended mutation would have caught. The indentation was invisible in a grep listing, which is what made the error easy. Confirm the site, not only the difference: print the mutant's diff and read which line changed, and give a repeated line enough of its context to be unambiguous. A survivor is evidence about the code path you actually mutated.

Scope: bash conditional-expression semantics. Cross-reference: `docs/development/bash-coding-conventions.md`; the vacuity family is [A] 2026-09-22 "A condition on an always-true helper is a vacuous assertion", whose subject is an assertion rather than a mutation.

---

Skill-trap coverage gaps (bash entries marked "no trap" or partially covered): consolidation into the bash-scripting-traps skill is deferred to a future skill-maintenance session; per-entry coverage is noted in each entry's Cross-reference line.

---

### [A] 2026-09-25  --  A guard that errexit already provides cannot be pinned by a unit

```text
state: open
scoped: M3.1 T1 -- the read-through brief's disposition rule for a surviving bite
legacy: none
mitigation: when a bite survives, classify the row by running the deletion and comparing the outcome for the code's callers, never by argument. If no input changes output or exit status, the row is a code row: delete the line, write no unit. Do not add a gate for the idiom, because whether `cmd || exit 1` decides anything depends on the call context: errexit is suspended for the whole body of a function invoked in a condition.
```

Three instances, filed as coverage gaps (`action_kind: test`), each with a different mechanism. `scripts/workflows/apply.sh` ends `apply_run` with `exit $?`: unreachable when the preceding command failed, because errexit exits first, and a no-op when it succeeded. `scripts/resume_agent.sh` guards the picker call with `chosen="$(picker)" || exit 1`: the arm does run (`bash -c 'set -e; x="$(false)" || { echo ARM; exit 1; }; echo after'` prints ARM and exits 1), and the line is redundant only because errexit produces the same exit status without it. `scripts/workflows/draft.sh`'s `main` sets `CHANNEL_ARG="${CHANNEL_ARG:-session}"` and no reader uses the value, because `resolve_source_for_draft` applies the same default.

No unit can fail on any of the three, so the mutation survives by construction. The brief's earlier text, "a surviving mutation is a coverage finding", would have pushed the next agent to write a source-text assertion, which the suite's anti-patterns forbid because it pins the text and not the behaviour.

Gate probe, shellcheck 0.9.0 over the 193 shell files the gate scans: SC2317, "unreachable command", does not exist in that version (`shellcheck --list-optional` does not list it), so the measurement cannot be taken and a version upgrade is the precondition for revisiting; the adjacent optional check `check-set-e-suppressed` (SC2310/SC2311) returns zero findings; SC2320 (`$?` refers to echo or printf) is already on at warning severity and does not fire, because the command before `apply.sh:218` is not echo. No gate is available for this class, so the disposition rule carries the whole mitigation.

Scope: any pass that mutates a production file to test a unit's claim. Cross-reference: the read-through brief's bite requirement and its glossary; register rows 313, 314 and 316.

### [A] 2026-09-30  --  A backgrounded process holding the caller's stdout stalls the whole tool call

```text
state: probation
scoped: T1 -- the process-scan rule is recorded in `bash-coding-conventions.md` section 4.7; the redirect and explicit-stop prescriptions were not adopted
legacy: none
mitigation: a process scan must match on the executable and the argument and exclude the current pid, then verify the process is gone rather than read a kill as success. See `docs/development/bash-coding-conventions.md` section 4.7.
```

A script that starts a long-lived background process without redirecting its stdout keeps the caller's stdout pipe open for as long as it lives. A pipeline such as `timeout 300 bash script.sh | tail -20` then reports nothing at all: `timeout` kills the foreground script at 300s, the orphan keeps the write end of the pipe open, and the reader blocks until the tool call itself is aborted. Measured cost: 47 minutes for a script whose own budget was 300 seconds. The failure is silent, because the killed script produced no output to explain itself.

Two adjacent traps in the same session, both from a cleanup scan written as a shell loop over `/proc`. A scan matching a process name with a glob also matches the scanning shell's own command line, because the pattern text is in that command line: the loop signalled itself and the tool call died with 143. And `pkill` does not exist in this image, so an earlier cleanup that used it silently removed nothing and left the port held, which made the next run's probe talk to a dead server and report that nothing had been captured. The scan discipline is recorded in `bash-coding-conventions.md` section 4.7.

Scope: any test or script that starts a background process or scans for one. Cross-reference: `docs/development/bash-coding-conventions.md`.

Resolved at the source: the script that caused the stall stood up a loopback capture server to read a request body, and pi already exposes `onPayload` plus an injectable `fetch` for exactly that. Rewritten to use the hook, the background process is gone, and the class of incident goes with it. The entry is probation because the redirect and explicit-stop prescriptions were not adopted as rules; the process-scan discipline is the recorded part.

## Node

### [A] 2026-09-29  --  A nested `node --test` inherits `NODE_TEST_CONTEXT` and exits 0 without running anything

```text
state: open
scoped: none
legacy: none
mitigation: when a test spawns `node --test` as a child, delete `NODE_TEST_CONTEXT` from the child's environment. Before trusting a child test runner's exit status, confirm the child ran its file: the recursive-run guard warns on stderr and exits 0, so a harness that reads the status alone records every run as green.
```

The mutation gate for the task-queue extension replays each catalog row in a temp mirror and runs the owning suite in a child process. Its first run reported all 22 rows as survivors in 10 seconds, which is faster than the suites it claimed to have run. The cause was the harness, not the extension: `node --test` sets `NODE_TEST_CONTEXT=child-v8` in its children, and a child that inherits the marker and receives a `--test` argument treats the invocation as a recursive run. It prints "node:test run() is being called recursively within a test file. skipping running files." on stderr, runs nothing, and exits 0. Every mutant therefore looked uncaught, and the failure mode is a gate that reports a clean result on a broken subject. The tell is the wall time: a gate that replays suites finishes faster than the suites, and it is the one signal available before the subjects are re-checked by hand.

The family is the [A] 2026-09-25 entry on a mutation that is not a mutation, read one level up: a mutation harness must prove the mutant was exercised by the suite it names, not only that the harness exited zero.

---

## Gotchas  --  operator-raised entries

Entries raised by the operator (tagged `[O]`), migrated from the former `devlog/GOTCHAS.md` (deleted in the unification).

### [O] 2026-08-09  --  Set handover Status Closed before the final commit (close = the commit)

```text
state: open
scoped: M3 -- iteration close one-commit rule (`docs/operations/git_policy.md` transient-commits; `docs/operations/iteration_policy.md` close-produces-one-commit)
legacy: the original fix landed 2026-08-19 and held across the intervening sessions; the defect resurfaced 2026-09-24 as `docs: close` commits whose only change was the handover Status flip and roadmap write-back (recorded in handover `20260924-02`); it resurfaced again 2026-09-26 as a register-closing iteration shipped as a pile -- 13 commits (8 typed `fix:`/`docs:`/`chore:` and 4 `wip:`) across one logical iteration with no open handover, so the operator asked for a retrospective squash
mitigation: a commit whose only change is the handover Status flip or the roadmap write-back is a defect, not a delivery commit. The close edit belongs in the iteration's single delivery commit: set `Status: Closed` and apply the write-back, then commit or amend once. Within the iteration, commit the work when useful, with `wip:` prefix only -- a mid-iteration `fix:`/`docs:`/`feat:`/`chore:` commit is a false delivery surface that reads as closed and later folds away. Do not let `wip:` checkpoints pile up to the close gate: squash each into the evolving delivery commit after a discrete task group, or amend an existing `wip:`. An iteration has an open handover from Step 1; a pile of commits at HEAD with no open handover is a missing-record signal, not progress. The 2026-09-24 governance fix prescribes the close in the transient-commits rule (git_policy) and close-produces-one-commit (iteration_policy); the 2026-09-26 fix adds the discipline-mid-iteration rule to git_policy, iteration_policy, AGENTS.md, and the `wrapup` runbook (`workflow/coding-agent/prompts/wrapup.md`). Screen each subsequent close for a pile of typed intermediates or an un-squashed `wip:` chain; drop the entry when several closes in a row show none.
```

### [O] 2026-08-12  --  Library functions must `return`, not `exit`

```text
state: mitigated
scoped: M3.1 -- sourced-lib / library lint rules
legacy: not swept, fixed on contact
mitigation: library functions sourced by entrypoint scripts must use `return 1`, not `exit 1`. All entrypoints run under `set -euo pipefail`, so a non-zero return triggers script exit identically. Bare `exit` in a sourced function is a latent bug if the function is ever called from a different context (e.g. test harness, sub-shell, interactive use). Entrypoint scripts (`scripts/*.sh`) may use `exit` legitimately. Canonical rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md) rule 3.1. Now gated by `scripts/check_lib_contract.sh`, which runs in the lint gate.
```

### [O] 2026-09-18  --  Mechanical-edit one-liners must carry a match-count guard and a timeout

```text
state: open
scoped: M3 T2 -- tool timeout / run-budget on the bash tool, tests, and lint
legacy: none
mitigation: a perl one-liner intended to count matches in a test file was written with the `/g` modifier against a full-file slurp; it matched nothing, but the loop structure ran forever, emitting a line count that grew into the hundreds of millions before the run was aborted and the log killed. The deeper fix: a mechanical transform that prints only a summary at the end is invisible while it spins. Always (1) bound the tool with `timeout`, (2) have the transform emit a match/replacement count to stderr BEFORE any output, and (3) diff against the input to verify the change before committing. A long-running transform with no stderr progress is the signal to inspect the loop, not to wait. The standing order to run every script through `timeout` is withdrawn: a blanket timeout on a simple script maxes out the wait every run. Move to a test harness with per-test timeouts.
```

### [O] 2026-09-25  --  An autonomous scope proposal must assign the work to units and commits, not only name the deliverables

```text
state: open
scoped: M3 T1 -- Workflow + Policy Organization (iteration and handover policy; roadmap row under T1)
legacy: recurring form of [A] 2026-09-21 "Process improvement: gate-release and scope-first discipline"; that rule covered scope and acceptance criteria but not the commit decomposition of a multi-lane autonomous iteration.
mitigation: for an autonomous iteration, the scope proposal carries a work-unit table naming each unit, its commit type, its file ownership, and its own handover, and the operator confirms that table at Gate 1 before any file is written. One commit per unit. A batch of four fix lanes is four commits, not one. Draw the boundaries by concern, not by file class or commit type: one concern that touches a data file, a dockerfile and a policy clause is one unit, and several concerns that happen to share one commit type are several units.
```

The read-through close was released as "follow through everything autonomously", and the agent then landed three workflow briefs, a 661-line lesson plan, the register repair, and 87 fix rows across four lanes as a single commit with one handover. Each sampled change reviewed fine; the aggregate was unreviewable as a unit of work. The operator expected six commits - one per workstream and one per fix lane, each with its own handover - which is the decomposition the scope proposal should have offered and awaited release on. The gate asked what would be delivered and named the lanes, but it never bound the lanes to commits, so autonomy collapsed them.

A second form recurred one turn after the first fix. The agent applied the rule and then split the structured-data work into three commits by file class - a `refactor` for the data and its documentation, a `build` for the `jq` package, a `workflow` for the policy clause - and the operator collapsed them into one, because they are one concern: the register moves to JSON Lines, and the tooling and the references it needs travel with it. The counter-case sits in the same session: four fix lanes shared the `fix` type and were correctly left as four commits. The distinguishing test is not the kind of file but the unit of approval - would one reviewer accept or reject these changes together? The JSON change is accepted or rejected as a whole; one fix lane is accepted or rejected on its own.

### [O] 2026-09-29  --  `/iter` pauses for confirmation at nearly every step, not only at the gates

```text
state: probation
scoped: M3.2.1 -- `/iter` gate collapse and per-prompt quality pass (roadmap row 83)
legacy: none
mitigation: the operator previously expected to respond to the agent only at Gate 1, Gate 2, and Gate 3. After the loop-to-workflow move, `/iter` stops for confirmation at nearly every step, and each pause reads as a gate, so the operator approves step after step instead of only at the three decision points. The gate-collapse and quality pass (roadmap row 83) must restore gates as the only confirmation points and cut the per-step pauses that add no operator decision. The quality bar is: a step is a gate only when the operator must decide something; a step that only reports progress or awaits an acknowledge signal should not pause the loop. Recorded in handover `20260929-08`.
probation_note: the gate collapse (handover `20260929-10`) folded confirmation into two gates (scope gate, release gate) and a glm quality-pass review found no remaining pedantic pause in `/iter` -- unconditional stops stand only at the scope gate and the Step 7 pre-close summary that feeds the release gate. The entry stays under probation at the operator's direction (2026-09-29): the fix has not been stress-tested by a live interactive run, so it is not confirmed resolved. Maintained at the M3.2.1 close (2026-10-03): still no live interactive run to test the fix against.
```

### [O] 2026-09-29  --  Conversational numbering must be unambiguous

```text
state: open
scoped: M3 T1 -- documentation conventions; `documentation_policy.md` `### References`
legacy: the close-milestone discipline entry's rule ("session-relative finding numbers are valid only in their source conversation") covers cross-conversation validity, not a single exchange that carries two numbered/lettered axes at once (see [A] 2026-09-21 "Process improvement: gate-release and scope-first discipline", rule 2).
mitigation: when the agent presents several numbered or lettered sets in one exchange -- a review's numbered findings beside lettered option choices -- the operator's index reply can map to the wrong axis, and the agent must guess. Present exactly one indexable axis per presentation, or name each axis so the reply is self-mapping ("finding 1", "option A"). Do not place two independent numbering schemes side by side and let the operator index one of them. The numbering convention in `documentation_policy.md` `### References` must state this rule. Raised 2026-09-29 when the agent presented glm's findings (1, 2) beside its own options (A, B), and the operator's ".ok, .ok" indexed the findings, not the options.
```

### [O] 2026-09-29  --  Review prompts: convergence must be optional and the subagent budget echoed

```text
state: open
scoped: M3 T1 -- prompt authoring; `docs/development/prompt-authoring-conventions.md`; review prompts `advisor.md` and `thermo-nuclear-code-quality-review`
legacy: the review-loop-entry guidance on re-runs ("re-run sparingly", AGENT_FEEDBACK `[A]` 2026-09-28 advisor re-run value) covers when a re-run earns its cost, not whether convergence is optional.
mitigation: a review prompt must not hard-mandate "work to consensus". The convergence loop is one mode; a single-pass review is a legitimate invocation and must be allowed. Advisor-style prompts should be invokable as a single consultation without being forced to converge. Thermo-nuclear-style review prompts should be invokable with or without the convergence constraint. Every review prompt should echo a subagent invocation budget -- the prompt states how many subagent runs the loop may use, so the cost is bounded and visible before dispatch. Put the budget in the brief and the invocation. Raised 2026-09-29 when the operator observed advisor "work to consensus" is a hard constraint and thermo-nuclear carries no budget; record in handover `20260929-11`.
```

### [O] 2026-10-01  --  The roadmap's closed rows are ritual re-description, not the durable record; the handover is the durable record

```text
state: open
scoped: M3 T1 -- roadmap policy; `docs/operations/roadmap_policy.md`
legacy: the roadmap `roadmap_policy.md` line "The roadmap is the accumulated decision log for the milestone" and "A closed roadmap entry ... does not change" treat closed rows as durable history; the changelog is the permanent record (roadmap_future already says this).
mitigation: an agent needs to rewrite the milestone's own task rows in the active sub-milestone when the semantics of a name shift (for example renaming `/auto` to `sequential-work`) rather than treating a closed `[x]` row as history to preserve. The handover is the durable record of each iteration's work; the changelog holds a proper description of what landed a milestone at its close. The roadmap is a living task list and its rows may be rewritten freely within the active milestone. A closed row needing correction is a narrow exception, not the default. Raised 2026-10-01 when the agent proposed leaving the roadmap's historical `/auto`/`/parallel-auto` rows untouched because it assumed they were durable history; the operator corrected: the milestone's changelog entry, not the roadmap rows, is the record that outlives the milestone.
```

### [O] 2026-10-01  --  Discussion status semantics: no clean term for a doc rolled into a handover and deleted

```text
state: open
scoped: M3 T1 -- discussion policy status model; `docs/operations/discussion_policy.md`
legacy: none
mitigation: the status table defines `superseded` as "replaced by a newer doc" and `archived` as "terminal -- no active references", but neither covers a discussion doc whose content was rolled into a handover and the file deleted. The `20260721-03` spec cleanup used the word "Deleted" (not a table status) for exactly this case, and recorded the deletion while the deletion commit never landed, so two vestigial specs persisted under `settled` until 2026-10-01. There is no determination rule for `settled` vs `superseded` vs rolled-up. Proposed fix: widen `superseded` to "replaced by a newer record (doc or handover)" and state the rule -- a file is `superseded` only when a successor record explicitly absorbs it (banner or commit message); otherwise it is `settled`, and a rolled-up-and-deleted doc is deleted, not relabelled. Raised 2026-10-01 during the discussion-rename chore.
```

## Agent experience  --  session 20260809-04

### [A] 2026-08-10  --  git operations touching the index/worktree revert uncommitted session work

```text
state: open
scoped: M3 T7 -- sandbox persistence (protect uncommitted session work from git ops)
legacy: none
mitigation: negative-test mutation was reverted with `git restore scripts/stop.sh`, which
reverts to HEAD  --  destroying the session"s uncommitted array refactor in that file (the
mutation check itself passed: the test failed as expected; only the revert was wrong).
The generalized form surfaced the same session: a `git stash` + `git checkout
tests/test_trace_start.sh`, since merged into `tests/test_run_agent.sh`, (a) normalized the stub"s working-tree exec mode to the index
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
```

---
[Post-edit annotation -- 2026-09-01]: corrected misdiagnosis. The container mode churn was due to a host-side `core.fileMode` mismatch (host `false` vs container `true`), not a repo defect. Exec-bit issue resolved on the host by bringing `core.fileMode` to parity (`true`) and normalising host tree exec bits.

### [A] 2026-08-18  --  Multi-question turns and implicit acceptance during a grill-me design walk

```text
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
recurrence (2026-10-02, planning session over the rescope learnings): two new
specifics from the same class. One: after several exchanges, referring to an
open question by number ("Q3 remains") is not helpful -- the question the
number names has fallen out of operator working memory; restate the question
in full when asking. Two: when the operator clarifies an earlier answer, the
agent asked the next question before the clarification was recorded, so the
operator had to choose between answering (growing the list) and not answering
(risking implicit approval). The rule the skill needs: the next question waits
until every open question so far is explicitly resolved -- answered, withdrawn,
or explicitly parked by the operator; parked items are re-asked in full later,
never silently approved. Both apply to the grill-me skill file; the skill
lives outside the repo tree, so the routing is the record.
```

### [A] 2026-08-21  --  Knowledge/diagnostic tests outside `make test` rot silently

```text
state: mitigated
scoped: none
legacy: none
mitigation: `make test-smoke` / `scripts/check_test_smoke.sh` (20260823-07)
syntax-checks every excluded script non-gatingly; the 20260823-06 audit
also removed the three scripts that had already rotted.
```

`tests/knowledge/`, `tests/integration/` and `tests/eval/` are excluded from the runner glob by documented policy (testing_policy.md), which is correct for non-deterministic seams  --  but nothing ever executes or even lint-checks them, so they rot unnoticed. Precedent: `tests/test_dirs.sh`"s header records that its coverage previously lived in "a broken manual knowledge test that sourced a nonexistent libs/dirs.sh path"  --  rotted until noticed by accident. Cheapest fix: a non-gating `make test-knowledge-smoke` running each script under `bash -n` (syntax only) plus shellcheck, catching structural rot without asserting on their nondeterministic behavior.

### [A] 2026-09-02  --  Non-conforming test prefix introduced (`discovery_` vs `knowledge_`)

```text
state: mitigated
scoped: M2.6
legacy: none
mitigation: 2026-09-04 -- both `discovery_tar_*` probes were deleted with the legacy seed pipeline they probed (handover `20260904-06`), resolving the prefix defect by removal. The entry's deeper failure mode -- a `run_test` registration lost to rename-without-grep, silent because unregistered tests never run -- is now caught mechanically by `scripts/check_test_liveness.sh` (`make test-liveness`), which verified both directions on its first run.
```

The tar feasibility probes landed in `tests/knowledge/` as `discovery_tar_*.sh`, a prefix the testing policy does not list. Their content (external-tool behaviour) is the knowledge category, so the defect is the name, not the placement. Cleanup: rename to `knowledge_tar_*.sh`. Cross-reference: the same change introduced the rename-without-grep pattern -- a `run_test` registration was renamed by `sed` and briefly went missing before the suite caught it.

## Agent experience  --  session 20260904-01 (seed transport redesign)

### [A] 2026-09-04  --  Record-layer documents drafted as reasoning traces needed a full rewrite

```text
state: open
scoped: M3 T8 -- STE-clean sweep / record-layer drafting discipline
legacy: none
mitigation: First drafts of the seed-transport ADR and concept doc mirrored the session's reasoning: narrative history, transient identifiers (session ids, commit hashes, handover names), implementation command dumps, and rationale-as-argument instead of rationale-as-mapping. The operator steer (records state, not session history; problem / solution / rejected-with-failure-locus / follow-up; requirements as behavioral contracts in concept docs; interface-level descriptions, commands only for external interactions) required full rewrites of both. Mitigation for next time: before writing a record-layer document, propose its skeleton (section list + what each section holds) in chat and get the structure confirmed; write prose only against the confirmed skeleton. Findings F8-F14 in handover 20260904-01-design-start_resume_rsync_stall.md carry the policy-amendment candidates.
```

## Agent experience  --  session 20260918-10 (thermo-nuclear review pass)

### [A] 2026-09-20  --  A subagent review pass is expensive and unmeasured

```text
state: open
scoped: M3 T2 -- the subagent run telemetry and subagent liveness rows
legacy: none
mitigation: postponed to the M3 T2 telemetry rows, which own the instrument for both halves (liveness and per-run metrics). Verbosity guidance until then: seed each round with the prior round's blockers and state the scope narrowly, because a fresh reviewer re-derives context that a measured, resumable run would not need to. Two cheap measures worked in the 2026-09-27 parallel-track trial and are the interim mitigation: wrap the dispatch in a shell that echoes the exit code and the elapsed seconds, and poll the worktree for liveness rather than the log.
```

The thermo-nuclear review pass over this iteration ran two models per round across ten rounds in two tranches. Each round is a fresh `pi -p` context, so no round inherits the previous round's reasoning, and the log stays empty until the run flushes: neither the main agent nor the operator can see whether a round is progressing, stalled on the provider, or merely slow. There is no per-run accounting of wall-clock, tokens, throughput, latency, tool-call time, or agent turns, so the cost of a review tranche cannot be compared against its yield. The concrete cost of that blindness: a round that reports nothing new still consumes a full model pass, and the operator cannot tell from the outside whether a silent log means "thinking hard" or "network died".

Scope: harness-wide measurement gap, not a bash or skill trap. Cross-reference: the consolidated `edit`-tool failure entry in the `## Consolidated (M3 cleanup 2026-09-21)` section routes to the same M3 `perf`/T2 task, which instruments failed tool calls by cause.

## Agent experience  --  session 20260922 (test-harness isolation, M3.1 U1-U7)

### [A] 2026-09-22  --  A condition on an always-true helper is a vacuous assertion; a masked rc hides real defects

```text
state: open
scoped: M3.1 -- final per-assertion sweep (U7)
legacy: ties to [A] 2026-09-20 "A subagent review pass is expensive and unmeasured" -- the fresh-subagent sweep is the yield side of that entry; resurfaced 2026-09-25 in a second form, a mutation that leaves its guard always true (see the `[[ ]]` entry in Bash)
mitigation: `if trace_grep "..." > /dev/null` always took the pass branch because `trace_grep` ends in `|| true`; the traced operation was never gated. Any conditional on a helper that always returns 0 is a vacuous assertion -- use the `grep -q` variant. The sweep found six such assertions and one silent-green (an empty failed `docker compose config` satisfied its own grep). The reverse face: a masked invocation rc hid a real production defect (`scripts/prune.sh` committed without its exec bit, so `stop --prune` returned 126); the same masks that U4 documented as load-bearing also conceal genuine failures, so assert the rc of any success-expected command.
```

---

## Agent experience  --  session 20260924 (test-suite read-through, phase 4)

### [A] 2026-09-25  --  The probe shell persists its exports between tool calls, so a probe can test the wrong environment

```text
state: open
scoped: none
legacy: none
mitigation: `unset` every variable a probe assumes absent, and pass the environment the probe depends on explicitly instead of relying on the caller's state. When a mutant's result looks identical to the pristine run, check for ambient values before concluding equivalence.
```

The bash tool keeps one shell across calls, so an `export` from an earlier fixture survived into a later probe: `PROVIDER_NAME=pi` from a run_agent fixture made a resume mutant - which passes `$PROVIDER_NAME` where the recovered value belongs - behave exactly like the pristine run, and the mutant looked equivalent. Its real behaviour is an abort under `set -u` at the point where the provider is consumed. The same risk applies to any probe that reads a variable it did not set, and the general form is worth keeping: an identical result is evidence of equivalence only if the environment was controlled.

Scope: agent harness (the persistent tool shell). Cross-reference: [A] 2026-09-22 "Test subshells run `set +e`..." documents shell state leaking from a sourced script into its caller; this entry is the same family one level up, between tool invocations.

### [A] 2026-09-25  --  A finding re-found by a later file pass was recorded as a second row instead of checked against the log

```text
state: open
scoped: none
legacy: none
mitigation: before numbering a new finding row, grep the findings table for the finding itself, not for the class it belongs to. When the defect is already recorded, add the new pass's evidence to that row and name the new row as the same finding; do not give it a second disposition. The read-through's own Format section carries the rule.
```

The phase-4 `confirm.sh` pass probed `eval` on a `.draft-state` field, demonstrated the execution, and filed it as row 242. The phase-2 `draft_state.sh` pass had already recorded the same defect as row 38, with both call sites and an end-to-end chain probe, and row 22's KV-family entry already named `.draft-state` as the family's colon-delimited member with eval'd readers. The duplicate was invisible to the per-file workflow because each pass greps the subject file, not the accumulated log, and the finding arrived from a different direction: a chain from the exporter in phase 2, a direct record in phase 4. A class-level grep would not have caught it either, since the class (persisted record formats) has 17 rows. The operator caught it by asking whether the `.draft-state` entry was consolidated with the KV entry.

A second, purely mechanical form recurred during the `guards.sh` integration. Rows 275 to 283 were appended with an `edit` anchor copied from the previous round, `list \`--interactive\` on the two lines |`, which is row 266's tail rather than the tail of the row just added. The anchor still matched, so the new block landed after row 266 and duplicated row 274. The sorting check showed one extra row (`GAP 275` onward, 284 slots for 283 numbers), which is how it was caught. Anchor on the row you just inserted, not on the one you used last time, and run the contiguity check after every append. The report's Format section already states the rule.

Scope: the read-through's findings log and any long-running review whose rows are numbered. Cross-reference: the report's Format section, numbering policy; row 22, row 38, row 242.

The same class recurred on 2026-09-27 inside a dispatched subagent's output, one level up from the findings log. A unit that replaced two tolerant-mode tests with strict-mode coverage defined a test function whose name already existed in the file and registered it a second time. Bash's last-definition-wins made the first body disappear without an error, the registration liveness gate passed because it checks both directions of the registration contract and not for a name used twice, and the suite's unit count came out one higher than the units actually added. The count is what a reviewer compares against a baseline, so an inflated count is not a cosmetic defect: it is an unverifiable number. The durable fix is a duplicate check in `scripts/check_test_liveness.sh`, filed as a T1 roadmap row (the duplicate test name check in the registration gate); the mitigation until it lands is to account for the arithmetic of the count growth after every dispatched return rather than reading the count as a fact.

### [A] 2026-09-25  --  A heavy test file flakes against the shared deadline, and a timeout hides the whole file's unit count

```text
state: mitigated
scoped: M3.1 - Backpressure
legacy: none
mitigation: declare the budget in the file's first ten lines (`# TEST_DEADLINE: <seconds>`) instead of raising `TEST_TIMEOUT` for every file. The runner reads the declaration and names it when the file expires. The runner reads `TEST_DEADLINE`, and three test files declare one.
```

One 5s default is a single budget for test files whose honest runtimes differ by more than an order of magnitude. A harness file that spawns 20+ probe invocations (`tests/test_dry_run_probe.sh`, 3.4 to 5.4s) or runs the real umbrella gate repeatedly (`tests/test_lint_umbrella.sh`, 4.0 to 5.8s) sits on the deadline, so the 8-way parallel suite run expires it at random as the container loads up. The failure mode is worse than a red test: the file prints no `UNIT:` report, so the aggregate silently drops every unit in the file. `tests/test_dry_run_probe.sh` expired once during a mutation run and the suite read 764 units against a 783-unit baseline, with one timeout and no other sign - which also made the mutation's verdict unreadable, since a timeout is not a proof of anything. Two files now declare 10s (`tests/test_lint_umbrella.sh`, `tests/test_runner_selftest.sh`) and the third is added with this entry. Three more files measured above 5s standalone on a loaded container (`test_start_agent.sh`, `test_runner_selftest.sh`, `test_dry_run_probe.sh`), so the declaration is a pattern, not a one-off.

Scope: `scripts/run_tests.sh` and every test file whose honest runtime is near the default. Cross-reference: [`docs/development/test_harness_mechanism.md`](../docs/development/test_harness_mechanism.md) (The gates, The selftest); the mutation-suite roadmap row, which reads the aggregate to judge a survivor.

## Agent experience  --  session 20260927-04 (parallel tracks experiment)

### [A] 2026-09-27  --  A subagent brief's file list must be closed under the test surface

```text
state: open
scoped: M3 T1 -- the brief-construction roadmap row (derive a unit's owned-file set from the tree)
legacy: none
mitigation: before writing a brief, compute each changed file's test closure by searching the test tree for its basename, and put the result in the brief. State the track's whole owned-file set in the brief rather than a per-unit list, and tell the subagent that its working directory is the worktree, so the harness boundary rule maps onto it instead of contradicting it.
```

The first dispatch of the parallel-track trial produced a unit that changed `scripts/macos_bootstrap.sh` and did not own `tests/test_macos_bootstrap.sh`, because the brief named the script and not its test. The subagent verified the two test files the brief named, quoted its counts, reported `done`, and was wrong: the primary's own full-suite run in that worktree read two failures. A subagent cannot see a defect in a file its brief kept it out of, and the ownership rule that produced the clean report is the same rule that hid the defect. The closure is not a naming convention: `scripts/X.sh` maps to `tests/test_X.sh` for most files and misses `src/libs/cli.sh`, which is covered by `tests/test_cli_lib.sh`, so the closure has to be computed by searching the test tree for the basename rather than by pattern.

Two sub-cases from the same trial. A per-unit file list invents a boundary that does not exist: a repair subagent found a defect in a file its own track already owned, declined to fix it because that unit's list omitted the file, and reported it instead - the right call under the brief it was given, and a wasted dispatch under a track-level one. And a subagent working in a worktree outside the canonical sandbox directory needs the brief to remap the boundary rule explicitly, because the provider-layer instruction not to modify files outside the sandbox is a contradiction until the brief says which directory is the project root.

Scope: brief construction for every dispatched subagent, not only the parallel case. Cross-reference: the trial's design record [`20260927-design-draft-parallel_auto_experiment.md`](discussions/20260927-design-draft-parallel_auto_experiment.md), findings F3 and F4; the unit and brief contract in [`auto.md`](../workflow/coding-agent/drafts/auto.md).

### [O] 2026-10-02  --  The policy forbids task lists in non-active milestones, and the roadmap contradicts it every day

```text
state: open
scoped: none
legacy: none
mitigation: M3.1.2 is planned with its task list and a `Not started` status, and `roadmap_policy.md` gains the invariant the practice relies on -- a milestone holding open rows is never `Complete`
```

`roadmap_policy.md` `### Record shape` states: "Non-active sub-milestones -- carry an objective and scope paragraph only. No task checklist until the sub-milestone becomes active." The roadmap has not followed that for months. M3.2.2 carries four rows and reads `Not started` until this session made it `In progress`; M3.2.3 carries nine; the T tracks carry their work as rows; and this session creates M3.1.2 with two tasks and two moved rows against the same line. The alternative the policy names -- a milestone whose work lives in prose and no task list -- is the shape that produced the eighteen deferred items dropped from the handover chain, which were filed nowhere and surfaced only when a survey looked for them.

The line protects something real: a reader scanning for unchecked work at the top level should find the active milestone, and a milestone reading `Complete` while holding open rows is a status that lies. But the line as written forbids the one thing that keeps work reachable, and the practice it forbids is what the roadmap depends on. The fix is not to restore the line; it is to replace it with the invariant the practice actually relies on, which is that a milestone holding open rows is never `Complete`, and that a milestone's rows move with it.

Raised by the operator during plan session `20261002-23`.

### [O] 2026-10-02  --  A workflow document restated the instructions the workflow already prints

```text
state: mitigated
scoped: T1 - Workflow + Policy Organization
legacy: none
mitigation: `prompt-authoring-conventions.md` carries `## A workflow document owns one step, and owns it whole`; the apply flow is recorded in `diff_packaging.md` and each step prints its own next hop.
```

`/package-branch` carried a `How to apply` section naming `make draft`, `make confirm`, `make reject`, and the soft-reset sequence. Every one of those is printed by a host script, and the section had drifted: it described only the fast-forward route, while a rebased bundle needs `make confirm TARGET_BRANCH=<new-branch> NEW=1`. The drift was silent, because nothing compared the prompt's copy against the scripts'.

Two costs, not one. The reader had no way to tell which copy was current, and the agent could not have told either: it cannot test whether the target fast-forwards, so any route it named would have been a guess from a hash. `make draft` answers it with `merge-base --is-ancestor` and now prints the matching direction.

The rule that persists it: when a workflow hands off to a script, it relays that script's output and adds only what the script cannot know. An instruction the next command prints belongs to that command, and a multi-step flow belongs in the ADR that owns the pipeline rather than in the prompt that starts the first step.

Raised by the operator during handover `20261002-24`.
