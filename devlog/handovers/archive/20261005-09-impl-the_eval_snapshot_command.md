---
date: 2026-10-05
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - The Eval Snapshot Command

## Objective

Give the eval snapshot an owner: one command whose run produces the frozen transcript, the self-contained repository bundle and the fact sheet an eval needs, so two snapshots taken a month apart have the same shape.

## Scope

An eval snapshot was assembled by hand at the end of the M3.3.1 series, and the process held no script: the transcript was copied, the repository bundled, the operator turns extracted, the session facts read from the environment, and a README written to name what an eval would score. Every step was ad-hoc shell, so the next snapshot would differ, and the differences would be invisible until an eval compared two of them.

The shape follows the container's existing packaging command, which separates mechanism from judgement: `/opt/sandbox/lib/package_branch.sh` writes the artefacts and prints the operator reply block, and the `package-branch` prompt covers the summary name, the reply, and the report when the branch point moved. This unit does the same for the snapshot.

1. **The script writes the facts and the files.** `src/libs/package_eval_snapshot.sh` copies the live transcript, bundles every ref, extracts the operator turns, reads the session facts from the environment and the session state, scans the transcript for credentials, and prints a reply block the prompt echoes.
2. **The prompt covers the judgement.** `workflow/coding-agent/prompts/package-eval-snapshot.md` names the snapshot, states the graded moments an eval would score, triages the credential scan, writes `README.md`, and relays the reply.
3. **The artefacts are fixed.** A snapshot holds `chat.jsonl`, `operator-turns.md`, `repo.bundle`, `bundle-verify.txt`, `commits.txt`, `eval-point.json`, `credentials-scan.txt`, and the `README.md` the prompt writes. The bundle is complete rather than incremental, so an eval can clone the snapshot with nothing else.
4. **The scan reports, and the prompt judges.** The credential scan prints pattern counts and never a matched value. It does not refuse: the transcript of the run that scans it contains the pattern, so a refusal would fire on its own command. The prompt reads the hits and says which are the scan's own text.
5. **The command is documented where commands are.** The container command table, the tool interface, and the provider `AGENTS.md` tool list name it, and the installed agent copy is updated with the provider source.
6. **Tests cover both halves.** `tests/test_package_eval_snapshot.sh` covers the script's artefacts, its fail-closed paths, and the prompt's frontmatter through the existing gate; the prompt's judgement is not machine-checked and this unit does not pretend otherwise.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| One command produces a snapshot with every declared artefact | run the script against a fixture repository; the directory holds the seven files | Agent [x] -- 12 test cases; the direct mode was run over this session and its artefact set matches the hand-made snapshot's |
| The transcript copy is byte-identical to the live session file at the copy | `cmp` the two in the test | Agent [x] |
| The bundle carries every ref and verifies | `git bundle verify`; `git clone` the result and read the history | Agent [x] -- the test clones the bundle and compares the head commit |
| A missing session file or an absent git repository fails closed with a named cause | the test's two negative cases; the finding count is printed, never encoded in the exit code | Agent [x] -- four negative cases: unset, absent, no base, a base that is not a commit |
| The operator turns are extracted in order, and a turn with no text is skipped | the fixture transcript's extraction | Agent [x] -- and a truncated final line is dropped from the turns and reported in the facts, with the copy untouched |
| The credential scan prints counts, never a matched value | the test asserts the reported output holds no fixture secret | Agent [x] |
| The prompt carries frontmatter and names the artefacts it expects | `bash scripts/check_prompt_frontmatter.sh` | Agent [x] -- the gate scans 42 files, one more than before |
| The command is named in the container command table, the tool interface, and both `AGENTS.md` copies | read the four files | Agent [x] -- three of the four: the container command table and both `AGENTS.md` copies. The tool interface was read and left alone, because its `## Commands` section is the host's; container commands live in the host-interface concept |
| `bash scripts/lint.sh` is clean | the command | Agent [x] -- 8 gates, clean in 6s |
| `bash scripts/run_tests.sh` is clean | the command | Agent [x] -- 1101 tests across 75 files, 0 failed |
| The row is written back and the handover closes | `devlog/roadmap.md`; this handover | Operator [ ] |

## Hot files

| File | Why in scope |
|---|---|
| `src/libs/package_eval_snapshot.sh` | new: the mechanical half |
| `workflow/coding-agent/prompts/package-eval-snapshot.md` | new: the judgement half, shipped with the module |
| `tests/test_package_eval_snapshot.sh` | new: the script's cases |
| `docs/concepts/sandbox_host_interface.md` | the container command table and the artefact table |
| `docs/architecture/tool_interface.md` | read and not changed: its `## Commands` section is the host's, and container commands live in the host-interface concept |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` and the installed `~/.pi/agent/AGENTS.md` | the agent-facing tool list |
| `devlog/roadmap.md` | this row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The script writes the facts, the prompt writes the judgement | the split the packaging command already uses, and the half that needs a model is the naming, the graded moments and the scan triage | this handover |
| The bundle is complete, not incremental | an eval must be able to clone the snapshot with nothing else; the host already has the base, but an eval run may not | this handover |
| The credential scan reports and never refuses | the transcript holds the scan's own pattern, so a refusal fires on every run after the first | this handover |
| The command does not call `/package-branch` | the two produce different artefacts for different readers, and the snapshot's README names the sibling bundle when one exists | this handover |
| The prompt ships with the module, not the harness | the module is the toggle unit, and a project that enables it gets the command with the rest of its payload | `docs/adr/module_instruction_payload.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The first draft of the turn extractor numbered every turn as turn 1. jq streams one document per input line, so `to_entries` ran once per line and saw a one-element array each time. The fix is `--slurp` with an explicit `.[]`, and the test case that catches it asserts the second turn's number, not only that a turn exists. | defect, caught by the test | current iteration | Triaged to: `src/libs/package_eval_snapshot.sh` and `tests/test_package_eval_snapshot.sh` |
| A `node -e` transform that rewrote the test file doubled its content. The replacement string held `$'`, which JavaScript reads as the portion of the input after the match rather than as literal text, and both guards the feedback record prescribes -- a replacement count and a size comparison -- were skipped. The file still parsed and the suite still ran, so the damage surfaced only at a later anchor. Recorded as a recurrence on the entry that already prescribes the guards. | defect, silent | current iteration | Triaged to: `devlog/AGENT_FEEDBACK.md`, the 2026-09-18 entry, extended with the mechanism and the function-replacer fix |
| The scan counted three `sk-` hits in the live transcript, and none is a credential: two are the scan's own pattern text, one is the fake key the session wrote into a throwaway fixture. The prompt's triage step is what establishes that, which is why the scan reports rather than refuses. | evidence | current iteration | Triaged to: the prompt's Step 3 and the snapshot's README step |
| The eval trial ran against the wrong subject. The intended case was the commit-body budget failure (`git_policy.md` and its `AGENTS.md` pointer); the run instead tested whether a checker skill adds value, so its null result is void for the intended question. What the trial did validate is the machinery: fixture from a snapshot, the per-run config directory as the isolation switch, blind grading, the benchmark. | process, caught by the operator | current iteration | Triaged to: the eval-skill row, where the commit-body case is the first case |
| The trial found a defect in the skill under test. `roadmap-maintenance` check 3.10 makes a section blurb the placement authority, which contradicts `roadmap_policy.md` `**Roadmap task placement**` and certifies the misfiling the check exists to catch. The trial's own case set also failed to discriminate: one case failed in both configurations, the other passed in both, and the one observable difference -- the skill's JSON record schema against the baseline's prose -- is not asserted. No change made; the correction is pending direction. | defect, caught by trial | open | Triaged to: `workflow/coding-agent/skills/roadmap-maintenance/SKILL.md`, pending operator direction |

## Completed

| File | Change |
|---|---|
| `src/libs/package_eval_snapshot.sh` | new: the transcript copy, the bundle and its verification, the turn stream, the commits, the session facts, the credential scan, the status file and the reply block |
| `workflow/coding-agent/prompts/package-eval-snapshot.md` | new: the summary, the reply, the scan triage, the README and the report |
| `tests/test_package_eval_snapshot.sh` | new: 12 cases across the artefacts, the turn stream, the partial line, the scan, four fail-closed paths, the summary shape and the explicit baseline |
| `docs/concepts/sandbox_host_interface.md` | the container command table |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` and `~/.pi/agent/AGENTS.md` | the agent-facing tool list, both copies identical |
| `devlog/AGENT_FEEDBACK.md` | the recurrence on the mechanical-transform entry |
| `devlog/roadmap.md` | this row, the M3.3.1 survey write-back, and the T1 eval-infrastructure row: the five open rows of the sub-milestone annotated with their measured state, the eval-snapshot capability filed as a subtask under the T1 row `Skill and prompt eval infrastructure`, and that row rewritten to name its two process sources, the trigger clause and the negation caution, and the deletion below |
| `tests/eval/eval_protocol.md` `[REMOVED]` | the draft protocol is deleted. Its mechanisms are weaker than the agentskills guide's, and its two surviving ideas -- a policy change re-runs the checks that depend on it, and a textual check mis-reads negation -- moved into the T1 row. Consumers updated: the smoke checker's header comment and directory list, the test-harness mechanism doc, and the story's two Working Documents entries |
| eval trial, artefacts outside the tree | the agentskills loop reproduced end to end on two cases against fixtures built from this session's snapshot: isolated with-skill and baseline runs under a per-run config directory, blind grading with evidence, and a benchmark. Artefacts at `$HOME/workspace/output/evals/skill-eval-roadmap-maintenance/iteration-1/`; the repo carries none of them |
