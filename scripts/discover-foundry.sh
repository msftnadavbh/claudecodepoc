#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/assert-azure-context.sh"
source "${SCRIPT_DIR}/azure-context.sh"

printf 'Locked subscription: %s\n' "$AZURE_SUBSCRIPTION_ID"
printf 'Target region:       %s\n' "$AZURE_LOCATION"

rg="$(az group show \
  --name "$FOUNDRY_RESOURCE_GROUP" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --output json)"
jq -e --arg location "$AZURE_LOCATION" '.location == $location' >/dev/null <<<"$rg"
printf 'Resource group:      %s (existing)\n' "$FOUNDRY_RESOURCE_GROUP"

foundry="$(az cognitiveservices account show \
  --name "$FOUNDRY_RESOURCE_NAME" \
  --resource-group "$FOUNDRY_RESOURCE_GROUP" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --output json)"
jq -e --arg location "$AZURE_LOCATION" '
  .kind == "AIServices" and
  .location == $location and
  .properties.provisioningState == "Succeeded"
' >/dev/null <<<"$foundry"
printf 'Foundry resource:    %s (existing, Succeeded)\n' "$FOUNDRY_RESOURCE_NAME"

project="$(az rest \
  --method get \
  --url "https://management.azure.com/subscriptions/${AZURE_SUBSCRIPTION_ID}/resourceGroups/${FOUNDRY_RESOURCE_GROUP}/providers/Microsoft.CognitiveServices/accounts/${FOUNDRY_RESOURCE_NAME}/projects/${FOUNDRY_PROJECT_NAME}?api-version=2026-05-01" \
  --output json)"
jq -e --arg location "$AZURE_LOCATION" '
  .location == $location and
  .properties.provisioningState == "Succeeded"
' >/dev/null <<<"$project"
printf 'Foundry project:     %s (existing, Succeeded)\n' "$FOUNDRY_PROJECT_NAME"

deployment="$(az cognitiveservices account deployment show \
  --name "$FOUNDRY_RESOURCE_NAME" \
  --resource-group "$FOUNDRY_RESOURCE_GROUP" \
  --deployment-name "$CLAUDE_DEPLOYMENT_NAME" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --output json)"
jq -e --arg model "$CLAUDE_MODEL_NAME" --arg version "$CLAUDE_MODEL_VERSION" '
  .properties.provisioningState == "Succeeded" and
  .properties.model.format == "Anthropic" and
  .properties.model.name == $model and
  .properties.model.version == $version
' >/dev/null <<<"$deployment"
printf 'Claude deployment:   %s (%s v%s, %s/%sK TPM, Succeeded)\n' \
  "$CLAUDE_DEPLOYMENT_NAME" "$CLAUDE_MODEL_NAME" "$CLAUDE_MODEL_VERSION" \
  "$(jq -r '.sku.name' <<<"$deployment")" "$(jq -r '.sku.capacity' <<<"$deployment")"

apim_id="$(az apim show \
  --name "$APIM_RESOURCE_NAME" \
  --resource-group "$FOUNDRY_RESOURCE_GROUP" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query id --output tsv 2>/dev/null || true)"
printf 'APIM resource:       %s\n' "${apim_id:-absent (greenfield)}"
