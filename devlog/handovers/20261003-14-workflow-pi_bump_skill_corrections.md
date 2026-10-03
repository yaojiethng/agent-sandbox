---
date: 2026-10-03
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Workflow
status: Closed
---

# Handover - Workflow: correct the pi-bump skill

## Objective

Audit `src/reasoning/agent/skills/pi-bump/SKILL.md` against the current tree and the 1.0.0 target, and land the corrections the audit requires. The operator named the hardcoded API response example; the audit supplies the rest.

## Scope

| In | Out |
|---|---|
| The corrections inside `src/reasoning/agent/skills/pi-bump/SKILL.md`, including the file's 35-finding doc-wrap debt, a technical-writing pass, and the operator's constraint relaxation | The `PI_SKIP_VERSION_CHECK` rationale's policy home, which stays with the T12 row that owns it |
| The stale `roadmap_future.md` version-edit instruction | Whether the compat checker joins `make lint`, which stays with its T12 row |
| The generic API response example | The T12 placement-row removal, which rides the roadmap write-back |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The response example carries no version literal and names an unbound placeholder | `grep -n '0\.99\.2' src/reasoning/agent/skills/pi-bump/SKILL.md` returns nothing; the line reads `{"ok":true,"version":"<version>",...}` | `Agent [x]` |
| 2 | The only mention of `devlog/roadmap_future.md` says the bump does not edit it | `grep -n 'roadmap_future'` over the file returns one line | `Agent [x]` |
| 3 | Step 7 carries no session-history narrative | `grep -n '2026-10-02'` over the file returns nothing | `Agent [x]` |
| 4 | Step 2 names the read for a major version | `grep -n -i 'major'` over the file returns the new sentence | `Agent [x]` |
| 5 | The skill's doc-wrap debt is cleared and its `legacyFiles` exemption is removed | `bash scripts/check_doc_wrap_legacy.sh -- src/reasoning/agent/skills/pi-bump/SKILL.md` reports clean; `grep -n 'pi-bump' .markdownlint-cli2.mjs` returns nothing | `Agent [x]` |
| 6 | The relaxed constraints are gone: no `Version policy` section, a fixed commit message in step 7, and no standing `roadmap_future.md` check | read steps 5 to 7; `grep -c 'Version policy'` returns 0 | `Agent [x]` |
| 7 | Step 3 is extension-agnostic and hands each subagent a literal brief | read step 3 | `Agent [x]` |

## Hot files

`src/reasoning/agent/skills/pi-bump/SKILL.md` and `.markdownlint-cli2.mjs`.

## Decisions

1. **The required changes are scoped to the skill file.** The T12 row that needs a policy home (the `PI_SKIP_VERSION_CHECK` rationale) stays out, because it needs a decision this iteration does not make.
2. **The pi-bump procedure stays a skill** (operator, 2026-10-03). The T12 placement row is removed; the skill file is the record.
3. **The skill's doc-wrap debt is cleared in this iteration** (operator ruling). Touching the file ends its `legacyFiles` exemption under the gate's rule, so the iteration reflows the file and removes the entry.
4. **The operator relaxed four constraints** (2026-10-03). The `roadmap_future.md` standing check is dropped. The `## Version policy` section is dropped. Step 7 gives a fixed commit message instead of the commit taxonomy. The installed copy is no longer mirrored. The `Why pi update --self` section became a bare prohibition, which removes the prescriptive rule the T12 row names.

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The skill's step 5 instructs a version edit to the `roadmap_future.md` M7 note, and step 6 requires a `<NEW>` hit there, but that note now carries no version literal | contradiction | the instruction cannot be carried out and the check cannot pass | this iteration |
| `src/reasoning/agent/skills/pi-bump/SKILL.md` sits in `legacyFiles` and carries 35 doc-wrap findings; the legacy wrap gate reports its debt ends when the file is next edited | obstacle | clearing it required reflowing 35 paragraphs to one line each and removing the file from `legacyFiles` | this iteration |
| `tests/test_runner_contract.sh` (10s deadline) exceeded its deadline twice under parallel load, then passed on a third run at 97s | obstacle | a loaded box reports a false red | `devlog/AGENT_FEEDBACK.md` `[A] 2026-10-03` |
| Operator requested a technical-writing review pass at the pre-close gate | steering | applied: the skill was reworded against mode, voice, sentence load, and ambiguity | this iteration |
| Operator asked to relax constraints whose maintenance cost exceeds their benefit | steering | applied: the `roadmap_future.md` standing check, the `Version policy` section, and step 7's taxonomy are gone; the installed copy is no longer mirrored | this iteration |
| Operator asked to cut step 3's historical context and dispatch the evaluation to subagents | steering | applied: step 3 now leads with the assumption table and one subagent per row | this iteration |
| The reframing removes the prescriptive "do not remove the env var" rule, so the T12 row `A prescriptive rule lives only in the pi-bump skill` no longer describes the skill | record | closed in the write-back | `devlog/roadmap.md` T12 `[x]` |
| `task-queue` has no `README.md`, so the skill's per-extension semantics walk has no record for it | gap | filed as a T12 row | `devlog/roadmap.md` T12 (new row) |

## Completed

Roadmap maintenance check: not required. The roadmap matches handover `20261003-13`.

The skill corrected: generic API response example; the `roadmap_future.md` version-edit instruction replaced at three sites by a no-edit confirmation; a major-version read added to step 2; step 7's session-history paragraph replaced by a one-line rule. The file reflowed to one paragraph per physical line (35 findings to 0) and removed from `legacyFiles`.

A technical-writing pass followed the operator's request: step 4's stale "a roadmap note" became "a pin and a settings record"; step 7's "a bump is never one commit" became "not always one commit"; semicolons became periods; over-long sentences split; the "licensing another" idiom dropped. Step 3 is extension-agnostic and hands each subagent a literal brief, and it names an extension without a record as an unaudited surface.

The operator relaxed four constraints: the `roadmap_future.md` standing check, the `Version policy` section, step 7's commit taxonomy (now a fixed message), and the installed-copy mirror. The `Why pi update --self` section is now titled `Do not use pi update --self`. Step 3 was rewritten to be extension-agnostic: each extension owns its bump semantics in its `README.md`, and the skill hands each subagent a literal brief. The probe essay and the `mergeModels` history are gone.
