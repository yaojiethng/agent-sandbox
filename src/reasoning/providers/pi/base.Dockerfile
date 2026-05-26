ARG BASE_IMAGE=agent-node-base
FROM ${BASE_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
        rsync fd-find ripgrep \
        shellcheck wget \
    && rm -rf /var/lib/apt/lists/*

    
RUN wget -O /usr/local/bin/hadolint https://github.com/hadolint/hadolint/releases/download/v2.14.0/hadolint-linux-x86_64 \
        && chmod +x /usr/local/bin/hadolint

RUN apt-get clean \
        && rm -rf /var/lib/apt/lists/*

RUN hadolint --version

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.75.5
