# reasoning/runtimes.dockerfile
# Shared agent-runtime tier for the reasoning layer. Tagged as agent-runtimes,
# and built as tier 2 by scripts/build.sh.
#
# What lives here and what does not:
#   Here  -- the registry-package agent-runtimes: @earendil-works/pi-coding-agent
#            and opencode-ai, each installed exactly once.
#   Not here -- the language runtime set, which comes from agent-base
#            (reasoning/base.dockerfile); any provider's config, environment,
#            entrypoint or project content; and a source-built agent-runtime,
#            which keeps a provider base of its own (providers/hermes/base.dockerfile).

ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@1.3.0

# The OpenCode CLI, so the runner seam (scripts/dispatch.sh) can dispatch a
# model only OpenCode reaches. pi's own request for the free tier answers 403
# FreeTierError; the real CLI, invoked as a subagent, is the sanctioned route.
# OpenCode stays a base-level provider as well, so this install is the dispatch
# tool rather than a replacement for that image.
# Unlike the pi-coding-agent install above, this one must run its postinstall:
# that script selects the platform package and writes it at the path opencode's
# bin names, so --ignore-scripts leaves the bin a stub that errors.
RUN npm install -g opencode-ai@1.19.1
