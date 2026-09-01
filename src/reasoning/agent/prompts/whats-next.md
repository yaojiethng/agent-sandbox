---
name: whats-next
description: >
  Survey the current state of the codebase and produce a ranked list of
  remaining tasks, unfinished refactors, deferred items, and process
  improvements. Use when opening a fresh iteration to re-establish
  context about what remains to be done.
---

# What's Next?

When you are starting a fresh iteration and need to understand what work
remains, this skill helps you survey the codebase systematically.

## Step 1  --  Read the handover chain

```bash
ls devlog/handovers/ | sort -r | head -5
```

Read the most recent handover (both the Objective and What's Next
sections). Work backwards through the chain if the context is thin.
Closed handovers are read-only records  --  do not modify them.

## Step 2  --  Read the roadmap frontmatter, summary, and active milestone

```bash
head -5 devlog/roadmap.md                         # frontmatter  --  active milestone
grep -A30 "^## Milestone Summary" devlog/roadmap.md | head -35  # milestone table
```

Read the active milestone's detailed section. The frontmatter `active-milestone:`
field identifies the current target. Navigate to its section anchor to read the
task list and deferred items.

```bash
# Find the active milestone section  --  reads from the frontmatter field
ACTIVE=$(grep "^active-milestone:" devlog/roadmap.md | sed 's/.*: //' | tr -d '"')
# Extract the section for the active milestone (between its heading and the next sibling)
sed -n "/^#### ${ACTIVE%%  --  *}/,/^#### [A-Z0-9]/p" devlog/roadmap.md | head -80
# Also extract deferred items within the active milestone
sed -n "/^#### ${ACTIVE%%  --  *}/,/^#### [A-Z0-9]/p" devlog/roadmap.md | grep -A5 "^- \\[ \]\|Deferred\|deferred" | head -20
```

If the active milestone has nested sub-milestones (e.g. M2.6.1, M2.6.2),
extract each sub-milestone section:

```bash
# Find and read sub-milestones under the active milestone
PREFIX="${ACTIVE%%  --  *}"  # e.g. "M2.6"
sed -n "/^### ${PREFIX}.[0-9]/,/^### /p" devlog/roadmap.md | head -60
```

Identify incomplete task groups and any deferred items from the detailed sections.

## Step 3  --  Survey recent git history

```bash
git log --oneline -20
git diff --stat HEAD~5..HEAD   # show scope of recent work
```

Understand what changed recently and what areas were being worked on.

## Step 4  --  Check for findings in the last handover

```bash
grep -A30 -E "Findings" devlog/handovers/$(ls devlog/handovers/ | sort -r | head -1)
```

Findings that were triaged but not resolved are the highest
priority items for the next iteration.

## Step 5  --  Check for open design documents

```bash
ls devlog/discussions/ 2>/dev/null
```

Design documents that exist but have no corresponding implementation
handover are candidates for the next iteration.

## Step 6  --  Look for stale branches, temp files, or uncommitted work

```bash
git status --short
git stash list
git branch -a 2>/dev/null | head -10
```

Uncommitted changes or stashed work may contain in-progress features.

## Step 7  --  Compile the task list

Present your findings as a ranked list:

```
**High priority (blocked on nothing):**
- Item  --  why now

**Medium priority (needs design or upstream work):**
- Item  --  what's blocking it

**Deferred / low priority:**
- Item  --  reason
```

For each item, state:
- What needs to be done
- Why it matters now (or why it can wait)
- Any dependencies that must be resolved first
