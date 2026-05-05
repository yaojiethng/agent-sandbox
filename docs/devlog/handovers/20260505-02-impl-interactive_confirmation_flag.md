# Agent Handover

**Session date:** 2026-05-04
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Active

## Objective

Implement the `--interactive` flag for `make apply` and `make draft` — a multi-step numbered picker that guides the operator through channel selection, session selection, and diff type selection instead of requiring explicit SESSION= or --channel arguments.

## Scope

Targets the **Pending — interactive confirmation flag** task group from the roadmap. Per the design at `docs/devlog/discussions/design_interactive_confirmation_flag.md`:

**Unit 1 — `libs/interactive_session_select.sh`**
- `interactive_confirm_or_abort` — shared print-and-prompt helper
- `interactive_select_channel` — channel picker (entry counts, newest timestamps)
- `interactive_select_session` — session entry picker (availability indicators)
- `interactive_select_diff_type` — diff type picker (uncommitted vs all-changes)

**Unit 2 — `apply --interactive` wiring in `agent-sandbox.sh`**
- Three paths: `--diff=` (one-step confirm), full channel→session→diff-type picker, or skip if all args provided

**Unit 3 — `draft --interactive` wiring in `agent-sandbox.sh`**
- Two paths: both `--channel` and `--session` given (show patch list + confirm), or channel→session picker

**Unit 4 — Makefile template update**
- Replace `BUNDLE ?=` / `AUTOSAVE ?=` with `FROM ?=` (value is channel name directly)
- Add `INTERACTIVE ?=`
- Wire `--interactive` into both targets

**Unit 5 — Tests in `tests/test_interactive_session_select.sh`**
- Unit tests for all four interactive functions
- Integration tests in `test_diff_workflow.sh` and `test_draft_workflow.sh`

**Unit 6 — Documentation alignment**
- Update `tool_interface.md`, `sandbox_lifecycle.md`, `sandbox_host_correspondence_model.md`, `project_index.md`, `roadmap.md`

**Explicitly deferred:**
- Trigger B (not until all M2.3 tasks including this one are complete)
- Any M2.5 (Vault) or M2.6 (Session Resume) work
- No changes outside the interactive flag scope

## Carried forward

None.

## Acceptance criteria

1. `echo y | agent-sandbox apply --sandbox=<path> --project=<path> --interactive` applies the resolved diff
2. `echo n | agent-sandbox apply --sandbox=<path> --project=<path> --interactive` aborts without applying
3. `echo 1 | echo 1 | agent-sandbox draft --sandbox=<path> --project=<path> --interactive` creates a draft branch (channel 1, then session 1)
4. `echo q | agent-sandbox draft --sandbox=<path> --project=<path> --interactive` aborts at channel prompt
5. `make apply INTERACTIVE=1` passes `--interactive` through
6. `make draft INTERACTIVE=1 FROM=bundles` passes `--interactive --channel=bundles`
7. Non-interactive behaviour unchanged — full test suite passes
8. `draft --interactive` with zero sessions prints "No sessions available." and exits non-zero
9. `apply --interactive --diff=<path>` shows path, prompts once (no channel/session steps)
10. `grep -rn "BUNDLE\b\|AUTOSAVE\b" docs/ --include="*.md" | grep -v devlog/discussions` returns 0 results outside devlog/discussions/ archive docs
11. `tool_interface.md`, `sandbox_lifecycle.md`, and `sandbox_host_correspondence_model.md` document `--interactive`, `INTERACTIVE=1`, and `FROM=<channel>`
12. Architecture documents in scope describe the system as built

## Hot files

| File | Why in scope |
|---|---|
| [`libs/interactive_session_select.sh`](../../libs/interactive_session_select.sh) | **New** — all interactive helper functions |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Wire `--interactive` dispatch for apply and draft |
| [`libs/_templates/Makefile.template`](../../libs/_templates/Makefile.template) | Add `FROM=`, `INTERACTIVE=1`; remove BUNDLE/AUTOSAVE |
| [`tests/test_interactive_session_select.sh`](../../tests/test_interactive_session_select.sh) | **New** — unit tests for interactive helpers |
| [`tests/test_diff_workflow.sh`](../../tests/test_diff_workflow.sh) | Integration tests for `apply --interactive` |
| [`tests/test_draft_workflow.sh`](../../tests/test_draft_workflow.sh) | Integration tests for `draft --interactive` |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Document `--interactive`, `FROM=`, `INTERACTIVE=1` |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Replace BUNDLE/AUTOSAVE with FROM=; add --interactive examples |
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | Update command map |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Update Last touched in |
| [`docs/devlog/roadmap.md`](../../docs/devlog/roadmap.md) | Update interactive flag description to match multi-step picker design |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Interactive mode is a 2-level (draft) or 3-level (apply) multi-step numbered picker | Original design proposed single-table; grill-me resolved to two-step flow | `design_interactive_confirmation_flag.md §3.1–3.3` |
| `BUNDLE=` / `AUTOSAVE=` replaced by `FROM=<channel>` | Single variable, explicit channel names, no implicit mapping | `design_interactive_confirmation_flag.md §3.7` |
| New file `libs/interactive_session_select.sh` | Avoids coupling `session.sh` to routing; domain-specific name | `design_interactive_confirmation_flag.md §3.5` |
| Cap at 10 entries, hardcoded `INTERACTIVE_MAX_ENTRIES=10` | Prevents wall-of-text; easy to change | `design_interactive_confirmation_flag.md §3.4` |
| Read stdin directly for prompts; warn on non-TTY but proceed | Enables test piping; no /dev/tty or FD trickery | `design_interactive_confirmation_flag.md §3.5` |
| Pre-fill when `--session` provided; empty enter selects default | Acts as visual sanity check; composable with automation | `design_interactive_confirmation_flag.md §3.1` |
| Both channel+session given → skip pickers, show patch list + confirm | Avoids redundant prompting when all info is supplied | `design_interactive_confirmation_flag.md §3.3` |

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| [`libs/interactive_session_select.sh`](../../libs/interactive_session_select.sh) | **New** — all four interactive helper functions: `interactive_confirm_or_abort`, `interactive_select_channel`, `interactive_select_session`, `interactive_select_diff_type` |
| [`scripts/agent-sandbox.sh`](../../scripts/agent-sandbox.sh) | Added `--interactive` flag parsing; wired into `apply` dispatch (3 paths) and `draft` dispatch (2 paths: both args given → patch list + confirm, or channel→session picker) |
| [`libs/_templates/Makefile.template`](../../libs/_templates/Makefile.template) | Replaced `BUNDLE=`/`AUTOSAVE=` with `FROM=<channel>`; added `INTERACTIVE=`; wired `--interactive` into both targets; updated help text |
| [`tests/test_interactive_session_select.sh`](../../tests/test_interactive_session_select.sh) | **New** — 25 unit tests covering all four interactive helper functions: confirm_or_abort (7), select_channel (6), select_session (6), select_diff_type (5) |
| [`docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Added `--interactive`/`INTERACTIVE=1` docs; replaced `AUTOSAVE=`/`BUNDLE=` with `FROM=<channel>` |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Replaced `BUNDLE=`/`AUTOSAVE=` with `FROM=`; added `INTERACTIVE=1` examples |
| [`docs/concepts/sandbox_host_correspondence_model.md`](../../docs/concepts/sandbox_host_correspondence_model.md) | Updated command map; replaced `AUTOSAVE=` reference with `FROM=` |
| [`docs/development/project_index.md`](../../docs/development/project_index.md) | Added `interactive_session_select.sh` entry; added `test_interactive_session_select.sh` entry; updated Makefile.template note |
| [`docs/devlog/roadmap.md`](../../docs/devlog/roadmap.md) | Updated interactive flag description to multi-step picker; marked task group complete |

## Deferred items

None.

## Next session

<To be populated at session close.>

**Conclusions from this session:**

None yet.
