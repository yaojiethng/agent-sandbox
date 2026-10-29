---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The general review payload, and the carrier that held it

## Objective

Persist what is general in the `kelsey-code-reviewer` payload as a file beside `thermo-nuclear-code-quality-review`, and delete the carrier that held it. The carrier's shell standards are entries in `code-review-bash`, its container standards are entries in `code-review-container`, and what remains is a judgement about production readiness that neither runbook supplies.

The new file is not a runbook yet. It names no scope, so the `code-review` shell cannot dispatch it, and it enters the runbook table only after it produces a finding on code it was not written for. The test is not run in this iteration: the operator has no case in mind, and it will run beside `thermonuclear-review` on the next code review that happens.

## Scope

In scope:

1. `workflow/coding-agent/skills/code-review/runbooks/kelsey-code-reviewer/SKILL.md`, holding the carrier's residue: cleaned frontmatter, the persona and its standard, the core philosophy, one section of judgements that generalise past a language, the feedback discipline, the output shape, and the production test.
2. the removal of the two standards blocks and the two review-process subsections that state bash and Dockerfile rules, since both subjects now have a pattern set.
3. the removal of the frontmatter the harness cannot parse or honour, and of the worked examples inside the description.
4. the rewording of a shell and image specific example or question wherever one carried the general rule.
5. `.agents/audits/kelsey-code-reviewer.skill.md` deleted, and every pointer to it repointed or removed.
6. the new file listed in `code-review`'s payload-under-test table with its route, and not in the runbook table.

Out of scope: running the test. It needs a code review to sit beside, and none is being run for it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The carrier does not exist | `git ls-files .agents/audits/kelsey-code-reviewer.skill.md` prints nothing | Agent [x] -- deleted, and its bytes stay in the eval fixture and in history |
| No live document claims the carrier is current | every live grep hit names the new skill, a retirement, or the fixture | Agent [x] -- five sites: the surface-area row says deleted, the base skill names the new file, and two roadmap rows name the deletion |
| The new file names no bash or container rule | a grep for each of `set`, `Dockerfile`, `ENTRYPOINT`, `apt-get`, `COPY`, `curl` and `local` prints nothing | Agent [x] -- 81 lines, no hit |
| The new file names no scope, and so cannot be dispatched | it is absent from the runbook table, and the file states no slot that would give it one | Agent [x] -- the payload-under-test table is its only entry anywhere |
| The frontmatter the harness cannot read is gone | a grep for a `tools`, `model` or `color` key prints nothing, and the description holds no `<example>` | Agent [x] -- three keys, and the escaped examples, all gone |
| The judgment that generalises is still there, in the carrier's words where they were general | a diff of the new file against the carrier's lines 67-87 and 116-160, read for lost distinctions | Agent [x] -- nine judgements, five feedback rules, five output sections and four questions, with two bullets removed and three phrases reworded; the handover's Completed rows name them |
| The gate is clean and the suite passes | `bash scripts/lint.sh`, `bash scripts/run_tests.sh` | Agent [x] -- the gate is clean across 13; the suite passes 1321 |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The material is kept as a payload under test, not as a runbook | the operator's ruling. Its checkable residue is about five judgements, and a runbook that names no scope is a payload rather than a runbook, so listing it beside two measured runbooks would claim an equivalence it has not earned | this handover |
| The known faults ship as they stand | `Concrete` demands code with every observation and `Prioritised` promises three tiers while the output shape emits two. Nobody has ruled them, and pre-correcting them removes what the test would find | this handover |
| The residue keeps the persona | persisting the reviewer means persisting what makes it one, and the persona is what the material's remaining judgements are framed by. The roadmap row asking whether a runbook carries one now has an instance to read | this handover |
| The skill file carries review instructions only | the operator's ruling. Provenance, the test route and what was cut are the record's subject, and a skill that carries them reads as the agent talking about its work instead of instructing a reviewer | this handover |
| A shell or image example becomes the general rule it carries, and is not restated in a general file | the same single-source rule the pattern set is built on: a general reviewer that carries a bash example is a second copy of a bash entry | this handover |

## Decisions pending

| Code | Item | State | Ruling |
|---|---|---|---|
| L1 | Does the payload survive its first test, or retire into the `code-review` shell's shared body | Open | The next code review that runs `thermonuclear-review` runs this beside it, and the operator reads both reports |
| L2 | Whether the feedback discipline and the output shape are this payload's, or the `code-review` shell's shared body | Open | Both are stated here because they were stated in the carrier. Where they finally live follows from `L1`, since a retired payload pushes them to the shell |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The carrier restated eight bash rules and eighteen language rules under `## Review Process`, not only under the two `## Review Standards` headings | finding | removing the two headings alone would have left that duplication in a file deployed to the agent skill root, which is the state the whole cleanup exists to remove | this iteration's scope, items 2 and 4 |
| One architecture bullet and one production question name this repository rather than code | finding | the host and container split is this repository's layering, and "would this image rebuild in six months" is a build question. Both went; the rest generalised by dropping a path or a language word, which changes no requirement | the Completed rows, which name what went |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/skills/code-review/runbooks/kelsey-code-reviewer/SKILL.md` | new, 81 lines: the persona and its standard, six philosophy bullets, nine judgements, five feedback rules, five output sections and four production questions, with frontmatter the harness can read and no note about where it came from |
| `.agents/audits/kelsey-code-reviewer.skill.md` | deleted. Its shell rules are entries, its image rules are `p-49` to `p-57`, its general residue is the skill above, and nothing it stated is now unowned |
| `workflow/coding-agent/skills/code-review/SKILL.md` | the payload-under-test row replaces the carrier row, with the route that makes it dispatchable |
| `.agents/audits/surface-area-report.md` | the carrier row becomes `(deleted)`, naming where each of its three parts went |
| `devlog/discussions/20261026-report-settled-carrier_fates.md` | the `kelsey` row, the section that said the file stays, and all eight parts of its table now state what landed |
| `devlog/roadmap.md` | the consolidation row records the deletion and the payload; the persona row gains the instance it now has to read |
