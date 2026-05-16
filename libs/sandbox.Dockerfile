# dockerfile-default.sandbox
# agent-sandbox template version: 1
# Default capability layer Dockerfile template.
# Copy into SANDBOX_DIR as Dockerfile.sandbox and customise as needed.
# Docker Compose references the project-level Dockerfile.sandbox.
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# -------------------------
# System packages (root)
# -------------------------
# No Node/npm/opencode — the capability layer owns the sandbox and diff
# pipeline only. The reasoning layer container handles agent invocation.
RUN apt-get update && apt-get install -y \
    bash git ca-certificates rsync \
    && rm -rf /var/lib/apt/lists/*

# -------------------------
# Entrypoint and libs (root, before USER switch)
# -------------------------
# Build context is a temp directory populated by build_context in libs/build.sh;
# files are copied flat so paths here match the temp dir layout.
COPY sandbox-entrypoint.sh /opt/sandbox/bin/sandbox-entrypoint.sh
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY snapshot.sh /opt/sandbox/lib/snapshot.sh
COPY diff.sh /opt/sandbox/lib/diff.sh
COPY session.sh /opt/sandbox/lib/session.sh
COPY routing.sh /opt/sandbox/lib/routing.sh
COPY package_branch.sh /opt/sandbox/lib/package_branch.sh
COPY docs/ /opt/sandbox/docs/
RUN chmod +x /opt/sandbox/bin/sandbox-entrypoint.sh

# -------------------------
# Non-root user
# -------------------------
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser

# -------------------------
# Working directories
# -------------------------
# sandbox/ is owned by this container. The reasoning layer accesses it
# exclusively via --volumes-from — if this container is not running,
# the reasoning layer cannot start.
# VOLUME promotes sandbox/ to an anonymous Docker volume at container
# creation time, which is what makes --volumes-from work. It is not a
# named volume — it is removed with docker rm -v (or compose down -v)
# after each session so it does not persist across runs.
# workspace/session-diffs/ is bind-mounted from SANDBOX_DIR/.workspace/session-diffs/
# on the host — the diff pipeline writes changes.diff, EXPORT-TIME.txt, and patches/*.diff
# The capability layer does not mount the workspace parent.
# .snapshot/ is bind-mounted read-only from SANDBOX_DIR/.snapshot/ on the host.
# All directories created as agentuser so mounts are not blocked by ownership.
RUN mkdir -p /home/agentuser/sandbox \
             /home/agentuser/workspace/session-diffs \
             /home/agentuser/.snapshot

VOLUME /home/agentuser/sandbox

WORKDIR /home/agentuser

# -------------------------
# Health check
# -------------------------
# Checks that sandbox/.git exists — confirming snapshot copy and git init
# completed successfully. Compose uses this to gate reasoning layer startup:
# the reasoning layer service should declare depends_on with condition
# service_healthy so it does not start until this check passes.
HEALTHCHECK --interval=2s --timeout=5s --start-period=30s --retries=5 \
  CMD test -d /home/agentuser/sandbox/.git

ENTRYPOINT ["/opt/sandbox/bin/sandbox-entrypoint.sh"]
