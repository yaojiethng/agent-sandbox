# Agent Handover

**Date:** 2026-09-20
**Milestone:** M2 close (formal) - M3 promotion
**Type:** chore
**Status:** Closed

## Objective

Formally close M2 according to the maintenance protocol in `roadmap_policy.md`. The top-level close runs because all direct children of M2 (M2.1-M2.4, M2.6, M2.7) are complete. The operator then merges this branch and opens an M3 branch.

## Scope

Operator direction: "formally close M2 according to the maintenance protocol in roadmap_policy. I will then merge the M2_6 branch, and start a M_3 branch before opening the next major loop." One amendment approved at Step 2: the nushell rewrite evaluation moves to M3 as a task row, not to the changelog out-of-scope list.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | M2 changelog entry written in milestone order (before M2.1), fenced-block content committed | `grep -n "^## M2" devlog/changelog.md` | accepted |
| AC2 | M2.6 changelog entry's standing promise fulfilled (general-track work appended, no placeholder left) | promise text absent from changelog M2.6 entry | accepted |
| AC3 | M2 detail section removed from roadmap.md Upcoming Milestones; M3 section promoted in its place with correct heading levels | diff review | accepted |
| AC4 | Summary table: M2 -> changelog link, M2.6 -> changelog link (local anchor removed), M3 -> In progress with local anchor | `sed -n '22,31p' devlog/roadmap.md` | accepted |
| AC5 | Frontmatter: M3, in-progress | `head -4 devlog/roadmap.md` | accepted |
| AC6 | M3 removed from roadmap_future.md; nushell rewrite evaluation row added to M3 | diff review | accepted |
| AC7 | Lint gate clean (0 findings) | `bash scripts/lint.sh` | accepted |
| AC8 | Handover committed with the close commit | git log | accepted |

## Hot files

| File | Why in scope |
|---|---|
| `devlog/changelog.md` | M2 parent entry inserted before M2.1; M2.6 general-track promise fulfilled |
| `devlog/roadmap.md` | M2 section removed; M3 promoted; summary table + frontmatter updated |
| `devlog/roadmap_future.md` | M3 section removed (promoted); W1 and later sections preserved |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3 promotes with Doc Bloat and Perf as `####` sub-blocks | They were `###` children of `## M3` in the future file; the promotion transport moves the parent and sub-sections as one block | this handover |
| Heading dashes normalized `--` to `-` on promotion | roadmap.md section headings use single dashes (M2 - ...); roadmap_future used double | this handover |
| Nushell rewrite: evaluation task in M3, not out-of-scope list | Operator amendment to original scope | this handover |
| Anchor style: ` - ` becomes `--` | Dominant convention in the summary table (m1, m21-m27); only the old M2.6 local anchor used `---`; MD051 not lint-enforced | this handover |

## Completed

| File | Change |
|---|---|
| `devlog/changelog.md` | M2 parent entry (capability sentence + mechanism + out-of-scope); M2.6 general-track sentence replaces the promise placeholder |
| `devlog/roadmap.md` | M2 section removed; M3 section with task list, backpressure group, Doc Bloat + Perf promoted; summary rows M2/M2.6/M3; frontmatter M3/in-progress |
| `devlog/roadmap_future.md` | M3 section removed |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| M3 backpressure work (mount hooks, ShellCheck hook) | M3 scope | M3 section, now in roadmap.md |

## What's Next

Merge this branch, open `M3` branch. M3's promoted section in roadmap.md is the task list; the first iteration should pick the sub-milestone containment design question or a small M3 task.
