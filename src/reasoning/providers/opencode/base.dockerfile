ARG BASE_IMAGE=agent-node-base
FROM ${BASE_IMAGE}

RUN npm install -g opencode-ai
