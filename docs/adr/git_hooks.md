# Git Hooks

**Current:** 2026-09-20

## 2026-09-20 -- Copy delivery installs a Markdown pre-commit hook

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
