#!/usr/bin/env bash
# scripts/auth-setup.sh — verify Azure CLI session is ready.
set -euo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { printf "${GREEN}  OK${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW} WARN${NC} %s\n" "$1"; }
fail() { printf "${RED} FAIL${NC} %s\n" "$1"; }

echo ""
echo "=== Azure session check ==="
echo ""

if ! command -v az >/dev/null 2>&1; then
  fail "az CLI not found. Install from https://learn.microsoft.com/cli/azure/install-azure-cli"
  exit 1
fi
AZ_VER=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
ok "az CLI present (version: ${AZ_VER})"

ACCOUNT_JSON=$(az account show 2>/dev/null || true)
if [ -z "$ACCOUNT_JSON" ]; then
  warn "Not logged in. Running az login..."
  az login
  ACCOUNT_JSON=$(az account show 2>/dev/null || true)
fi

if [ -z "$ACCOUNT_JSON" ]; then
  fail "az login failed or was cancelled."
  exit 1
fi

SUB_NAME=$(echo "$ACCOUNT_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin)['name'])" 2>/dev/null || echo "unknown")
SUB_ID=$(echo "$ACCOUNT_JSON"   | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"   2>/dev/null || echo "unknown")
ok "Logged in — subscription: ${SUB_NAME} (${SUB_ID})"

# Token freshness check
TOKEN_EXP=$(az account get-access-token --query expiresOn -o tsv 2>/dev/null || echo "")
if [ -n "$TOKEN_EXP" ]; then
  ok "Token valid until: ${TOKEN_EXP}"
else
  warn "Could not determine token expiry — may need re-login during session."
fi

# Mark auth done for this session (suppresses SessionStart hook nudge)
PROJECT_HASH=$(echo "$PWD" | md5sum 2>/dev/null | cut -c1-8 || echo "anpunkit")
touch "/tmp/anpunkit-auth-${USER:-unknown}-${PROJECT_HASH}"

echo ""
echo "Azure session ready. You can now run /infra or Azure-dependent phases."
