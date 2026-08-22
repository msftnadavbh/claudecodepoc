#!/usr/bin/env bash
set +x
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
GENERATED_ENV="${REPO_ROOT}/.env.azure.generated"

if ! command -v jq >/dev/null 2>&1; then
  printf 'ERROR: jq is required by the Claude Desktop credential helper.\n' >&2
  exit 1
fi

source "${SCRIPT_DIR}/azure-context.sh" >/dev/null
if [[ ! -f "$GENERATED_ENV" ]]; then
  printf 'ERROR: Missing .env.azure.generated; run scripts/configure-claude-desktop.sh.\n' >&2
  exit 1
fi

configured_tenant_id="$AZURE_TENANT_ID"
configured_subscription_id="$AZURE_SUBSCRIPTION_ID"
"${SCRIPT_DIR}/assert-azure-context.sh" >/dev/null

unset AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID FOUNDRY_RESOURCE_GROUP
unset APIM_RESOURCE_NAME APIM_SUBSCRIPTION_NAME
set -a
if ! source "$GENERATED_ENV" >/dev/null; then
  set +a
  printf 'ERROR: Generated Azure configuration is invalid; rerun scripts/configure-claude-desktop.sh.\n' >&2
  exit 1
fi
set +a

for name in AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID FOUNDRY_RESOURCE_GROUP \
  APIM_RESOURCE_NAME APIM_SUBSCRIPTION_NAME; do
  if [[ -z "${!name:-}" ]]; then
    printf 'ERROR: Generated Azure configuration is missing %s.\n' "$name" >&2
    exit 1
  fi
done
if [[ "$AZURE_TENANT_ID" != "$configured_tenant_id" ||
      "$AZURE_SUBSCRIPTION_ID" != "$configured_subscription_id" ]]; then
  printf 'ERROR: Generated Azure configuration is stale; rerun scripts/configure-claude-desktop.sh.\n' >&2
  exit 1
fi

if ! apim_key="$(get_apim_subscription_key)"; then
  exit 1
fi

if ! printf '%s' "$apim_key" |
  jq -Rsc '{"token":"unused","headers":{"Ocp-Apim-Subscription-Key":.}}'; then
  printf 'ERROR: Unable to encode the Claude Desktop credential response.\n' >&2
  exit 1
fi

unset apim_key configured_tenant_id configured_subscription_id name
