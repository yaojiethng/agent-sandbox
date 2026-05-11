# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Workflow
**Status:** Closed

## Objective

Revise the `/new-session` prompt template to improve session directive handling, readability, and session list distinguishability.

## Scope

Workflow session. No implementation tasks. One prompt template revised.

## Carried forward

None.

## Acceptance criteria

Not yet defined. Workflow session — no operator-runnable AC apply.

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `.pi/prompts/new-session.md` | Session directive block rewritten; directive moved to top; scene-setting removed; frontmatter description cleaned | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Session directive moved to top of template body as blockquote | Directive is the distinguishing content per session; moving it top makes session list previews meaningful and scannable | `.pi/prompts/new-session.md` |
| `> $@` blockquote used as directive slot | Visually separates substituted user input from surrounding instructions; empty blockquote renders as visible empty form slot, handled explicitly by branching logic | `.pi/prompts/new-session.md` |
| Three-case focus logic replacing single prose paragraph | Original `$@` mid-sentence substitution was jarring and logically ambiguous; explicit case structure is more reliable for no-thinking models | `.pi/prompts/new-session.md` |
| Session type table inlined in template | Type classification is load-bearing in the divergence check; referencing `handover_policy.md` alone is insufficient if the policy is not in context | `.pi/prompts/new-session.md` |
| Two-step mechanical divergence check (type then topic) | "Materially different goal" prose was too vague for consistent model behaviour; type mismatch is a binary check; topic overlap check uses keywords, named files, and task references | `.pi/prompts/new-session.md` |
| Ambiguous topic overlap → ask operator, not guess | Topic overlap with matching types is not always determinable from the directive alone; asking is cheaper than a wrong case classification | `.pi/prompts/new-session.md` |
| Case labels retained in template | Labels aid model reasoning in 128k no-thinking context; "Case 1/2/3" not surfaced in responses — workflow correctness prioritised over labelling | `.pi/prompts/new-session.md` |
| "Running Steps 1, 1b, and 6" opening line cut | Scene-setting for operator, not instructions for model; step numbers in Gates are load-bearing and retained | `.pi/prompts/new-session.md` |
| `iteration_policy.md` reference preserved in Orient step | Reference is useful for operator orientation; moved inline as a parenthetical link rather than standalone sentence | `.pi/prompts/new-session.md` |
| Step numbers removed from frontmatter description | Autocomplete description should describe what the template does, not which step numbers it covers | `.pi/prompts/new-session.md` |
| Section naming confirmed: "Next session" | Verified against `handover_policy.md` — section is consistently named "Next session" throughout | `handover_policy.md` (read-only, no change) |
| `handover_policy.md#session-types` anchor to be verified | Link used in diverges branch; anchor correctness depends on header rendering as `## Session Types` | Flagged — operator to verify |

## Completed this session

| File | Change summary |
|---|---|
| `.pi/prompts/new-session.md` | Directive blockquote moved to top of body; three-case focus logic with inline session type table and two-step mechanical check; "Running Steps 1, 1b, and 6" opening line removed; `iteration_policy.md` reference preserved as inline link in Orient step; step numbers removed from frontmatter description |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation — continue Unit sequence.

Read `docs/development/roadmap.md` M2.3 pending section for current unit and dependency order. Upload the files required for the next unit before beginning.

**Watch-outs:**
- Verify `handover_policy.md#session-types` anchor resolves correctly before the revised template is used in production.
- Policy documents amended in the prior session (`handover_policy.md`, `iteration_policy.md`, `roadmap_policy.md`, `documentation_policy.md`) — ensure repo versions are up to date before the next implementation session opens.

Context handover: [`20260422-04-impl-remove_checkpoint_tags.md`](handovers/20260422-04-impl-remove_checkpoint_tags.md)
