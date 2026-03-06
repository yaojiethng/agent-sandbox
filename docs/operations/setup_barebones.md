# OpenCode Barebones First Iteration

This document describes the minimal setup to start coding with OpenCode agents safely. Focus is on getting agents running in containers with basic output staging.

---

## 1. Project Folder Structure

project-alpha/
├── src/             # main source code
├── tests/           # tests
├── .workspace/      # agent writes outputs here
│   └── changes/
└── logs/            # optional, ignored for now

**Notes:**

- Only `.workspace/` is considered trusted.
- Everything else is ignored in this iteration.
- No `.config/` or `.skills/` yet; barebones defaults.
- Safe mode: `--network none`.

---

## 2. Container Setup

- Minimal Docker image: `ubuntu:22.04`, Python, Git, curl
- Unprivileged agent user
- Mounts:
  - `src/` → read-only
  - `tests/` → read-only
  - `.workspace/` → read-write
- No other directories mounted
- Resource limits optional (`--memory`, `--cpus`)

---

## 3. Return Staging

- Agent writes **all outputs** to `.workspace/changes/`
- Review `.workspace/changes/` manually before applying to `src/` or `tests/`
- No git branches or PR workflow required at this stage
- Logs can be ignored or kept for debugging

---

## 4. Starting an Agent Container

#!/bin/bash
PROJECT=$1
docker run --rm -it \
  --name opencode-agent-$PROJECT \
  --user agentuser \
  --network none \
  -v ~/opencode-projects/$PROJECT/src:/home/agentuser/project/src:ro \
  -v ~/opencode-projects/$PROJECT/tests:/home/agentuser/project/tests:ro \
  -v ~/opencode-projects/$PROJECT/.workspace:/home/agentuser/project/.workspace \
  opencode-agent-image:latest \
  bash

- Usage: `./start-agent.sh project-alpha`
- Agent writes outputs only to `.workspace/changes/`
- Safe mode prevents network access

---

## 5. Recommended First Steps

1. Create project folder using above structure
2. Spin up container using the script
3. Agent writes outputs to `.workspace/changes/`
4. Review outputs manually
5. Merge manually into `src/` / `tests/` when satisfied

**Notes:**

- Start simple — ignore `.config/`, `.skills/`, secrets, and branch automation for now
- Workflow will evolve iteratively as you build habits
- Focus on **safety, readability, and output staging**