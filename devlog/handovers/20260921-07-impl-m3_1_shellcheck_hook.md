# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Extend the copy-delivery `pre-commit` hook to gate staged shell files with ShellCheck, and promote M3.1 to the active milestone in the roadmap.

## Scope

- Roadmap: set the `active-milestone` frontmatter to M3.1 and move the M3.1 section above the un-promoted T1-T8 tracks.
- Hook: add a staged-shell section to `src/capability/git-hooks/pre-commit.sh` running ShellCheck at `-S warning`, mirroring the staged-Markdown behavior (skip when no shell file staged, note and allow when the tool is absent, name the `--no-verify` bypass on findings).
- Entrypoint: update the hook install message to name both gates.
- Tests: extend `tests/test_git_hook.sh` with ShellCheck-stub tests (blocks on finding, passes clean, skips non-shell commits, never invokes markdownlint on a shell-only commit).
- ADR: record the extension in `docs/adr/git_hooks.md` as the current entry.
- Roadmap write-back: mark the ShellCheck-as-a-git-hook row complete at iteration end.

**Deferred:** the lint-speed investigation (row "Lint and tests take forever") stays open; iteration `20260921-09` delivers its study. The `[A]` shellcheck-directive feedback entry resolution is surfaced at the M3.1 pre-close review, not edited here.

**Questions:** None.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | A staged shell file with a ShellCheck finding blocks the commit, and the output names the `--no-verify` bypass | `bash tests/test_git_hook.sh` | Agent [x] -- test `test_hook_blocks_staged_shell_finding` |
| 2 | A commit staging only clean shell files passes the hook and never invokes the markdownlint binary | `bash tests/test_git_hook.sh` | Agent [x] -- test `test_hook_passes_clean_staged_shell` |
| 3 | A commit staging no shell file never invokes the shellcheck binary | `bash tests/test_git_hook.sh` | Agent [x] -- test `test_hook_ignores_non_shell_commit` |
| 4 | Copy delivery installs the hook and the install message names the ShellCheck gate | `bash tests/test_git_hook.sh` | Agent [x] -- `test_entrypoint_installs_hook_for_copy` passes; `git diff src/capability/entrypoint.sh` shows the message |
| 5 | Roadmap frontmatter reads `M3.1 - Backpressure` and the M3.1 section precedes the T1 track | `grep -n` on `devlog/roadmap.md` | Agent [x] -- frontmatter line 2; M3.1 at line 63, T1 at 73, no duplicate section |
| 6 | `docs/adr/git_hooks.md` carries a current 2026-09-21 entry documenting the staged-shell gate | read `docs/adr/git_hooks.md` | Agent [x] -- Current: 2026-09-21, entry read above |

## Hot files

| File | Why in scope |
|---|---|
| [`devlog/roadmap.md`](devlog/roadmap.md) | active-milestone promotion, M3.1 section move, ShellCheck row write-back |
| [`src/capability/git-hooks/pre-commit.sh`](src/capability/git-hooks/pre-commit.sh) | add the staged-shell ShellCheck section |
| [`src/capability/entrypoint.sh`](src/capability/entrypoint.sh) | hook install message names both gates |
| [`tests/test_git_hook.sh`](tests/test_git_hook.sh) | ShellCheck-stub behavioral tests |
| [`docs/adr/git_hooks.md`](docs/adr/git_hooks.md) | current entry records the staged-shell extension |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The ShellCheck gate mirrors the Markdown gate's skip and bypass behavior (tool absent -> note and allow; finding -> block with the `--no-verify` name) | one hook contract for both languages; the `--no-verify` bypass is already deliberate policy | `docs/adr/git_hooks.md` entry 2026-09-21 |
| Roadmap frontmatter reads `M3.1 - Backpressure`, and the M3.1 section moves above the T1-T8 tracks | the check-in must frame itself on the active sub-milestone, not the parent M3 section | `devlog/roadmap.md` |

## Findings

None.

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-07-impl-m3_1_shellcheck_hook.md` | opened and closed this handover | done |
| `devlog/roadmap.md` | active-milestone to M3.1; M3.1 section moved above the T1-T8 tracks; ShellCheck row marked `[x]` with outcome summary | done |
| `src/capability/git-hooks/pre-commit.sh` | added the staged-shell ShellCheck gate beside the Markdown gate | done |
| `src/capability/entrypoint.sh` | install message names both gates | done |
| `tests/test_git_hook.sh` | 4 new tests + `make_sc_stub` factory; suite now 20 asserts | done |
| `docs/adr/git_hooks.md` | new current entry 2026-09-21, prior entry demoted | done |

## Deferred items

None.

## What's Next

M3.1 - Backpressure. Roadmap maintenance: none pending for this sub-milestone.

Next iteration (`20260921-08`): the sourced-lib / library lint rules row (rules `3.1` and `4.4` of `docs/development/bash-coding-conventions.md`). Watch-outs: (1) the new gate must pass on the current tree with zero findings, so grep `src/libs/` and `src/build/` for `exit` and variable redirections before writing the gate; (2) the gate needs a scan-root seam for fixture tests like `SHELLCHECK_SCAN_ROOT` in `check_shell.sh`; (3) the gate must use the verdict-only exit convention (0/1, no counts, per `bash-coding-conventions.md` 3.2).

Follow-up (pending operator input): the `[A]` 2026-09-19 shellcheck-directive feedback entry has its durable fix in the gate's directive wording; surface dismiss/probation at the M3.1 pre-close review.
