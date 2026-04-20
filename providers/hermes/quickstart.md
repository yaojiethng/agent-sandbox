# Hermes Provider — Quick Reference

Day-to-day command reference and troubleshooting for the Hermes provider. All commands run from `SANDBOX_DIR`.

---

## Build & run

```sh
# Build all images
make build

# Build Hermes provider image only
make build TARGET=hermes

# Start agent (interactive)
make start PROVIDER=hermes

# Start in serve mode (Open WebUI + Hermes gateway)
make serve PROVIDER=hermes

# Liveness check
make dry-run PROVIDER=hermes

# Rebuild images then start
make start PROVIDER=hermes REBUILD=1
make serve PROVIDER=hermes REBUILD=1
```

---

## Apply changes

```sh
# Review the diff first
cat .workspace/session-diffs/staged.diff

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

## Serve mode

In serve mode, Open WebUI is available at `http://localhost:<SERVE_PORT>` (default `46553`).
Hermes runs as a gateway API server; Open WebUI connects to it at `http://agent:8642/v1`.

```sh
# Start serve mode
make serve PROVIDER=hermes

# Open in browser
open http://localhost:46553
```

First run: Hermes may redirect to an interactive setup flow. Complete setup, exit to bash, then run `hermes chat` manually. On subsequent runs setup is skipped.

Config and credentials persist across runs in `.workspace/output/.hermes/`. See [Provider config](#provider-config) below.

---

## Container inspection

```sh
# List running containers
docker ps

# Attach a shell to the running agent container
docker exec -it hermes-agent-<PROJECT_NAME> bash

# Stream container logs
docker logs -f hermes-agent-<PROJECT_NAME>

# Run a throwaway shell in the image without starting the agent
docker run --rm -it hermes-agent-<PROJECT_NAME> bash
```

`<PROJECT_NAME>` is the value of `PROJECT_NAME` in `SANDBOX_DIR/Makefile`.

---

## Image management

```sh
# List images
docker images | grep hermes

# Remove provider image (forces rebuild on next run)
docker rmi hermes-agent-<PROJECT_NAME>

# Remove base image (forces full rebuild — slow)
docker rmi hermes-base
```

---

## Workspace inspection

```sh
# Check staged diff after a run
cat .workspace/session-diffs/staged.diff

# Check autosave diff mid-session
cat .workspace/session-diffs/autosave.diff

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

## Provider config

Hermes config and credentials persist on the host at `.workspace/output/.hermes/`:

```sh
# Edit provider credentials (API keys, model config)
$EDITOR .workspace/output/.hermes/.env

# Edit Hermes config (backend, model settings)
$EDITOR .workspace/output/.hermes/config.yaml
```

Both files are bind-mounted into the container at runtime. Changes take effect on the next `make start` or `make serve` — no rebuild required.

If `.workspace/output/.hermes/config.yaml` does not exist, `setup.sh` seeds it from `providers/hermes/config.yaml` on first run.

---

## Troubleshooting

**Container exits immediately**
Check entrypoint output: `docker logs hermes-agent-<PROJECT_NAME>`. Snapshot validation failure is the most common cause — check that `PROJECT_DIR` has at least one commit and no tracked files are missing from disk.

**`staged.diff` is empty after run**
Agent made no changes, or the EXIT trap did not fire. If the container was killed rather than stopped cleanly, the trap may not have run. Use `make stop` rather than `docker kill`.

**`make start` errors: PROVIDER not set**
`PROVIDER` is required: `make start PROVIDER=hermes`.

**Image not found**
Run `make build PROVIDER=hermes` before the first start. Images are not built automatically unless `REBUILD=1` is passed.

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

## Serve mode troubleshooting

**Open WebUI cannot connect to Hermes (`Connection refused` at `agent:8642`)**

Confirm Hermes gateway is running and bound to all interfaces:
```sh
# From inside the agent container
docker exec hermes-agent-<PROJECT_NAME> curl -s \
  -H "Authorization: Bearer $API_SERVER_KEY" \
  http://localhost:8642/v1/models
```
If this succeeds but Open WebUI still cannot connect, Hermes is binding to loopback only. Ensure the gateway command includes `--host 0.0.0.0`:
```yaml
# providers/hermes/docker-compose.serve.yml
services:
  agent:
    command: ["hermes", "gateway", "--host", "0.0.0.0"]
```

**Confirm cross-container connectivity**
```sh
# From inside the Open WebUI container
docker exec hermes-agent-<PROJECT_NAME>-open-webui curl -s \
  -H "Authorization: Bearer none" \
  http://agent:8642/v1/models
```
A valid JSON response confirms the connection is working. `Connection refused` means Hermes is not bound to `0.0.0.0`.

**Confirm both containers are on the same network**
```sh
docker inspect hermes-agent-<PROJECT_NAME> \
  --format '{{json .NetworkSettings.Networks}}'
docker inspect hermes-agent-<PROJECT_NAME>-open-webui \
  --format '{{json .NetworkSettings.Networks}}'
```
Both should show the same `NetworkID`.

**Ollama connection errors in Open WebUI logs**
```
Cannot connect to host host.docker.internal:11434
```
This is Open WebUI attempting to reach a local Ollama instance. Not required for Hermes. Suppress by adding to the `open-webui` service environment:
```yaml
environment:
  - ENABLE_OLLAMA_API=false
```

**Open WebUI shows no models**
Hermes gateway exposes a single model: `hermes-agent`. If the models list is empty, the Open WebUI ↔ Hermes connection has not been established — work through the connectivity steps above.

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
make dry-run PROVIDER=hermes
```

---

## References

| Document | Purpose |
|---|---|
| [`../../docs/operations/quickstart.md`](../../docs/operations/quickstart.md) | First-run setup guide |
| [`../../docs/architecture/tool_interface.md`](../../docs/architecture/tool_interface.md) | Full command reference and `.env` variables |
