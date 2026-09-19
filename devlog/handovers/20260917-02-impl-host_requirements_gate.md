# Handover 20260917-02: implementation -- host-requirement gate

## Status

Closed

## Type

Implementation

## Milestone

M2.6.6 (post-list close) -- operator-directed host-support iteration

## Objective

Gate the CLI install behind host-requirement checks (bash 4.0+, git, and on macOS the GNU toolchain), record the requirements in a document, and register a deferred nushell-rewrite roadmap entry.

## Scope

Operator continuation of the 20260917-01 fix session. Three deliverables:

1. Roadmap: register the nushell rewrite idea as indefinitely deferred, under `#### Not in scope`.
2. `scripts/install.sh` (new): bash >= 4 and git checks on all hosts; on Darwin, per-tool GNU checks (realpath/readlink -f, sha256sum, GNU date, GNU sed, GNU xargs) with Homebrew hints; falls closed; then performs the CLI symlink install. The Makefile `install`/`uninstall` targets delegate to it, so the symlink logic has one canonical home.
3. `docs/development/host_requirements.md` (new): supported-hosts table, requirement matrix with call-site citations, macOS setup, enforcement section. Registered in the `project_index.md` Development registry; one pointer line added to the quickstart prerequisites.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| 1 | `install_main` passes on Linux (bash + git present) and creates the CLI symlink | `test_install_passes_on_linux_default` | done |
| 2 | On Darwin with a BSD-style PATH (no GNU tools), install aborts with rc != 0 and prints the coreutils brew hint and the requirements-doc pointer | `test_install_detects_missing_gnu_tools_on_darwin` | done |
| 3 | On Darwin with the GNU toolchain present, install passes and creates the symlink | `test_install_passes_on_darwin_with_gnu_shim` | done |
| 4 | On Linux with git missing, install aborts with rc != 0 and a git hint | `test_install_detects_missing_git_on_linux` | done |
| 5 | `--uninstall` removes the symlink; `INSTALL_DIR` override and the `~/.local/bin` default behave as before | `test_install_uninstall_removes_symlink` | done |
| 6 | Requirements doc exists, is registered, and carries the enforcement link; roadmap carries the deferred nushell row | Read the files; suite 788/0/0 | done |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/install.sh` | New install gate + symlink install |
| `Makefile` | `install`/`uninstall` delegate to the new script |
| `tests/test_install.sh` | PATH-shim tests for the gate |
| `docs/development/host_requirements.md` | New requirements record |
| `docs/development/project_index.md` | Registry row for the new doc |
| `docs/development/quickstart.md` | Prerequisites pointer |
| `devlog/roadmap.md` | Deferred nushell-rewrite row |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate fails closed, with no force flag | A silent partial setup fails later in the session with an unclear error; the gate names the missing tool at install time | `host_requirements.md` (Enforcement) |
| GNU-tool checks run only on Darwin; bash and git check on every host | Linux ships the GNU userland; bash and git are the universal floor | `scripts/install.sh` |
| The macOS xargs probe tests `xargs --version` for GNU findutils instead of probing `-r` behaviour | BSD xargs accepts `-r` as a replacement-string option, so a behaviour probe is ambiguous; the version probe fails closed on BSD | `scripts/install.sh`, `host_requirements.md` (matrix note) |
| `make install`/`make uninstall` delegate to `scripts/install.sh` | One canonical home for the symlink logic; the checks must run before every install path | `Makefile` |
| Check functions live in a sourceable script; main runs only when executed | Tests source the script and drive the checks with an `INSTALL_OS` override | `scripts/install.sh`, `tests/test_install.sh` |

## Findings

- macOS bash is 3.2.57; the harness uses `mapfile` and associative arrays, so bash 4.0+ is a hard floor, not a recommendation. The gate enforces it.
- BSD xargs parses `-r` as the replacement-string option, so `xargs -0 -r` in `src/libs/container_sig.sh` can misbehave silently on macOS even when the gate cannot detect it (the version probe only rejects BSD xargs). The fix belongs to the deferred portable-call-sites iteration; recorded in the matrix note.
- No new feedback/gotcha entries this iteration. The install-gate learning is captured in the requirements doc.
- Roadmap write-back: one row added (`#### Not in scope`: nushell rewrite). No milestone checkbox changed; the delivery was operator-directed, not a roadmap task.

## Completed

| Task | Result |
|---|---|
| Roadmap | Nushell-rewrite row added under `#### Not in scope` with the bounded-alternative rationale and a doc link |
| Install gate | `scripts/install.sh`: bash/git checks, Darwin GNU checks with brew hints, fail-closed summary, symlink install and uninstall; `INSTALL_DIR` resolution order preserved (env, repo `.env`, `~/.local/bin`) |
| Makefile | `install` and `uninstall` targets delegate to the script; duplicated inline logic removed |
| Requirements doc | `docs/development/host_requirements.md` with supported-hosts table, requirement matrix (call-site citations), macOS setup, enforcement |
| Registry + pointers | `project_index.md` row (Hot); quickstart prerequisites pointer line |
| Tests | `tests/test_install.sh`, 5 tests via PATH shims; suite 788/0/0 across 45 files; lint findings identical to baseline (changed files clean) |

## Deferred items

- Portable-call-sites port for the six GNU-only host-side call sites (`readlink -f`, `realpath`, GNU `sed -i`, `sha256sum`, `date -d`, `xargs -r`). Offered as the next iteration; makes macOS work without Homebrew.

## What's Next

- Operator: fetch/merge to the host repo, run `make install` on the macOS host to see the gate in action, then apply the brew setup from `docs/development/host_requirements.md` and rerun.
- Decide whether the portable-call-sites iteration starts next.
