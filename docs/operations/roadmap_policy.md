# Roadmap Policy

Policy rules for `docs/development/roadmap.md`.

---

## Update Sequence

Every update follows this order:

1. **Clean up the previous update** — summarise fully-checked subsections into a conceptual outcome sentence in the milestone description and remove them; collapse fully-checked milestones into a completion paragraph; remove empty headers.
2. **Mark new completions** — check off tasks completed in this update. Leave them in place for the next update to clean up.

Never clean up completions you just marked. Never mark completions without cleaning up first.

---

## Rules

**Completed milestones** — replace task list with a single outcome paragraph. Keep `*Complete.*`. Remove all checklist items.

**Completed subsections** — add a conceptual outcome sentence to the milestone description, then remove the subsection header and checklist. The sentence must describe what the system can now do, not which files changed. File changes are visible in git history; the roadmap preserves conceptual outcomes.

**Task granularity** — identify the file and nature of change. Omit implementation detail; link to the discussion document if context is needed.

**Persistent sections** — Milestone Summary table, Milestones & Tasks, Known Limitations, Future Security & Network Hardening, and Governance Hardening are structural and must not be removed.

**Empty sections** — remove immediately.
