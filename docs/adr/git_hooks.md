# Git Hooks

**Current:** 2026-09-21

## 2026-09-21 -- Host-initiated hook install gives the host checkout the same gate

**Decision.** The operator can install the pre-commit hook into a host checkout by running `scripts/manual/install_host_git_hooks.sh`. The script copies `src/capability/git-hooks/pre-commit.sh` into the checkout's `.git/hooks/pre-commit`, enforces a tool floor (fail closed when `markdownlint-cli2` or `shellcheck` is absent, unless `--skip-tool-check`), and offers `--check` to detect drift from the source. The agent never writes the host `.git`.

**Rationale.** The host checkout runs the operator's own commits during draft-branch review and merge, and it deserves the same commit-time backpressure the copy-delivery hook gives the agent - WITHOUT the rejected host-exposure change. Because the operator installs and owns the hook, its content is the reviewed `pre-commit.sh` and nothing untrusted can rewrite it. The `2026-09-20` rejection stands for container-planted hooks; this is a separate, host-initiated path.

**Rejected alternatives.** Unchanged from the `2026-09-20` entry: mount delivery installing the hook from the container (the rejected host-exposure model), `core.hooksPath` into an image path (breaks the host's git; config can be repointed), and a `git` shim on PATH (wraps one invocation, not the operation).

**Edge cases / drivers.**

- **Delivery-agnostic hook.** `pre-commit.sh` resolves the root with `git rev-parse --show-toplevel` and note-and-allows a missing tool, so the same file runs host-side unchanged.
- **Tool floor.** The hook itself tolerates a missing tool; the installer fails closed instead, so a host hook is never a silent no-op. `--skip-tool-check` overrides for a host that already accepts the degradation.
- **Drift detection.** `--check` compares the installed hook to the source; re-run the installer after a branch update that changed the hook.
- **Scope.** The installer targets the agent-sandbox checkout; running it against a project checkout would impose the harness hook's policy on that project.

## 2026-09-21 -- Copy-delivery hook gates staged Markdown and shell files

**Decision.** The copy-delivery `pre-commit` hook gates the staged Markdown files with `markdownlint-cli2 --no-globs` and the staged shell files with ShellCheck at `-S warning`. Both gates block the commit on a finding; a check is bypassed deliberately with `git commit --no-verify`, and a missing tool prints a note and allows the commit. The installation model is unchanged: the capability entrypoint installs the one hook into the session volume's `.git/hooks/pre-commit` on every start (fresh and resume), copy delivery only.

**Rationale.** Shell rules receive the same commit-time backpressure as the Markdown rules. The hook keeps its staged-file scope in both gates, so a commit never re-lints the whole repository. The rejection reasons from the `2026-09-20` entry continue to apply unchanged (mount delivery, `core.hooksPath`, and a `git` shim remain rejected).

**Rejected alternatives.**

- **Run the full `scripts/check_shell.sh` gate in the hook.** Rejected: that gate scans every tracked shell file and costs seconds on every commit, undoing the staged-file cost design; the whole-repository check stays a pre-close lint task.
- **A separate `post-commit` or `commit-msg` hook for shell.** Rejected: one hook keeps the install surface minimal, and both gates must fire before the commit is written.

**Edge cases / drivers.**

- **Missing linter.** If `shellcheck` is absent, the hook prints a note and allows the commit, matching the `markdownlint-cli2` behavior. The linter ships in every provider base, so a missing binary signals a stale image.
- **Directive parsing.** ShellCheck parses any comment whose first token after `#` is `shellcheck` as a directive and reports `SC1072`/`SC1073`. The hook prints the same reword-the-line hint as the full gate (`scripts/check_shell.sh`).
- **Partial staging.** Both linters read the working-tree file, not the index copy, so a partially staged file is checked as it exists on disk.
- **Non-matching commits.** A commit that stages neither Markdown nor shell files exits immediately; neither linter runs.

## 2026-09-20 -- Copy delivery installs a Markdown pre-commit hook

**Reason superseded by 2026-09-21:** the hook now gates staged shell files too; the Markdown-only framing no longer describes the current hook. The installation and bypass model it records is unchanged.

**Decision.** The harness installs exactly one git hook, in copy delivery only: a `pre-commit` hook that lints the staged Markdown files and blocks the commit on a finding. The capability entrypoint installs it into the session volume's `.git/hooks/pre-commit` on every start (fresh and resume). A check is bypassed deliberately with `git commit --no-verify`. The hook source is `src/capability/git-hooks/pre-commit.sh`, baked into the capability image; the harness owns it, and it is not part of a project's committed files.

**Rationale.** The copy-delivery `.git` lives inside the session volume, so a hook installed there can never execute on the host. The Markdown gate then fires where the change is made, instead of only at pre-close review. The hook lints the staged Markdown file list with `--no-globs`, so a commit does not re-lint the whole repository.

**Rejected alternatives.**

- **Mount delivery installs the hook too.** Rejected for security: the mount `.git` is a host directory (`${SANDBOX_DIR}/.worktree`), so the hook file is host-resident and the agent can rewrite it; a git operation in the worktree on the host would then run agent-controlled code. Mount delivery therefore installs no hook under the current delivery model.
- **`core.hooksPath` pointing at an image path.** Rejected on two counts: an absolute path that does not exist on the host breaks the host's git in mount delivery, and the agent can repoint the config away from the hook.
- **A `git` shim earlier on PATH.** Rejected as insufficient: it wraps one invocation path rather than hooking the operation, and any other `git` invocation bypasses it.

**Edge cases / drivers.**

- **Mount delivery excluded.** Mount delivery carries no commit hook under the current restrictions. This is a recorded limitation, not an oversight; lifting it requires a change to the delivery model's host-exposure posture.
- **Partial staging.** `markdownlint-cli2` reads the working-tree file, not the index copy, so a partially staged Markdown file is checked as it exists on disk.
- **Project `core.hooksPath`.** A project that sets `core.hooksPath` in its own config overrides the installed hook. The harness does not fight the project's git topology.
- **Missing linter.** If `markdownlint-cli2` is absent, the hook prints a note and allows the commit. The linter ships in every provider base, so a missing binary signals a stale image.
- **Non-Markdown commits.** A commit that stages no Markdown file exits immediately; the linter never runs.

**Rejected alternatives on record.** The delivery model states that the harness runs no hooks itself (`sandbox_delivery_model.md`, 2026-07-30 entry). This entry scopes that statement: the harness installs one hook, and only where the hook cannot reach the host.
