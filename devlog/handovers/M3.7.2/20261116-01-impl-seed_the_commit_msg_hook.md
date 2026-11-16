---
date: 2026-11-16
milestone: M3.7.2 - The change model and its refinements
type: Implementation
status: Closed
---

# Handover - seed the commit-msg hook in copy delivery

## Objective

Make a fresh copy-delivery container audit its first commit with the project's `commit-msg` hook, and prove the unseeded clone as the failure it is.

## Scope

M3.7.2, the row **The container seeds the commit hook**, a continuation of **The convention leads from history as a commons and owns the primitives**.

The message check landed (`scripts/check_commit_message.sh`, handover `20261114-03`) and the hook file exists (`.githooks/commit-msg`), but `core.hooksPath` is unset in the clone, so the hook never runs. The entrypoint already owns the copy-delivery `.git` and installs the harness `pre-commit`; this iteration adds the project's `commit-msg` installation there.

The row's diagnosis names `git config core.hooksPath .githooks`; the design below records why the install copies the hook into `.git/hooks/` instead.

Out of scope: the message policy itself, the harness `pre-commit` hook, mount-delivery hook support (rejected by the delivery model), and the other open M3.7.2 rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A copy-delivery entrypoint run where the project ships `.githooks/commit-msg` leaves an executable `.git/hooks/commit-msg`; a non-conforming message is refused naming the policy layer, and a conforming one lands. | `bash tests/test_git_hook.sh` (`test_entrypoint_seeds_commit_msg_hook`) | Agent [x] |
| Mount delivery installs no `commit-msg`, and a copy project without `.githooks/commit-msg` installs none and still exits clean. | `bash tests/test_git_hook.sh` (mount and no-file cases) | Agent [x] |
| The unseeded clone is stated as the failure: without the install a bad message commits; after it, it is refused. | `bash tests/test_commit_hook.sh` (`test_hook_is_inert_without_the_install`) | Agent [x] |
| The records agree: `git_hooks.md` carries the dated second-hook entry, `.githooks/commit-msg` names the install model and not `core.hooksPath`, `sandbox_delivery_model.md` no longer says one hook, and the draft and `/commit` name the install. | `git diff` on the carriers; `grep -n "core.hooksPath" .githooks/commit-msg` and `grep -n "installs one hook" docs/adr/sandbox_delivery_model.md` both empty | Agent [x] |
| The stale subject/body row is `[x]` with its landed evidence (`2ca03f42`, handover `20261114-10`). | `grep -n "The subject names the change" devlog/roadmap.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table against the file table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Seed by installing the project's `.githooks/commit-msg` into `$SANDBOX_DIR/.git/hooks/commit-msg` for copy delivery, not by setting `core.hooksPath`. | `core.hooksPath` is rejected in `docs/adr/git_hooks.md` (it breaks the host's git in mount delivery and the agent can repoint it), and setting it would switch off the harness `pre-commit` already installed in `.git/hooks/`. Installing beside it keeps one hook directory and the existing ownership split. | this handover; `docs/adr/git_hooks.md` gains a dated entry |
| Install only when the project ships `.githooks/commit-msg`; install nothing in mount delivery and nothing for a project that does not ship it. | The hook is project-owned and copy delivery's `.git` lives in the session volume; mount delivery's `.git` is host-resident, so the recorded limitation stands. A project without the file gets no second hook and no error. | this handover; `docs/adr/git_hooks.md` |
| Leave the hook's own `exec "$root/scripts/check_commit_message.sh" "$1"` as the project's contract. | The script and the active types are project files; the harness carries no copy. The hook is installed only when the project ships it, so a project that ships the hook and not the script has a defect its own test should catch. | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The row's proposed mechanism (`core.hooksPath`) conflicts with `docs/adr/git_hooks.md`, which rejects it and records "exactly one hook". The install-beside model resolves it without repointing git config. | design | the row's stated route would disable the existing pre-commit | this iteration |
| The roadmap row **The subject names the change and the body gives the reason** is already landed in `2ca03f42` (handover `20261114-10`) but still open; closed here as a single-edit record correction. | record | a stale open row misleads the next scope decision | roadmap M3.7.2, this iteration |
| The first fixture staged the copied `commit-types.md`, so the harness `pre-commit` refused the commit before `commit-msg` ran, and the test would have proven the wrong gate. The fixture now commits its setup with `--no-verify` and stages a non-Markdown change. | test | a false green over the wrong hook | this iteration |
| The host-contract/project-style row was re-filed from M3.7.2 to M3.4.3 on operator direction (2026-11-16); the move is in this iteration's roadmap diff and is not this iteration's work. | record | none this iteration; it changes a future task's milestone | roadmap M3.4.3 |
| After this iteration every sub-row of **The convention leads from history as a commons and owns the primitives** is `[x]`, so the parent compacts to its outcome summary rather than staying open with no open child. | record | an uncompacted parent with no open child misreads as live work | roadmap M3.7.2, this iteration |

## Completed

| File | One-line change |
|---|---|
| `src/capability/entrypoint.sh` | Installs the project's `.githooks/commit-msg` into `.git/hooks/commit-msg` for copy delivery, beside the harness `pre-commit` |
| `.githooks/commit-msg` | Header now names the entrypoint install instead of `core.hooksPath` |
| `docs/adr/git_hooks.md` | Dated entry for the second, project-owned hook; `Current:` advanced |
| `docs/adr/sandbox_delivery_model.md` | "Installs one hook" corrected to "its hooks" |
| `.agents/drafts/precommit-gate-runbook.md` | Hook table gains the copy-delivery `commit-msg` row |
| `workflow/coding-agent/prompts/commit.md` | States that the hook is installed at container start |
| `tests/test_git_hook.sh` | New entrypoint seeding test, mount and no-file negatives |
| `tests/test_commit_hook.sh` | Seeding test moved from `core.hooksPath` to the install, with the uninstalled clone as the negative |
| `devlog/roadmap.md` | Marked this row and the stale subject/body row; compacted the fully resolved parent row; carries the M3.4.3 re-file |
| `devlog/handovers/M3.7.2/20261116-01-impl-seed_the_commit_msg_hook.md` | This record |
