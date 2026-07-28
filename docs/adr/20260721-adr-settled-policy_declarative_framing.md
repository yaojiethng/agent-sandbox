# ADR — Declarative Policy Framing

**Status:** settled

## Summary

Policy files under `docs/operations/` state rules declaratively, not as design records. Rationale and justification are concentrated in a single steering sentence per document. Correction forms and format rules live in the type-specific policy, not in a general index.

## Context

The `docs/operations/` directory contains 14 policy files and 3 onboarding guides accumulated over the M1–M2 milestones. These files were written incrementally — each session adding the rule structure it needed without a consistent framing. Over time, several structural problems emerged:

1. **Duplicated correction forms.** The same correction format (amendment block format, inline tag format) is described in `documentation_policy.md` and restated in `handover_policy.md`, `study_policy.md`, and `roadmap_policy.md`. When a correction format changes, all four documents must be updated in lockstep.

2. **Mixed rationale and rule.** Many policies embed justification paragraphs ("A well-run investigation produces a clear recommendation...", "The story is the reasoning record...") alongside declarative rules. This makes grep-targeting difficult — an agent looking for a naming rule must filter prose to find it.

3. **Procedural drift.** Some policies include operational steps (e.g. `audit.skill.md` Step 1–7 procedure) that are execution guidance rather than policy constraints. The boundary between "what the rule is" and "how to execute it" is not consistently drawn.

4. **No central principles document.** The project's principles for how policies relate to each other (one rule one owner, no bridge documents, type-specific ownership) existed only in `AGENTS.md` and session handovers — not in `docs/operations/` where they govern.

## Options Considered

### Option A — Keep current framing, fix overlaps editorially

Edit each policy file to remove the most egregious duplications without a stated principle. Each session decides its own approach.

- **Advantages:** No upfront overhead; fixes can be targeted.
- **Disadvantages:** No governing principle to prevent re-divergence; next agent sees the same overlaps and must re-derive the approach.

### Option B — Declare principles in a central ADR + apply to each file

Write this ADR encoding the declarative framing. Then edit each policy file to conform, one session at a time.

- **Advantages:** Governs future edits; gives agents a rule to check against; the ADR is the rationale anchor — policies don't need to explain themselves.
- **Disadvantages:** Requires initial investment to write the ADR and apply it.

### Option C — Merge all policies into one file with clear sections

Collapse the 14 files into a single `operations_policy.md` with well-named sections.

- **Advantages:** No cross-file duplication possible; single grep target.
- **Disadvantages:** Loses grep-targetability at the file level; 14 files → 1 file creates a monolithic reference that agents must read to find anything. Violates existing `documentation_policy.md` rule about unnamed blocks.

## Decision

Adopt **Option B**.

## Consequences

### Positive

- **Single rationale anchor.** Policy files no longer explain themselves — the ADR is the "why". This compacts each policy file by 15–30% on average.
- **One rule, one owner becomes enforceable.** A future agent reviewing a policy file can check: does this rule duplicate another file? If yes, one must be a link and the other the owner.
- **Type-specific ownership of format/correction rules.** `handover_policy.md` defines handover corrections; `study_policy.md` defines study corrections; `documentation_policy.md` provides a link-only index. Changes propagate in one place.

### Negative

- **Initial pass required.** Each policy file needs a targeted edit to strip rationale paragraphs and move correction details to type-specific owners.
- **Risk of over-trimming.** A policy that is too terse loses context for why the rule exists. The steering sentence per document mitigates this.

### Neutral

- The existing `adr_policy.md` and `documentation_policy.md` linking conventions remain valid — they reference the ADR where the rationale lives, not the other way around.
- No new naming conventions introduced. Policy files keep their current names and section structure.

## Supersedes

None.
