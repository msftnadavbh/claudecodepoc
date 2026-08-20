#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/azure-context.sh"

if ! account="$(az account show --output json 2>/dev/null)"; then
  printf 'ERROR: The isolated Azure CLI context is not authenticated.\n' >&2
  printf 'Run: ./scripts/login-azure.sh\n' >&2
  exit 1
fi

actual_tenant="$(jq -r '.tenantId // empty' <<<"$account")"
actual_subscription="$(jq -r '.id // empty' <<<"$account")"

if [[ "$actual_tenant" != "$AZURE_TENANT_ID" || "$actual_subscription" != "$AZURE_SUBSCRIPTION_ID" ]]; then
  printf 'ERROR: Azure context mismatch; refusing to continue.\n' >&2
  printf 'Expected tenant:       %s\n' "$AZURE_TENANT_ID" >&2
  printf 'Actual tenant:         %s\n' "${actual_tenant:-<none>}" >&2
  printf 'Expected subscription: %s\n' "$AZURE_SUBSCRIPTION_ID" >&2
  printf 'Actual subscription:   %s\n' "${actual_subscription:-<none>}" >&2
  exit 1
fi

printf 'Azure context verified: tenant=%s subscription=%s\n' \
  "$AZURE_TENANT_ID" "$AZURE_SUBSCRIPTION_ID"
