# Gotchas

A persistent record of recurring agent mistakes and code smells witnessed by the operator, chiefly via mid-turn steering. Recorded by the operator. Surfaced to the agent at session open as a primer. Fixed by the agent.

**Writer:** operator.
**Reader:** agent (session-open primer) and operator (pre-close review gate).

Entries are point-in-time records. Reconcile an entry against the current tree before acting on it. If the tree has outgrown an entry, mark it probation; if the entry is superseded  --  its lesson already carried by another entry or record  --  it jumps to probation as well. Either way, follow the normal procedure: wait to see whether it resurfaces; drop it if it does not.

This file is tied into the session's Findings section for recording and into the sub-milestone pre-close review gate for reconciliation. See the finalized-workflow artifact `devlog/discussions/20260809-design-settled-agent_feedback_and_gotchas_workflow.md`.

---

## Preamble - length

If this file grows too long, find a durable resolution (for example, fold the recurring entries into a skill, or fix the underlying stack). Do not build an index. Long length is a signal that the underlying problem needs a permanent fix, not better indexing.

---

## Entry format

Each entry follows this structural template.

```markdown
## [<A|G>] <date> - <short title>

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

## Open gotchas

This section holds the active gotcha backlog. The agent reads it at session open (Step 1) and avoids or re-checks the patterns during the session. A sweep applies a gotcha fix across recent code at sub-milestone cleanup. When gotchas accumulate, fold the recurring patterns into a skill so the loaded surface stays small.

### [G] 2026-08-09 - Policy-text changes need per-section approval even after task-list confirmation

state: open
scoped: none
legacy: none
mitigation: when a session names policy files (`docs/operations/`, `AGENTS.md`), a released task-list gate confirms scope and acceptance criteria, not policy text. Content is confirmed; gates and policy text are released. Present each changed policy section verbatim in chat and wait for an explicit release before writing it.

### [G] 2026-08-09 - Session-relative finding numbers used outside their source session

state: probation
scoped: none
legacy: none
mitigation: durable fix applied (session `20260810-03`): `documentation_policy.md` gained `### Numbering and cross-references` (a number is valid only in the conversation or document where it appears; outside the defining place, use the descriptive name or a link; persistent records do not take numbers from transient lists) and `AGENTS.md` gained the context-aware numbering + code-comment clauses. The known instances (design doc "Session 11b-11e" headings, "M2.7 item 8" code comments, handover_policy "item 13" example) were remediated in the same session. Monitor for resurfacing; when confirmed durable, delete and record in changelog/roadmap.

### [G] 2026-08-09 - Set handover Status Closed before the final commit (close = the commit)

state: mitigated
scoped: none
legacy: none
mitigation: the final commit must include the Closed handover. Set Status to `Closed`, then run `git add -A && git commit`. Do not commit then re-amend to add the Closed marker. Marked mitigated 2026-08-19 (P1): the durable policy fix landed in session `20260809-05` (P2)  --  `iteration_policy.md` Step 8 now reads "The close is the commit"  --  and practice held across the intervening sessions. Monitored through the next few closes; delete when confirmed durable.

### [H] 2026-08-12  --  Library functions must `return`, not `exit`

state: open
scoped: `src/libs/*.sh`, `src/build/*.sh` (sourced libraries, not standalone scripts)
legacy: not swept, fixed on contact
mitigation: library functions sourced by entrypoint scripts must use `return 1`,
not `exit 1`. All entrypoints run under `set -euo pipefail`, so a non-zero
return triggers script exit identically. Bare `exit` in a sourced function
is a latent bug if the function is ever called from a different context
(e.g. test harness, sub-shell, interactive use). Entrypoint scripts
(`scripts/*.sh`) may use `exit` legitimately. Canonical rules: [`docs/development/bash-coding-conventions.md`](../docs/development/bash-coding-conventions.md) rule 3.1.

### [G] 2026-08-18 - Table-row append edits must keep the anchor row in newText

state: open
scoped: devlog markdown tables (handovers, design records, feedback/gotchas)
legacy: not swept, fixed on contact
mitigation: appending a row to a markdown table three times in one session replaced the
anchor row instead of appending (N5-record twice, D7 once  --  each time newText carried
only the new row, dropping the anchor). For any append, oldText must be the anchor row
AND newText must be that same anchor row followed by the new row(s). After a multi-row
table edit, re-grep the table"s row keys and confirm every prior row still exists before
continuing. Same family as the "did the write land?" reflex but distinct: that catches
un-applied edits, this catches overwrite-instead-of-append. Cross-reference: the
agent-side family record is AGENT_FEEDBACK ("did the write land?" reflex entry,
2026-08-09, with resurfacing instances).

### [G] 2026-08-23  --  Close-out propagation greps must sweep the full tests tree

state: open
scoped: M2.6 (any lib/production change with contract language)
legacy: none
mitigation: handover 20260823-09 changed `current_sig`"s contract but its close-out
residue grep covered only `src/`, `scripts/`, and the directly-edited test file  --  stale
"memoized" contract comments survived in `tests/test_trace_build.sh` and
`tests/test_session_inventory.sh` until the operator challenged propagation (fixed within
the same handover"s scope). Rule: the AC "no references to <old contract> remain" sweep is always
`grep -rn <term> scripts/ src/ tests/ docs/ Makefile`, never a file subset; test
comments asserting removed behavior are contract references and count as residue.

### [G] 2026-08-23 - Hollow iterations: content that should be amendments to an open handover

state: open
scoped: session workflow (any active session)
legacy: none
mitigation: operator-authored. During 20260823, two standalone handovers were cut for
content below the unit-of-work threshold: a two-line roadmap registration (-13, deleted)
and a fix iteration that should have amended the same-day ASCII-sweep iteration (renumbered
into -11). Rule: before opening a new handover, check whether the content amends, extends,
or completes work from an Open or same-session Closed handover -- if so, extend that
handover and let the delivery commit absorb it (squash per git policy). Minimum unit of
work for a new handover: implementation, investigation, or a substantive decision. Pure
record-keeping rides along with the next real unit of work.

### [G] 2026-08-31 - Roadmap open-item status can go stale against closed handovers

state: probation
scoped: devlog/roadmap.md (any active milestone task list)
legacy: none
mitigation: several `- [ ]` items stayed open after their resolving handover closed (`20260828-03`, `20260828-04`, campaign findings; cleared in `20260831-09` post-close corrections; the class recurred through 2026-09). Rule, canonical in `roadmap_policy.md#when-the-roadmap-is-touched`: mark `- [x]` in the same iteration its resolving handover closes; never leave the claim implicit. Durable fix `20260912-04`: iteration_policy Step 7 defines a pre-close summary with a Roadmap write-back section (exact row change per task touched; `none worked this iteration` when none); the operator release approves it and Steps 8-9 apply it. Escalate to open if a close again ships without the write-back section.

### [G] 2026-09-01 - Editing or composing a doc whose own policy text forbids the pattern: verify the recipient file's rules first

state: probation
scoped: M2.6
legacy: none
mitigation: when composing or editing a document, open the recipient file and check its own formatting rules before writing prose. I manually column wrapped two policy documents at ~80 characters; the very file being edited (documentation_policy.md `### Line wrapping`) forbids exactly that -- prose is written as single-flowing paragraphs, one paragraph per line, no manual wrap. The compliance failure was visible from the file itself, so it should not have required operator steering to catch. reworked 2026-09-01: the section now states the rule positively (never manually word wrap prose; no line break mid-paragraph, not at sentence boundaries, not at a column limit) -- the old wording's "falls on a sentence or paragraph boundary" licensed the exact misreading recorded here; governed docs swept and unwrapped (content-identical, line structure only); sweep tooling promoted as `scripts/manual/unwrap_prose.sh`. Escalated to probation (durable fix applied); drop if it does not resurface.

Cross-reference: consolidated agent-side record is AGENT_FEEDBACK (hard-wrapped instruction blocks entry, 2026-08-09; resurfaced 2026-09-01, probation lifted to open).

### [G] 2026-09-01 - Broad sweep launched before realigning a redesign task onto its true purpose

state: open
scoped: M2.6
legacy: none
mitigation: when a task is a redesign, confirm the objective and the unit of
work with the operator before starting exploration. I opened this iteration
fixated on the narrow ``partial-supersede status freshness`` framing and ran a
broad roadmap/deferred/gotchas/agent-feedback sweep; the operator steered that
the real objective was a redesign of what an ADR is (a living, component-scoped
rationale record), which subsumed the status problem as a symptom. A redesign
task should first establish purpose, then scope the exploration to it.

### [G] 2026-09-11 - A feedback entry's follow-up note is not a task assignment

state: open
scoped: none
legacy: none
mitigation: AGENT_FEEDBACK entries can carry "follow-up candidate" notes that
diverge from the roadmap (the dual-use-guards entry described sed-extraction
probes as current work after the conventions sweep had deleted them). The
roadmap is the sole task list; a feedback follow-up note is an observation,
not a task assignment. When a feedback entry and a roadmap item disagree,
the roadmap item is the canonical record, and the feedback entry points at
it. Check the tree before writing record text that names files or functions
as current.

### [G] 2026-09-18 - Mechanical-edit one-liners must carry a match-count guard and a timeout

state: open
scoped: none
legacy: none
mitigation: a perl one-liner intended to count matches in a test file was
written with the `/g` modifier against a full-file slurp; it matched nothing,
but the loop structure ran forever, emitting a line count that grew into the
hundreds of millions before the run was aborted and the log killed. The
operator's standing rule applies: run every script through `timeout`. The
deeper fix: a mechanical transform that prints only a summary at the end is
invisible while it spins. Always (1) bound the tool with `timeout`, (2) have
the transform emit a match/replacement count to stderr BEFORE any output, and
(3) diff against the input to verify the change before committing. A
long-running transform with no stderr progress is the signal to inspect the
loop, not to wait.

### [G] 2026-09-19 - A symlinked CLI can resolve to a stale checkout and masquerade as a code regression

state: open
scoped: host surface / install
legacy: none
mitigation: `agent-sandbox` is a symlink into the repo
(`install.sh`: `ln -sfn "$REPO_ROOT/scripts/agent-sandbox.sh" ...`), so ``$0``
resolves to whichever git checkout the link points at. When a matched change
lands in one commit (here `e76c33f`: the dispatcher gained `resolve_identity`
for `start`, and the Makefile.template stopped passing `--name/--project/--sandbox`
in the same commit), the two files are internally consistent ONLY within one
coherent checkout. If the installed symlink points at a tree older than the
matched commit while the project's Makefile.template is newer, `make start`
fails with `Error: --name, --project, and --sandbox are required` -- the old
CLI's `require_base_args`, which read like a regression in the project tree
but was a skew between two on-disk trees. Diagnose before fixing: an error
from a self-locating/symlinked CLI is a red flag for install skew -- resolve
the link (`readlink -f "$(which <cmd>)"`) and check that checkout's git log /
feature presence against the project tree before touching the project source.
A fresh install (re-run `install.sh`/`make install` to re-point the symlink at
the current checkout) resolved it. The interface-contract P2 work is unrelated
to this failure; it touched only identity-independent contract logic.

### [G] 2026-09-19 - A green committed iteration without an open handover is a record defect, not a fast close

state: open
scoped: iteration lifecycle (handover open/close)
legacy: none
mitigation: after handover 20260919-08 (P3) closed, five further iterations ran in the same session, each opened with the operator saying "new iteration" or "next iteration", and NONE created a handover file. The agent implemented, committed (15 commits, correctly typed), and certified the suite green each time, but omitted iteration_policy Step 1 (Open handover) and Steps 8-9 (Close and seed) entirely. The operator's "new iteration" / "next iteration" phrasing IS a Step-1 trigger and must be acted on as such: open the handover file and run the Step-2 scope gate before any implementation, per the workflow table. The commits alone, even correctly typed with docs, do not constitute an iteration; the handover is the close record. A handover-less green delivery is a missing record, not a fast close. This is the inverse of the 2026-08-23 "Hollow iterations" gotcha (too many handovers for one task), where here there were zero handovers across five tasks. The whole post-08 stretch had to be backfilled by reading the pi session log and rebasing the handover files into history.

### [G] 2026-09-20 - A production flag added without updating the test double's argument parser turns the suite red and slow

state: open
scoped: test infrastructure (`tests/stubs/`)
legacy: none
mitigation: commit `ea080bf` added `--progress quiet` to the dry-run `compose up -d` in `src/build/compose.sh`, but did not teach the compose-arg parser in `tests/stubs/docker` that `--progress` takes a value. The parser's catch-all branch then read the value (`quiet`) as the compose subcommand, so the call never reached the `up` branch: the stub never wrote the per-container diagnostics records, and every dry-run test polled the full `DRY_RUN_RECORD_TIMEOUT` default (180s), twice per run, before failing. The suite did not terminate and two test files went red, while the handover recorded the suite as green. Rule: when you add, rename, or remove a flag on any docker or compose invocation that tests exercise, update `tests/stubs/docker` in the same commit, and give the stub parser an explicit value-taking arm for every flag that takes an argument. A catch-all `*)` arm silently absorbs a misparsed token -- the failure appears as a hang or an unrelated assertion, not as a parse error. Verify by running the affected test file, not just the suite tail; a 180s-per-test poll is the signature of a dry-run record wait that never resolves.
