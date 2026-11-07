# reasoning/runtimes.dockerfile
# Shared agent-runtime tier for the reasoning layer. Tagged as agent-runtimes,
# and built as tier 2 by scripts/build.sh.
#
# What lives here and what does not:
#   Here  -- the agent-runtimes: @earendil-works/pi-coding-agent from its frozen
#            registry lockfile, and the OpenCode CLI from its pinned release
#            binary.
#   Not here -- the language runtime set, which comes from agent-base
#            (reasoning/base.dockerfile); any provider's config, environment,
#            entrypoint or project content; and a source-built agent-runtime,
#            which keeps a provider base of its own.
#
# pi installs frozen from its committed lockfile in src/reasoning/registry/, so
# the build never re-resolves a dependency tree. OpenCode does not: its package
# publishes one binary per platform and per C library, and npm installs every
# variant whose os and cpu match -- four of them here, 730MB for one executable.
# The image needs one binary, so the build pins that binary instead.

ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

# pi's install runs no scripts: its postinstall is not needed for the CLI, and
# skipping it keeps the install to what the lockfile names. The cache goes in
# the same layer, or the tarballs it holds ship in the image beside the tree
# they were unpacked into.
COPY src/reasoning/registry/pi/ /opt/npm/pi/
RUN cd /opt/npm/pi && npm ci --ignore-scripts \
    && npm cache clean --force \
    && ln -s /opt/npm/pi/node_modules/.bin/* /usr/local/bin/

# The OpenCode CLI, so the runner seam (scripts/dispatch.sh) can dispatch a
# model only OpenCode reaches. pi's own request for the free tier answers 403
# FreeTierError; the real CLI, invoked as a subagent, is the sanctioned route.
#
# The package's tarball holds the linux-x64 glibc binary and nothing else the
# image needs, so pinning the tarball, verifying it and keeping that one file
# replaces a dependency install of the whole platform matrix.
ARG OPENCODE_VERSION=1.19.1
ARG OPENCODE_SHA256=6ee2f2facfec08bd975f2c90eacec4c23078fe16744e0085f1f0a2ee3887a734
RUN curl -fsSL -o /tmp/opencode.tgz \
        "https://registry.npmjs.org/opencode-linux-x64/-/opencode-linux-x64-${OPENCODE_VERSION}.tgz" \
    && echo "${OPENCODE_SHA256}  /tmp/opencode.tgz" | sha256sum -c - \
    && tar -xzf /tmp/opencode.tgz -C /tmp package/bin/opencode \
    && install -D -m 0755 /tmp/package/bin/opencode /opt/opencode/opencode \
    && rm -rf /tmp/package /tmp/opencode.tgz \
    && ln -s /opt/opencode/opencode /usr/local/bin/opencode
