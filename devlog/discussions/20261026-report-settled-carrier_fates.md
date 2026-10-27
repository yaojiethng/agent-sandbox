---
date: 2026-10-26
type: Report
status: settled
subject: the fate of each review-instruction carrier
---

# Carrier fates

## Objective

Record, per carrier, what happens to it. This table is what the consolidation executes and what the eval grades its rulings against, so a fate that lives only in a conversation is a fate a later session re-derives wrongly.

## The fates

| Carrier | Lines | Fate |
|---|---|---|
| `bash-audit.skill.md` | 29 | subsumed into a `code-review-bash` runbook; deleted, its pointers repointed |
| `kelsey-code-reviewer.skill.md` | 158 | the bash half absorbed into `code-review-bash`, the container half awaiting a container runbook, the file deleted in that unit |
| `architecture-doc-reviewer.skill.md` | 166 | subsumed into a `prose-review` runbook, file deleted |
| `dhh-code-audit.skill.md` | 99 | subsumed: the general parts reach the `code-review` shell, the Rails doctrine is dropped, the JavaScript part becomes a `code-review-javascript` runbook, file deleted |
| `test-quality-campaign.md` | 106 | pending |
| `test-assertion-sweep-brief.md` | 49 | pending |

Every carrier is subsumed, so no carrier survives at its own path and none is vendored. That closes one fault class for the whole set: a defect whose whole content is packaging, being frontmatter, heading text, section order or filename, has no action, because there is no destination file for the edit. The first such site is `bash-audit.skill.md:1`, the absent frontmatter; the fault holds and the fate is `moot`.

## The parts of `dhh-code-audit.skill.md`

A file-level fate cannot carry this one: it holds three subjects, and the operator's ruling keeps one of them.

| Part | Lines | Fate |
|---|---|---|
| Core Philosophy | 11-21 | the general plane, deduped against the shell |
| Review Process | 22-43 | the general plane, deduped against the shell |
| For Ruby/Rails Code | 46-55 | dropped: seven bullets of Rails doctrine, no Ruby in this repository, and no owner document to cite |
| For JavaScript/Svelte Code | 56-63 | `code-review-javascript`, as its Focus slot |
| Feedback Style | 64-72 | the general plane, deduped against the shell; two carriers in the set state the same discipline |
| Output Format, including `### Refactored Version` | 73-98 | the general plane, without the rewrite pass |

`code-review-javascript` is the smallest runbook in the set: five questions as its Focus, no conformance pass and no rewrite pass.

## `kelsey` absorbed, and what it holds that the set does not

The ruling is absorb: `code-review-bash` is the survivor, and a second bash runbook would put two standards on one language. Its bash block now opens by naming the pattern set as the better version of every rule in it, so a reader who lands on the file is sent to the entry rather than to the paraphrase.

The file stays for one reason, and it is not the bash half. The Dockerfile rules it carries have no owner: pin the base image, `COPY` over `ADD`, combine `RUN` to cut layers, run as a non-root user, make `WORKDIR`, `USER` and `ENTRYPOINT` explicit, keep the image minimal, use exec-form `ENTRYPOINT`, and ask whether the image rebuilds the same in six months. No pattern file, no convention document and no runbook states any of them; the two documents that mention `ENTRYPOINT` and the non-root user describe this repository's own images rather than stating a rule to review against. Deleting the file deletes the only statement of those rules, so the deletion waits for the container runbook that takes them, and that runbook is the container third of the consolidation row.

The frozen copy in the eval fixture is not an argument for keeping the live file: `tests/eval/instruction-cleanup/room/kelsey-code-reviewer.skill.md.orig` holds the bytes and `SHA256SUMS` names them, so the calibration file is already preserved without a live path.

| Part | Lines | Fate |
|---|---|---|
| Core Philosophy | 11-21 | the general plane, deduped against the shell |
| Review Process, safety audit | 26-38 | the general plane, with the option line and the silent-failure line naming `p-18` and `p-29` |
| Review Process, idiomatic discipline | 39-66 | the general plane; the bash questions become the runbook's Focus, citing ids where the set holds the rule |
| Review Standards, Bash | 88-101 | Focus, citing ids. Seven rules here have no entry, listed below |
| Review Standards, Dockerfile | 102-113 | out of a bash runbook's subject: a container runbook's material, or dropped with the carrier |
| Feedback Style | 114-123 | the general plane, deduped against the shell |
| Output Format | 124-145 | the general plane, without the rewrite pass |
| The Production Test | 146-158 | the general plane |

The seven rules in that block which no entry held at the time of the mapping, and where each went:

| Rule | Fate |
|---|---|
| every variable declared in a library function is `local` | `p-44` in the declaration patterns |
| diagnostics to stderr, the values a caller will use to stdout | `p-45` in the operator-facing text patterns |
| an error names the function, what failed, and what the caller should do | `p-46`, with the last clause dropped: `p-30` leaves the next step to the entry point, so a library that states it is the fault that entry reports |
| arguments validated at the top of every function and every script, stating what was expected | `p-47` in the argument patterns |
| `[[ ]]` and `$( )` over the older forms | `p-48` for the test, and nothing for the substitution: shellcheck's SC2006 is on by default and reports a backtick, which was measured here on version 0.9.0. The test form is not reported, so it needs the entry |
| `git status --porcelain` over flags accumulated from repeated `git diff` | dropped: a git detail the shell gate already settles, and a reviewer reading a delta has nothing to add |
| one construction for an image name across scripts | dropped: a repository-wide invariant, so no reviewer reading one delta can report it |

## A rule a carrier repeats

A carrier that restates a rule now held by a pattern is deduplicated in the same pass that migrates the rule, and the carrier points at the pattern instead of restating it. Two carriers currently restate bash rules, and both are measured rather than suspected:

| Carrier | Site | What it repeats | Disposition |
|---|---|---|---|
| `.agents/audits/bash-audit.skill.md` | `21` | seven rule subjects in one sentence: bare exit in libraries, unquoted expansions, heredocs generating Makefile content, local at top level, export of behaviour flags, a bare true-absorb on pipelines, circular source paths | becomes the successor runbook's Focus, expressed as pattern ids `p-13`, `p-7`, `p-19`, `p-4`, `p-5`, `p-9`, `p-27` |
| `.agents/audits/kelsey-code-reviewer.skill.md` | `17`, `30`, `45`, `46`, `90`, `91` | `set -euo pipefail` demanded at the top of every executable script, "No exceptions", with sourced libraries exempt | corrected against `p-18` in the container runbook: a dual-use script, executed and sourced by tests, puts the flags inside `main()` or the guard |

The kelsey line is a harmful duplicate rather than a tidy one: it demands a top-level `set` in a file the tests source, which is the case `p-18` forbids, so the persona as written would flag correct code as a fault.

## The bridge

A carrier's document became a bridge when its statements and forms moved into the pattern set: the headings stayed, each carrying one line that named the patterns now holding its content. The bridge is gone, and so is the file. Thirty live citations were repointed first, twenty-nine of them by the number-to-id map the bridge headings themselves carried; the stub was kept for the record citations and the two accepted ADRs, then deleted once both of those reasons went. The ADRs were repointed as claim-record corrections, and the operator ruled that a record citation is closed once committed, so only live links must resolve. The three that remained were the friction log's canonical-rules line and two roadmap rows.

## Where the patterns live

The examples that leave `bash-coding-conventions.md` collect in one place, and that place is the runbook that reads them: `workflow/coding-agent/skills/code-review/code-review-bash/patterns/`. The pattern set is the single canonical source for a bash form, so a rule and its example are not kept twice.

The split follows the work rather than the file. The implementer writes what the code needs and is reviewed afterwards, so the implementer is not the reader being served; the reviewer is, and the reviewer arrives holding a runbook. Putting the set beside that runbook means the reviewer reads rules and forms from one dispatch, with no second load and no question of which copy is current. A rule in `docs/development/` points at the pattern instead of carrying it.

A runbook here is a skill folder: `code-review-bash/SKILL.md`, with its `patterns/` beside it. The build counts a skill as any directory under a skills root holding a `SKILL.md`, walked recursively, so the nested folder registers as the skill `code-review-bash` with no second entry at the root; the shell tables it, and its own description says when it applies.

One file per subject, indexed by the runbook's tag table: a pattern entry is reached from a rule or from a tag, and it names neither. Nothing in the pattern set is a reverse index of its callers, because an index of callers is derived state that goes stale the first time a rule is reworded.

## Superseded

This replaces the earlier ruling that a part whose language this repository does not write keeps as a vendored bucket with a provenance block. That ruling assumed a repository may hold a review for a language it never writes; the operator's verdict is that it does not, and that the JavaScript part is a live subject with a home. No file in the set is vendored as a result.
