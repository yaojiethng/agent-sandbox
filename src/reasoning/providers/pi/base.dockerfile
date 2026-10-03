ARG BASE_IMAGE=agent-base
FROM ${BASE_IMAGE}

RUN npm install -g --ignore-scripts @earendil-works/pi-coding-agent@1.0.0