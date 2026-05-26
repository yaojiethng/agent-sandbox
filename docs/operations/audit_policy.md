# Audit Policy

**Purpose:** Formalise the handover audit workflow — operator-invoked reviews of closed handovers to catch deferred items dropped across sessions, incomplete close sequences, non-standard formatting, dangling references, and unresolved findings before they compound.

An audit is not a session type. It is invoked by the operator as needed — typically as a housekeeping or workflow session when the handover chain has grown unwieldy or a specific deferred item needs tracing.

---

## When to Audit

| Trigger | Scope | Recommendation |
|---|---|---|
| **Periodic** | Last N handovers (recommended: 2 weeks or 20 sessions, whichever comes first) | Run when deferred items have survived multiple hops or operator suspects items have been dropped |
| **Event-driven** | Handover chain containing a specific deferred item | Run when a deferred item has survived 2+ hops without resolution — carry-forward escalation check |
| **Recovery** | Prior session's handover | Already covered by Step 1 recovery check per [`handover_policy.md`](handover_policy.md#at-session-open-step-1) |

---

## Audit Scope

A full handover audit covers:

1. **Status completeness** — every handover in scope must have `**Status:**` set to `Active` or `Closed`. Non-standard values (`✓ Complete`, `` `Complete` ``, `` `Closed` ``) are corrections.

2. **Structural completeness** — every handover must have at minimum the following sections (with null markers where empty):
   - `## Objective`
   - `## Scope`
   - `## Carried forward` (or `None.`)
   - `## Acceptance criteria` (or `Not yet defined.`)
   - `## Hot files`
   - `## Decisions made this session` (or `None.`)
   - `## Mid-session findings` (or `None.`)
   - `## Completed this session` (or `No file changes this session.`)
   - `## Deferred items` (or `None.`)
   - `## Next session`

3. **Deferred item chain integrity** — for each deferred item with a "Next session" or "Following session" destination, verify that the target session either resolved it or re-deferred it. A deferred item that disappears without resolution or explicit cancellation is a dropped item.

4. **Carry-forward escalation** — a deferred item that has survived 2+ handover hops without resolution must be escalated to the roadmap per [`handover_policy.md`](handover_policy.md#at-session-close-step-8) — carry-forward escalation.

5. **Mid-session findings triage** — all entries in `## Mid-session findings` must be triaged at session close per [`handover_policy.md`](handover_policy.md#at-session-close-step-8) — triage Mid-session findings. At close, the section should be empty or contain only items explicitly marked as triaged.

6. **Dangling references** — files, functions, or paths referenced in the Completed or Hot files sections that no longer exist in the codebase.

7. **Standardised status values** — status values should use the canonical `Active` or `Closed`. Variation like `✓ Complete`, `` `Complete` ``, or `` `Closed` `` is a formatting defect.

---

## Audit Procedure

### Step 1 — Scope the audit

Determine the set of handovers to review:
- **Periodic:** list all handovers in `devlog/handovers/` within the date range. Sort by date.
- **Event-driven:** identify the chain by tracing the deferred item through handover `## Next session` and `## Carried forward` sections.

### Step 2 — Structural scan

For each handover in scope:

Run the section header scan:
```bash
grep "^## " path/to/handover.md
```

Verify:
- All required sections are present (see structural completeness checklist above)
- Section headers match canonical casing: `## Completed this session` not `## Completed This Session`, `## Hot files` not `## Hot Files`, etc.

Anomalies fall into two categories:

**Can be 1:1 replaced** — headers that have a direct canonical equivalent differing only in casing or wording (e.g. `## Hot Files` → `## Hot files`, `## Decisions Made` → `## Decisions made this session`). Replace directly and record in a `[CORRECTION]` block.

**Cannot be 1:1 replaced** — headers that carry custom content with no canonical equivalent (e.g. `## Tag Cleanup Procedure`, `## Required reading`). Add a `[AMENDMENT]` block acknowledging the policy violation and leave the content unchanged.

### Step 3 — Deferred chain audit

For each non-null deferred item, trace forward:

1. Read the destination session's `## Carried forward` section — was the item picked up?
2. If yes, was it resolved (Completed table) or re-deferred (Deferred items)?
3. If it disappeared without resolution, flag as **dropped**.
4. If it survived 2+ hops, flag as needing **carry-forward escalation** to the roadmap.

### Step 4 — Status audit

Check each handover's `**Status:**` field:
- `Active` — only for the most recent handover (the current session)
- `Closed` — all others
- Any other value is a correction

### Step 5 — Dangling reference check

For each file mentioned in `## Completed this session` or `## Hot files`:
- Verify the file exists at the referenced path
- If deleted or renamed in a later session, the reference is stale — add a `[CORRECTION]` noting the deletion context

For each function or variable mentioned:
- Grep the codebase to confirm it still exists
- If removed, the reference is stale

### Step 6 — Corrections and amendments

Apply corrections per [`handover_policy.md`](handover_policy.md#corrections-to-closed-handovers):

- `[CORRECTION — YYYY-MM-DD]` — factual errors: wrong status, wrong filename, misrecorded decision. Edit the affected text inline, append the correction block.
- `[AMENDMENT — YYYY-MM-DD]` — non-standard formatting or policy violations that cannot be cleanly corrected. Append the block, leave content unchanged.
- `[REMOVED in MX.X]` — abandoned or superseded items. Append to the affected deferred item or claim inline.

### Step 7 — Report

Produce a structured audit report covering:
1. Handovers examined and date range
2. Corrections applied (summary table)
3. Dropped deferred items (with originating handover)
4. Items escalated to roadmap
5. Dangling references found
6. Policy violations noted

---

## Child Documents

| Document | Governs |
|---|---|
| [`handover_policy.md`](handover_policy.md) | Handover format, correction procedure, deferred item chain rules |
| [`documentation_policy.md`](documentation_policy.md) | Post-close document corrections, REMOVED/SUPERSEDED markers |
