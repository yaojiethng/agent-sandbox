# Makefile — agent-sandbox
# This Makefile covers repo-level operations only: installing and uninstalling
# the agent-sandbox CLI.
#
# To run agent-sandbox against this project, use the sandbox Makefile:
#   make -C sandbox <target>
#   make -C sandbox help

SHELL      := /bin/bash
INSTALL_DIR := ~/.local/bin

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
	@echo "Usage: make <target>"
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
	@echo ""
	@echo "To run agent-sandbox against this project:"
	@echo "  make -C sandbox <target>"
	@echo "  make -C sandbox help"
