# OpenCode Provider — Quick Reference

Day-to-day command reference and troubleshooting for the OpenCode provider. All commands run from `SANDBOX_DIR`.

---

## Build & run

```sh
# Build all images
make build

# Build OpenCode provider image only
make build TARGET=opencode

# Start agent (interactive)
make start PROVIDER=opencode

# Start in serve mode (web UI)
make serve PROVIDER=opencode

# Liveness check
make dry-run PROVIDER=opencode

# Rebuild images then start
make start PROVIDER=opencode REBUILD=1
make serve PROVIDER=opencode REBUILD=1
```

---

## Apply changes

```sh
# Review the diff first
cat .workspace/session-diffs/<SESSION_TS>-<BRANCH>/session/staged.diff

# Apply to current branch
make apply

# Apply to a named branch (created if it does not exist)
make apply BRANCH=<branch-name>
```

---

## Stop

```sh
make stop
```

Stops all session containers and removes the sandbox volume.

---

## Container inspection

```sh
# List running containers
docker ps

# Attach a shell to the running agent container
docker exec -it opencode-agent-<PROJECT_NAME> bash

# Stream container logs
docker logs -f opencode-agent-<PROJECT_NAME>

# Run a throwaway shell in the image without starting the agent
docker run --rm -it opencode-agent-<PROJECT_NAME> bash
```

`<PROJECT_NAME>` is the value of `PROJECT_NAME` in `SANDBOX_DIR/Makefile`.

---

## Image management

```sh
# List images
docker images | grep opencode-agent

# Remove image (forces rebuild on next run)
docker rmi opencode-agent-<PROJECT_NAME>
```

---

## Workspace inspection

```sh
# Check staged diff (full session delta) after a run
cat .workspace/session-diffs/<SESSION_TS>-<BRANCH>/session/staged.diff

# Check autosave diff mid-session
cat .workspace/session-diffs/<SESSION_TS>-<BRANCH>/autosave/changes.diff

# Check snapshot contents before a run
ls -la .snapshot/
```

---

## Operator input channel

```sh
# Place task files before a run
cp my-task.md .workspace/input/

# Clear input between runs
rm .workspace/input/*
```

---

## Troubleshooting

**Container exits immediately**
Check entrypoint output: `docker logs opencode-agent-<PROJECT_NAME>`. Snapshot validation failure is the most common cause — check that `PROJECT_DIR` has at least one commit and no tracked files are missing from disk.

**`staged.diff` is empty after run**
Agent made no changes, or the EXIT trap did not fire. If the container was killed rather than stopped cleanly, the trap may not have run. Use `make stop` rather than `docker kill`.

**`make start` errors: PROVIDER not set**
`PROVIDER` is required: `make start PROVIDER=opencode`.

**Image not found**
Run `make build` before the first start. Images are not built automatically unless `REBUILD=1` is passed.

**`cp: cannot stat` during snapshot**
Tracked files are missing from disk. Fix:
```sh
git -C <PROJECT_DIR> rm --cached <file>
git -C <PROJECT_DIR> commit -m "remove missing file from index"
```

**WSL path errors**
All paths must be Linux format. Convert with: `wslpath 'C:\your\path'`

**Line ending issues in scripts or config files**
```sh
sed -i 's/\r//' <file>
```

---

## Recovery

If a bad diff has been applied and the project repo is in a broken state:

```sh
# Reset to a known-good commit
git -C <PROJECT_DIR> reset --hard <commit-sha>

# Clear workspace and snapshot
rm -rf .workspace/session-diffs/ .snapshot/
mkdir -p .workspace/session-diffs/

# Verify
make dry-run PROVIDER=opencode
```

---

## References

| Document | Purpose |
|---|---|
| [`../../docs/operations/quickstart.md`](../../docs/operations/quickstart.md) | First-run setup guide |
| [`../../docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Full command reference and `.env` variables |
