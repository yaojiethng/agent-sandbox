# Makefile — agent-sandbox
# Usage: make <target>
#
# Examples:
#   make start
#   make serve
#   make dry-run
#   make apply
#   make apply BRANCH=my-branch

PROJECT_NAME   := agent-sandbox
PROJECT_ROOT   := $(CURDIR)
AGENT_BRIEF    := docs/development/agent_context_brief.md
ENV_FILE       := .env

PREFIX         ?= /usr/local/bin

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
	-agent-sandbox start \
	  --name=$(PROJECT_NAME) \
	  --root=$(PROJECT_ROOT) \
	  --brief=$(AGENT_BRIEF) \
	  --env=$(ENV_FILE)

.PHONY: serve
serve:
	-agent-sandbox start \
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
	-agent-sandbox rebuild start \
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
	@sed 's|@@AGENT_SANDBOX_REPO@@|$(CURDIR)|g' scripts/agent-sandbox.sh \
	  > $(PREFIX)/agent-sandbox
	@chmod +x $(PREFIX)/agent-sandbox
	@echo "Installed agent-sandbox to $(PREFIX)/agent-sandbox"

.PHONY: uninstall
uninstall:
	@rm -f $(PREFIX)/agent-sandbox
	@echo "Removed $(PREFIX)/agent-sandbox"

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
	@echo "  install      — install agent-sandbox CLI to PREFIX (default: /usr/local/bin)"
	@echo "  uninstall    — remove agent-sandbox CLI from PREFIX"
	@echo ""
	@echo "Options:"
	@echo "  PREFIX=<path>   install location (default: /usr/local/bin)"
