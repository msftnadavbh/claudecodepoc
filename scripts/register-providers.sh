#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/azure-context.sh"
"${SCRIPT_DIR}/assert-azure-context.sh"

for provider in Microsoft.ApiManagement Microsoft.CognitiveServices Microsoft.Insights Microsoft.OperationalInsights; do
  if [[ "$(az provider show --namespace "$provider" --subscription "$AZURE_SUBSCRIPTION_ID" --query registrationState --output tsv)" != 'Registered' ]]; then
    printf 'Registering %s...\n' "$provider"
    az provider register --namespace "$provider" --wait --subscription "$AZURE_SUBSCRIPTION_ID"
  fi
done
