---
description: "Handoff - track the skill packages a project adds with a manifest, and report drift against what is installed. The mechanism tracks and checks only: it installs nothing, resolves nothing, and repairs nothing."
argument-hint: "[scope note, e.g. manifest path or drift case - optional]"
---

> $ARGUMENTS

# Handoff - a manifest for the packages a project adds

## What the next session is for

Give the operator of the sandbox a way to track the skill packages a project adds, and a check that reports drift between what the manifest says and what is actually installed. That is the whole task. The mechanism does not install, resolve, retry or repair: those belong to the provider's package manager, which already does them and reports its own failures.

Delete this file when the task lands.

## Where things stand

The seam was settled on 2026-10-31: this repository ships one reviewed stack, and the person onboarding a project may add skill packages of their own. Nothing exists yet for the added side -- no manifest, no check, no record. An earlier design for it was withdrawn and is absent from the branch; see `## Do not resurrect` below before proposing a shape.

Facts a fresh session would otherwise re-derive wrongly:

| Fact | Evidence |
|---|---|
| The reasoning image is project-agnostic; only its tag names a project, and its build context is the repository root, so no Dockerfile step can read a project's files | `src/build/image.sh`, `scripts/build.sh` |
| The container can read the project: the worktree, `.agents` included, is seeded into the volume or bind-mounted at `/home/agentuser/sandbox` | `src/capability/snapshot.sh`, `src/build/docker-compose.mount.yml` |
| `npm` and `pi@1.3.0` are both present in the reasoning image | `src/reasoning/providers/pi/base.dockerfile` |
| `onboard.sh` runs on the host before compose; the container's own start is `/opt/sandbox/bin/provider-entrypoint.sh` | `src/reasoning/providers/pi/onboard.sh`, `src/reasoning/entrypoint.sh` |
| pi loads skills from the user root, then the project root, then each package in settings order; first name wins | `node_modules/@earendil-works/pi-coding-agent/dist/core/skills.js` |

## Suggested skills

| Skill | Why this session needs it |
|---|---|
| `principle-delegation-over-machinery` | the task is to add the smallest thing that reports, not to build an installer |
| `testing` | the check is behaviour, and the suite's homes and patterns are stated there |
| `git-discipline` | the commit type and the fold rules |

## What the manifest has to be

State the intent, then choose the method:

1. **One artifact and one check.** The artifact names the packages a project asked for. The check reports a difference between it and the installed state, with enough detail that a reader can act on it.
2. **No management.** No install, no resolve, no version selection, no error recovery, no retry. If a package is missing, that is a finding; the fix is the operator running the provider's own command.
3. **No pin taxonomy invented here.** Record what the operator pinned, in the form they pinned it. Resist a class system for registry versus git versus path inputs.
4. **The check is the drift detector.** A package in the manifest that is absent from the installation is a finding, and so is an installed set the manifest does not mention. Keep the comparison mechanical so a rename cannot silently pass.
5. **It does not ship.** This is a maintainer and operator tool, so it lives in the repository tree, not in the image payload.

## Done when

- The manifest and the check exist, with a fixture proving a drift case is a finding and a clean case is not.
- The check runs in the project's gate set at a stage where its evidence exists -- the installed state is only observable in a container, so decide deliberately whether the check is a repo-time check over the manifest alone or a runtime report, and say which in the record.
- `bash scripts/lint.sh` and `bash scripts/run_tests.sh` are clean.

## Do not resurrect

A declaration file with per-class pin forms, a resolver lockfile written at one stage and consumed at another, an install-time filter that deletes names out of an installed package, and a form gate over bytes the repository does not hold. Each was built, reviewed and withdrawn on 2026-10-31; each is far larger than this task, and each certifies something nobody could act on.
