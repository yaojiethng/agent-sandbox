# Agent Handover

**Date:** 2026-09-19
**Milestone:** M2.6 -- Session Persistence (general track)
**Type:** Workflow
**Status:** Closed

## Objective

Land the markdownlint lint gate as a documented, repeatable part of the repo, wire the linter into every provider base, and fire the check automatically on `git commit` in a copy-delivery container.

## Scope

- [x] Fold the markdownlint gate infrastructure into this iteration (config, check scripts, `scripts/lint.sh` umbrella, Makefile target, Dockerfile npm layer).
- [x] Document the gate in `docs/operations/documentation_policy.md`: how to run it, what it enforces, and the zero-findings baseline.
- [x] Reference the gate in the project-layer `AGENTS.md` so agents run it before close.
- [x] Clear the one gate finding (the `MD022` in closed handover `20260919-09`).
- [x] Wire the linter into every provider base: the shared node layer covers pi and opencode, `hermes/base.dockerfile` gains the install.
- [x] Install a `pre-commit` hook that lints staged Markdown, for copy delivery only.
- [x] Verify the gate reports zero findings and the test suite stays green.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| AC1 | `documentation_policy.md` documents the run commands, the enforced rules, and the zero-findings baseline | Operator read | accepted |
| AC2 | The project-layer `AGENTS.md` tells agents to run the gate before the pre-close gate | Operator read | accepted |
| AC3 | The Markdown gate reports zero findings over all tracked Markdown, and the ShellCheck gate is clean | `bash scripts/lint.sh` | accepted |
| AC4 | Every provider agent base installs `markdownlint-cli2` (shared node layer for pi and opencode, `hermes/base.dockerfile` for hermes) | `make build` / Dockerfile read | accepted |
| AC5 | Copy delivery installs an executable `pre-commit` hook into the session volume; mount delivery installs none | `bash tests/test_git_hook.sh` | accepted |
| AC6 | A commit with a staged Markdown finding is blocked, and the output names the `--no-verify` bypass | `bash tests/test_git_hook.sh` | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`.markdownlint-cli2.mjs`](.markdownlint-cli2.mjs) | Gate config |
| [`scripts/lint.sh`](scripts/lint.sh) | Umbrella static-check gate |
| [`scripts/check_shell.sh`](scripts/check_shell.sh) | ShellCheck gate |
| [`scripts/check_markdown.sh`](scripts/check_markdown.sh) | Markdown gate runner |
| [`scripts/lint/`](scripts/lint/) | Custom `doc-ascii` rule and sweep tools |
| [`Makefile`](Makefile) | `lint` runs `scripts/lint.sh` |
| [`src/reasoning/node.dockerfile`](src/reasoning/node.dockerfile) | Linter install for the shared node layer |
| [`src/reasoning/providers/hermes/base.dockerfile`](src/reasoning/providers/hermes/base.dockerfile) | Linter install for the python provider base |
| [`src/capability/git-hooks/pre-commit.sh`](src/capability/git-hooks/pre-commit.sh) | Commit hook source |
| [`src/capability/dockerfile`](src/capability/dockerfile) | Ships the hook in the capability image |
| [`src/capability/entrypoint.sh`](src/capability/entrypoint.sh) | Installs the hook for copy delivery |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | Gate documentation |
| [`docs/adr/git_hooks.md`](docs/adr/git_hooks.md) | Hook decision and the mount limitation |
| [`AGENTS.md`](AGENTS.md) | Pre-close gate reference |
| [`devlog/handovers/20260919-09-impl-stale_resume_hang_fix_and_quiet_docker_output.md`](devlog/handovers/20260919-09-impl-stale_resume_hang_fix_and_quiet_docker_output.md) | Correction block cleared the `MD022` finding |
| [`tests/`](tests/) | ShellCheck tidy-ups and the new hook tests |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate reference goes in the project-layer [`AGENTS.md`](AGENTS.md), not the provider-layer brief | The provider-layer template forbids project-workflow content in provider files | this handover |
| [`hermes/base.dockerfile`](src/reasoning/providers/hermes/base.dockerfile) gains the linter install | Hermes does not inherit the shared node layer, so it was the one provider base without the tool | this handover |
| The correction block in handover `20260919-09` takes a blank line before its closing fence | A tight closing fence parses the tag paragraph as a setext heading and trips `MD022` | this handover |
| The harness installs one git hook, in copy delivery only | Copy's `.git` is volume-local and cannot reach the host; mount's `.git` is a host directory, so a hook there is host-resident and agent-rewritable | [`git_hooks.md`](docs/adr/git_hooks.md) |
| The hook lints the staged Markdown list with `--no-globs` | Avoids re-linting the whole repository on every commit | [`git_hooks.md`](docs/adr/git_hooks.md) |
| The hook source keeps a `.sh` extension and installs as `pre-commit` | Git requires the exact hook name; the `.sh` source stays inside the ShellCheck gate | this handover |
| One `make lint` runs `scripts/lint.sh`, which invokes the two leaf gates; the `markdown` target is removed | One umbrella entry point, one place to add a future gate; each leaf script owns its rule set | this handover |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The gate was not at zero findings: the `[CORRECTION]` block in handover `20260919-09` tripped `MD022` | contradiction | current iteration | fixed in Completed |
| `hermes/base.dockerfile` did not install the linter, so a hermes container could not run the gate | scope change | current iteration | fixed in Completed |
| Operator steering: a `git commit` in a new container must run the Markdown check | steering | current iteration | implemented for copy delivery (Completed); the mount limitation is the next row |
| Mount delivery cannot carry the commit hook under the current restrictions: its `.git` is a host directory, so a hook there is host-resident and agent-rewritable | limitation | next iteration | recorded in [`git_hooks.md`](docs/adr/git_hooks.md); no follow-up work scheduled |
| `handover_policy.md` showed the tight correction fence in its example, the form that trips `MD022` | bug | next iteration | fixed in Completed |
| Operator steering: the `check_lint.sh` name reads as the umbrella lint gate but runs the ShellCheck half only | steering | current iteration | fixed in Completed |
| Operator steering: `make markdown` was the wrong shape; the Makefile exposes one `make lint` running `scripts/lint.sh` over both leaf gates | steering | current iteration | fixed in Completed |
| The roadmap has no row for the gate, and the general-track `Open:` list holds only completed items | contradiction | roadmap | roadmap write-back |

## Completed

| File | Change |
|---|---|
| [`.markdownlint-cli2.mjs`](.markdownlint-cli2.mjs) | New gate config: policy-aligned rule subset plus the `doc-ascii` rule; `MD013` and `MD060` disabled |
| [`scripts/check_markdown.sh`](scripts/check_markdown.sh) | New blocking gate runner over all tracked Markdown |
| [`scripts/lint.sh`](scripts/lint.sh) | New umbrella gate: runs both leaf gates, exits with the first failure's code |
| [`scripts/lint/`](scripts/lint/) | New `doc-ascii.mjs` custom rule and the sweep tools used to reach zero findings |
| [`Makefile`](Makefile) | `lint` now runs `scripts/lint.sh`; removed the superseded `markdown` target |
| [`tests/test_lint_umbrella.sh`](tests/test_lint_umbrella.sh) | New: umbrella exit-code aggregation and both-gates-always-run |
| `scripts/check_lint.sh` -> [`scripts/check_shell.sh`](scripts/check_shell.sh) | Renamed: the script runs the ShellCheck gate only, so the name now pairs with `check_markdown.sh` |
| [`src/reasoning/node.dockerfile`](src/reasoning/node.dockerfile) | Added the `markdownlint-cli2` install for the shared node layer |
| [`src/reasoning/providers/hermes/base.dockerfile`](src/reasoning/providers/hermes/base.dockerfile) | Added the `markdownlint-cli2` install for the python provider base |
| [`src/capability/git-hooks/pre-commit.sh`](src/capability/git-hooks/pre-commit.sh) | New hook: lint staged Markdown with `--no-globs`, block on a finding, name the `--no-verify` bypass |
| [`src/capability/dockerfile`](src/capability/dockerfile) | Copy the hook source into the image at `/opt/sandbox/git-hooks/` |
| [`src/capability/entrypoint.sh`](src/capability/entrypoint.sh) | Install the hook into the volume `.git/hooks/` for copy delivery only; add the `GIT_HOOKS_DIR` test seam |
| [`tests/test_git_hook.sh`](tests/test_git_hook.sh) | New: hook block, pass, and scope behaviour plus the entrypoint install and mount-skip checks |
| [`docs/adr/git_hooks.md`](docs/adr/git_hooks.md) | New ADR: the copy-only hook, the rejected mount and `core.hooksPath` alternatives, the mount limitation |
| [`docs/adr/sandbox_delivery_model.md`](docs/adr/sandbox_delivery_model.md) | Scoped the "harness runs no hooks itself" clause to point at the new ADR |
| [`docs/operations/documentation_policy.md`](docs/operations/documentation_policy.md) | Added the `Markdown lint gate` section; reworded the character-set ban to ASCII-safe names; tagged untyped fences |
| [`docs/operations/handover_policy.md`](docs/operations/handover_policy.md) | Correction-format example gains the blank line before the closing fence, with the reason, so a copied correction stays lint-clean |
| [`AGENTS.md`](AGENTS.md) | Added the pre-close gate reference |
| [`devlog/handovers/20260919-09-impl-stale_resume_hang_fix_and_quiet_docker_output.md`](devlog/handovers/20260919-09-impl-stale_resume_hang_fix_and_quiet_docker_output.md) | Added a blank line before the closing correction fence, clearing `MD022` |
| [`tests/libs/test_common.sh`](tests/libs/test_common.sh), [`tests/test_capability_entrypoint_mount.sh`](tests/test_capability_entrypoint_mount.sh), [`tests/test_seed_volume.sh`](tests/test_seed_volume.sh), [`tests/test_trace_resume.sh`](tests/test_trace_resume.sh) | ShellCheck tidy-ups (split `local`, quoting, targeted disable) |

## Deferred items

None.

## What's Next

**Next:** M2.6 -- Session Persistence (general track), continued. Roadmap maintenance ran at this close: the general-track `Open:` group held only completed rows, so it was compacted into the completed list, and the stale `make lint` claim in the test-harness row was corrected. No sub-milestone completed.

**Watch-outs:**

- The copy-delivery hook is covered by tests but not yet exercised in a live container. Verify on the next session start: a `git commit` inside the sandbox container runs `markdownlint-cli2` over the staged Markdown.
- Mount delivery carries no commit hook under the current restrictions (ADR [`git_hooks.md`](../docs/adr/git_hooks.md)).
- The lint surface is one umbrella: `make lint` -> [`scripts/lint.sh`](../scripts/lint.sh) -> `check_shell.sh` + `check_markdown.sh`. A new gate joins `scripts/lint.sh`.

**Conclusions from this iteration:** the Markdown gate is authoritative (policy section plus the project `AGENTS.md` reference), and the leaf scripts are named for what they check. One commit hook is installed, in copy delivery only, because the mount `.git` is host-resident; the `core.hooksPath` and git-shim alternatives were rejected on the same ground. `markdownlint-cli2` installs in the shared node layer (pi, opencode) and in `hermes/base.dockerfile`. Docs-only changes to closed records use the corrected correction-block form.
