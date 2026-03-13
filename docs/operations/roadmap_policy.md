# Roadmap Policy

Policy rules for `docs/development/roadmap.md` and `docs/development/changelog.md`.

---

## Update Sequence

Every update follows this order:

1. **Clean up the previous update** — summarise fully-checked subsections into a conceptual outcome sentence in the milestone description and remove them; extract fully-checked milestones to the changelog; remove empty headers.
2. **Mark new completions** — check off tasks completed in this update. Leave them in place for the next update to clean up.

Never clean up completions you just marked. Never mark completions without cleaning up first.

---

## Procedure

Two trigger modes. Identify which applies before acting.

**Trigger A — Completion pass** (a milestone just finished):
1. Read `roadmap.md` and `changelog.md`
2. Write changelog entry for the completed milestone (see Changelog Format)
3. Output entry as a `changelog` fenced block for operator to append
4. Remove the milestone section from `roadmap.md` Upcoming Milestones
5. Update the Milestone Summary table row: remove anchor link, set status to `[Complete — see changelog](changelog.md)`

**Trigger B — Update pass** (tasks completed within an in-progress milestone):
1. Read `roadmap.md`
2. Clean up previous update: collapse any fully-checked subsections into a conceptual outcome sentence; remove their headers and checklists
3. Mark newly completed tasks with `[x]`
4. If all tasks in the milestone are now checked, treat as Trigger A on the next pass — do not combine cleanup and extraction in the same update

Produce all roadmap edits as targeted changes, not full-file rewrites.

---

## Rules

**Completed milestones** — extract to `changelog.md` using the format below, then remove the milestone entry from the roadmap entirely. Update the Milestone Summary table row to link to the changelog instead of the milestone anchor.

**Completed subsections** — add a conceptual outcome sentence to the milestone description, then remove the subsection header and checklist. The sentence must describe what the system can now do, not which files changed. File changes are visible in git history; the roadmap preserves conceptual outcomes.

**Task granularity** — identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**Persistent sections** — Milestone Summary table, Upcoming Milestones, Known Limitations, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed.

**Empty sections** — remove immediately.

---

## Changelog Format

Changelog entries live in `docs/development/changelog.md`, appended in milestone order. Each entry is self-contained and can be produced without reading the rest of the file.

### Entry structure

```
## M{n} — {Title}

*{One sentence: what the system can now do.}*

{Two to four sentences: what was built — mechanisms, key decisions, concrete outcomes. No file lists. No future language. Capability first, mechanism second.}

---
```

### Writing guidance

- The italicised summary is the capability sentence. Write it as a statement of what an operator or agent can now do that they could not before.
- The body sentences describe the mechanism — what was built to enable the capability and any key decisions made. Mention concrete components (scripts, pipeline stages, config patterns) without listing files.
- Do not use future language (`will`, `plan`, `eventually`). The changelog describes completed work only.
- Balance: M1/M1.1-style entries are too abstract; M1.2/M1.3-style entries from the old roadmap are too implementation-heavy. Aim for one capability sentence plus two to three mechanism sentences.

### Agent snippet output

When producing a changelog entry during a milestone completion pass, output the entry as a fenced block so it can be appended to `changelog.md` without reading the existing file:

````
```changelog
## M{n} — {Title}

*{Capability sentence.}*

{Mechanism sentences.}

---
```
````

The operator appends the block contents verbatim to `changelog.md`.
