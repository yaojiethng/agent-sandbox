# Roadmap Policy

Policy rules for `docs/development/roadmap.md`, `docs/development/roadmap_future.md`, and `docs/development/changelog.md`.

---

## When the Roadmap Is Touched

The roadmap is not updated continuously during a session. It is touched at two defined moments in the minor loop and once at major loop close. Do not update it outside these moments.

**Minor loop Step 1 (session open):**
1. Read `roadmap.md`
2. Compact any fully-checked subsections from the previous session — collapse into a conceptual outcome sentence, remove the header and checklist
3. Read the remaining task list into the handover

**Minor loop Step 9a (session close):**
1. Mark all tasks completed this session with `[x]`
2. Do not compact — leave checked items in place for the next session's Step 1 to collapse

**Major loop close (Trigger A — milestone complete):**
1. Read `roadmap.md` and `changelog.md`
2. Write and output the changelog entry for the completed milestone (see Changelog Format)
3. Remove the completed milestone section from `roadmap.md` Upcoming Milestones
4. Update the Milestone Summary table row: remove anchor link, set status to `[Complete — see changelog](changelog.md)`
5. Promote the next milestone from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones` (see Milestone Promotion below)

**The separation between Step 9a and Step 1 is load-bearing.** Compacting at the same session that marks completions removes the only verification point — the operator cannot confirm what was done if the evidence is already collapsed. The session boundary enforces this: Step 9a marks, the next Step 1 compacts.

Produce all roadmap edits as targeted changes, not full-file rewrites.

---

## Rules

**Completed milestones** — extract to `changelog.md` using the format below, then remove the milestone entry from the roadmap entirely. Update the Milestone Summary table row to link to the changelog instead of the milestone anchor.

**Completed subsections** — add a conceptual outcome sentence to the milestone description, then remove the subsection header and checklist. The sentence must describe what the system can now do, not which files changed. File changes are visible in git history; the roadmap preserves conceptual outcomes.

**Task granularity** — identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**Persistent sections** — Milestone Summary table, Upcoming Milestones, Known Limitations, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed.

**Empty sections** — remove immediately.

---

## Milestone Promotion

Future milestone detail lives in `roadmap_future.md` to keep `roadmap.md` focused on the active milestone. When a milestone completes (Trigger A), the next milestone is promoted from `roadmap_future.md` into `roadmap.md`.

**Promotion steps:**
1. Move the milestone section from `roadmap_future.md` into `roadmap.md` under `## Upcoming Milestones`
2. Update the Milestone Summary table row in `roadmap.md`: add anchor link, set status to `In progress`
3. Remove the section from `roadmap_future.md`

**Which milestone to promote:** the next incomplete milestone in the Milestone Summary table order. If the next milestone has sub-milestones (e.g. M2.1, M2.2), promote the parent section and all sub-milestone sections together as a single block.

`roadmap_future.md` is a planning document, not a historical record — sections may be rewritten freely as understanding evolves. The changelog is the permanent record.

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
