#!/bin/bash
set -euo pipefail

# Environment variables expected from Jenkins
: "${PRIVATE_KEY:?Missing PRIVATE_KEY}"
: "${RPC_URL:?Missing RPC_URL}"
: "${CONTRACT_ADDRESS:?Missing CONTRACT_ADDRESS}"

ABI_FILE="contract_abi.json"
FUNC="mintTokenAndDistribute()"
# VIEW_FUNC="lastEmission()"

# Sanity check ABI file
if [ ! -f "$ABI_FILE" ]; then
  echo "❌ ABI file $ABI_FILE not found!"
  exit 1
fi

echo "📡 Connecting to: $RPC_URL"
echo "📜 Calling $FUNC on $CONTRACT_ADDRESS"

# Send updatePeriod() transaction
TX_HASH=$(cast send "$CONTRACT_ADDRESS" "$FUNC" \
  --rpc-url "$RPC_URL" \
  --private-key "$PRIVATE_KEY" \
  --json \
  --legacy | jq -r '.transactionHash')

echo "⏳ TX sent: $TX_HASH"
echo "⏳ Waiting for confirmation..."

# Wait for confirmation
cast await "$TX_HASH" --rpc-url "$RPC_URL"

echo "✅ updatePeriod() confirmed"

# # Query lastEmission
# LAST=$(cast call "$CONTRACT_ADDRESS" "$VIEW_FUNC" \
#   --rpc-url "$RPC_URL" \
#   --abi "$ABI_FILE")

# echo "📊 lastEmission: $LAST"
