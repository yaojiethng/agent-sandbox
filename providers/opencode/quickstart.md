# OpenCode Provider — Quick Reference

Operator cheat sheet for working with the OpenCode provider. Commands for debugging,
inspecting container state, and troubleshooting common issues.

---

## Build & run

```sh
# Build image
make build

# Start agent (interactive)
make start

# Start in serve mode (web UI)
make serve

# Force rebuild, then start
make start --rebuild
make serve --rebuild

# Liveness check
make dry-run
```

---

## Apply changes

```sh
# Apply to current branch
make apply

# Apply to named branch (created if missing)
make apply BRANCH=my-branch
```

---

## Container inspection

```sh
# List running containers
docker ps

# Attach a shell to a running container
docker exec -it opencode-agent-<project-name> bash

# Stream container logs (entrypoint output goes to stderr)
docker logs -f opencode-agent-<project-name>

# Run a throwaway shell in the image without starting the agent
docker run --rm -it opencode-agent-<project-name> bash
```

---

## Image management

```sh
# List images
docker images | grep opencode-agent

# Remove image (forces rebuild on next run)
docker rmi opencode-agent-<project-name>

# Remove all opencode-agent images
docker images | grep opencode-agent | awk '{print $3}' | xargs docker rmi
```

---

## Snapshot & workspace inspection

```sh
# Check snapshot contents before container starts
ls -la <PROJECT_ROOT>/.bootstrap/snapshot/

# Check workspace output after run
ls -la <PROJECT_ROOT>/.workspace/changes/
cat <PROJECT_ROOT>/.workspace/changes/staged.diff

# Check autosave diff mid-session
cat <PROJECT_ROOT>/.workspace/changes/autosave.diff
```

---

## Troubleshooting

**Container exits immediately**
Check entrypoint output: `docker logs opencode-agent-<project-name>`
Gate 2 snapshot validation likely failed — inspect `.bootstrap/snapshot/`.

**staged.diff is empty after run**
Agent made no changes, or the EXIT trap did not fire. Check container logs.
If the container was killed rather than exited cleanly, the trap may not have run.

**`make apply` reports nothing to apply**
`staged.diff` is missing or empty. Confirm the agent run completed cleanly.

**Image not found error on `make start`**
Run `make build` first. `start` does not build automatically if the image is absent
without the wrapper detecting it — confirm `agent-sandbox` CLI is installed: `which agent-sandbox`.

**WSL path errors**
All paths must be Linux format. Convert with:
```sh
wslpath 'C:\your\path'
```

**Line ending issues in conf or script files**
```sh
sed -i 's/\r//' <file>
```

**Debug Makefile expansion**
```sh
make --debug=basic <target>
```
