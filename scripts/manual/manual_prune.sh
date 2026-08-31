#!/usr/bin/env bash
# scripts/manual/manual_prune.sh

bash tests/knowledge/diagnose_prune_orphans.sh \                                  
        --sandbox="$HOME/sandbox/agent-sandbox" --name=agent-sandbox \
        --mode=cleanup --yes                                                         