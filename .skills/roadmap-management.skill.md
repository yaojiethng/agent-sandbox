# Skill — Roadmap Management

## Purpose

Manage `docs/devlog/roadmap.md` and `docs/development/changelog.md` following project policy. Use this skill when asked to update the roadmap, mark completions, or extract a completed milestone.

---

## Before Acting

Read `docs/development/roadmap_policy.md`. All rules, format specifications, and the step-by-step procedure are defined there. This skill does not restate them.

Identify the trigger mode (Trigger A or Trigger B) from the operator's request before reading any other files.

---

## Read Sequence

**Trigger A (completion pass):** read `roadmap.md`, then `changelog.md`
**Trigger B (update pass):** read `roadmap.md` only

---

## Output Shape

- Changelog entry: fenced `changelog` block, ready to append verbatim
- Roadmap changes: targeted edits only — section removal, table row update, task check-offs. No full-file rewrites.
- State what you changed and what the operator needs to do (e.g. "append changelog block, apply roadmap edits")

---

## Constraints

- Do not combine Trigger A and Trigger B in a single pass
- Do not clean up completions marked in the same update
- Do not rewrite sections not affected by the current trigger
