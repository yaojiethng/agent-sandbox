ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@1.3.0

# The OpenCode CLI, so the runner seam (src/libs/dispatch.sh) can dispatch a
# model only OpenCode reaches. pi's own request for the free tier answers 403
# FreeTierError; the real CLI, invoked as a subagent, is the sanctioned route.
# OpenCode stays a base-level provider as well, so this install is the dispatch
# tool rather than a replacement for that image.
RUN npm install -g --ignore-scripts opencode-ai@1.19.1