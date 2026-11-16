# Where the evidence lives

The skill states the search order. This file names the places, by runtime and delivery mode. A runtime not named here follows the same order with its own transcript and artifact store.

Start with the least durable evidence: the working tree and the index are lost on the next checkout; the reflog and dangling objects are eventually garbage-collected; the bundle and the transcript last until they are pruned.

## The repository

| Source | Where to look | Command |
|---|---|---|
| Working tree and index | the checkout the session ran in | `git status`, `git diff`, `git diff --cached` |
| Stash | the repository's stash | `git stash list`, `git stash show -p <ref>` |
| Refs | branches, tags, worktrees | `git branch -a`, `git tag`, `git worktree list`, `git log --all --oneline` |
| Reflog | the reference history | `git reflog --all --date=iso` |
| Dangling objects | unreachable commits and blobs | `git fsck --lost-found` |
| Draft and bundle | the draft branch, the packaged bundle | the output channel below; `make draft` |
| Transcript | the runtime's session log | the runtime section below |
| Host checkpoints | the host repository's tags | `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS`, the last five kept |

## pi

- **Session transcript:** `~/.pi/agent/sessions/<encoded-cwd>/<timestamp>_<id>.jsonl`. Each line is a message, a tool call or a tool result; the encoded directory names the working tree, and a task-queue worker has its own transcript. When no commit holds the work, this is the only record of what the edits were.
- **Model and provider settings:** `~/.pi/agent/settings.json`; a session's header names the provider and model it ran.

## This harness

- **Output channel:** `$HOME/workspace/output/` (or the mount the session declares). Agent-written and durable across the session; text and serialised data only.
- **Session diffs:** `$HOME/workspace/session-diffs/{session,autosave}/`. The capability layer writes them; `session/` holds the exit artifacts and `autosave/` the checkpoint.
- **Draft and bundle:** the draft branch is built from the packaged bundle; `make draft` rebuilds it. The bundle is on the host output channel.
- **Delivery mode:** copy delivery keeps `.git` inside the session volume, which persists and receives the hooks; mount delivery keeps `.git` in the host worktree, installs no hook, and the host repository is the source.
- **Session state:** `.git/SESSION_STATE` holds `init_sha`, `host_head_sha` and `session_id`, the claim's range and identity.
- **Host checkpoints:** tags named `agent-checkpoint/<worktree-id>/YYYYMMDD-HHMMSS`; the most recent five per worktree are kept.

## The task queue

- **Worktrees:** `$HOME/.taskq-worktrees/<sandbox>/<run>-<task>`, one per task, each with its own branch and its own transcript.
- **Branches:** a terminated task's branch is packaged into the run record before the worktree and branch are pruned; the run record and the package are the evidence after retirement.

## Other runtimes

The sequence is the same; the transcript and the artifact store move. Name the runtime's session log, its durable output, and whether its git state survives a restart. Name the runtime's own paths; if it has no session log, say so, and the record and the artifacts are the evidence.
