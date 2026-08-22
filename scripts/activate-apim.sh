#!/usr/bin/env bash

_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${_script_dir}/azure-context.sh"
"${_script_dir}/assert-azure-context.sh" || return 1

if [[ ! -f "${REPO_ROOT}/.env.azure.generated" ]]; then
  printf 'ERROR: Run scripts/deploy.sh first.\n' >&2
  return 1
fi

_configured_tenant_id="$AZURE_TENANT_ID"
_configured_subscription_id="$AZURE_SUBSCRIPTION_ID"
unset AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID FOUNDRY_RESOURCE_GROUP
unset APIM_RESOURCE_NAME APIM_SUBSCRIPTION_NAME APIM_CLAUDE_BASE_URL CLAUDE_DEPLOYMENT_NAME
set -a
if ! source "${REPO_ROOT}/.env.azure.generated"; then
  set +a
  printf 'ERROR: Generated Azure configuration is invalid; run scripts/deploy.sh again.\n' >&2
  return 1
fi
set +a

for _name in AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID FOUNDRY_RESOURCE_GROUP \
  APIM_RESOURCE_NAME APIM_SUBSCRIPTION_NAME APIM_CLAUDE_BASE_URL CLAUDE_DEPLOYMENT_NAME; do
  if [[ -z "${!_name:-}" ]]; then
    printf 'ERROR: Generated Azure configuration is missing %s; run scripts/deploy.sh again.\n' "$_name" >&2
    return 1
  fi
done
if [[ "$AZURE_TENANT_ID" != "$_configured_tenant_id" ||
      "$AZURE_SUBSCRIPTION_ID" != "$_configured_subscription_id" ]]; then
  printf 'ERROR: Generated Azure configuration is stale; run scripts/deploy.sh again.\n' >&2
  return 1
fi
if ! _apim_key="$(get_apim_subscription_key)"; then
  return 1
fi

export PATH="$HOME/.local/bin:$PATH"
export CLAUDE_CODE_USE_FOUNDRY=1
export ANTHROPIC_FOUNDRY_BASE_URL="$APIM_CLAUDE_BASE_URL"
export CLAUDE_CODE_SKIP_FOUNDRY_AUTH=1
export ANTHROPIC_CUSTOM_HEADERS="Ocp-Apim-Subscription-Key: ${_apim_key}"
unset ANTHROPIC_FOUNDRY_RESOURCE ANTHROPIC_FOUNDRY_API_KEY ANTHROPIC_FOUNDRY_AUTH_TOKEN
export ANTHROPIC_DEFAULT_OPUS_MODEL="$CLAUDE_DEPLOYMENT_NAME"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$CLAUDE_DEPLOYMENT_NAME"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$CLAUDE_DEPLOYMENT_NAME"
export ANTHROPIC_MODEL='opus'
export CLAUDE_CODE_DISABLE_AUTO_MEMORY=1

printf 'Claude Code APIM -> Foundry mode\n'
printf '  Gateway:    %s\n' "$APIM_CLAUDE_BASE_URL"
printf '  Deployment: %s\n' "$CLAUDE_DEPLOYMENT_NAME"
printf '  Client auth: Ocp-Apim-Subscription-Key\n'
printf '  Backend auth: APIM system-assigned managed identity\n'

unset _apim_key _configured_tenant_id _configured_subscription_id _name _script_dir
