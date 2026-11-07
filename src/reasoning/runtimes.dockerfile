# reasoning/runtimes.dockerfile
# Shared agent-runtime tier for the reasoning layer. Tagged as agent-runtimes,
# and built as tier 2 by scripts/build.sh.
#
# What lives here and what does not:
#   Here  -- the registry-package agent-runtimes: @earendil-works/pi-coding-agent
#            and opencode-ai, each installed once.
#   Not here -- the language runtime set, which comes from agent-base
#            (reasoning/base.dockerfile); any provider's config, environment,
#            entrypoint or project content; and a source-built agent-runtime,
#            which keeps a provider base of its own.
#
# Each runtime installs frozen from its committed lockfile in
# src/reasoning/registry/, so the build never re-resolves a dependency tree.

ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

# pi's install runs no scripts: its postinstall is not needed for the CLI, and
# skipping it keeps the install to what the lockfile names.
COPY src/reasoning/registry/pi/ /opt/npm/pi/
RUN cd /opt/npm/pi && npm ci --ignore-scripts \
    && ln -s /opt/npm/pi/node_modules/.bin/* /usr/local/bin/

# The OpenCode CLI, so the runner seam (scripts/dispatch.sh) can dispatch a
# model only OpenCode reaches. pi's own request for the free tier answers 403
# FreeTierError; the real CLI, invoked as a subagent, is the sanctioned route.
# Unlike the pi install above, this one must run its postinstall: that script
# selects the platform package and writes it at the path opencode's bin names,
# so --ignore-scripts leaves the bin a stub that errors.
COPY src/reasoning/registry/opencode/ /opt/npm/opencode/
RUN cd /opt/npm/opencode && npm ci \
    && ln -s /opt/npm/opencode/node_modules/.bin/* /usr/local/bin/
