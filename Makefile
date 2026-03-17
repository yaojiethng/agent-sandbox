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
PROJECT_DIR    := $(CURDIR)
SANDBOX_DIR    := $(CURDIR)/sandbox
AGENT_BRIEF    := docs/development/agent_context_brief.md
ENV_FILE       := .env
INSTALL_DIR	   := ~/.local/bin


# -------------------------
# Container targets
# -------------------------

.PHONY: build
build:
	agent-sandbox build \
	  --name=$(PROJECT_NAME) \
	  --root=$(PROJECT_ROOT)

.PHONY: start
start:
	agent-sandbox start \
	  --name=$(PROJECT_NAME) \
	  --root=$(PROJECT_ROOT) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

.PHONY: serve
serve:
	agent-sandbox start \
	  --name=$(PROJECT_NAME) \
	  --root=$(PROJECT_ROOT) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE) \
	  --serve

.PHONY: dry-run
dry-run:
	agent-sandbox dry-run \
	  --name=$(PROJECT_NAME) \
	  --root=$(PROJECT_ROOT) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

.PHONY: rebuild
rebuild:
	agent-sandbox rebuild start \
	  --name=$(PROJECT_NAME) \
	  --root=$(PROJECT_ROOT) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE) \
	  --serve

# -------------------------
# Workspace targets
# -------------------------

.PHONY: apply
apply:
	agent-sandbox apply \
	  --root=$(PROJECT_ROOT) \
	  $(if $(BRANCH),--branch=$(BRANCH),)

# -------------------------
# Install
# -------------------------

.PHONY: install
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

.PHONY: uninstall
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
	@echo "Usage: make <target> [PREFIX=<path>]"
	@echo ""
	@echo "Container:"
	@echo "  build        — build Docker image only"
	@echo "  start        — start container (builds if image missing)"
	@echo "  serve        — start container in serve mode (builds if image missing)"
	@echo "  dry-run      — liveness check only (builds if image missing)"
	@echo "  rebuild      — force rebuild then start in serve mode"
	@echo "  Use: agent-sandbox rebuild <start|dry-run> ... for other modes"
	@echo ""
	@echo "Workspace:"
	@echo "  apply              — apply staged.diff to current branch"
	@echo "  apply BRANCH=<n>   — apply staged.diff to named branch (created if needed)"
	@echo ""
	@echo "Install:"
	@echo "  install                    — install agent-sandbox CLI"
	@echo "  install INSTALL_DIR=<path> — install to specified directory"
	@echo "  uninstall                  — remove agent-sandbox CLI"
	@echo ""
	@echo "Install directory resolution (in order):"
	@echo "  1. INSTALL_DIR=<path> argument"
	@echo "  2. INSTALL_DIR in .env"
	@echo "  3. /usr/local/bin (default)"
