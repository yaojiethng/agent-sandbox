---
name: whats-next
description: >
  Survey the current state of the codebase and produce a ranked list of
  remaining tasks, unfinished refactors, deferred items, and process
  improvements. Use when opening a fresh session to re-establish
  context about what remains to be done.
---

# What's Next?

When you are starting a fresh session and need to understand what work
remains, this skill helps you survey the codebase systematically.

## Step 1 — Read the handover chain

```bash
ls devlog/handovers/ | sort -r | head -5
```

Read the most recent handover (both the Objective and Next session
sections). Work backwards through the chain if the context is thin.
Closed handovers are read-only records — do not modify them.

## Step 2 — Read the roadmap and deferred items

```bash
head -80 devlog/roadmap.md
grep -A5 "Deferred" devlog/roadmap.md
```

Identify incomplete task groups and any deferred items.

## Step 3 — Survey recent git history

```bash
git log --oneline -20
git diff --stat HEAD~5..HEAD   # show scope of recent work
```

Understand what changed recently and what areas were being worked on.

## Step 4 — Check for mid-session findings in the last handover

```bash
grep -A30 "Mid-session findings" devlog/handovers/$(ls devlog/handovers/ | sort -r | head -1)
```

Mid-session findings that were triaged but not resolved are the highest
priority items for the next session.

## Step 5 — Check for open design documents

```bash
ls devlog/discussions/ 2>/dev/null
```

Design documents that exist but have no corresponding implementation
handover are candidates for the next session.

## Step 6 — Look for stale branches, temp files, or uncommitted work

```bash
git status --short
git stash list
git branch -a 2>/dev/null | head -10
```

Uncommitted changes or stashed work may contain in-progress features.

## Step 7 — Compile the task list

Present your findings as a ranked list:

```
**High priority (blocked on nothing):**
- Item — why now

**Medium priority (needs design or upstream work):**
- Item — what's blocking it

**Deferred / low priority:**
- Item — reason
```

For each item, state:
- What needs to be done
- Why it matters now (or why it can wait)
- Any dependencies that must be resolved first
