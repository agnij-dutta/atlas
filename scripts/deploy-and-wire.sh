#!/usr/bin/env bash
set -euo pipefail

# Atlas Protocol — Deploy contracts and wire all packages
# Usage: ./scripts/deploy-and-wire.sh
# Requires: PRIVATE_KEY env var set, wallet funded with Base Sepolia ETH

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
CONTRACTS_DIR="$ROOT_DIR/packages/contracts"
RPC_URL="${BASE_SEPOLIA_RPC_URL:-https://sepolia.base.org}"

echo "=== Atlas Protocol Deployment ==="
echo "RPC: $RPC_URL"
echo ""

# Check private key
if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "ERROR: PRIVATE_KEY env var not set"
  exit 1
fi

DEPLOYER=$(cast wallet address "$PRIVATE_KEY" 2>/dev/null)
echo "Deployer: $DEPLOYER"

# Check balance
BALANCE=$(cast balance "$DEPLOYER" --rpc-url "$RPC_URL" 2>/dev/null)
echo "Balance: $BALANCE wei"
if [ "$BALANCE" = "0" ]; then
  echo "ERROR: Deployer has 0 balance. Fund it with Base Sepolia ETH first."
  exit 1
fi
echo ""

# Deploy
echo "=== Deploying contracts ==="
cd "$CONTRACTS_DIR"
DEPLOY_OUTPUT=$(forge script script/Deploy.s.sol \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  -vvv 2>&1)

echo "$DEPLOY_OUTPUT" | tail -30

# Extract addresses from deploy output
REGISTRY=$(echo "$DEPLOY_OUTPUT" | grep "WorkflowRegistry:" | awk '{print $2}')
ENGINE=$(echo "$DEPLOY_OUTPUT" | grep "ExecutionEngine:" | awk '{print $2}')
REWARD=$(echo "$DEPLOY_OUTPUT" | grep "RewardManager:" | awk '{print $2}')

if [ -z "$REGISTRY" ] || [ -z "$ENGINE" ] || [ -z "$REWARD" ]; then
  echo "ERROR: Failed to extract addresses from deploy output"
  echo "Full output:"
  echo "$DEPLOY_OUTPUT"
  exit 1
fi

echo ""
echo "=== Deployed Addresses ==="
echo "WorkflowRegistry: $REGISTRY"
echo "ExecutionEngine:  $ENGINE"
echo "RewardManager:    $REWARD"
echo ""

# Register the executor (deployer) on the engine
echo "=== Registering deployer as executor ==="
# The ExecutionEngine is already registered as executor on Registry and RewardManager via Deploy.s.sol
# Now register the deployer wallet as an executor on ExecutionEngine
cast send "$ENGINE" "addExecutor(address)" "$DEPLOYER" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  2>/dev/null && echo "Deployer registered as executor on ExecutionEngine" || echo "Warning: executor registration may have failed"

echo ""

# Wire addresses into all packages
echo "=== Wiring addresses into packages ==="

# 1. shared/constants
SHARED_CONSTANTS="$ROOT_DIR/packages/shared/src/constants/index.ts"
cat > "$SHARED_CONSTANTS" << EOF
export const ATLAS_CONTRACTS = {
  baseSepolia: {
    workflowRegistry: '${REGISTRY}' as \`0x\${string}\`,
    executionEngine: '${ENGINE}' as \`0x\${string}\`,
    rewardManager: '${REWARD}' as \`0x\${string}\`,
  },
} as const;

export const BASE_SEPOLIA_CHAIN_ID = 84532;
export const MIN_REWARD_PER_STEP = 100000000000000n; // 0.0001 ETH
export const EXECUTOR_SELECTION_WINDOW = 2; // blocks
export const GAS_PROFITABILITY_MULTIPLIER = 1.2;
EOF
echo "  Updated: packages/shared/src/constants/index.ts"

# 2. dashboard/lib/contracts.ts
DASHBOARD_CONTRACTS="$ROOT_DIR/packages/dashboard/src/lib/contracts.ts"
sed -i.bak "s|process.env.NEXT_PUBLIC_REGISTRY_ADDRESS || '0x0.*'|process.env.NEXT_PUBLIC_REGISTRY_ADDRESS || '${REGISTRY}'|" "$DASHBOARD_CONTRACTS" 2>/dev/null || true
sed -i.bak "s|process.env.NEXT_PUBLIC_ENGINE_ADDRESS || '0x0.*'|process.env.NEXT_PUBLIC_ENGINE_ADDRESS || '${ENGINE}'|" "$DASHBOARD_CONTRACTS" 2>/dev/null || true
sed -i.bak "s|process.env.NEXT_PUBLIC_REWARD_ADDRESS || '0x0.*'|process.env.NEXT_PUBLIC_REWARD_ADDRESS || '${REWARD}'|" "$DASHBOARD_CONTRACTS" 2>/dev/null || true
rm -f "${DASHBOARD_CONTRACTS}.bak"
echo "  Updated: packages/dashboard/src/lib/contracts.ts"

# 3. subgraph.yaml
SUBGRAPH_YAML="$ROOT_DIR/packages/subgraph/subgraph.yaml"
sed -i.bak "s|address: '0x0000000000000000000000000000000000000000'|address: '${REGISTRY}'|" "$SUBGRAPH_YAML" 2>/dev/null
# Need to handle each datasource separately — use python or manual
# For now just replace all zero addresses in order
python3 -c "
import re
with open('$SUBGRAPH_YAML', 'r') as f:
    content = f.read()
addrs = ['$REGISTRY', '$ENGINE', '$REWARD']
idx = 0
def replacer(match):
    global idx
    if idx < len(addrs):
        addr = addrs[idx]
        idx += 1
        return f\"address: '{addr}'\"
    return match.group(0)
content = re.sub(r\"address: '0x0{40}'\", replacer, content)
# Set startBlock to a recent block
content = re.sub(r'startBlock: 0', 'startBlock: 20000000', content)
with open('$SUBGRAPH_YAML', 'w') as f:
    f.write(content)
" 2>/dev/null && echo "  Updated: packages/subgraph/subgraph.yaml" || echo "  Warning: subgraph.yaml update needs manual fix"
rm -f "${SUBGRAPH_YAML}.bak"

# 4. Create .env files
cat > "$ROOT_DIR/packages/executor/.env" << EOF
PRIVATE_KEY=${PRIVATE_KEY}
RPC_URL=${RPC_URL}
REGISTRY_ADDRESS=${REGISTRY}
ENGINE_ADDRESS=${ENGINE}
REWARD_ADDRESS=${REWARD}
EXECUTOR_INDEX=0
TOTAL_EXECUTORS=1
LOG_LEVEL=info
EOF
echo "  Created: packages/executor/.env"

cat > "$ROOT_DIR/packages/dashboard/.env.local" << EOF
NEXT_PUBLIC_WC_PROJECT_ID=75628b0ef3dfd5cf95da9d669c0edda7
NEXT_PUBLIC_REGISTRY_ADDRESS=${REGISTRY}
NEXT_PUBLIC_ENGINE_ADDRESS=${ENGINE}
NEXT_PUBLIC_REWARD_ADDRESS=${REWARD}
EOF
echo "  Created: packages/dashboard/.env.local"

# 5. Save deployment record
DEPLOY_RECORD="$ROOT_DIR/deployments/base-sepolia.json"
mkdir -p "$(dirname "$DEPLOY_RECORD")"
cat > "$DEPLOY_RECORD" << EOF
{
  "network": "base-sepolia",
  "chainId": 84532,
  "deployer": "${DEPLOYER}",
  "deployedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "contracts": {
    "WorkflowRegistry": "${REGISTRY}",
    "ExecutionEngine": "${ENGINE}",
    "RewardManager": "${REWARD}"
  }
}
EOF
echo "  Created: deployments/base-sepolia.json"

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "  1. cd packages/dashboard && pnpm dev  (start dashboard)"
echo "  2. cd packages/executor && pnpm dev   (start executor)"
echo "  3. Create a test workflow via the dashboard"
echo ""
