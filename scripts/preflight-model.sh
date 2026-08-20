#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/azure-context.sh"
"${SCRIPT_DIR}/assert-azure-context.sh"

catalog="$(az cognitiveservices model list \
  --location "$AZURE_LOCATION" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query "[?kind=='AIServices' && model.format=='Anthropic' && model.name=='${CLAUDE_MODEL_NAME}' && model.version=='${CLAUDE_MODEL_VERSION}' && model.capabilities.hostedOn=='azure'] | [0]" \
  --output json)"

if [[ "$catalog" == 'null' || -z "$catalog" ]]; then
  printf 'ERROR: %s version %s Hosted on Azure is unavailable in %s.\n' \
    "$CLAUDE_MODEL_NAME" "$CLAUDE_MODEL_VERSION" "$AZURE_LOCATION" >&2
  exit 1
fi
if ! jq -e '.model.skus | any(.name == "GlobalStandard")' >/dev/null <<<"$catalog"; then
  printf 'ERROR: %s version %s does not support GlobalStandard in %s.\n' \
    "$CLAUDE_MODEL_NAME" "$CLAUDE_MODEL_VERSION" "$AZURE_LOCATION" >&2
  exit 1
fi

if [[ "$DEPLOYMENT_MODE" == 'brownfield' ]]; then
  printf 'Model catalog:       %s version %s Hosted on Azure\n' "$CLAUDE_MODEL_NAME" "$CLAUDE_MODEL_VERSION"
  exit 0
fi

if [[ "$(az group exists --name "$FOUNDRY_RESOURCE_GROUP" --subscription "$AZURE_SUBSCRIPTION_ID")" == true ]]; then
  printf 'ERROR: Greenfield target resource group %s already exists. Use a new name or DEPLOYMENT_MODE=brownfield.\n' \
    "$FOUNDRY_RESOURCE_GROUP" >&2
  exit 1
fi

quota_name="AIServices.GlobalStandard.${CLAUDE_MODEL_NAME}.Azure"
usage="$(az cognitiveservices usage list \
  --location "$AZURE_LOCATION" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --query "[?name.value=='${quota_name}'] | [0]" \
  --output json)"

if [[ "$usage" == 'null' || -z "$usage" ]]; then
  printf 'ERROR: No Hosted-on-Azure quota row %s is available in this subscription.\n' "$quota_name" >&2
  exit 1
fi

limit="$(jq -r '.limit | floor' <<<"$usage")"
current="$(jq -r '.currentValue | floor' <<<"$usage")"
available=$((limit - current))
if ((available < CLAUDE_MODEL_CAPACITY)); then
  printf 'ERROR: Insufficient %s quota: requested=%dK TPM available=%dK TPM.\n' \
    "$CLAUDE_MODEL_NAME" "$CLAUDE_MODEL_CAPACITY" "$available" >&2
  exit 1
fi

printf 'Model catalog:       %s version %s Hosted on Azure\n' "$CLAUDE_MODEL_NAME" "$CLAUDE_MODEL_VERSION"
printf 'Model quota:         requested=%dK TPM available=%dK TPM\n' "$CLAUDE_MODEL_CAPACITY" "$available"
