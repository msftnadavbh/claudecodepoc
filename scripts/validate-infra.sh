#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/assert-azure-context.sh"
source "${SCRIPT_DIR}/azure-context.sh"
source "${SCRIPT_DIR}/bicep-parameters.sh"

deploy_gateway=false
if [[ "${1:-}" == '--gateway' ]]; then
  deploy_gateway=true
elif [[ $# -gt 0 ]]; then
  printf 'Usage: %s [--gateway]\n' "$0" >&2
  exit 2
fi

"${SCRIPT_DIR}/preflight-model.sh"
"${SCRIPT_DIR}/discover-foundry.sh"

az deployment sub validate \
  --name "claude-code-poc-validation" \
  --location "$AZURE_LOCATION" \
  --template-file "${REPO_ROOT}/infra/main.bicep" \
  "${BICEP_PARAMETERS[@]}" \
  --parameters deployGateway="$deploy_gateway" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --output none

az deployment sub what-if \
  --name "claude-code-poc-what-if" \
  --location "$AZURE_LOCATION" \
  --template-file "${REPO_ROOT}/infra/main.bicep" \
  "${BICEP_PARAMETERS[@]}" \
  --parameters deployGateway="$deploy_gateway" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --result-format ResourceIdOnly
