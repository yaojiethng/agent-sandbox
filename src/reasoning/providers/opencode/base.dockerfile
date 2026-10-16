# providers/opencode/base.dockerfile
# The OpenCode CLI install only. The shared runtime set (Node, Python, uv, CLI
# tools, lint gates) comes from agent-base; see reasoning/base.dockerfile.

ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

# opencode-ai's postinstall builds the platform binary; passing --ignore-scripts
# here would leave this image's bin a stub that errors.
RUN npm install -g opencode-ai@1.19.1
