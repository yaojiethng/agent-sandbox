# Agent Handover

**Date:** 2026-05-23
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Study / Implementation
**Status:** Closed

## Objective

Trace the root cause of the `@` file reference popup (fuzzy file search) silently failing to appear in Pi's editor, and document the filesystem incompatibility discovered.

## Scope

Investigate why `@` file reference popup stopped working. Covers:
- Pi's autocomplete pipeline (`CombinedAutocompleteProvider` in `@earendil-works/pi-tui`)
- The `fd` binary dependency and its provisioning via `ensureTool()`
- The mount strategy for `~/.pi/agent/bin/` (tmpfs overlay introduced by M2.7 mount strategy redesign)
- Any interaction between the tmpfs overlay mount flags and binary execution

**Out of scope:**
- Fixing the mount configuration (operator resolves)
- Fixing Pi's silent error handling (upstream concern)

## Carried forward

None.

## Acceptance criteria

Not defined — investigation session. Root cause was identified and a workaround applied before formal AC were written. Operator reviewed and confirmed the output directly.

## Hot files

| File | Reason | Status |
|---|---|---|
| `docs/devlog/discussions/story_windows_filesystem_incompatibilities.md` | Issue 3 (`noexec` tmpfs) added | ✅ Completed |
| `providers/pi/base.Dockerfile` | `fd-find`/`ripgrep` added to apt install | ✅ Completed |
| `/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-tui/dist/autocomplete.js` | Silent failure point (upstream) | 🔍 Referenced only |
| `/proc/mounts` | Showed `noexec` flag during investigation | 🔍 Referenced only |

## Decisions made this session

| Decision | Rationale |
|---|---|
| Install `fd-find` and `ripgrep` via apt in base Dockerfile instead of relying on Pi's auto-download | Bypasses the `noexec` tmpfs issue entirely. Pi's `getToolPath` checks system PATH first, so apt-installed binaries take priority over `~/.pi/agent/bin/`. Also aligns with operator preference for explicit dependency management over silent auto-downloads. |

## Mid-session findings

| Finding | Triaged to |
|---|---|
| `~/.pi/agent/bin/` tmpfs has `noexec` — blocks `fd`/`rg` execution | `story_windows_filesystem_incompatibilities.md` Issue 3 |
| Pi silently swallows spawn errors in `walkDirectoryWithFd()` | Deferred — upstream concern, not in scope |

## Completed this session

| File | Change |
|---|---|
| [`providers/pi/base.Dockerfile`](../../providers/pi/base.Dockerfile) | Added `fd-find` and `ripgrep` to apt install list |
| [`docs/devlog/discussions/story_windows_filesystem_incompatibilities.md`](../../docs/devlog/discussions/story_windows_filesystem_incompatibilities.md) | Added Issue 3 (`noexec` tmpfs) and documented workaround |
| [`docs/devlog/handovers/20260523-07-study-at_popup_noexec_root_cause.md`](20260523-07-study-at_popup_noexec_root_cause.md) | This handover |

## Deferred items

None.

## Next session

Rebuild pi-base image and test that `@` file reference popup works. The apt-installed binaries should be picked up by Pi's PATH lookup; if so, the noexec tmpfs issue is fully sidestepped. If the rebuild pipeline is not yet ready, the handover records the changes needed.

**Pending operator action:** Rebuild the pi-base image with the updated Dockerfile so the apt packages take effect.
