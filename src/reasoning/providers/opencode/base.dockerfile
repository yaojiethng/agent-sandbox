# providers/pi/base.dockerfile
# The pi agent install only. The shared runtime set (Node, Python, uv, CLI
# tools, lint gates) comes from agent-base; see reasoning/base.dockerfile.

ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

RUN npm install -g opencode-ai
