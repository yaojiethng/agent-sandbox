ARG BASE_IMAGE=agent-node-base
FROM ${BASE_IMAGE}

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@0.84.1
