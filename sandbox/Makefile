# Makefile — agent-sandbox
# Usage: make <target>
#
# Examples:
#   make start
#   make serve
#   make dry-run
#   make apply
#   make apply BRANCH=my-branch

SHELL := /bin/bash

PROJECT_NAME   := agent-sandbox
PROJECT_DIR    := $(CURDIR)/..
SANDBOX_DIR    := $(CURDIR)
AGENT_BRIEF    := agents.md
ENV_FILE       := .env
INSTALL_DIR    := ~/.local/bin


# -------------------------
# Build
# -------------------------

.PHONY: build build-sandbox build-agent build-all

build: build-all

build-sandbox:
	agent-sandbox build sandbox \
	  --name=$(PROJECT_NAME) \
	  --sandbox=$(SANDBOX_DIR)

build-agent:
	agent-sandbox build agent \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR)

build-all:
	agent-sandbox build all \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR)

# -------------------------
# Run
# -------------------------

.PHONY: start serve dry-run

start:
	-agent-sandbox start \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

serve:
	-agent-sandbox serve \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

dry-run:
	agent-sandbox dry-run \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

# -------------------------
# Apply
# -------------------------

.PHONY: apply

apply:
	agent-sandbox apply \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  $(if $(BRANCH),--branch=$(BRANCH),)

# -------------------------
# Rebuild (force rebuild all images, then start)
# -------------------------

.PHONY: rebuild rebuild-start rebuild-serve rebuild-dry-run

rebuild: rebuild-start

rebuild-start:
	-agent-sandbox rebuild start \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

rebuild-serve:
	-agent-sandbox rebuild serve \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

rebuild-dry-run:
	agent-sandbox rebuild dry-run \
	  --name=$(PROJECT_NAME) \
	  --project=$(PROJECT_DIR) \
	  --sandbox=$(SANDBOX_DIR) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

# -------------------------
# Workspace
# -------------------------

# -------------------------
# Install
# -------------------------

.PHONY: install uninstall

install:
	@_INSTALL_DIR="$(INSTALL_DIR)"; \
	if [[ -z "$$_INSTALL_DIR" && -f .env ]]; then \
	  _INSTALL_DIR=$$(grep '^INSTALL_DIR=' .env | cut -d'=' -f2-); \
	fi; \
	if [[ -z "$$_INSTALL_DIR" ]]; then \
	  _INSTALL_DIR="/usr/local/bin"; \
	fi; \
	_INSTALL_DIR="$${_INSTALL_DIR/#\~/$${HOME}}"; \
	sed 's|@@AGENT_SANDBOX_REPO@@|$(CURDIR)|g' scripts/agent-sandbox.sh \
	  > "$$_INSTALL_DIR/agent-sandbox"; \
	chmod +x "$$_INSTALL_DIR/agent-sandbox"; \
	echo "Installed agent-sandbox to $$_INSTALL_DIR/agent-sandbox"

uninstall:
	@_INSTALL_DIR="$(INSTALL_DIR)"; \
	if [[ -z "$$_INSTALL_DIR" && -f .env ]]; then \
	  _INSTALL_DIR=$$(grep '^INSTALL_DIR=' .env | cut -d'=' -f2-); \
	fi; \
	if [[ -z "$$_INSTALL_DIR" ]]; then \
	  _INSTALL_DIR="/usr/local/bin"; \
	fi; \
	_INSTALL_DIR="$${_INSTALL_DIR/#\~/$${HOME}}"; \
	rm -f "$$_INSTALL_DIR/agent-sandbox"; \
	echo "Removed $$_INSTALL_DIR/agent-sandbox"

# -------------------------
# Help
# -------------------------

.PHONY: help

help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Build:"
	@echo "  build            — build both images (alias for build-all)"
	@echo "  build-sandbox    — build capability layer image only"
	@echo "  build-agent      — build reasoning layer image only"
	@echo "  build-all        — build both images"
	@echo ""
	@echo "Run:"
	@echo "  start            — start session (builds if images missing)"
	@echo "  serve            — start in serve mode (builds if images missing)"
	@echo "  dry-run          — liveness check (builds if images missing)"
	@echo ""
	@echo "Rebuild (force rebuild all images, then run):"
	@echo "  rebuild          — force rebuild then start (alias for rebuild-start)"
	@echo "  rebuild-start    — force rebuild then start"
	@echo "  rebuild-serve    — force rebuild then serve"
	@echo "  rebuild-dry-run  — force rebuild then dry-run"
	@echo ""
	@echo "Workspace:"
	@echo "  apply              — apply staged.diff to current branch"
	@echo "  apply BRANCH=<n>   — apply staged.diff to named branch"
	@echo ""
	@echo "Install:"
	@echo "  install                    — install agent-sandbox CLI"
	@echo "  install INSTALL_DIR=<path> — install to specified directory"
	@echo "  uninstall                  — remove agent-sandbox CLI"
