# Maintenance record

## Source

Source: `mattpocock-skills`; see [`NOTICE`](../NOTICE).

## Adapted

**Kept.** The name, the deepening process, the history-first scoping, the deletion test, the HTML report shape and its diagram patterns, the grilling loop, and the ADR-conflict rule.

**Rewritten.** The `codebase-design` and `grilling` calls became local reads: the vocabulary and principles come from [LANGUAGE.md](LANGUAGE.md), the interview from the `grilling` skill, and the domain model from the `domain-modeling` skill. The sub-agent calls go through the `dispatch` skill, one read-only child per brief. The report is written under `.scratchpad/` rather than the OS temp directory, and nothing opens it, because the container has no display. `SKILL.md` and `HTML-REPORT.md` carry the repository-wide ASCII punctuation sweep.

**Added.** This maintenance record, the `domain-modeling` call in the grilling loop, and `disable-model-invocation: true`.

**Dropped.** Nothing. `DEEPENING.md`, `INTERFACE-DESIGN.md` and `LANGUAGE.md` stay, because this repository holds no `codebase-design` skill to move them to; `SKILL.md` points at them where the upstream points at that skill.

## Name

`improve-codebase-architecture` stays. The name describes the act, not the provider, and the skill is still the one a reader reaches for when the work is architecture improvement.

**Install path.** The skill installs from `src/reasoning/agent/skills/improve-codebase-architecture/`; the config-home copy is seeded from this tree. A change to the install target needs this record and the install source changed together.
