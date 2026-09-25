#!/usr/bin/env bash
cd /home/agentuser/sandbox || exit 1
F=scripts/templates/Makefile.template
run_case() {
  local name="$1" OLD="$2" NEW="$3"
  cp /tmp/mk.orig "$F"
  OLD="$OLD" NEW="$NEW" perl -0777 -pi -e 's/\Q$ENV{OLD}\E/$ENV{NEW}/' "$F"
  if cmp -s /tmp/mk.orig "$F"; then echo "$name  NO-OP-MUTANT"; cp /tmp/mk.orig "$F"; return; fi
  local out rc
  out=$(bash scripts/run_tests.sh 2>&1); rc=$?
  if [[ $rc -eq 0 ]]; then echo "$name  SURVIVED"; else echo "$name  PROVEN  ($(echo "$out" | tail -1 | cut -c1-58))"; fi
  cp /tmp/mk.orig "$F"
}

run_case M1 'stop:
	agent-sandbox stop \
	  --env=$(ENV_FILE) \
	  $(SESSION_ID_FLAG) \
	  $(PRUNE_FLAG)' 'stop:
	agent-sandbox stop \
	  --project=$(PROJECT_DIR) \
	  --env=$(ENV_FILE) \
	  $(SESSION_ID_FLAG) \
	  $(PRUNE_FLAG)'
run_case M2 'start:
	agent-sandbox start \
	  $(PROVIDER_FLAG) \' 'start:
	agent-sandbox start \
	  --sandbox=$(SANDBOX_DIR) \
	  $(PROVIDER_FLAG) \'
run_case M3 'ifdef CHANNEL
$(error CHANNEL is not a Make variable. Did you mean FROM? Example: make $(MAKECMDGOALS) FROM=$(CHANNEL))
endif
' ''
run_case M4 '	  $(if $(FORCE),--force,)
' ''
run_case M5 '.PHONY: build start dry-run stop apply draft confirm reject refresh help' '.PHONY: build start dry-run stop apply draft confirm refresh help'
run_case M6 'DRAFT_CHANNEL := $(if $(FROM),$(FROM),session)' 'DRAFT_CHANNEL := $(if $(FROM),$(FROM),autosave)'
run_case M7 '# agent-sandbox template version: 5' '# agent-sandbox template version: 6'
run_case M8 '# Harness maintenance
# -------------------------
#
# refresh: update stale template files and re-register git aliases after a
# harness update. Safe to run repeatedly  --  does not overwrite .env.

# -------------------------
# Package exports' '# -------------------------
# Package exports'
run_case M9 '@echo "  FORCE=1           --  apply with --reject (draft/apply)"' '@echo "  FORCE=1           --  changed"'
run_case M10 'ENV_FILE := $(CURDIR)/.env' 'ENV_FILE := $(CURDIR)/env'
run_case M11 '	  $(INTERACTIVE_FLAG) \
	  $(DELIVERY_FLAG) \' '	  $(DELIVERY_FLAG) \'
echo "--- restore ---"; cmp -s /tmp/mk.orig "$F" && echo "byte-identical" || echo "MISMATCH"
