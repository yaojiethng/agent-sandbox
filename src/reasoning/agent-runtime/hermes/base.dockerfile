# providers/hermes/base.dockerfile
# Hermes reasoning layer base image.
# Inherits the shared runtime set from agent-base (see reasoning/base.dockerfile)
# and adds the Hermes agent install. Tagged as hermes-base (no project suffix --
# it contains no project-specific content).
# Built by scripts/build.sh --type=agent as tier 2.
#
# Multi-stage build: the builder compiles the Hermes Python packages; the
# runtime stage copies the venv and the source without carrying build tools
# (gcc, libffi-dev) into the final image. Both stages start from agent-base, so
# Node, Python, uv, and the repo lint gates are present in each.
#
# Provenance: the upstream Docker PR NousResearch/hermes-agent#1841 (Aralobster
# rewrite) moved this image to a multi-stage build on a pinned Python slim base
# with uv for venv and package work. Upstream installed Node and uv separately
# per stage; the shared base now owns both.
#
# Browser automation is Browserbase/CDP, not Playwright, so no browser layer.

ARG BASE_IMAGE=agent-base

# -- Stage 1: builder -------------------------------------------------
FROM ${BASE_IMAGE} AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        gcc libffi-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/hermes

RUN git clone https://github.com/NousResearch/hermes-agent /opt/hermes

RUN uv venv /opt/venv --python 3.11 && \
    uv pip install --python /opt/venv/bin/python --no-cache-dir -e ".[all]"

RUN npm install --omit=dev

# -- Stage 2: runtime -------------------------------------------------
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
        ffmpeg \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/venv /opt/venv
COPY --from=builder /opt/hermes /opt/hermes

WORKDIR /opt/hermes

ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv" \
    PYTHONUNBUFFERED=1
