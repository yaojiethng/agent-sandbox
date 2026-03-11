#!/usr/bin/env bash
# .vault/scripts/vault-prepare.sh
#
# Prepares a vault for use with agent-sandbox. Run via `make initialize`.
#
# Runs in sequence:
#   1. vault-init.sh   — git + LFS initialization and baseline commit
#   2. checkpoint-create.sh — baseline checkpoint
#
# If either step fails, vault-init.sh rolls back any partial git state.
# The vault is left unchanged on failure.
#
# If the problem looks like a file classification issue, run the LFS
# test suite to diagnose it:
#   bash .vault/tests/vault-lfs-test.sh --vault=<path>
#
# Usage:
#   bash .vault/scripts/vault-prepare.sh --vault=<path>
#
# Prerequisites: git, git-lfs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------
# Args
# -------------------------
VAULT_DIR=""

for arg in "$@"; do
  case "$arg" in
    --vault=*) VAULT_DIR="${arg#--vault=}" ;;
    *) echo "Unknown argument: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$VAULT_DIR" ]]; then
  echo "ERROR: --vault is required." >&2
  echo "Usage: bash .vault/scripts/vault-prepare.sh --vault=<path>" >&2
  exit 1
fi

if [[ ! -d "$VAULT_DIR" ]]; then
  echo "ERROR: vault directory not found: $VAULT_DIR" >&2
  exit 1
fi

VAULT_DIR="$(cd "$VAULT_DIR" && pwd)"

# -------------------------
# Helpers
# -------------------------
fail() {
  echo "" >&2
  echo "INITIALIZATION FAILED: $*" >&2
  echo "" >&2
  echo "If this looks like a file classification problem, run the LFS test suite:" >&2
  echo "  bash .vault/tests/vault-lfs-test.sh --vault=${VAULT_DIR}" >&2
  exit 1
}

# -------------------------
# Step 1 — Initialize
# -------------------------
echo "=== Step 1/2 — Initializing vault ==="
echo ""

bash "${SCRIPT_DIR}/vault-init.sh" --vault="$VAULT_DIR" \
  || fail "vault-init.sh did not complete successfully."

# -------------------------
# Step 2 — Baseline checkpoint
# -------------------------
echo ""
echo "=== Step 2/2 — Creating baseline checkpoint ==="
echo ""

bash "${SCRIPT_DIR}/checkpoint-create.sh" --root="$VAULT_DIR" --label="init" \
  || fail "checkpoint-create.sh did not complete successfully."

# -------------------------
# Done
# -------------------------
echo ""
echo "Vault ready. Run 'make start' to begin an agent session."
echo ""
echo "Before each session, ensure the working tree is clean."
echo "After applying agent output, create a new checkpoint:"
echo "  bash .vault/scripts/checkpoint-create.sh --root=${VAULT_DIR}"
