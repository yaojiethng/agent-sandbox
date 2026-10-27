---
date: 2026-10-26
milestone: M3.2.2 - Audit and Review Workflow Cleanup
type: Workflow
status: Closed
---

# Handover - The two base review skills

## Objective

Create `prose-review` and `code-review` as base skills, so that a review is dispatched from a shell that owns the machinery around the run and names the runbooks it accepts, and so that each runbook is written against one fillable template and then evolves on its own.

## Scope

In scope: the two shells, one template document, and the pass sections they take over.

- `workflow/coding-agent/skills/prose-review/SKILL.md` and `.../code-review/SKILL.md`: when to invoke the family, a guide to meeting a runbook's requirements in this environment -- attribution, scope, a reviewer that changes nothing, the report and its log -- and the runbook index with its aliases and its not-yet-accepted entries.
- One new template document under `docs/reference/`: the slots a runbook fills. Authoring-plane only, cited by both shells and by the pass.
- `workflow/coding-agent/prompts/instruction-cleanup.md`: `## The runbooks` keeps the classification and the coverage-gap restraint and cites the template; `## Creating the shells` is removed.
- `src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md` is read and left as it stands: a runbook is invoked by name without its shell, so its own dispatch sentence is what keeps it self-contained.

Out of scope: the judging content of any runbook; a use case that needs a runbook and has no file, which is filed as a coverage gap rather than written; the three check skills (`doc-maintenance`, `roadmap-maintenance`, `handover-maintenance`), which are procedures the agent runs over its own records and stay where they are; and any review actually dispatched, so no prompt is run and no seat is launched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Both shells exist at their shipped path and carry the frontmatter the authoring bar requires | `ls workflow/coding-agent/skills/{prose,code}-review/SKILL.md`; the frontmatter gate over both paths | Agent [x] |
| Each shell states when its family is invoked, how a runbook's requirements are met in this environment, and the runbook index | a read of both files against the three parts; the index holds one accepted entry per family | Agent [x] |
| The shell's index is the family's registry, and no global list is created | `grep -rn "code-review" docs/reference/` names no second registry | Agent [x] |
| Every runbook named resolves to a file on disk, and every unaccepted payload names its route | one grep per name; the linking gate resolves each target | Agent [x] |
| The template states its slots, and both shells and the pass cite it rather than restating it | each slot name appears once, in the template; `grep -c review_runbook_template` prints 1 in each of the three citing files | Agent [x] |
| The pass no longer states the runbook rules and no longer instructs its own shell creation | `grep -c "^## Creating the shells"` prints 0; the retained text names no slot | Agent [x] |
| No review was run | no session file, run directory or seat log written by this unit | Agent [x] |
| The runbook carries a provenance block naming its source and the revision it matches | `diff <(sed '9,10d' src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md) <the fetched upstream>` prints nothing | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` clean across 12 gates; `bash scripts/run_tests.sh` 1313 of 1313 | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A runbook evolves independently once written, and no shape is coerced across reviews | the operator's direction of 2026-10-26: a review is one self-contained file read by one subagent with one scope, so there is no interface to fix and nothing composes two reviews at run time | this handover |
| The scaffolding in this milestone is for writing a runbook, not for the run itself | what the rules constrain is the author of the file -- declare a scope, refuse a focus outside it, give no verdict from a narrowed run -- so they are authoring rules, not run-time contract | this handover |
| The shell owns the general plane; the runbook owns what it judges | the operator's direction: the shell carries when to invoke the family, how to dispatch, how to collect, and the scaffolding such as the worktree; the runbook carries its own judging standard | this handover |
| The shell guides the translation and enforces nothing | the operator's direction of 2026-10-26: the shell is not an environment or a format, it is guidance on how to achieve what the review file asks for here. Each statement is written as what the runbook asks and how it is met, and a report that cannot name its attribution, its scope or its log is an incomplete translation rather than a violation | this handover |
| The code runbooks stay upstream and are not edited to suit this repository | the translation is the shell's job, so a runbook keeps the review's own rules; the one environment sentence `thermo-nuclear-code-quality-review` carried was removed from the runbook and now lives in the shell | this handover |
| The vendored runbook states its provenance and the one removal it carries | a vendored file that cannot say which revision it came from cannot be re-checked, and the block is where the local edit is declared rather than discovered. The shape is `writing-for-agents`': a source line, the landed commit, and each change named | this handover |
| The shell holds its family's consolidated runbook index | a caller needs one place naming what the family accepts, and the per-family index keeps it from becoming a global registry that restates every shell's table | this handover |
| The authoring artifact is a template document, not a contract | the agent's choice under the operator's direction that the shape is open, so long as a later slot can be added. A template is copied and filled; a contract would name a binding this milestone decided not to have | this handover |
| The template's slots are scope accepted, focus, returns, verdict, and what the run does not judge | these are the five statements every runbook in the corpus has had to make, and a filled slot is what makes "a runbook that accepts no scope is a fault" checkable rather than rhetorical | this handover |
| The pass keeps two sentences and cites the template | the classification -- a fresh context judging a scope is a runbook, a procedure over the agent's own records is a check skill -- belongs to no review document, and the coverage-gap restraint is the fold's own decision | this handover |
| The shell carries three states for a payload: accepted, pending the cleanup pass, coverage gap | a coverage gap is a use case with no file at all; a file that exists and has not been screened is a different state, and folding it into "gap" would hide both the file and the screening it waits on | this handover |
| `prose-review` accepts the vendored `writing-for-agents` reference as its initial runbook | it is the only prose-side review on disk whose screening is settled, and it landed for this call site | this handover |
| The code runbook is cited by its on-disk name, `thermo-nuclear-code-quality-review` | a rename would move the directory, the `name` field and every citation, for a difference no reader acts on | this handover |
| A shell may declare shorthands for a runbook, and `thermonuclear-review` is the code shell's | a caller types the short form that reads naturally; the shorthand resolves to the on-disk name, so the alias names one runbook and does not become a second identifier for it | this handover |
| The shell cites the `dispatch` skill for the dispatch mechanism and states only what is review-specific | role resolution, route memory, the invocation flags, the session file and the exit codes are stated once in `dispatch.md`, and restating them would make a third origin for a fact with an owner. The shell's own content is narrower: which role a review uses, that the caller sets the seat count, that a runbook never names a model, and how the brief and the logs are kept | this handover |
| A runbook keeps its own dispatch sentence | a runbook is invoked by name without its shell, so self-containment requires it. The shell states the family's machinery, which is a different claim from one runbook's role assignment | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| All four reviewer payloads in `.agents/audits/` declare no accepted scope, and three carry a foreign frontmatter shape (`tools:`, `model: opus`, `color:`) | corpus | each is a fault by the pass's own rule, so none can be accepted as a runbook before screening | the cleanup pass's census, as a first target list |
| `architecture-doc-reviewer.skill.md` is described as absorbed by a documentation-audit prompt that no file provides | corpus | a disposition recorded against an artifact that does not exist | M3.2.2's documentation-audit prompt row |
| The convention-pointer gate rejects a runtime skill listed under `## Project conventions`, and rightly: that section names conventions at `.agents/skills/`, while `dispatch` lives in the agent's own root | gate | a shell that reads both kinds must state the runtime one in its body, so the two roots are not conflated | this handover |
| The pass's `## The categories` still named the shared body as a thing with no artifact behind it, once the template became that artifact | corpus | a reader looks for a body of repeated text that is now the template's slots | fixed in this unit: `## The categories` now names the template |
| Every reviewer payload carries no accepted scope, and the four unscreened payloads are the cleanup pass's first target list | corpus | a caller has nothing to dispatch to until each is screened | the cleanup pass's census |
| `thermo-nuclear-code-quality-review` carried no provenance block, unlike `writing-for-agents` | corpus | the file could not say which upstream revision it came from | fixed in this unit: the block is added and the upstream fetched, which shows the file byte-identical to `cursor/plugins` at `6e3d2ea5` apart from the named removal |
| The environment block is a class, not an incident: each pending payload carries the same thing in its frontmatter -- `model: opus`, `tools:`, `color:` -- so a review file is naming its own environment in three of the four cases | corpus | screening one is a strip and a translation rather than a rewrite, and the shell is where the stripped part already lives | the cleanup pass's census, as the shape its first screening takes |
| Three observations from this unit were held in chat and surfaced only after the release gate had released | process | the gate reads the record, so an observation the agent does not write there is not presented at all | `devlog/AGENT_FEEDBACK.md`, the `[O]` entry of 2026-10-26 |

## Completed

| File | Change |
|---|---|
| [`code-review/SKILL.md`](../../workflow/coding-agent/skills/code-review/SKILL.md) | the code shell: when it runs, the translation of a runbook's requirements into this environment, the family's index with the `thermonuclear-review` alias, and three payloads routed to the cleanup pass |
| [`prose-review/SKILL.md`](../../workflow/coding-agent/skills/prose-review/SKILL.md) | the prose shell, the same shape over `writing-for-agents`, with `architecture-doc-reviewer` routed to the documentation-audit prompt |
| [`review_runbook_template.md`](../../docs/reference/review_runbook_template.md) | the five slots a runbook fills, and the one-row extension rule |
| [`instruction-cleanup.md`](../../workflow/coding-agent/prompts/instruction-cleanup.md) | `## The runbooks` reduced to the classification and the coverage gap plus a pointer to the template; `## Creating the shells` deleted; `## The categories` names the template where it named a body with no artifact |
| [`thermo-nuclear-code-quality-review/SKILL.md`](../../src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md) | the one environment paragraph removed, and a provenance block added naming `cursor/plugins` at `6e3d2ea5`. With the block removed, the file is byte-identical to upstream |
| [`devlog/roadmap.md`](../roadmap.md) | row 167 ticks the unit and names the shells, the template and the pass's reduction |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | one `[O]` entry recording that an observation held in chat is invisible to the release gate |
