ARG BASE_IMAGE=agent-node-base
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
        rsync fd-find ripgrep \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.75.4
