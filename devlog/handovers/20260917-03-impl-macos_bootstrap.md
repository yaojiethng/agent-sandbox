# Handover 20260917-03: implementation -- macOS requirements bootstrap

## Status

Closed

## Type

Implementation

## Milestone

M2.6.6 (post-list close) -- operator-directed host-support continuation

## Objective

Provide a provisioning script that installs the macOS host requirements (brew bash, GNU toolchain) instead of only checking for them.

## Scope

`scripts/macos_bootstrap.sh` (new): installs `bash`, `coreutils`, `gnu-sed`, `findutils`, and `git` via Homebrew; idempotent; fails closed when Homebrew is missing (prints the Homebrew install command, does not install it); prints the gnubin PATH export; `--patch-shell` appends it to `~/.zshrc` (guarded against duplicates); `--switch-shell` prints the login-shell switch commands; verifies the brew bash version and the four gnubin binaries at the end. The script is bash 3.2-safe so it runs under macOS's system bash before the toolchain exists. Companion tests, doc pointer in `host_requirements.md`, registry rows in `project_index.md`.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verification | Status |
|---|---|---|---|
| 1 | The bootstrap aborts outside macOS with a clear message | `test_bootstrap_aborts_on_non_macos` | done |
| 2 | Missing Homebrew aborts with the install command, fails closed | `test_bootstrap_aborts_without_homebrew` | done |
| 3 | Absent packages install via brew; verification passes; the CLI-install pointer prints | `test_bootstrap_installs_missing_packages` | done |
| 4 | Present packages are skipped (no reinstalls) | `test_bootstrap_skips_present_packages` | done |
| 5 | Verification flags missing gnubin binaries | `test_bootstrap_verification_flags_missing_gnubin` | done |
| 6 | The `--patch-shell` export is appended to `~/.zshrc` exactly once | `test_patch_shell_appends_once` | done |
| 7 | Docs point to the bootstrap; registry lists both install scripts | Suite 794/0/0; lint clean on changed files | done |

## Hot files

| File | Why in scope |
|---|---|
| `scripts/macos_bootstrap.sh` | New provisioning script |
| `tests/test_macos_bootstrap.sh` | Six tests with a fake brew and prefix fixtures |
| `docs/development/host_requirements.md` | macOS setup opens with the bootstrap |
| `docs/development/project_index.md` | Rows for `install.sh` and `macos_bootstrap.sh` |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The bootstrap installs packages but never installs Homebrew itself | Installing Homebrew silently is invasive and needs interaction; fail closed with the command instead | `scripts/macos_bootstrap.sh`, `host_requirements.md` |
| The script is bash 3.2-safe (no `mapfile`, no associative arrays) | It runs under macOS's system bash before brew bash exists | `scripts/macos_bootstrap.sh` header |
| `--patch-shell` touches `~/.zshrc` only with the explicit flag, guarded against duplicates | Modifying shell rc files must be opt-in | `scripts/macos_bootstrap.sh` |
| Verification probes the prefix's own binaries (`$prefix/bin/bash`, gnubin paths), not `PATH` resolution | PATH gains the gnubin entries only after a new shell opens; the verify step must work in the current shell | `scripts/macos_bootstrap.sh` |

## Findings

- The gnubin binaries of an installed package may exist while `brew list` still fails transiently; the loop treats a failing list as "install" and `brew install` is a no-op reinstall then -- safe, idempotent behavior, no change needed.
- One test assertion needed one fix: alphabetical sort order of the logged package names (`git` sorts before `gnu-sed`). Not a script defect.
- Roadmap write-back: none. The delivery extends the 20260917-02 subject; no roadmap row changed.

## Completed

| Task | Result |
|---|---|
| Bootstrap script | `scripts/macos_bootstrap.sh`: OS gate, Homebrew gate, idempotent package install, PATH guidance, `--patch-shell`/`--switch-shell` flags, gnubin + brew-bash verification |
| Tests | `tests/test_macos_bootstrap.sh`: fake-brew fixtures, prefix fixtures with and without gnubin; 6 tests |
| Docs | `host_requirements.md` macOS setup opens with the bootstrap; `project_index.md` gains both install-script rows |
| Verify | Bootstrap tests 6/0/0; full suite 794/0/0 across 46 files; shellcheck clean on both changed files |

## Deferred items

None.

## What's Next

- Operator: on the macOS host, run `bash scripts/macos_bootstrap.sh --patch-shell`, open a new shell, then `make install` (the gate re-checks the requirements).
- The portable-call-sites port (six GNU-only call sites) remains offered as the next iteration, from 20260917-02.