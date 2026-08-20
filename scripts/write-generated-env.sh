#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/assert-azure-context.sh"
source "${SCRIPT_DIR}/azure-context.sh"

foundry_id="$(az cognitiveservices account show \
  --name "$FOUNDRY_RESOURCE_NAME" \
  --resource-group "$FOUNDRY_RESOURCE_GROUP" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query id --output tsv)"

apim_url="$(az apim show \
  --name "$APIM_RESOURCE_NAME" \
  --resource-group "$FOUNDRY_RESOURCE_GROUP" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query gatewayUrl --output tsv)"

umask 077
{
  printf 'AZURE_TENANT_ID=%q\n' "$AZURE_TENANT_ID"
  printf 'AZURE_SUBSCRIPTION_ID=%q\n' "$AZURE_SUBSCRIPTION_ID"
  printf 'AZURE_LOCATION=%q\n' "$AZURE_LOCATION"
  printf 'FOUNDRY_RESOURCE_GROUP=%q\n' "$FOUNDRY_RESOURCE_GROUP"
  printf 'FOUNDRY_RESOURCE_NAME=%q\n' "$FOUNDRY_RESOURCE_NAME"
  printf 'FOUNDRY_RESOURCE_ID=%q\n' "$foundry_id"
  printf 'FOUNDRY_BASE_URL=%q\n' "https://${FOUNDRY_RESOURCE_NAME}.services.ai.azure.com/anthropic"
  printf 'FOUNDRY_PROJECT_NAME=%q\n' "$FOUNDRY_PROJECT_NAME"
  printf 'CLAUDE_DEPLOYMENT_NAME=%q\n' "$CLAUDE_DEPLOYMENT_NAME"
  printf 'CLAUDE_MODEL_NAME=%q\n' "$CLAUDE_MODEL_NAME"
  printf 'CLAUDE_MODEL_VERSION=%q\n' "$CLAUDE_MODEL_VERSION"
  printf 'APIM_RESOURCE_NAME=%q\n' "$APIM_RESOURCE_NAME"
  printf 'APIM_SUBSCRIPTION_NAME=%q\n' "$APIM_SUBSCRIPTION_NAME"
  printf 'APIM_CLAUDE_BASE_URL=%q\n' "${apim_url}/claude"
} > "${REPO_ROOT}/.env.azure.generated"

printf 'Wrote non-secret configuration to %s/.env.azure.generated\n' "$REPO_ROOT"
