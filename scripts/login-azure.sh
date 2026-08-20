#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/azure-context.sh"

az login \
  --tenant "$AZURE_TENANT_ID" \
  --subscription "$AZURE_SUBSCRIPTION_ID" \
  --skip-subscription-discovery \
  --output none
"$(dirname -- "${BASH_SOURCE[0]}")/assert-azure-context.sh"
