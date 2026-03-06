# Makefile — agent-sandbox
# Usage: make <target> [MACHINE=<suffix>]
#
# Examples:
#   make start MACHINE=wsl
#   make serve MACHINE=wsl
#   make dry-run MACHINE=wsl
#   make apply MACHINE=wsl
#   make apply-branch BRANCH=agent_branch_1 MACHINE=wsl

PROJECT    := agent-sandbox
MACHINE    ?= wsl
BRANCH     ?= agent_branch
SCRIPTS    := ./providers/opencode/scripts

# Build machine flag if MACHINE is set
ifdef MACHINE
MACHINE_FLAG := --machine=$(MACHINE)
else
MACHINE_FLAG :=
endif

# -------------------------
# Container targets
# -------------------------

.PHONY: start
start:
	$(SCRIPTS)/start_agent.sh $(PROJECT) standard $(MACHINE_FLAG)

.PHONY: serve
serve:
	$(SCRIPTS)/start_agent.sh $(PROJECT) standard --serve $(MACHINE_FLAG)

.PHONY: build
build:
	$(SCRIPTS)/start_agent.sh $(PROJECT) standard --build $(MACHINE_FLAG)

.PHONY: serve-build
serve-build:
	$(SCRIPTS)/start_agent.sh $(PROJECT) standard --serve --build $(MACHINE_FLAG)

.PHONY: dry-run
dry-run:
	$(SCRIPTS)/start_agent.sh $(PROJECT) dry-run $(MACHINE_FLAG)

# -------------------------
# Workspace targets
# -------------------------

.PHONY: apply
apply:
	$(SCRIPTS)/apply_workspace_inplace.sh $(PROJECT) $(MACHINE_FLAG)

.PHONY: apply-branch
apply-branch:
	$(SCRIPTS)/apply_workspace_to_branch.sh $(PROJECT) $(BRANCH) $(MACHINE_FLAG)

# -------------------------
# Help
# -------------------------

.PHONY: help
help:
	@echo "Usage: make <target> [MACHINE=<suffix>] [BRANCH=<name>]"
	@echo ""
	@echo "Container:"
	@echo "  start        — start container in standard mode"
	@echo "  serve        — start container in serve mode"
	@echo "  build        — build image and start container"
	@echo "  serve-build  — build image and start container in serve mode"
	@echo "  dry-run      — liveness check only"
	@echo ""
	@echo "Workspace:"
	@echo "  apply        — apply patch.diff to current branch inplace"
	@echo "  apply-branch — apply patch.diff to BRANCH (default: agent_branch)"
	@echo ""
	@echo "Options:"
	@echo "  MACHINE=<suffix>  use opencode.<suffix>.conf (e.g. MACHINE=wsl)"
	@echo "  BRANCH=<name>     branch name for apply-branch (default: agent_branch)"
