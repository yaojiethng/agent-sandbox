# Skill — Handover Audit

## Purpose

Formalised handover audit workflow — operator-invoked reviews of closed handovers to catch deferred items dropped across sessions, incomplete close sequences, non-standard formatting, dangling references, and unresolved findings before they compound.

An audit is not a session type. It is invoked by the operator as needed.

## Before Acting

Read `docs/operations/handover_policy.md` and `docs/operations/documentation_policy.md` — the audit applies rules defined in both. The audit does not restate them.

---

## When to Audit

| Trigger | Scope | Recommendation |
|---|---|---|
| **Periodic** | Last N handovers (2 weeks or 20 sessions, whichever comes first) | Run when deferred items have survived multiple hops or operator suspects items have been dropped |
| **Event-driven** | Handover chain containing a specific deferred item | Run when a deferred item has survived 2+ hops without resolution |
| **Recovery** | Prior session's handover | Already covered by Step 1 recovery check per `handover_policy.md` |

---

## Audit Scope

A full handover audit covers:

1. **Status completeness** — every handover in scope must have `**Status:**` set to `Active` or `Closed`.
2. **Structural completeness** — every handover must have all required sections (Objective, Scope, Carried forward, Acceptance criteria, Hot files, Decisions made this session, Mid-session findings, Completed this session, Deferred items, Next session), with null markers where empty.
3. **Deferred item chain integrity** — each deferred item with a next-session destination must have been resolved or re-deferred in the target session.
4. **Carry-forward escalation** — a deferred item that has survived 2+ hops must be escalated to the roadmap per `handover_policy.md`.
5. **Mid-session findings triage** — all entries must be triaged at session close.
6. **Dangling references** — files, functions, or paths referenced in Completed or Hot files sections that no longer exist.
7. **Standardised status values** — `Active` or `Closed` only.

---

## Audit Procedure

### 1. Scope the audit

Determine the set of handovers to review:
- **Periodic:** list all handovers in `devlog/handovers/` within the date range. Sort by date.
- **Event-driven:** trace the deferred item through `## Next session` and `## Carried forward` sections.

### 2. Structural scan

For each handover in scope:

```bash
grep "^## " path/to/handover.md
```

Verify all required sections are present and headers match canonical casing.

Anomalies fall into two categories:

- **Can be 1:1 replaced** — headers with a direct canonical equivalent differing only in casing. Replace directly and record in a `[CORRECTION]` block.
- **Cannot be 1:1 replaced** — headers with custom content and no canonical equivalent. Add an `[AMENDMENT]` block and leave content unchanged.

### 3. Deferred chain audit

For each non-null deferred item, trace forward:
1. Read the destination session's `## Carried forward` — was the item picked up?
2. If yes, was it resolved (Completed table) or re-deferred (Deferred items)?
3. If it disappeared without resolution, flag as **dropped**.
4. If it survived 2+ hops, flag for **carry-forward escalation**.

### 4. Status audit

Check each handover's `**Status:**`:
- `Active` — only for the most recent handover
- `Closed` — all others
- Any other value is a correction

### 5. Dangling reference check

For each file mentioned in `## Completed this session` or `## Hot files`:
- Verify the file exists at the referenced path
- If deleted or renamed, add a `[CORRECTION]` noting the deletion context

For each function or variable mentioned:
- Grep the codebase to confirm it still exists
- If removed, the reference is stale

### 6. Corrections and amendments

Apply corrections per `handover_policy.md`:
- `[CORRECTION — YYYY-MM-DD]` — factual errors: edit inline, append correction block
- `[AMENDMENT — YYYY-MM-DD]` — non-standard formatting or policy violations that cannot be cleanly corrected
- `[REMOVED in MX.X]` — abandoned or superseded items

### 7. Report

Produce a structured audit report covering:
1. Handovers examined and date range
2. Corrections applied (summary table)
3. Dropped deferred items (with originating handover)
4. Items escalated to roadmap
5. Dangling references found
6. Policy violations noted
