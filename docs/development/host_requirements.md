# Host Requirements

This document records the host tools and versions agent-sandbox requires, per platform. `scripts/install.sh` enforces these requirements at install time. It fails closed with per-tool install hints when a requirement is missing.

## Supported Hosts

| Host | Status | Notes |
|---|---|---|
| Linux | Primary target | GNU userland is the baseline. |
| macOS (Darwin) | Supported with the GNU toolchain | macOS ships bash 3.2 and BSD tools; the harness needs newer bash and GNU tools. See the macOS setup section. |
| Windows | Via WSL2 only | The Linux userland inside WSL is the host. All paths must be WSL/Linux format. Convert Windows paths with `wslpath`. |

## Requirement Matrix

| Tool | Minimum | Used by | What breaks if missing |
|---|---|---|---|
| bash | 4.0 | All scripts | `mapfile` and associative arrays (bash 4.0+) appear in `scripts/build.sh` and other files. macOS ships bash 3.2.57. |
| git | any | All host workflows | Everything fails: onboarding, commits, diffs. |
| GNU coreutils | any | `realpath` (or `readlink -f`), `sha256sum`, GNU `date -d` | `scripts/onboard.sh`, `scripts/run_agent.sh`, `src/libs/session_env.sh`, `scripts/prune.sh`, `src/build/compose.sh` use these. BSD tools reject the GNU flags. |
| GNU sed | any | `sed -i` without a backup argument | `scripts/onboard.sh`, `src/libs/session_inventory.sh` use the GNU form. BSD `sed -i` demands a backup suffix. |

## macOS Setup

Run the bootstrap from the repo to install the requirements automatically:

```bash
bash scripts/macos_bootstrap.sh              # install packages, print PATH guidance
bash scripts/macos_bootstrap.sh --patch-shell   # also append the PATH export to ~/.zshrc
```

The bootstrap is idempotent and fails closed when Homebrew is missing. It only installs the packages; it does not install Homebrew itself. The manual steps below are what the bootstrap performs, for reference.

macOS does not ship any of the missing tools. Install them with Homebrew:

```bash
brew install bash coreutils gnu-sed git
```

Then put the GNU binaries first in `PATH`. Add this line to `~/.zshrc` (or `~/.bashrc`):

```bash
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/opt/gnu-sed/libexec/gnubin:$PATH"
```

The scripts resolve bash through `PATH` (`#!/usr/bin/env bash`). With the export above, `bash scripts/install.sh` and `make install` run under bash 5 instead of bash 3.2. To make bash 5 the interactive login shell as well:

```bash
echo '/opt/homebrew/bin/bash' | sudo tee -a /etc/shells
chsh -s /opt/homebrew/bin/bash
```

This last step is optional. The interactive shell does not matter to the harness; every script invokes bash itself.

Verify the install:

```bash
bash --version            # Bash version 5.x
realpath /                # prints /
sha256sum --version       # coreutils
sed --version             # prints "GNU sed"
date -d '1 day ago'       # prints a date
```

## Enforcement

`scripts/install.sh` runs the requirement checks, prints the failing checks with their Homebrew hints, and exits non-zero. `make install` runs it before creating the CLI symlink. The checks run unconditionally for bash and git; the GNU-tool checks run only on Darwin, where the BSD/GNU difference exists.

The gate deliberately fails closed. A silent partial setup fails later in the session with an unclear error; the gate names the missing tool at install time.

## Notes

- The inside-the-container work always runs on Linux, regardless of the host. The requirement surface above is only the host-side prelude (`scripts/`, `src/libs/`).
- A full rewrite of the host tooling in a cross-platform language (nushell) is indefinitely deferred. See `devlog/roadmap.md`, `#### Not in scope`.