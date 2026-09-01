# Agent Handover

**Date:** 2026-05-30
**Milestone:** M2.7 — Session Identity and Harness Versioning
**Type:** Impl
**Status:** Closed

## Objective

Resolve thermo-nuclear review Finding 1: remove redundant `--sandbox=` from package-diff and package-branch dispatch exec lines, and remove the `--sandbox=*) : ;;` stubs from both scripts.

## Completed this session

| File | Change summary |
|---|---|
| `scripts/agent-sandbox.sh` | Removed explicit `--sandbox=...` from `package-diff` and `package-branch` exec lines. |
| `src/libs/package_diff.sh` | Removed `--sandbox=*) : ;;` accept-and-ignore stub. |
| `src/libs/package_branch.sh` | Removed `--sandbox=*) : ;;` accept-and-ignore stub. |

## Mid-session findings

| Finding | Description | Triaged to |
|---|---|---|
| package-branch and package-diff use different working-context variables that should be unified | `package_diff.sh` derives its target from `git rev-parse --show-toplevel` (REPO_ROOT). `package_branch.sh` hardcodes `$HOME/sandbox` and errors on host. Both should accept a common target path (e.g. `--sandbox` or `--target`) and use it consistently instead of self-resolving. The `REPO_ROOT` vs `SANDBOX/SANDBOX_DIR` naming is confounding — they represent the same concept (the working context to package changes from) but are derived differently for historical reasons. Proper resolution requires adding a `--target` or similar flag that both scripts accept and use. | Future session — requires design and additional logic |
