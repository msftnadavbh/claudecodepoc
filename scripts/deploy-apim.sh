#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/azure-context.sh"
source "${SCRIPT_DIR}/bicep-parameters.sh"

"${SCRIPT_DIR}/register-providers.sh"
"${SCRIPT_DIR}/validate-infra.sh" --gateway

az deployment sub create \
  --name "claude-code-poc-gateway" \
  --location "$AZURE_LOCATION" \
  --template-file "${REPO_ROOT}/infra/main.bicep" \
  "${BICEP_PARAMETERS[@]}" \
  --parameters deployGateway=true \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --output none

"${SCRIPT_DIR}/write-generated-env.sh"
"${SCRIPT_DIR}/discover-foundry.sh"

az apim show \
  --name "$APIM_RESOURCE_NAME" \
  --resource-group "$FOUNDRY_RESOURCE_GROUP" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query '{name:name,state:provisioningState,sku:sku.name,location:location,gatewayUrl:gatewayUrl,principalId:identity.principalId}' \
  --output table
